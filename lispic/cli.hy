"Expose build, check, and a two-origin local preview through the Lispic command line."
(import argparse sys threading functools http.server [ThreadingHTTPServer SimpleHTTPRequestHandler])
(import lispic.config [load-config])
(import lispic.build [build])

(defn main []
  "Run the selected command; return an exit status and cleanly stop preview servers on Ctrl+C."
  (setv parser (argparse.ArgumentParser :description "Lispic — statický fotografický web") )
  (.add-argument parser "command" :choices ["build" "check" "serve"])
  (.add-argument parser "--config" :default "site.sexp")
  (.add-argument parser "--port" :type int :default 8000)
  (.add-argument parser "--gallery-port" :type int :default 8001)
  (setv args (.parse-args parser))
  (try
    (setv cfg (load-config args.config))
    (when (= args.command "serve")
      (when (= args.port args.gallery-port) (raise (ValueError "Porty obou webů musí být různé")))
      ;; Record original origins before replacing them, so explicit links in
      ;; content and navigation can be rewritten alongside generated URLs.
      (setv (get cfg "preview-origins") {(get cfg "blog" "url") f"http://localhost:{args.port}" (get cfg "gallery" "url") f"http://localhost:{args.gallery-port}"})
      (setv (get cfg "blog" "url") f"http://localhost:{args.port}"
            (get cfg "gallery" "url") f"http://localhost:{args.gallery-port}"
            (get cfg "blog" "output") ".preview/blog"
            (get cfg "gallery" "output") ".preview/gallery"))
    (setv data (build cfg (= args.command "check")))
    (print f"OK: {(len (get data "public-posts"))} článků, {(len (get data "photos"))} katalogových fotografií.")
    (when (= args.command "serve")
      (setv servers [])
      (try
        ;; Both sites need distinct origins even locally; use separate loopback
        ;; ports and daemon threads, with explicit shutdown in the finally block.
        (for [[site port] [["blog" args.port] ["gallery" args.gallery-port]]]
          (setv directory (str (/ (get cfg "root") (get cfg site "output")))
                handler (functools.partial SimpleHTTPRequestHandler :directory directory)
                server (ThreadingHTTPServer #("127.0.0.1" port) handler))
          (.append servers server)
          (.start (threading.Thread :target server.serve-forever :daemon True))
          (print f"{site}: http://localhost:{port}"))
        (print "Ukončení: Ctrl+C. Po změně obsahu spusťte serve znovu.")
        (.wait (threading.Event))
        (except [KeyboardInterrupt] None)
        (finally (for [server servers] (.shutdown server) (.server-close server)))))
    0
    (except [e [ValueError OSError KeyError TypeError]]
      (print f"Chyba: {e}" :file sys.stderr)
      (return 1))))
