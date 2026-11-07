{:language "cs"
 :timezone "Europe/Prague"
 :author "Jana Nováková"
 :blog {:url "https://blog.example.cz" :title "Mezi cestami" :output "dist/blog"
        :identity "urn:lispic:jana-novakova" :per-page 12}
 :gallery {:url "https://foto.example.cz" :title "Světlo / krajina" :output "dist/gallery" :per-page 60}
 :sources {:posts "content/posts" :pages "content/pages" :albums "content/albums"
           :catalog "content/photos.sexp" :originals "originals" :cache ".cache/lispic"}
 :labels {:krajina "Krajina" :panorama "Panoramata" :poznamky "Poznámky"}
 :images {:sizes [480 960 1600 2400] :jpeg-quality 88 :webp-quality 85 :webp true}
 :layout {:gap 0 :target-height 260 :tall-ratio 2.5 :lookahead 6 :tall-min-width 700 :reorder false
          :local-lookahead 3 :group-limit 12 :min-height-factor 0.5 :max-height-factor 1.8 :max-score 1.1}
 :feeds {:count 20}
 :randomization {:enabled true :seed "cesty-2026" :margin 3 :mobile-margin 1
                 :font-min 98 :font-max 102 :line-height 1.7}
 :appearance {:background "#141618" :foreground "#e4e1db" :accent "#d2b98a"
              :text-width "44rem" :navigation []}}
