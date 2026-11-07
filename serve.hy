"Preview both websites over local HTTP with correctly rewritten cross-site links."
(import pathlib [Path] sys)

;; The shared launcher imports no image-processing dependencies in global Hy.
(setv project (. (.resolve (Path __file__)) parent))
(.insert sys.path 0 (str project))
(import lispic.launcher [run])

(when (= __name__ "__main__")
  (sys.exit (run "serve" project)))
