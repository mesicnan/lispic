"Create orientation-correct, metadata-free web variants backed by a content-addressed cache."
(import hashlib json io shutil pathlib [Path])
(import PIL [Image ImageOps ImageCms __version__])
(import lispic.model [ContentError])
;; Bump this value when conversion behavior changes, to invalidate old variants.
(setv PIPELINE "lispic-images-1")

(defn process-image [path options cache]
  "Return cached or newly generated variant metadata after orientation and sRGB conversion."
  ;; Content and conversion settings determine identity; file paths and text
  ;; metadata do not. Pillow versions are included because encoders may change.
  (setv digest (hashlib.sha256 (.read-bytes (Path path))))
  (.update digest (.encode (json.dumps [PIPELINE __version__ options] :sort-keys True)))
  (setv key (.hexdigest digest) folder (/ (Path cache) key) manifest (/ folder "manifest.json"))
  (when (.is-file manifest)
    (setv existing (json.loads (.read-text manifest)))
    (when (all (gfor v (get existing "variants") (.is-file (/ folder (get v "file")))))
      (return existing)))
  (.mkdir folder :parents True :exist-ok True)
  (with [raw (Image.open path)]
    ;; Orientation must be applied before measuring ratios or resizing.
    (setv im (ImageOps.exif-transpose raw) profile (.get im.info "icc_profile"))
    (when profile
      (try
        (setv im (ImageCms.profileToProfile im (ImageCms.ImageCmsProfile (io.BytesIO profile)) (ImageCms.createProfile "sRGB") :outputMode "RGB"))
        (except [e Exception] (raise (ContentError f"{path}: nelze převést ICC profil do sRGB: {e}")))))
    (when (in im.mode ["RGBA" "LA" "P"])
      (setv rgba (.convert im "RGBA") background (Image.new "RGB" im.size "white"))
      (.paste background rgba :mask (.getchannel rgba "A"))
      (setv im background))
    ;; Without an ICC profile, interpret RGB pixels as sRGB. Transparency is
    ;; flattened above so JPEG and WebP variants use the same background.
    (setv im (.convert im "RGB") width im.width height im.height variants [])
    ;; Discard inherited metadata, including GPS, rather than copying EXIF
    ;; into derived public files. The pixels have already been color-converted.
    (.clear im.info)
    ;; Clamp and deduplicate long-edge targets before encoding small originals.
    (for [size (sorted (set (gfor n (get options "sizes") (min n (max width height)))))]
      (setv variant (.copy im))
      (.thumbnail variant #(size size) Image.Resampling.LANCZOS)
      (for [[ext quality] (+ [["jpg" (get options "jpeg-quality")]] (if (get options "webp") [["webp" (get options "webp-quality")]] []))]
        (setv filename f"{size}.{ext}")
        (.save variant (/ folder filename) :quality quality)
        (.append variants {"file" filename "width" variant.width "height" variant.height "format" ext})))
    (setv result {"key" key "width" width "height" height "variants" variants})
    (.write-text manifest (json.dumps result) :encoding "utf-8")
    result))

(defn publish-image [image cache output]
  "Copy only image variants from the cache into output/media/<content-key>."
  (setv target (/ (Path output) "media" (get image "key")))
  (.mkdir target :parents True :exist-ok True)
  (for [v (get image "variants")]
    (shutil.copyfile (/ (Path cache) (get image "key") (get v "file")) (/ target (get v "file")))))
