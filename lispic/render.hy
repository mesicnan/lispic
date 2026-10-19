(import html json datetime [datetime] zoneinfo [ZoneInfo])
(import lispic.model [Text Node plain])
(import lispic.typography [paragraph-style])
(import lispic.excerpts [summary])

(defn esc [value] (html.escape (str value) :quote True))
(defn attrs-html [attrs]
  (.join "" (gfor [key value] (.items attrs) f" {key}=\"{(esc value)}\"")))
(defn public-href [href cfg]
  (for [[production local] (.items (.get cfg "preview-origins" {}))]
    (when (or (= href production) (.startswith href (+ production "/")) (.startswith href (+ production "?")) (.startswith href (+ production "#")))
      (return (+ local (cut href (len production) None)))))
  href)

(defn post-url [record cfg] (+ (get cfg "blog" "url") "/clanky/" (get record "attrs" "slug") "/"))
(defn photo-url [id cfg] (+ (get cfg "gallery" "url") "/foto/" id "/"))
(defn media-url [image variant cfg]
  (+ (get cfg (get image "site") "url") "/media/" (get image "key") "/" (get variant "file")))

(defn image-tag [image alt cfg [small False]]
  (setv jpg (lfor v (get image "variants") :if (= (get v "format") "jpg") v)
        webp (lfor v (get image "variants") :if (= (get v "format") "webp") v)
        default (get jpg (min 1 (- (len jpg) 1))))
  (defn srcset [variants] (.join ", " (gfor v variants f"{(media-url image v cfg)} {(get v "width")}w")))
  (setv sizes "(max-width: 700px) 100vw, 70vw")
  (setv img (+ "<img" (attrs-html {"src" (media-url image (if small (get jpg 0) default) cfg)
       "alt" alt "width" (get default "width") "height" (get default "height")
       "loading" "lazy" "decoding" "async"})
       (if small "" (attrs-html {"srcset" (srcset jpg) "sizes" sizes})) ">"))
  (if (or small (not webp)) img
    (+ "<picture><source type=\"image/webp\"" (attrs-html {"srcset" (srcset webp) "sizes" sizes}) ">" img "</picture>")))

