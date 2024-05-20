import ../skulite
from ../skulite/sqlite3 import bind_text

proc tapi {.inline.} =
  let db = openDatabase(":memory:")

  block:
    proc readonly(stmt: Statement): bool {.importc: "sqlite3_stmt_readonly", noconv.}
    let s1 = db.prepStatement "CREATE TABLE IF NOT EXISTS test(words)"
    doAssert not readonly(s1)
    exec s1
    let s2 = db.prepStatement "SELECT * from test"
    doAssert readonly(s2)

  block:
    var v {.global.} = 0
    block:
      let s = db.prepStatement "CREATE TABLE IF NOT EXISTS test(words)"
      proc one(_: pointer) {.noconv.} =
        v = 1
      discard sqlite3.bind_text(s, 1, "", 0, one)
    doAssert v == 1
tapi()
