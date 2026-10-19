"Select plain-text excerpts and the first photo without rendering a complete article."
(import re)
(import lispic.model [Text plain])

(defn paragraph-text [node]
  "Extract inline text while omitting photos, galleries, preformatted blocks, and code."
  (if (isinstance node Text) node.value
    (if (in node.name ["photo" "gallery" "pre" "code"]) ""
      (.join "" (gfor c node.children (paragraph-text c))))))

(defn paragraphs [node]
  "Yield normalized ordinary paragraphs directly inside a post or page."
  (when (not (isinstance node Text))
    (cond
      (= node.name "p") (yield (.strip (re.sub "\\s+" " " (paragraph-text node))))
      (in node.name ["post" "page"]) (for [c node.children] (yield :from (paragraphs c))))))

(defn summary [record]
  "Use a manual summary or choose an approximately 500-character paragraph/sentence excerpt."
  (setv attrs (get record "attrs"))
  (when (in "summary" attrs) (return (get attrs "summary")))
  (setv parts (list (paragraphs (get record "node"))) text (.join " " parts))
  (when (<= (len text) 500) (return text))
  (setv boundaries [] offset 0)
  (for [part parts]
    (+= offset (len part))
    (when (<= 300 offset 650) (.append boundaries offset))
    (+= offset 1))
  ;; Treat common Czech abbreviations, initials, and numeric periods as
  ;; continuations rather than sentence endings. This is intentionally heuristic.
  (for [m (re.finditer "[.!?](?:[\"”’])?(?=\\s|$)" text)]
    (setv end (.end m) before (cut text 0 end)
          word (.lower (get (.split before) -1)))
    (when (and (<= 300 end 650)
               (not (in word ["např." "tj." "tzn." "atd." "apod." "tzv." "resp." "č." "str." "ing." "mgr." "dr." "prof." "cca."]))
               (not (re.search "(?:\\d|\\b[A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ])\\.$" before)))
      (.append boundaries end)))
  ;; Choose the nearest acceptable ending; an unbroken token falls back to
  ;; a character limit because there is no word boundary available.
  (if boundaries
    (cut text 0 (min boundaries :key (fn [n] (abs (- n 500)))))
    (do (setv boundary (.rfind text " " 0 501))
        (+ (.rstrip (cut text 0 (if (> boundary 0) boundary 500))) "…"))))

(defn first-photo [node]
  "Find the first photo in content order, treating a gallery as its first photo reference."
  (when (isinstance node Text) (return None))
  (when (= node.name "photo") (return node))
  (when (= node.name "gallery")
    (import lispic.model [Node])
    (return (Node "photo" {"ref" (get node.attrs "photos" 0)} [] node.pos)))
  (for [child node.children]
    (setv found (first-photo child))
    (when found (return found)))
  None)
