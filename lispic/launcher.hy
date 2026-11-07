"Launch checkout commands through the local environment using only standard-library dependencies."
(import argparse os pathlib [Path] subprocess sys)

(defn run [command project]
  "Parse a checkout script's flags, run the preflight when needed, and preserve exit codes."
  (setv project (.resolve (Path project))
        parser (argparse.ArgumentParser
                 :description (if (= command "build")
                                "Check content and build both static websites."
                                "Preview both websites with working local links.")))
  (.add-argument parser "--config" :type Path
    :default (/ project.parent "content" "site.sexp")
    :help "Site configuration (default: the sibling content/site.sexp).")
  (if (= command "build")
    (.add-argument parser "--skip-check" :action "store_true"
      :help "Skip the separate preflight check; normal build validation still applies.")
    (do
      (.add-argument parser "--port" :type int :default 8000 :help "Local blog port (default: 8000).")
      (.add-argument parser "--gallery-port" :type int :default 8001 :help "Local gallery port (default: 8001).")))
  (setv args (.parse-args parser)
        executable (/ project ".venv" (if (= os.name "nt") "Scripts/lispic.exe" "bin/lispic")))
  (when (not (.is-file executable))
    (print f"Set up the project in {project}:\n  python3 -m venv .venv\n  .venv/bin/python -m pip install -e ." :file sys.stderr)
    (return 1))
  ;; These modules are also imported by globally installed Hy. Run the actual
  ;; CLI in the checkout environment, where Pillow and the package are installed.
  (setv commands (if (and (= command "build") (not args.skip_check)) ["check" "build"] [command])
        options ["--config" (str args.config)])
  (when (= command "serve")
    (.extend options ["--port" (str args.port) "--gallery-port" (str args.gallery_port)]))
  (try
    (for [step commands]
      (setv status (. (subprocess.run [(str executable) step #* options]) returncode))
      ;; A failed check must never start a build or modify generated output.
      (when (!= status 0) (return status)))
    0
    (except [KeyboardInterrupt] 130)))
