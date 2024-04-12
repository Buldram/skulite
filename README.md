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

# Hello,
# World!
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
let proj = {"name": "skulite", "language": "nim", "license": "blessing"}.toTable
db.exec "INSERT INTO projects (metadata) VALUES (?)", proj
echo "name: ", db.query("SELECT metadata FROM projects", Table[string, string])["name"]
echo "language: ", db.query("SELECT json_extract(metadata, '$.language') FROM projects", string)

# name: skulite
# language: nim
```
† See all `bindParam` and `getColumn` implementations in [stmtops.nim](skulite/stmtops.nim).

####

## Notes

* `-d:staticSqlite`: Build and link SQlite statically, enabled by default on Windows.
  * There are more options related to compiling SQLite in the header of [sqlite3c.nim](skulite/sqlite3c.nim).
* `-d:checkSqliteUsage`: Check if you're misusing the SQLite API, enabled by default for debug builds.

## See also
* https://github.com/codehz/easy_sqlite3
* https://github.com/nim-lang/db_connector
* https://github.com/olliNiinivaara/SQLiteral
* https://github.com/GULPF/tiny_sqlite
* https://github.com/arnetheduck/nim-sqlite3-abi
