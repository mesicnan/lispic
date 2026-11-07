"Check and build the sibling websites without activating an environment."
(import pathlib [Path] sys)

;; Resolve imports and defaults from the script rather than the caller's cwd.
(setv project (. (.resolve (Path __file__)) parent))
(.insert sys.path 0 (str project))
(import lispic.launcher [run])

(when (= __name__ "__main__")
  (sys.exit (run "build" project)))
