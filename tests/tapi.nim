import ../skulite

proc readonly(stmt: Statement): bool {.importc: "sqlite3_stmt_readonly".}
let db = openDatabase(":memory:")
let s1 = db.prepStatement "CREATE TABLE IF NOT EXISTS test(words)"
doAssert not readonly(s1)
exec s1
let s2 = db.prepStatement "SELECT * from test"
doAssert readonly(s2)
