import ../skulite, pkg/criterion

proc benchEmpty {.inline.} =
  var cfg = newDefaultConfig()
  benchmark cfg:
    let db = openDatabase(":memory:")
    db.exec "CREATE TABLE IF NOT EXISTS test(id)"
    db.exec "INSERT INTO test (id) VALUES (?)", params = ""
    let stmt = db.step "SELECT id FROM test LIMIT 1"

    proc a {.measure.} =
      doAssert `[]`(stmt, 0, string) == ""
benchEmpty()
