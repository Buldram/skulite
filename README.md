# Skulite

High-level [SQLite](https://www.sqlite.org) bindings for [Nim](https://nim-lang.org).  
Requires Nim 2.0 or greater and ARC/ORC memory management.

## Examples

#### Basic example
```nim
import pkg/skulite

let db = openDatabase(":memory:")
db.exec "CREATE TABLE IF NOT EXISTS greeting(words TEXT) STRICT"
db.exec "INSERT INTO greeting (words) VALUES (?),(?)", ("Hello,", "World!")
for word in db.query("SELECT words FROM greeting", string):
  echo word
```

#### Serializing a [Table](https://nim-lang.org/docs/tables.html) as [JSON](https://www.sqlite.org/json1.html) using [Sunny](https://github.com/guzba/sunny)
```nim
import pkg/[skulite, sunny],
       std/tables

proc bindParam*(stmt: Statement; index: Positive32; val: SomeTable) {.inline.} =
  bindParam(stmt, index, toJson val)

proc getColumn*[K,V](stmt: Statement; index: Natural32; T: typedesc[SomeTable[K,V]]): T {.inline.} =
  T.fromJson getColumn(stmt, index, string)

let db = openDatabase(":memory:")
db.exec "CREATE TABLE IF NOT EXISTS projects(metadata TEXT) STRICT"
let skulite = {"name": "skulite", "language": "nim", "license": "blessing"}.toTable
db.exec "INSERT INTO projects (metadata) VALUES (?)", skulite
doAssert db.query("SELECT metadata FROM projects LIMIT 1", Table[string, string])["language"] == "nim"
```
† See all `bindParam` and `getColumn` implementations in [stmtops.nim](skulite/stmtops.nim).

####

## Notes

* `-d:staticSqlite`: Statically build and bundle SQlite instead of dynamically linking, enabled by default on Windows.
  * There are more options for configuring the compilation and linking of SQLite in the header of [sqlite3c.nim](skulite/sqlite3c.nim).
* `-d:checkSqliteUsage`: Check for errors after calls which cannot fail outside of misuse, enabled by default for debug builds.

## See also
* https://github.com/codehz/easy_sqlite3
* https://github.com/nim-lang/db_connector
* https://github.com/olliNiinivaara/SQLiteral
* https://github.com/GULPF/tiny_sqlite
* https://github.com/arnetheduck/nim-sqlite3-abi
