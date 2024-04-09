High-level [SQLite](https://www.sqlite.org) bindings in Nim.

```nim
## Basic example
import pkg/skulite

let db = openDatabase(":memory:")
db.exec "CREATE TABLE IF NOT EXISTS example(words TEXT) STRICT"
db.exec "INSERT INTO example (words) VALUES (?),(?)", ("Hello,", "world!")
for word in db.query("SELECT words FROM example LIMIT 1"):
  echo word
```
