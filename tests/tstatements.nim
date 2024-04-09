import ../skulite

let db = openDatabase(":memory:")
db.exec "CREATE TABLE IF NOT EXISTS example(words TEXT) STRICT"
let s1 = db.prepStatement("INSERT INTO example (words) VALUES (?),(?)", ("Hello,", "world!"))
doAssert s1.sql == "INSERT INTO example (words) VALUES (?),(?)"
doAssert s1.expandedSql == "INSERT INTO example (words) VALUES ('Hello,'),('world!')"
doAssert s1.numParams == 2
doAssert s1.numColumns == 0
doAssert not s1.readonly
doAssert not s1.busy
doAssert s1.isExplain == 0
explain(s1)
exec s1
doAssert db.lastStatement() == s1

let s2 = db.prepStatement("SELECT words FROM example LIMIT 1")
doAssert db.lastStatement(s2) == s1
doAssert s2.numParams == 0
doAssert s2.numColumns == 1
doAssert s2.numValues == 0
doAssert s2.readonly
step s2
doAssert s2.numValues == 1
explain(s2)
