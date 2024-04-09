import ../skulite

let db = openDatabase(":memory:")
db.exec "CREATE TABLE IF NOT EXISTS example(words TEXT) STRICT"
db.exec "INSERT INTO example (words) VALUES (?),(?)", ("Hello,", "world!")
doAssert db.query("SELECT words FROM example LIMIT 1", string) == "Hello,"
