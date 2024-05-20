import ../skulite

proc tstatements {.inline.} =
  var db = openDatabase(":memory:")
  db.exec "CREATE TABLE IF NOT EXISTS example(words TEXT) STRICT"
  let s1 = db.prepStatement("INSERT INTO example (words) VALUES (?),(:second)", "Hello,")
  s1[":second"] = "World!"
  doAssert s1.sql == "INSERT INTO example (words) VALUES (?),(:second)"
  doAssert s1.expandedSql == "INSERT INTO example (words) VALUES ('Hello,'),('World!')"
  doAssert s1.numParams == 2
  doAssert s1.numColumns == 0
  doAssert not s1.readonly
  doAssert not s1.busy
  doAssert s1.explainLevel == 0
  explain(s1)
  doAssert db.lastInsertRowid == 0
  exec s1
  doAssert db.lastStatement() == s1
  doAssert db.lastInsertRowid == 2

  let s2 = db.prepStatement("SELECT words FROM example LIMIT 1")
  doAssert db.lastStatement(s2) == s1
  doAssert s2.numParams == 0
  doAssert s2.numColumns == 1
  doAssert s2.numValues == 0
  doAssert s2.readonly
  doAssert step s2
  doAssert s2.numValues == 1
  explain(s2)

  db = openDatabase(":memory:")
  db.exec "CREATE TABLE IF NOT EXISTS example(a TEXT, b TEXT) STRICT"
  db.exec "INSERT INTO example(a,b) VALUES (?,?)", ("Hello,", "World!")
  let s3 = db.prepStatement("SELECT a,b FROM example")
  explain(s3)
  doAssert step s3
  doAssert unpack(s3, (string, string)) == ("Hello,", "World!")
  doAssert db.query("SELECT a,b FROM example", (string, string)) == ("Hello,", "World!")
tstatements()
