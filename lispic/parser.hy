"A data-only reader. No Hy reader or eval is used on content."
(import re json pathlib [Path])
(import lispic.model [Node Text Position fail])

(defclass Reader []
  "A recursive-descent reader with separate element-text and literal-data modes."
  (defn __init__ [self source [file "<text>"]]
    "Initialize a cursor over source; file is a diagnostic label, not an opened handle."
    (setv self.source source self.file (str file) self.i 0))
  (defn pos [self]
    "Return the current one-based source position, counting Unicode characters."
    (setv prefix (cut self.source 0 self.i))
    (Position self.file (+ 1 (.count prefix "\n")) (+ 1 (- self.i (+ 1 (.rfind prefix "\n"))))))
  (defn peek [self]
    "Return the current character without advancing, or an empty string at end of input."
    (if (< self.i (len self.source)) (get self.source self.i) ""))
  (defn ws [self]
    "Advance past whitespace while reading structural syntax or attribute data."
    (while (and (self.peek) (.isspace (self.peek))) (+= self.i 1)))
  (defn error [self message]
    "Raise a content error at the current cursor position."
    (fail (self.pos) message))
  (defn expect [self value]
    "Consume one required delimiter or report its absence at the cursor."
    (when (!= (self.peek) value) (self.error f"Očekáváno {(repr value)}"))
    (+= self.i 1))
  (defn token [self]
    "Read an unquoted data token up to whitespace or a structural delimiter."
    (setv start self.i)
    (while (and (self.peek) (not (.isspace (self.peek))) (not (in (self.peek) "{}[]()")))
      (+= self.i 1))
    (when (= start self.i) (self.error "Očekávána hodnota"))
    (cut self.source start self.i))
  (defn value [self]
    "Read one literal data value recursively; reject executable forms and duplicate keys."
    (self.ws)
    (setv c (self.peek))
    (cond
      (= c "{")
        (do
          (+= self.i 1)
          (setv result {})
          (self.ws)
          (while (!= (self.peek) "}")
            (when (not (self.peek)) (self.error "Neuzavřený slovník"))
            (setv key (self.token))
            (when (or (not (.startswith key ":")) (= key ":")) (self.error "Klíč musí být :keyword"))
            (setv key (cut key 1 None))
            (when (in key result) (self.error f"Opakovaný klíč :{key}"))
            (setv (get result key) (self.value))
            (self.ws))
          (+= self.i 1)
          result)
      (= c "[")
        (do
          (+= self.i 1)
          (setv result [])
          (self.ws)
          (while (!= (self.peek) "]")
            (when (not (self.peek)) (self.error "Neuzavřený seznam"))
            (.append result (self.value))
            (self.ws))
          (+= self.i 1)
          result)
      (= c "\"")
        (do
          (try
            (setv [value consumed] (.raw-decode (json.JSONDecoder) (cut self.source self.i None)))
            (except [e json.JSONDecodeError] (self.error f"Neplatný řetězec: {e.msg}")))
          (+= self.i consumed)
          value)
      True
        (do
          (setv token (self.token))
          (cond
            (= token "true") True
            (= token "false") False
            (.startswith token ":") token
            (re.fullmatch "[+-]?[0-9]+" token) (int token)
            (re.fullmatch "[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?" token) (float token)
            True (self.error f"Neplatná datová hodnota {(repr token)}")))))
  (defn element [self [preserve False]]
    "Read a positioned element tree, inheriting whitespace preservation inside pre."
    (setv pos (self.pos))
    (self.expect "(")
    (setv match (re.match "[a-z][a-z0-9-]*" (cut self.source self.i None)))
    (when (is match None) (self.error "Očekáván název prvku"))
    (setv name (.group match 0))
    (+= self.i (len name))
    (when (and (self.peek) (not (.isspace (self.peek))) (not (in (self.peek) "{)")))
      (self.error "Za názvem prvku musí být mezera nebo atributy"))
    ;; Spaces before attributes are structural. Without attributes retain the
    ;; original whitespace for pre; ordinary elements trim only their edges.
    (setv after-name self.i)
    (self.ws)
    (setv attrs {})
    (if (= (self.peek) "{")
      (do (setv attrs (self.value))
          (when (.isspace (self.peek)) (+= self.i 1)))
      (do (setv self.i after-name)
          (when (.isspace (self.peek)) (+= self.i 1))))
    ;; Pass preservation into descendants so (pre (code ...)) keeps its spacing.
    (setv preserve (or preserve (= name "pre")) children [] buffer [] start (self.pos))
    (defn flush []
      "Append buffered text with its starting position; normalize whitespace unless preserving it."
      (when buffer
        (setv value (.join "" buffer))
        (when (not preserve) (setv value (re.sub "\\s+" " " value)))
        (.append children (Text value start))
        (.clear buffer)))
    (while (and (self.peek) (!= (self.peek) ")"))
      (cond
        (= (self.peek) "(")
          (do (flush) (.append children (self.element preserve)) (setv start (self.pos)))
        (= (self.peek) "\\")
          (do
            (+= self.i 1)
            (when (or (not (self.peek)) (not (in (self.peek) "()\\")))
              (self.error "Povoleno jen \\(, \\) a \\\\"))
            (.append buffer (self.peek)) (+= self.i 1))
        True (do (.append buffer (self.peek)) (+= self.i 1))))
    (flush)
    (self.expect ")")
    ;; Trim the element boundary only. Internal text around a child must keep
    ;; its space, while punctuation immediately after a child must stay adjacent.
    (when (and (not preserve) children)
      (when (isinstance (get children 0) Text)
        (setv (. (get children 0) value) (.lstrip (. (get children 0) value))))
      (when (isinstance (get children -1) Text)
        (setv (. (get children -1) value) (.rstrip (. (get children -1) value)))))
    (Node name attrs children pos)))

(defn parse [source [file "<text>"]]
  "Parse zero or more root elements from source and retain file in their positions."
  (setv reader (Reader source file) nodes [])
  (reader.ws)
  (while (reader.peek)
    (.append nodes (reader.element))
    (reader.ws))
  nodes)

(defn parse-file [path]
  "Read a UTF-8 content file and parse its root elements with path-based diagnostics."
  (parse (.read-text (Path path) :encoding "utf-8") (str path)))

(defn parse-data [source [file "<data>"]]
  "Read exactly one data value and reject any trailing non-whitespace input."
  (setv reader (Reader source file) value (reader.value))
  (reader.ws)
  (when (reader.peek) (reader.error "Neočekávaný text za konfigurací"))
  value)
