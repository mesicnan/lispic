(import hashlib json re)
(import lispic.model [Text])

(defn canonical [node]
  (if (isinstance node Text) (re.sub "\\s+" " " node.value)
    [node.name node.attrs (lfor c node.children (canonical c))]))

(defn paragraph-style [node post-id options]
  (setv identity (.get node.attrs "id" (json.dumps (canonical node) :sort-keys True :ensure-ascii False)))
  (defn number [name low high]
    (setv data (json.dumps [(get options "seed") post-id identity name] :ensure-ascii False)
          digest (.digest (hashlib.sha256 (.encode data)))
          fraction (/ (int.from-bytes (cut digest 0 8) "big") (- (** 2 64) 1)))
    (+ low (* fraction (- high low))))
  (setv left (number "left" 0 (get options "margin")) right (number "right" 0 (get options "margin"))
        mobile-left (number "left" 0 (get options "mobile-margin")) mobile-right (number "right" 0 (get options "mobile-margin"))
        font (/ (number "font" (get options "font-min") (get options "font-max")) 100))
  f"--pl:{left :.4f}%;--pr:{right :.4f}%;--pml:{mobile-left :.4f}%;--pmr:{mobile-right :.4f}%;--pf:{font :.5f}rem")
