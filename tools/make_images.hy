"Regenerate labelled technical fixtures, not photographs."
(import argparse pathlib [Path] PIL [Image ImageDraw ImageFont])
(import lispic.config [load-config])
(setv parser (argparse.ArgumentParser :description "Generate labelled regression images in a chosen site directory."))
(.add-argument parser "destination" :type Path :help "Site directory containing site.sexp; labelled fixture filenames are overwritten.")
(setv root (.resolve (. (.parse-args parser) destination))
      cfg (load-config (/ root "site.sexp")))
(setv fixtures [["pole-01" 1500 1000 #(134 105 61)] ["vez-01" 500 1800 #(63 87 103)]
               ["pole-02" 1500 1000 #(74 108 110)] ["pole-03" 1200 800 #(76 92 61)]
               ["pole-04" 900 900 #(118 103 91)] ["panorama-01" 2400 600 #(122 92 77)]
               ["sesit" 900 700 #(83 76 66)] ["poznamky" 900 600 #(102 89 74)]])
;; Use labelled geometric layers rather than photographic assets so fixtures
;; are reproducible and clearly distinguishable from real portfolio content.
(for [[name w h color] fixtures]
  (setv im (Image.new "RGB" #(w h) color) draw (ImageDraw.Draw im))
  (for [i (range 1 7)]
    (setv y (int (* h (/ i 8))))
    (.polygon draw [#(0 (+ y 60)) #((int (* w 0.3)) y) #(w (+ y 100)) #(w h) #(0 h)]
      :fill (tuple (gfor c color (max 0 (- c (* i 7)))))))
  (setv font (ImageFont.load-default :size (max 16 (int (/ (min w h) 20)))))
  (.text draw #(25 25) f"TEST / {name}\n{w} x {h}" :fill "white" :font font)
  (setv path (if (= name "poznamky") (/ root (get cfg "sources" "posts") "images/poznamky.jpg") (/ root (get cfg "sources" "originals") (+ name ".jpg"))))
  (.mkdir path.parent :parents True :exist-ok True)
  (.save im path :quality 90))
