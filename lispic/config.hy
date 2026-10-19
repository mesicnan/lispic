"Load data-only site settings, merge defaults, and validate values before building."
(import copy pathlib [Path] zoneinfo [ZoneInfo] urllib.parse [urlsplit])
(import lispic.parser [parse-data])
(import lispic.model [ContentError])

(setv DEFAULTS
  {"language" "cs" "timezone" "Europe/Prague" "author" "Fotograf"
   "blog" {"url" "https://blog.example.cz" "title" "Zápisník" "output" "dist/blog" "identity" "urn:lispic:my-blog" "per-page" 12}
   "gallery" {"url" "https://foto.example.cz" "title" "Fotografie" "output" "dist/gallery" "per-page" 60}
   "sources" {"posts" "content/posts" "pages" "content/pages" "albums" "content/albums" "catalog" "content/photos.sexp" "originals" "originals" "cache" ".cache/lispic"}
   "labels" {}
   "images" {"sizes" [480 960 1600 2400] "jpeg-quality" 88 "webp-quality" 85 "webp" True}
   "layout" {"gap" 0 "target-height" 260 "tall-ratio" 2.5 "lookahead" 6 "tall-min-width" 700 "reorder" False "local-lookahead" 3 "group-limit" 12 "min-height-factor" 0.5 "max-height-factor" 1.8 "max-score" 1.1}
   "feeds" {"count" 20}
   "randomization" {"enabled" True "seed" "lispic-1" "margin" 3 "mobile-margin" 1 "font-min" 98 "font-max" 102 "line-height" 1.7}
   "appearance" {"background" "#141618" "foreground" "#e4e1db" "accent" "#d2b98a" "text-width" "44rem" "navigation" []}})

(defn merge [base override]
  "Return a deep copy of base with known overrides; empty dictionaries are open registries."
  (when (not (isinstance override dict)) (raise (ContentError "Očekáván konfigurační slovník")))
  (setv result (copy.deepcopy base))
  (for [[key value] (.items override)]
    (when (not (in key base)) (raise (ContentError f"Neznámá konfigurace :{key}")))
    (when (and (isinstance (get base key) dict) (not (isinstance value dict)))
      (raise (ContentError f":{key} musí být slovník")))
    (when (and (isinstance (get base key) list) (not (isinstance value list)))
      (raise (ContentError f":{key} musí být seznam")))
    ;; Nonempty defaults describe a fixed schema; an empty registry (labels)
    ;; accepts user-defined keys instead of treating them as unknown settings.
    (setv (get result key)
      (if (and (isinstance value dict) (isinstance (get base key) dict) (get base key))
        (merge (get base key) value) value)))
  result)

(defn load-config [path]
  "Load and validate site.sexp, normalize origins, and attach its parent directory as root."
  (setv path (.resolve (Path path)) raw (parse-data (.read-text path :encoding "utf-8") path))
  (when (not (isinstance raw dict)) (raise (ContentError "Konfigurace musí být slovník")))
  (setv cfg (merge DEFAULTS raw))
  (validate-settings cfg)
  (ZoneInfo (get cfg "timezone"))
  (for [site ["blog" "gallery"]]
    (setv data (get cfg site) url (urlsplit (get data "url")))
    (when (or (not (in url.scheme ["http" "https"])) (not url.netloc) (not (in url.path ["" "/"])) url.query url.fragment)
      (raise (ContentError f"{site}: URL musí být HTTP(S) origin bez cesty")))
    (setv (get data "url") (.rstrip (get data "url") "/"))
    (when (or (not (isinstance (get data "per-page") int)) (< (get data "per-page") 1))
      (raise (ContentError "Stránkování musí být kladné celé číslo"))))
  (for [key ["jpeg-quality" "webp-quality"]]
    (when (not (<= 1 (get cfg "images" key) 100)) (raise (ContentError f"{key}: očekáváno 1–100"))))
  (when (or (not (get cfg "images" "sizes")) (any (gfor n (get cfg "images" "sizes") (or (is-not (type n) int) (< n 1)))))
    (raise (ContentError "Velikosti obrázků musí být kladná celá čísla")))
  (when (< (get cfg "feeds" "count") 1) (raise (ContentError "Počet položek feedu musí být kladný")))
  (for [key ["gap" "lookahead"]]
    (when (< (get cfg "layout" key) 0) (raise (ContentError f"{key} nesmí být záporné"))))
  (for [key ["target-height" "tall-ratio" "tall-min-width" "min-height-factor" "max-height-factor" "max-score"]]
    (when (<= (get cfg "layout" key) 0) (raise (ContentError f"{key} musí být kladné"))))
  (setv (get cfg "root") path.parent)
  cfg)

