import ../skulite, pkg/criterion

proc benchEmpty {.inline.} =
  var cfg = newDefaultConfig()
  benchmark cfg:
    var db = openDatabase(":memory:")
    db.exec "CREATE TABLE IF NOT EXISTS test(id)"
    db.exec "INSERT INTO test (id) VALUES (?)", params = ""
    var stmt = db.prepStatement "SELECT id FROM test LIMIT 1"
    doAssert step stmt

    proc a {.measure.} =
      doAssert `[]`(stmt, 0, string) == ""
benchEmpty()
