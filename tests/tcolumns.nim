import ../skulite, ../skulite/sqlite3c
import std/options

block ordinals:
  let db = openDatabase(":memory:")
  db.exec "CREATE TABLE IF NOT EXISTS test(ints INT) STRICT"
  db.exec "INSERT INTO test (ints) VALUES (?)", -1
  doAssert db.query("SELECT ints FROM test LIMIT 1", int64) == -1
  when compileOption("rangechecks"):
    doAssertRaises(ValueError):
      discard db.query("SELECT ints FROM test LIMIT 1", uint32)

block floats:
  let db = openDatabase(":memory:")
  db.exec "CREATE TABLE IF NOT EXISTS test(floats REAL) STRICT"
  db.exec "INSERT INTO test (floats) VALUES (?)", 1.0
  doAssert db.query("SELECT floats FROM test LIMIT 1", float64) == 1.0

block strings:
  var db {.used.}: DatabaseWrapper

  template checkGetColumnMatches() =
    doAssert db.lastStatement().expandedSql == "INSERT INTO example (words) VALUES ('Hello')"
    let stmt = db.step("SELECT words FROM example LIMIT 1")
    doAssert stmt.expandedSql == "SELECT words FROM example LIMIT 1"
    doAssert stmt[0, cstring] == cstring "Hello"
    doAssert stmt[0, string] == "Hello"
    doAssert stmt[0, string, optForLong = true] == "Hello"
    doAssert stmt[0, seq[char]] == @"Hello"
    doAssert stmt[0, seq[char], optForLong = true] == @"Hello"
    doAssert stmt[0, array[5, char]] == ['H', 'e', 'l', 'l', 'o']
    doAssert stmt[0, openArray[char]] == "Hello"
    doAssert stmt[0, openArray[char], optForLong = true] == "Hello"

  template testInsert(hello: typed) =
    db.reopen(cstring ":memory:")
    db.exec "CREATE TABLE example(words TEXT) STRICT"
    db.exec "INSERT INTO example (words) VALUES (?)", hello
    checkGetColumnMatches()

  testInsert(cstring "Hello")
  testInsert("Hello")
  var hello = "Hello"; testInsert(hello)
  const Hello = "Hello"; testInsert(Hello)
  testInsert(@"Hello")
  var sHello = @"Hello"; testInsert(sHello)
  const SHello = @"Hello"; testInsert(SHello)
  testInsert(['H', 'e', 'l', 'l', 'o'])
  var aHello = ['H', 'e', 'l', 'l', 'o']; testInsert(aHello)
  const AHello = ['H', 'e', 'l', 'l', 'o']; testInsert(AHello)
  testInsert("Hello".toOpenArray(0, 4))
  testInsert(['H', 'e', 'l', 'l', 'o'].toOpenArray(0, 4))

  db.reopen(":memory:")
  db.exec "CREATE TABLE example(words TEXT) STRICT"
  db.exec "INSERT INTO example (words) VALUES (?)", "Tschüss, 🌍!"
  doAssert db.query("SELECT words FROM example LIMIT 1", string) == "Tschüss, 🌍!"

  db.reopen(":memory:")
  db.exec "CREATE TABLE example(words TEXT) STRICT"
  db.exec "INSERT INTO example (words) VALUES (?)", ""
  doAssert db.query("SELECT words FROM example LIMIT 1", string) == ""

block blobs:
  var db: Database

  template checkGetColumnMatches() =
    let stmt = db.step("SELECT blobs FROM test LIMIT 1")
    doAssert stmt[0, seq[byte]] == @[byte 1, 2, 3, 4, 5]
    doAssert stmt[0, array[5, byte]] == [byte 1, 2, 3, 4, 5]
    doAssert stmt[0, openArray[byte]] == [byte 1, 2, 3, 4, 5]

  template testInsert(countup: typed) =
    db.reopen(":memory:")
    db.exec "CREATE TABLE IF NOT EXISTS test(blobs BLOB) STRICT"
    db.exec "INSERT INTO test (blobs) VALUES (?)", countup
    checkGetColumnMatches()

  testInsert([byte 1, 2, 3, 4, 5])
  var aCountup = [byte 1, 2, 3, 4, 5]; testInsert(aCountup)
  const ACountup = [byte 1, 2, 3, 4, 5]; testInsert(ACountup)
  testInsert(@[byte 1, 2, 3, 4, 5])
  var sCountup = @[byte 1, 2, 3, 4, 5]; testInsert(sCountup)
  const SCountup = @[byte 1, 2, 3, 4, 5]; testInsert(SCountup)
  testInsert([byte 1, 2, 3, 4, 5].toOpenArray(0, 4))

type
  Test = object
    a: int
    b: char

  Test2 = object
    a: int

converter toTest2(t: Test): Test2 = Test2(a: t.a)

block objects:
  proc bindParam(stmt: Statement; index: Positive32; val: Test2) {.inline, used.} =
    doAssert false, "Will never be reached as Test->Test2 is a conversion match, concepts are considered generic matches and have a higher precedence."

  proc reset(db: var DatabaseWrapper) =
    db = openDatabase(":memory:")
    db.exec "CREATE TABLE IF NOT EXISTS test(blobs BLOB) STRICT"

  var db: DatabaseWrapper

  reset db
  db.exec "INSERT INTO test (blobs) VALUES (?)", Test(a: 10, b: 'b')
  doAssert db.query("SELECT blobs FROM test LIMIT 1", Test) == Test(a: 10, b: 'b')

  reset db
  const bomber = Test(a: 17, b: 'b')
  db.exec "INSERT INTO test (blobs) VALUES (?)", bomber
  doAssert db.query("SELECT blobs FROM test LIMIT 1", Test) == bomber

  proc bindParam[T: Test|Test2](stmt: Statement; index: Positive32; val: T) {.inline.} =
    sqliteCheck sqlite3_bind_blob(stmt, cint index, unsafeAddr bomber, cint sizeof(bomber), SQLITE_STATIC)

  reset db
  db.exec "INSERT INTO test (blobs) VALUES (?)", Test(a: 10, b: 'b')
  doAssert db.query("SELECT blobs FROM test LIMIT 1", Test) == bomber

block options:
  block strings:
    var db = openDatabase(":memory:")
    db.exec "CREATE TABLE IF NOT EXISTS test(words TEXT) STRICT"
    db.exec "INSERT INTO test (words) VALUES (?),(?),(?)", ("word", "", nil)
    var i: range[0..2]
    for x in db.query("SELECT words FROM test", Option[string]):
      case i
      of 0: doAssert x.get() == "word"; inc i
      of 1: doAssert x.get() == ""; inc i
      of 2: doAssert x.isNone()

  block blobs:
    let db = openDatabase(":memory:")
    db.exec "CREATE TABLE IF NOT EXISTS test(blobs BLOB) STRICT"
    db.exec "INSERT INTO test (blobs) VALUES (?),(?),(?)", ([byte 1, 2, 3], newSeq[byte](), nil)
    var i: range[0..2]
    for x in db.query("SELECT blobs FROM test", Option[seq[byte]]):
      case i
      of 0: doAssert x.get() == @[byte 1, 2, 3]; inc i
      of 1: doAssert x.isNone(); inc i
      of 2: doAssert x.isNone()
