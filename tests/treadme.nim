import ../skulite

block basic:
  let db = openDatabase(":memory:")
  db.exec "CREATE TABLE IF NOT EXISTS greeting(words TEXT) STRICT"
  db.exec "INSERT INTO greeting (words) VALUES (?),(?)", ("Hello,", "World!")
  for word in db.query("SELECT words FROM greeting", string):
    echo word

when(compiles do: import pkg/sunny):
  import std/tables
  block sunny:
    proc bindParam(stmt: Statement; index: Positive32; val: SomeTable) {.inline.} =
      bindParam(stmt, index, toJson val)

    proc getColumn[K,V](stmt: Statement; index: Natural32; T: typedesc[SomeTable[K,V]]): T {.inline.} =
      T.fromJson getColumn(stmt, index, string)

    let db = openDatabase(":memory:")
    db.exec "CREATE TABLE IF NOT EXISTS projects(metadata TEXT) STRICT"
    let skulite = {"name": "skulite", "language": "nim", "license": "blessing"}.toTable
    db.exec "INSERT INTO projects (metadata) VALUES (?)", skulite
    doAssert db.query("SELECT metadata FROM projects LIMIT 1", Table[string, string])["language"] == "nim"
