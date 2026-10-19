"Write short Atom and RSS entries with stable identities and metadata-derived dates."
(import xml.etree.ElementTree :as ET email.utils [format-datetime] uuid datetime [datetime timezone])
(import lispic.render [post-url photo-data image-tag esc])
(import lispic.excerpts [summary first-photo])
(setv ATOM "http://www.w3.org/2005/Atom")
(ET.register-namespace "" ATOM)
(defn child [parent tag text [attrs None]]
  "Append an XML child with optional attributes and text; ElementTree handles escaping."
  (setv element (ET.SubElement parent tag (or attrs {})))
  (when (is-not text None) (setv element.text (str text)))
  element)
(defn stable-id [record cfg]
  "Return a UUIDv5 URN based only on the stable blog identity and post ID."
  (+ "urn:uuid:" (str (uuid.uuid5 uuid.NAMESPACE_URL (+ (get cfg "blog" "identity") "#" (get record "attrs" "id"))))))
(defn item-html [record data cfg]
  "Render a short feed fragment containing the excerpt, first photo, and continuation link."
  (setv out (+ "<p>" (esc (summary record)) "</p>") photo (first-photo (get record "node")))
  (when photo
    (setv [image alt rec] (photo-data photo record data))
    (+= out (image-tag image alt cfg True)))
  (+ out "<p><a href=\"" (esc (post-url record cfg)) "\">Pokračovat ve čtení →</a></p>"))
(defn write-feeds [data cfg output]
  "Write atom.xml and rss.xml for published posts without using the build clock."
  ;; Feed dates must not change for a CSS-only rebuild. With no posts, use
  ;; a fixed epoch instead of introducing the current wall-clock time.
  (setv posts (cut (get data "public-posts") 0 (get cfg "feeds" "count"))
        updated (max (lfor p posts (get p "updated")) :default (datetime 1970 1 1 :tzinfo timezone.utc))
        base (get cfg "blog" "url")
        atom (ET.Element (+ "{" ATOM "}feed")))
  (defn ac [parent tag text [attrs None]]
    "Append an Atom-namespaced XML element using the shared child helper."
    (child parent (+ "{" ATOM "}" tag) text attrs))
  (ac atom "id" (get cfg "blog" "identity"))
  (ac atom "title" (get cfg "blog" "title"))
  (ac atom "updated" (.isoformat updated))
  (ac atom "link" None {"href" (+ base "/atom.xml") "rel" "self"})
  (ac atom "link" None {"href" (+ base "/")})
  (ac (ac atom "author" None) "name" (get cfg "author"))
  (setv rss (ET.Element "rss" {"version" "2.0"}) channel (child rss "channel" None))
  (child channel "title" (get cfg "blog" "title"))
  (child channel "link" (+ base "/"))
  (child channel "description" (get cfg "blog" "title"))
  (child channel "language" (get cfg "language"))
  (child channel "lastBuildDate" (format-datetime updated))
  (for [record posts]
    (setv entry (ac atom "entry" None) url (post-url record cfg) content (item-html record data cfg))
    (ac entry "id" (stable-id record cfg))
    (ac entry "title" (get record "attrs" "title"))
    (ac entry "link" None {"href" url})
    (ac entry "published" (.isoformat (get record "published")))
    (ac entry "updated" (.isoformat (get record "updated")))
    ;; ElementTree escapes the HTML fragment as XML text; Atom readers then
    ;; interpret that fragment according to type="html".
    (ac entry "summary" content {"type" "html"})
    (setv item (child channel "item" None))
    (child item "title" (get record "attrs" "title"))
    (child item "link" url)
    (child item "guid" (stable-id record cfg) {"isPermaLink" "false"})
    (child item "pubDate" (format-datetime (get record "published")))
    (child item "description" content))
  (.write (ET.ElementTree atom) (/ output "atom.xml") :encoding "utf-8" :xml-declaration True)
  (.write (ET.ElementTree rss) (/ output "rss.xml") :encoding "utf-8" :xml-declaration True))