(defn photo-data [node record data]
  (if (.get node.attrs "ref")
    (do
      (setv rec (get data "photos" (get node.attrs "ref")))
      [(get rec "image") (.get node.attrs "alt" (get rec "attrs" "alt")) rec])
    [(get data "inline" #((str (get record "path")) (get node.attrs "src"))) (get node.attrs "alt") None]))

(defn photo-anchor [image alt cfg [detail None]]
  (setv largest (get (lfor v (get image "variants") :if (= (get v "format") "jpg") v) -1)
        source (media-url image largest cfg)
        attrs {"class" "zoom" "href" (or detail source) "data-pswp-src" source
               "data-pswp-width" (get largest "width") "data-pswp-height" (get largest "height")})
  (+ "<a" (attrs-html attrs) ">" (image-tag image alt cfg) "</a>"))

(defn grid [ids data cfg [reorder False] [days False]]
  (setv options (dict (get cfg "layout")))
  (setv (get options "reorder") reorder)
  (setv out (+ "<div class=\"photo-grid lightbox\"" (attrs-html {"data-layout" (json.dumps options)}) ">"))
  (for [id ids]
    (setv rec (get data "photos" id) image (get rec "image") a (get rec "attrs")
          day (if (and days (.get rec "added")) (.isoformat (.date (.astimezone (get rec "added") (ZoneInfo (get cfg "timezone"))))) "")
          detail (if (.get a "gallery" False) (photo-url id cfg) None))
    (+= out (+ "<div class=\"tile\"" (attrs-html {"data-ratio" (/ (get image "width") (get image "height")) "data-day" day}) ">"
               (photo-anchor image (get a "alt") cfg detail) "</div>")))
  (+ out "</div>"))

(defn render-node [node record data cfg [randomize False]]
  (when (isinstance node Text) (return (esc node.value)))
  (setv name node.name)
  (when (= name "gallery") (return (grid (get node.attrs "photos") data cfg)))
  (when (= name "photo")
    (setv [image alt rec] (photo-data node record data)
          caption (if (.strip (plain node)) (.join "" (gfor c node.children (render-node c record data cfg False)))
                    (if rec (esc (.get (get rec "attrs") "caption" "")) "")))
    (return (+ "<figure class=\"lightbox\">" (photo-anchor image alt cfg)
      (if caption (+ "<figcaption>" caption "</figcaption>") "")
      (if (and rec (.get (get rec "attrs") "gallery" False))
        (+ "<a class=\"detail\" href=\"" (esc (photo-url (get rec "attrs" "id") cfg)) "\">Detail fotografie →</a>") "") "</figure>")))
  (setv attrs {})
  (when (= name "a")
    (setv (get attrs "href") (if (.get node.attrs "post") (post-url (get data "post-map" (get node.attrs "post")) cfg) (public-href (get node.attrs "href") cfg)))
    (when (.get node.attrs "title") (setv (get attrs "title") (get node.attrs "title"))))
  (when (and (= name "p") randomize)
    (setv (get attrs "class") "varied" (get attrs "style") (paragraph-style node (get record "attrs" "id") (get cfg "randomization"))))
  (when (= name "br") (return "<br>"))
  (+ "<" name (attrs-html attrs) ">"
     (.join "" (gfor c node.children (render-node c record data cfg randomize)))
     "</" name ">"))

(defn body [record data cfg]
  (setv node (get record "node") randomize (and (= node.name "post") (.get node.attrs "randomization" (get cfg "randomization" "enabled"))))
  (.join "" (gfor c node.children (render-node c record data cfg randomize))))

(defn labels [record cfg]
  (.join " " (gfor label (.get (get record "attrs") "labels" [])
    (+ "<a class=\"label\" href=\"" (esc (+ (get cfg "blog" "url") "/labels/" label "/")) "\">" (esc (get cfg "labels" label)) "</a>"))))

(defn listing [records cfg]
  (.join "" (gfor r records
    (+ "<article class=\"post-card\"><time>" (esc (.strftime (get r "published") "%d. %m. %Y")) "</time><h2><a href=\"" (esc (post-url r cfg)) "\">"
       (esc (get r "attrs" "title")) "</a></h2><p>" (esc (summary r)) "</p>" (labels r cfg) "</article>"))))

(defn document [title content site cfg data [canonical "/"]]
  (setv blog (get cfg "blog" "url") gallery (get cfg "gallery" "url")
        nav (+ "<a href=\"" (esc blog) "/\">Zápisník</a><a href=\"" (esc gallery) "/\">Fotografie</a><a href=\"" (esc gallery) "/alba/\">Alba</a>"))
  (for [page (get data "pages")]
    (+= nav (+ "<a href=\"" (esc (+ blog "/stranky/" (get page "attrs" "slug") "/")) "\">" (esc (get page "attrs" "title")) "</a>")))
  (for [item (get cfg "appearance" "navigation")]
    (+= nav (+ "<a href=\"" (esc (public-href (get item "href") cfg)) "\">" (esc (get item "title")) "</a>")))
  (setv sidebar "")
  (when (= site "blog")
    (setv sidebar "<aside><h2>Labely</h2><ul>")
    (for [[id name] (.items (get cfg "labels"))]
      (setv count (sum (gfor p (get data "public-posts") (int (in id (.get (get p "attrs") "labels" []))))))
      (+= sidebar (+ "<li><a href=\"/labels/" (esc id) "/\">" (esc name) f" <span>({count})</span></a></li>")))
    (+= sidebar "</ul><a href=\"/archiv/\">Archiv</a><p><a href=\"/atom.xml\">Atom</a> · <a href=\"/rss.xml\">RSS</a></p></aside>"))
  (+ "<!doctype html><html lang=\"" (esc (get cfg "language")) "\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
    "<title>" (esc title) " · " (esc (get cfg site "title")) "</title><link rel=\"canonical\" href=\"" (esc (+ (get cfg site "url") canonical)) "\">"
    "<link rel=\"stylesheet\" href=\"/assets/style.css\"><link rel=\"stylesheet\" href=\"/assets/theme.css\"><link rel=\"stylesheet\" href=\"/assets/photoswipe.css\">"
    (if (= site "blog") "<link rel=\"alternate\" type=\"application/atom+xml\" href=\"/atom.xml\" title=\"Atom\"><link rel=\"alternate\" type=\"application/rss+xml\" href=\"/rss.xml\" title=\"RSS\">" "")
    "<script type=\"module\" src=\"/assets/gallery.js\"></script></head><body class=\"" site "\"><a class=\"skip\" href=\"#content\">Přejít na obsah</a><header><a class=\"brand\" href=\"/\">"
    (esc (get cfg site "title")) "</a><nav>" nav "</nav></header><div class=\"shell\"><main id=\"content\">" content "</main>" sidebar "</div><footer>"
    (esc (get cfg "author")) " · Vytvořeno pomocí Lispic</footer></body></html>"))