(defn validate-settings [cfg]
  "Validate types and ranges before rendering CSS or touching output paths."
  (import re)
  (defn error [message]
    "Raise a configuration error with the shared diagnostic prefix."
    (raise (ContentError (+ "Konfigurace: " message))))
  (for [key ["language" "timezone" "author"]]
    (when (or (not (isinstance (get cfg key) str)) (not (get cfg key))) (error f":{key} musí být neprázdný řetězec")))
  (for [section ["blog" "gallery"] key ["title" "url" "output"]]
    (when (not (isinstance (get cfg section key) str)) (error f":{section} :{key} musí být řetězec")))
  (for [[key value] (.items (get cfg "sources"))]
    (when (or (not (isinstance value str)) (not value)) (error f"Cesta :{key} musí být neprázdný řetězec")))
  (for [[id label] (.items (get cfg "labels"))]
    (when (or (not (re.fullmatch "[a-z0-9]+(?:[-_][a-z0-9]+)*" id)) (not (isinstance label str)))
      (error f"Neplatný label {id}")))
  (for [[section key] [["images" "webp"] ["layout" "reorder"] ["randomization" "enabled"]]]
    (when (is-not (type (get cfg section key)) bool) (error f":{section} :{key} musí být true nebo false")))
  (for [[section keys] [["layout" ["gap" "target-height" "tall-ratio" "tall-min-width" "min-height-factor" "max-height-factor" "max-score"]]
                        ["randomization" ["margin" "mobile-margin" "font-min" "font-max" "line-height"]]]]
    (for [key keys]
      (when (or (not (isinstance (get cfg section key) #(int float))) (isinstance (get cfg section key) bool))
        (error f":{section} :{key} musí být číslo"))))
  (for [[section key] [["blog" "per-page"] ["gallery" "per-page"] ["feeds" "count"] ["layout" "lookahead"] ["layout" "local-lookahead"] ["layout" "group-limit"]]]
    (when (is-not (type (get cfg section key)) int) (error f":{section} :{key} musí být celé číslo")))
  (when (or (< (get cfg "layout" "local-lookahead") 0) (< (get cfg "layout" "group-limit") 3)
            (> (get cfg "layout" "min-height-factor") (get cfg "layout" "max-height-factor")))
    (error "Neplatné parametry místních přesunů"))
  (when (= (get cfg "blog" "url") (get cfg "gallery" "url")) (error "Oba weby musí mít různé URL"))
  (setv r (get cfg "randomization"))
  (when (or (not (<= 0 (get r "margin") 20)) (not (<= 0 (get r "mobile-margin") 20))
            (not (<= 50 (get r "font-min") (get r "font-max") 200)) (<= (get r "line-height") 0))
    (error "Neplatné rozsahy randomizace"))
  (setv identity (get cfg "blog" "identity"))
  (when (or (not (isinstance identity str)) (not (. (urlsplit identity) scheme)))
    (error ":blog :identity musí být stabilní URI, např. urn:lispic:moje-jmeno"))
  (for [key ["background" "foreground" "accent"]]
    (when (not (re.fullmatch "#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?" (get cfg "appearance" key)))
      (error f"Barva :{key} musí být #RGB nebo #RRGGBB")))
  (when (not (re.fullmatch "[0-9]+(?:\\.[0-9]+)?(?:rem|em|px|ch)" (get cfg "appearance" "text-width")))
    (error ":text-width musí být délka v rem, em, px nebo ch"))
  (for [item (get cfg "appearance" "navigation")]
    (when (or (not (isinstance item dict)) (!= (set item) #{"title" "href"})) (error "Navigace očekává {:title ... :href ...}"))
    (setv href (get item "href"))
    (when (or (not (in (. (urlsplit href) scheme) ["" "http" "https" "mailto"])) (.startswith href "//") (re.search "[\x00-\x20]" href))
      (error "Nepovolená URL v navigaci")))
  cfg)
