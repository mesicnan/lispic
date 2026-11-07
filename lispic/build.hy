"Coordinate validation, image publication, page generation, and replacement of both outputs."
(import json shutil tempfile pathlib [Path] datetime [datetime] zoneinfo [ZoneInfo])
(import lispic.config [load-config])
(import lispic.validation [load-content walk safe-file])
(import lispic.images [process-image publish-image])
(import lispic.model [ContentError])
(import lispic.render [document body listing labels grid photo-anchor esc photo-url])
(import lispic.feeds [write-feeds])

;; These files belong to the destination repository, not generated web content.
(setv REPOSITORY-FILES #{".git" ".gitignore" ".gitattributes"})

(defn publish-output [stage output]
  "Replace generated children while preserving repository metadata and configuration."
  (.mkdir output :parents True :exist-ok True)
  ;; Keep the output directory itself and .git in place. This also preserves
  ;; worktree .git files whose relative paths depend on the checkout location.
  (for [path (.iterdir output)]
    (when (not (in path.name REPOSITORY-FILES))
      (if (and (.is-dir path) (not (.is-symlink path)))
        (shutil.rmtree path)
        (.unlink path))))
  (for [path (.iterdir stage)] (.replace path (/ output path.name))))

(defn write-page [output route title content site cfg data]
  "Write a complete UTF-8 document at the directory-index path for route."
  (setv path (/ output (.lstrip route "/") "index.html"))
  (.mkdir path.parent :parents True :exist-ok True)
  (.write-text path (document title content site cfg data route) :encoding "utf-8"))

(defn paginate [items count]
  "Split items into fixed-size pages, retaining one empty page for an empty collection."
  (or (lfor i (range 0 (len items) count) (cut items i (+ i count))) [[]]))
(defn pager [index total base]
  "Render previous/next links for a zero-based page index under base."
  (defn route [n]
    "Map a zero-based page index to the first-page or numbered-page route."
    (if (= n 0) base (+ base "strana/" (str (+ n 1)) "/")))
  (+ "<nav class=\"pagination\" aria-label=\"Stránkování\">"
     (if (> index 0) (+ "<a href=\"" (route (- index 1)) "\">← Novější</a>") "")
     f"<span>{(+ index 1)} / {total}</span>"
     (if (< index (- total 1)) (+ "<a href=\"" (route (+ index 1)) "\">Starší →</a>") "") "</nav>"))

(defn output-paths [cfg]
  "Resolve separate output directories and refuse overlapping or unowned destinations."
  (setv root (get cfg "root") outputs (dfor site ["blog" "gallery"] site (.resolve (/ root (get cfg site "output")))))
  (setv protected [root])
  (for [[key value] (.items (get cfg "sources"))] (.append protected (.resolve (/ root value))))
  (for [output (.values outputs)]
    (when (= output output.parent) (raise (ContentError "Výstup nesmí být kořen souborového systému")))
    (for [source protected]
      (when (or (= output source) (.is-relative-to source output))
        (raise (ContentError f"Nebezpečný výstupní adresář {output}"))))
    (for [[key value] (.items (get cfg "sources"))]
      (when (.is-relative-to output (.resolve (/ root value))) (raise (ContentError "Výstup nesmí ležet ve zdrojích nebo cache")))))
  (setv a (get outputs "blog") b (get outputs "gallery"))
  (when (or (.is-relative-to a b) (.is-relative-to b a)) (raise (ContentError "Výstupy webů se nesmí překrývat")))
  ;; A fresh repository can contain its Git files before the first build.
  ;; Other content requires the ownership marker written by a previous build.
  (for [output (.values outputs)]
    (when (and (.exists output) (any (gfor path (.iterdir output) (not (in path.name REPOSITORY-FILES)))) (not (.is-file (/ output ".lispic-output"))))
      (raise (ContentError f"Výstup {output} obsahuje cizí soubory; zvol prázdný adresář"))))
  outputs)

(defn build [cfg [check-only False]]
  "Validate both sites or generate them in staging directories, then replace old output."
  (setv outputs (output-paths cfg) data (load-content cfg)
        root (get cfg "root") cache (/ root (get cfg "sources" "cache")))
  (setv (get data "public-posts") (lfor p (get data "posts") :if (not (.get (get p "attrs") "draft" False)) p)
        (get data "inline") {})
  ;; Check inspects image files without generating variants, output, or cache.
  (when check-only
    (import PIL [Image])
    (setv paths (lfor r (.values (get data "photos")) (get r "path")))
    (for [group ["posts" "pages" "albums"] r (get data group) n (walk (get r "node"))]
      (when (and (= n.name "photo") (.get n.attrs "src"))
        (.append paths (safe-file (. (get r "path") parent) (get n.attrs "src") n.pos))))
    (for [path paths] (with [im (Image.open path)] (.verify im)))
    (return data))
  (setv stages {})
  (for [[site output] (.items outputs)]
    (.mkdir output.parent :parents True :exist-ok True)
    (setv stage (Path (tempfile.mkdtemp :prefix (+ ".lispic-" site "-") :dir output.parent)))
    (setv (get stages site) stage))
  (try
    (for [[id rec] (.items (get data "photos"))]
      ;; Non-gallery catalog images are processed only if referenced publicly.
      (setv public (.get (get rec "attrs") "gallery" False) used public)
      (when (not used)
        (for [group ["public-posts" "pages"] r (get data group) n (walk (get r "node"))]
          (when (or (= (.get n.attrs "ref") id) (in id (.get n.attrs "photos" []))) (setv used True))))
      (when used
        (setv image (process-image (get rec "path") (get cfg "images") cache)
              site (if public "gallery" "blog")
              (get image "site") site
              (get rec "image") image)
        (publish-image image cache (get stages site))))
    ;; Inline sources use a (document path, relative source) lookup key because
    ;; identical relative paths in different documents can refer to different files.
    (for [group ["public-posts" "pages" "albums"] r (get data group) n (walk (get r "node"))]
      (when (and (= n.name "photo") (.get n.attrs "src"))
        (setv path (safe-file (. (get r "path") parent) (get n.attrs "src") n.pos)
              image (process-image path (get cfg "images") cache)
              (get image "site") "blog"
              (get data "inline" #((str (get r "path")) (get n.attrs "src"))) image)
        (publish-image image cache (get stages "blog"))))
    (setv static (/ (. (Path __file__) parent) "static"))
    (for [[site stage] (.items stages)]
      (shutil.copytree static (/ stage "assets"))
      (setv appearance (get cfg "appearance") random (get cfg "randomization"))
      (.write-text (/ stage "assets/theme.css")
        (+ ":root{" (.join "" (gfor [key value] (.items {"bg" (get appearance "background") "fg" (get appearance "foreground") "accent" (get appearance "accent") "text-width" (get appearance "text-width") "leading" (get random "line-height")}) f"--{key}:{value};")) "}") :encoding "utf-8")
      (.write-text (/ stage ".lispic-output") "Generated by Lispic\n"))
    (setv blog (get stages "blog") gallery (get stages "gallery") posts (get data "public-posts"))
    (defn post-list [records base title]
      "Generate all pages of a blog index, archive, or label listing."
      (setv chunks (paginate records (get cfg "blog" "per-page")))
      (for [[index chunk] (enumerate chunks)]
        (setv route (if (= index 0) base (+ base "strana/" (str (+ index 1)) "/")))
        (write-page blog route title (+ "<h1>" (esc title) "</h1>" (listing chunk cfg) (pager index (len chunks) base)) "blog" cfg data)))
    (post-list posts "/" (get cfg "blog" "title"))
    (post-list posts "/archiv/" "Archiv")
    (for [[id name] (.items (get cfg "labels"))]
      (post-list (lfor p posts :if (in id (.get (get p "attrs") "labels" [])) p) (+ "/labels/" id "/") name))
    (for [r posts]
      (setv a (get r "attrs") route (+ "/clanky/" (get a "slug") "/"))
      (write-page blog route (get a "title")
        (+ "<article class=\"prose\"><h1>" (esc (get a "title")) "</h1><div class=\"meta\"><time>" (.strftime (get r "published") "%d. %m. %Y") "</time> " (labels r cfg) "</div>" (body r data cfg) "</article>") "blog" cfg data))
    (for [r (get data "pages")]
      (write-page blog (+ "/stranky/" (get r "attrs" "slug") "/") (get r "attrs" "title")
        (+ "<article class=\"prose\"><h1>" (esc (get r "attrs" "title")) "</h1>" (body r data cfg) "</article>") "blog" cfg data))
    (setv photos (sorted (lfor [id r] (.items (get data "photos")) :if (.get (get r "attrs") "gallery" False) id)
                  :key (fn [id] #((- (.timestamp (get data "photos" id "added"))) id)))
          chunks (paginate photos (get cfg "gallery" "per-page")))
    (for [[index chunk] (enumerate chunks)]
      (setv route (if (= index 0) "/" (+ "/strana/" (str (+ index 1)) "/")))
      (write-page gallery route "Fotografie" (+ "<h1>Fotografie</h1>" (grid chunk data cfg (get cfg "layout" "reorder") True) (pager index (len chunks) "/")) "gallery" cfg data))
    (for [id photos]
      (setv r (get data "photos" id) a (get r "attrs") title (.get a "caption" (get a "alt")))
      (write-page gallery (+ "/foto/" id "/") title
        (+ "<h1>" (esc title) "</h1><figure class=\"lightbox photo-detail\">" (photo-anchor (get r "image") (get a "alt") cfg) "<figcaption>" (esc (.get a "caption" "")) "</figcaption></figure><p>"
           (if (.get a "taken") (+ "Pořízeno: " (esc (get a "taken")) " · ") "") "Přidáno: " (esc (.strftime (get r "added") "%d. %m. %Y")) "</p>") "gallery" cfg data))
    (setv album-list "<h1>Alba</h1><ul class=\"albums\">")
    (for [r (get data "albums")]
      (setv a (get r "attrs") route (+ "/alba/" (get a "slug") "/"))
      (+= album-list (+ "<li><a href=\"" route "\">" (esc (get a "title")) "</a></li>"))
      (write-page gallery route (get a "title") (+ "<h1>" (esc (get a "title")) "</h1><div class=\"prose\">" (body r data cfg) "</div>" (grid (get a "photos") data cfg (.get a "reorder" False))) "gallery" cfg data))
    (write-page gallery "/alba/" "Alba" (+ album-list "</ul>") "gallery" cfg data)
    (write-feeds data cfg blog)
    ;; Publish only after both sites render successfully. Remove stale generated
    ;; content but preserve destination Git metadata and repository settings.
    ;; Publication is not transactional in the event of a filesystem failure.
    (for [[site output] (.items outputs)]
      (publish-output (get stages site) output))
    (finally
      (for [stage (.values stages)] (when (.exists stage) (shutil.rmtree stage)))))
  data)
