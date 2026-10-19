(import re pathlib [Path] datetime [datetime time] zoneinfo [ZoneInfo] urllib.parse [urlsplit])
(import lispic.parser [parse-file])
(import lispic.model [Node Text ContentError fail plain])

(setv INLINE #{"em" "strong" "a" "code" "br"})
(setv TAGS #{"p" "h1" "h2" "h3" "h4" "h5" "h6" "em" "strong" "a" "ul" "ol" "li" "blockquote" "pre" "code" "br" "photo" "gallery"})
(setv ATTRS {"post" #{"id" "title" "slug" "published" "updated" "draft" "labels" "summary" "randomization"}
            "page" #{"id" "title" "slug"}
            "album" #{"id" "title" "slug" "photos" "reorder"}
            "photo" #{"id" "src" "alt" "caption" "gallery" "added" "taken" "ref"}
            "gallery" #{"photos"} "a" #{"href" "post" "title"} "p" #{"id"}})

(defn identifier [value pos]
  (when (or (not (isinstance value str)) (not (re.fullmatch "[a-z0-9]+(?:[-_][a-z0-9]+)*" value)))
    (fail pos f"Neplatný identifikátor nebo slug: {(repr value)}")))

(defn required [node keys]
  (for [key keys]
    (when (not (.get node.attrs key)) (fail node.pos f"Chybí :{key}"))))

(defn date-value [value pos cfg]
  (try
    (setv dt (datetime.fromisoformat value))
    (when (is dt.tzinfo None) (setv dt (.replace dt :tzinfo (ZoneInfo (get cfg "timezone")))))
    dt
    (except [e [ValueError TypeError]] (fail pos f"Neplatné datum {(repr value)}"))))

(defn safe-file [base relative pos]
  (when (not (isinstance relative str)) (fail pos "Cesta musí být řetězec"))
  (setv base (.resolve (Path base)) path (.resolve (/ base relative)))
  (when (not (.is-relative-to path base)) (fail pos "Cesta nesmí opustit zdrojový adresář"))
  (when (not (.is-file path)) (fail pos f"Soubor neexistuje: {path}"))
  path)

(defn walk [node]
  (yield node)
  (for [child node.children]
    (when (isinstance child Node) (yield :from (walk child)))))

(defn check-tree [node root]
  (for [n (walk node)]
    (when (and (is-not n node) (not (in n.name TAGS))) (fail n.pos f"Neznámý prvek {n.name}"))
    (when (in n.name ["p" "h1" "h2" "h3" "h4" "h5" "h6" "em" "strong" "a" "code" "photo"])
      (for [c n.children]
        (when (and (isinstance c Node) (not (in c.name INLINE)))
          (fail c.pos f"Prvek {c.name} nelze vložit do {n.name}"))))
    (when (in n.name ["ul" "ol"])
      (for [c n.children]
        (when (or (and (isinstance c Node) (!= c.name "li")) (and (isinstance c Text) (.strip c.value)))
          (fail c.pos "Seznam smí přímo obsahovat pouze li"))))
    (when (= n.name "a")
      (for [c (walk n)]
        (when (and (is-not c n) (= c.name "a")) (fail c.pos "Odkazy nelze vnořovat"))))
    (setv allowed (if (and (= n.name "photo") (is-not n node))
                    #{"ref" "src" "alt"} (.get ATTRS n.name #{})))
    (for [key n.attrs]
      (when (not (in key allowed)) (fail n.pos f"Nepovolený atribut :{key} v {n.name}")))
    (for [key ["id" "title" "slug" "published" "updated" "summary" "src" "alt" "caption" "added" "taken" "ref" "href" "post"]]
      (when (and (in key n.attrs) (not (isinstance (get n.attrs key) str))) (fail n.pos f":{key} musí být řetězec")))
    (for [key ["draft" "gallery" "reorder" "randomization"]]
      (when (and (in key n.attrs) (is-not (type (get n.attrs key)) bool)) (fail n.pos f":{key} musí být true nebo false")))
    (for [key ["labels" "photos"]]
      (when (in key n.attrs)
        (setv value (get n.attrs key))
        (when (or (not (isinstance value list)) (any (gfor v value (not (isinstance v str)))))
          (fail n.pos f":{key} musí být seznam řetězců"))))
    (when (= n.name "a")
      (when (= (bool (.get n.attrs "href")) (bool (.get n.attrs "post"))) (fail n.pos "Odkaz potřebuje právě jedno :href nebo :post"))
      (when (.get n.attrs "href")
        (setv href (get n.attrs "href") url (urlsplit href))
        (when (or (not (in url.scheme ["" "https" "http" "mailto"])) (.startswith href "//") (re.search "[\x00-\x20]" href))
          (fail n.pos "Nepovolená adresa odkazu"))))
    (when (and (= n.name "photo") (is-not n node))
      (when (= (bool (.get n.attrs "ref")) (bool (.get n.attrs "src"))) (fail n.pos "Fotografie potřebuje právě jedno :ref nebo :src"))
      (when (.get n.attrs "src") (required n ["alt"])))
    (when (= n.name "gallery") (required n ["photos"]))
    (when (and (= n.name "br") (or n.children n.attrs)) (fail n.pos "br nesmí mít obsah"))))

(defn load-content [cfg]
  (setv root (get cfg "root") sources (get cfg "sources") result {"posts" [] "pages" [] "albums" [] "photos" {} "post-map" {}})
  (for [[group kind] [["posts" "post"] ["pages" "page"] ["albums" "album"]]]
    (when (not (.is-dir (/ root (get sources group))))
      (raise (ContentError f"Chybí zdrojový adresář: {(/ root (get sources group))}")))
    (setv ids #{} slugs #{})
    (for [path (sorted (.rglob (/ root (get sources group)) "*.sexp"))]
      (setv nodes (parse-file path))
      (when (or (!= (len nodes) 1) (!= (. (get nodes 0) name) kind))
        (raise (ContentError f"{path}: očekáván jeden kořen {kind}")))
      (setv node (get nodes 0) attrs node.attrs)
      (check-tree node kind)
      (required node ["id" "title" "slug"])
      (for [[key seen] [["id" ids] ["slug" slugs]]]
        (identifier (get attrs key) node.pos)
        (when (in (get attrs key) seen) (fail node.pos f"Duplicitní :{key}"))
        (.add seen (get attrs key)))
      (setv record {"node" node "attrs" attrs "path" path})
      (when (= group "posts")
        (setv published (.get attrs "published"))
        (when (not published)
          (setv m (re.match "[0-9]{4}-[0-9]{2}-[0-9]{2}" path.name))
          (when (is m None) (fail node.pos "Chybí :published a datum v názvu souboru"))
          (setv published (.group m 0)))
        (setv (get record "published") (date-value published node.pos cfg))
        (setv (get record "updated") (date-value (.get attrs "updated" published) node.pos cfg))
        (for [label (.get attrs "labels" [])]
          (when (not (in label (get cfg "labels"))) (fail node.pos f"Neznámý label {label}")))
        (setv (get result "post-map" (get attrs "id")) record))
      (.append (get result group) record)))
  (for [node (parse-file (/ root (get sources "catalog")))]
    (when (!= node.name "photo") (fail node.pos "V katalogu je povoleno pouze photo"))
    (check-tree node "photo")
    (when (or (in "ref" node.attrs) (any (gfor c node.children (or (isinstance c Node) (.strip c.value)))))
      (fail node.pos "Katalogová fotografie má metadata, nikoliv :ref nebo tělo"))
    (required node ["id" "src" "alt"])
    (setv a node.attrs id (get a "id"))
    (identifier id node.pos)
    (when (in id (get result "photos")) (fail node.pos f"Duplicitní fotografie {id}"))
    (setv rec {"node" node "attrs" a "path" (safe-file (/ root (get sources "originals")) (get a "src") node.pos)})
    (when (.get a "gallery" False)
      (required node ["added"])
      (setv (get rec "added") (date-value (get a "added") node.pos cfg)))
    (when (.get a "taken") (date-value (get a "taken") node.pos cfg))
    (setv (get result "photos" id) rec))
  
  (for [group ["posts" "pages" "albums"] record (get result group)]
    (setv node (get record "node"))
    (when (= group "albums") (required node ["photos"]))
    (for [n (walk node)]
      (when (.get n.attrs "post")
        (setv id (get n.attrs "post") target (.get (get result "post-map") id))
        (when (is target None) (fail n.pos f"Neexistující článek {id}"))
        (when (and (not (.get node.attrs "draft" False)) (.get (get target "attrs") "draft" False))
          (fail n.pos f"Veřejný obsah odkazuje na koncept {id}")))
      (setv refs [])
      (when (.get n.attrs "ref") (.append refs (get n.attrs "ref")))
      (when (in n.name ["gallery" "album"]) (.extend refs (.get n.attrs "photos" [])))
      (for [id refs]
        (when (not (in id (get result "photos"))) (fail n.pos f"Neexistující fotografie {id}"))
        (when (and (= group "albums") (not (.get (get result "photos" id "attrs") "gallery" False)))
          (fail n.pos f"Album odkazuje na neveřejnou fotografii {id}")))
      (when (and (= n.name "photo") (.get n.attrs "src"))
        (when (= group "albums") (fail n.pos "Album může obsahovat pouze veřejné katalogové fotografie přes :ref"))
        (safe-file (. (get record "path") parent) (get n.attrs "src") n.pos))))
  (setv (get result "posts") (sorted (get result "posts") :key (fn [r] #((- (.timestamp (get r "published"))) (str (get r "path"))))))
  result)
