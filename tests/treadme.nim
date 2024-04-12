import ../skulite

block basic:
  let db = openDatabase(":memory:")
  db.exec "CREATE TABLE IF NOT EXISTS greeting(words TEXT) STRICT"
  db.exec "INSERT INTO greeting (words) VALUES (?),(?)", ("Hello,", "World!")
  var i: range[0..1]
  for word in db.query("SELECT words FROM greeting", string):
    case i
    of 0: doAssert word == "Hello,"; inc i
    of 1: doAssert word == "World!"

when NimMajor > 1:
  when (compiles do: import pkg/sunny):
    import std/tables
    block sunny:
      proc bindParam(stmt: Statement; index: Positive32; val: SomeTable) {.inline.} =
        bindParam(stmt, index, toJson val)

      proc getColumn[K,V](stmt: Statement; index: Natural32; T: typedesc[SomeTable[K,V]]): T {.inline.} =
        T.fromJson getColumn(stmt, index, string)

      let db = openDatabase(":memory:")
      db.exec "CREATE TABLE IF NOT EXISTS projects(metadata TEXT) STRICT"
      let proj = {"name": "skulite", "language": "nim", "license": "blessing"}.toTable
      db.exec "INSERT INTO projects (metadata) VALUES (?)", proj
      doAssert "skulite" == db.query("SELECT metadata FROM projects LIMIT 1", Table[string, string])["name"]
      doAssert "skulite" == db.query("SELECT json_extract(metadata, '$.name') FROM projects LIMIT 1", string)
      doAssert "nim" == db.query("SELECT metadata FROM projects LIMIT 1", Table[string, string])["language"]
      doAssert "nim" == db.query("SELECT json_extract(metadata, '$.language') FROM projects LIMIT 1", string)
      doAssert "blessing" == db.query("SELECT metadata FROM projects LIMIT 1", Table[string, string])["license"]
      doAssert "blessing" == db.query("SELECT json_extract(metadata, '$.license') FROM projects LIMIT 1", string)
