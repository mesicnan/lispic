"Source-positioned document nodes shared by parsing, validation, and rendering."
(import dataclasses [dataclass field])

(defclass [dataclass] Position []
  "A filename and one-based source coordinates used in content diagnostics."
  #^ str file
  #^ int line
  #^ int column)

(defclass [dataclass] Text []
  "A text segment with its original source position."
  #^ str value
  #^ Position pos)

(defclass [dataclass] Node []
  "An element name, data attributes, ordered children, and opening source position."
  #^ str name
  #^ dict attrs
  #^ list children
  #^ Position pos)

(defclass ContentError [ValueError]
  "A user-facing configuration, content, or image-processing failure.")

(defn fail [pos message]
  "Raise ContentError with the filename and one-based line and column from pos."
  (raise (ContentError f"{pos.file}:{pos.line}:{pos.column}: {message}")))

(defn plain [node]
  "Concatenate descendant text in source order, without adding separators or HTML."
  (if (isinstance node Text) node.value
    (.join "" (gfor child node.children (plain child)))))
