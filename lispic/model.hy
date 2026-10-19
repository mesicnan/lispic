(import dataclasses [dataclass field])

(defclass [dataclass] Position []
  #^ str file
  #^ int line
  #^ int column)

(defclass [dataclass] Text []
  #^ str value
  #^ Position pos)

(defclass [dataclass] Node []
  #^ str name
  #^ dict attrs
  #^ list children
  #^ Position pos)

(defclass ContentError [ValueError])

(defn fail [pos message]
  (raise (ContentError f"{pos.file}:{pos.line}:{pos.column}: {message}")))

(defn plain [node]
  (if (isinstance node Text) node.value
    (.join "" (gfor child node.children (plain child)))))
