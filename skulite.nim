import std/[macros, options, typetraits]
import skulite/shim
from skulite/sqlite3 import ResultCode, Database, Statement, OpenFlag, SuperJournal, PrepareFlag, Datatype, ConfigOp
export Database, Statement, OpenFlag, SuperJournal, PrepareFlag, Datatype, ConfigOp

when not defined(gcDestructors):
  when (NimMajor, NimMinor, NimPatch) >= (1, 6, 2): {.error: "requires --mm:arc/orc".}
  else: {.error: "requires --gc:arc/orc".}

const checkSqliteUsage* {.booldefine.} = not defined(release)
## Whether to often do costly checking for correct usage of the SQLite API.

type SqliteError* = object of CatchableError

template newException*(err: ResultCode): ref SqliteError =
  newException(SqliteError, $sqlite3.errstr(err))

func check*(ret: ResultCode) {.inline, raises: [SqliteError].} =
  if unlikely ret != Ok: raise newException(ret)


# We have "wrapper" objects for destructors but this module's procedures accept the underlying pointer (with implicit unwrapping via `converter`) to give users the option to create and use custom objects.

type
  DatabaseObj* = object
    raw*: Database

converter toPtr*(db: DatabaseObj): lent Database {.inline.} = db.raw
converter toPtr*(db: var DatabaseObj): var Database {.inline.} = db.raw

proc `=copy`*(dest: var DatabaseObj; src: DatabaseObj) {.error.}
proc `=dup`*(x: DatabaseObj): DatabaseObj {.error.}
when defined(nimAllowNonVarDestructor):
  proc `=destroy`*(x: DatabaseObj) = discard sqlite3.close_v2(x)
else:
  proc `=destroy`*(x: var DatabaseObj) = discard sqlite3.close_v2(x)

proc openDatabase*(filename: cstring|static[string]; flags = {ReadWrite, Create, ExResCode}; vfs: cstring = nil): DatabaseObj {.inline.} =
  check sqlite3.open_v2(filename, result, flags, vfs)

template openDatabase*(filename: string; flags = {ReadWrite, Create, ExResCode}; vfs: cstring = nil): DatabaseObj =
  openDatabase(cstring filename, flags, vfs)

proc flush*(db: Database) {.inline.} =
  check sqlite3.db_cache_flush(db)

macro config*(op: ConfigOp; args: varargs[untyped]) =
  result = quote do: check sqlite3.config(`op`)
  for arg in args: result[^1].add arg


type
  StatementObj* = object
    raw*: Statement

converter toPtr*(stmt: StatementObj): lent Statement {.inline.} = stmt.raw
converter toPtr*(stmt: var StatementObj): var Statement {.inline.} = stmt.raw

proc `=copy`*(dest: var StatementObj; src: StatementObj) {.error.}
proc `=dup`*(x: StatementObj): StatementObj {.error.}
when defined(nimAllowNonVarDestructor):
  proc `=destroy`*(x: StatementObj) = discard sqlite3.finalize(x)
else:
  proc `=destroy`*(x: var StatementObj) = discard sqlite3.finalize(x)

proc prepStatement*(db: Database; sql: cstring|static[string]; flags: set[PrepareFlag] = {}): StatementObj {.inline.} =
  check sqlite3.prepare_v3(db, sql, int32 sql.len, flags, result, nil)

proc prepStatement*(db: Database; sql: openArray[char]; flags: set[PrepareFlag] = {}): StatementObj {.inline.} =
  check sqlite3.prepare_v3(db, cast[cstring](unsafeAddr sql), int32 sql.len, flags, result, nil)


template sql*(stmt: Statement): cstring =
  ## Returns `stmt`'s internal copy of the SQL text used to create it.
  sqlite3.sql(stmt)

template `$`*(stmt: Statement|StatementObj): string =
  $stmt.sql


proc step*(stmt: Statement): bool {.inline.} =
  ## Evaluate or "step" an SQL `stmt`. Returns `true` if the evaluation returned a row of data.
  let ret = sqlite3.step(stmt)
  case ret
  of Row: true
  of Done: false
  else: raise newException(ret)

proc exec*(stmt: Statement) {.inline.} =
  ## Execute an SQL `stmt`. Raises an exception if the execution returned a row of data. TODO: Should this Rollback?
  let ret = sqlite3.step(stmt)
  if unlikely ret != Done:
    raise newException(ret)


template db*(stmt: Statement): Database =
  ## Returns the database connection to which `stmt` belongs.
  sqlite3.db_handle(stmt)

func checkForError(db: Database) {.inline.} =
  let ret = sqlite3.errcode(db)
  if unlikely ret notin {Ok, Row, Done}:
    raise newException(ret)

template checkForError(stmt: Statement) =
  checkForError(stmt.db)

template checkUsage(stmt: Statement) =
  ## Checking for static errors which only occur when the SQLite API is used incorrectly.
  ## Same process as `checkForError` above, but only ran in debug builds.
  when checkSqliteUsage:
    checkForError(stmt)

type
  Positive32* = range[1'i32 .. high(int32)] # bindParam indexes
  Natural32* = range[0'i32 .. high(int32)]  # getColumn indexes

include skulite/stmtops # Includes implementations of `bindParam` and `getColumn` for different value types

macro `[]=`*(stmt: Statement; index: auto; args: varargs[untyped]) =
  ## Bind a value to the parameter at `index`, index starts at 1.
  ## Alias for `bindParam`, `args` passes any extra arguments through.
  result = newCall("bindParam", stmt, index, args[^1])
  for i in 0 ..< args.len-1: result.add args[i]

macro `[]`*[t](stmt: Statement; index: auto; T: typedesc[t]; other: varargs[untyped]): t =
  ## Get a value of type `T` from `stmt` at column `index`.
  ## Alias for `getColumn`, `other` passes any extra arguments through.
  result = newCall("getColumn", stmt, index, T)
  for arg in other: result.add arg

template paramIndex*(stmt: Statement; name: cstring): Natural32 =
  ## Get the index of a named parameter or 0 if not found.
  sqlite3.bind_parameter_index(stmt, name)

template paramIndex*(stmt: Statement; name: string): Natural32 =
  ## Get the index of a named parameter or 0 if not found.
  paramIndex(stmt, cstring name)

macro bindParam*(stmt: Statement; name: cstring|string; val: typed; other: varargs[untyped]) =
  ## Bind `val` to a named parameter.
  ## `other` passes any extra arguments through.
  result = quote do:
    let index = paramIndex(`stmt`, `name`)
    if unlikely index == 0: raise newException(SqliteError, "Named parameter not found")
    bindParam(`stmt`, index, `val`)
  for arg in other: result[^1].add arg

proc restart*(stmt: Statement) {.inline.} =
  ## Reset a statement to the beginning of its program, ready to be re-executed.
  ## Does not unbind bound parameters.
  check sqlite3.reset(stmt)

proc clearParams*(stmt: Statement) {.inline.} =
  check sqlite3.clear_bindings(stmt)


#                                       Statement utilities

proc getColumnName*(stmt: Statement; index: Natural32): cstring {.inline.} =
  ## Warning: Copy-less access, freed when 1. `stmt` is finalized/freed (and finalized by `=destroy`) 2. `stmt` is stepped 3. `stmt` is reset.
  result = sqlite3.column_name(stmt, index)
  if unlikely isNil(result): checkForError(stmt)

template numParams*(stmt: Statement): int32 =
  sqlite3.bind_parameter_count(stmt)

template numColumns*(stmt: Statement): int32 =
  sqlite3.column_count(stmt)

template numValues*(stmt: Statement): int32 =
  ## Same as `numColumns`, but returns 0 if `stmt` hasn't been stepped yet.
  sqlite3.data_count(stmt)

type
  SqliteAlloc[T: pointer|ptr|cstring] = object ## Obj with a `=destroy` hook which calls `sqlite3.free`
    val*: T
when defined(nimAllowNonVarDestructor):
  proc `=destroy`*[T](x: SqliteAlloc[T]) =
    sqlite3.free(x.val)
else:
  proc `=destroy`*[T](x: var SqliteAlloc[T]) =
    sqlite3.free(x.val)
proc `=copy`*[T](dest: var SqliteAlloc[T]; src: SqliteAlloc[T]) {.error.}
proc `=dup`*[T](x: SqliteAlloc[T]): SqliteAlloc[T] {.error.}
converter get*[T](sqliteAlloc: SqliteAlloc[T]): lent T {.inline.} = sqliteAlloc.val
converter get*[T](sqliteAlloc: var SqliteAlloc[T]): var T {.inline.} = sqliteAlloc.val
template `$`*[T](wrapped: SqliteAlloc[T]): string = $wrapped.val

template expandedSql*(stmt: Statement): SqliteAlloc[cstring] =
  ## Computes and returns the SQL text of `stmt` after parameter substitution.
  SqliteAlloc[cstring](val: sqlite3.expanded_sql(stmt))

template readonly*(stmt: Statement): bool =
  sqlite3.stmt_readonly(stmt)

template busy*(stmt: Statement): bool =
  sqlite3.stmt_busy(stmt)

template lastInsertRowid*(db: Database): int64 =
  ## Returns the ROWID of the most recent insert, or 0 if there has never been a successful insert into a ROWID table on this connection.
  sqlite3.last_insert_rowid(db)

template lastStatement*(db: Database; stmt: Statement = nil): Statement =
  ## Returns the last `Statement` prepared before `stmt`, or if `stmt` is `nil`, the last `Statement` prepared.
  sqlite3.next_stmt(db, stmt)


#                                   Readable high-level interface

macro bindParams*(stmt: Statement; params: typed; start: Positive32 = 1) =
  if params.kind == nnkTupleConstr: # Tuple literal, ideal as we can bind static values even if not all values in the tuple are static
    result = newStmtList()
    for i in 0 ..< params.len:
      result.add newCall("bindParam", stmt, infix(start, "+", newLit(i)), params[i])
  else:
    result = quote do:
      when `params` isnot tuple:
        bindParam(`stmt`, `start`, `params`)
      elif `params` isnot tuple[]: # isnot empty tuple
        var i = `start`
        for param in `params`:
          bindParam(`stmt`, i, param)
          inc i

template prepStatement*(db: Database; sql: auto; params: auto; flags: set[PrepareFlag] = {}): StatementObj =
  # Template so that we can pass a tuple literal to `bindParams`
  let result = db.prepStatement(sql, flags)
  result.bindParams(params)
  result

template exec*(db: Database; sql: auto; params: auto = (); flags: set[PrepareFlag] = {}) =
  exec db.prepStatement(sql, params, flags)


template unpack*[t](stmt: Statement; T: typedesc[t]): t =
  when T isnot tuple:
    getColumn(stmt, 0, T)
  elif T isnot tuple[]:
    var result: T
    var i = 0'i32
    for field in result.fields:
      field = getColumn(stmt, i, typeof field)
      inc i
    result

template query*[t](db: Database; sql: auto; params: auto; T: typedesc[t]; flags: set[PrepareFlag] = {}): t =
  let stmt = db.prepStatement(sql, params, flags)
  if likely step stmt:
    unpack(stmt, T)
  else:
    raise newException(SqliteError, "Statement returned no rows")

template query*[t](db: Database; sql: auto; T: typedesc[t]; flags: set[PrepareFlag] = {}): t =
  query(db, sql, (), T, flags)

iterator query*[t](db: Database; sql: auto; params: auto|static[auto]; T: typedesc[t]; flags: set[PrepareFlag] = {}): t =
  let stmt = db.prepStatement(sql, params, flags)
  while step stmt:
    yield unpack(stmt, T)

iterator query*[t](db: Database; sql: auto; T: typedesc[t]; flags: set[PrepareFlag] = {}): t =
  let stmt = db.prepStatement(sql, flags)
  while step stmt:
    yield unpack(stmt, T)


template transaction*(db: Database; mode: string; body: typed) =
  assert mode in ["DEFERRED", "IMMEDIATE", "EXCLUSIVE"]
  db.exec "BEGIN " & mode
  try:
    body
    db.exec "COMMIT"
  except:
    db.exec "ROLLBACK"
    raise getCurrentException()

template transaction*(db: Database; body: typed) =
  transaction(db, "DEFERRED", body)



#                                              Debug

from std/strutils import alignLeft

template explainLevel*(stmt: Statement): range[0'i32..2'i32] =
  ## Returns 0 if `stmt` is not an "EXPLAIN" statement, 1 otherwise, and 2 if `stmt` is an "EXPLAIN QUERY PLAN" statement.
  sqlite3.stmt_isexplain(stmt)

proc setExplain*(stmt: Statement; mode: bool|range[0'i32..2'i32]|static[range[0..2]] = true) {.inline.} =
  ## Change the EXPLAIN flag for `stmt` so that it acts as if it was/wasn't prefixed with "EXPLAIN" or "EXPLAIN QUERY PLAN".
  if stmt.busy: restart stmt
  check sqlite3.stmt_explain(stmt, int32 mode)

proc getExplanation(stmt: Statement): seq[seq[string]] {.inline.} =
  let origExplain = stmt.explainLevel
  if origExplain != 1:
    setExplain(stmt)
  let numColumns = stmt.numColumns
  result = @[newSeq[string](numColumns)]
  for i in 0 ..< numColumns:
    result[0][i] = $stmt.getColumnName(i)
  var j = 1
  while step stmt:
    result.add newSeq[string](numColumns)
    for i in 0 ..< numColumns:
      result[j][i] = stmt[i, string]
    inc j
  if origExplain != 1:
    setExplain(stmt, origExplain)

proc echoTable(data: seq[seq[string]]) {.inline.} =
  if likely data.len > 0:
    var maxWidths = newSeqUninit[int](data[0].len)
    for i in 0 .. data[0].high:
      maxWidths[i] = data[0][i].len
    for i in 1 .. data.high:
      for j in 0 .. data[i].high:
        maxWidths[j] = max(maxWidths[j], data[i][j].len)
    for i in 0 .. data.high:
      for j in 0 .. data[i].high:
        stdout.write alignLeft(data[i][j], maxWidths[j] + 1)
      stdout.write '\n'; stdout.flushFile()

proc explain*(stmt: Statement) =
  ## Echoes a table explaining how `stmt`'s execution within SQLite is planned.
  ## The output format of EXPLAIN is not fully specified and is subject to change from one release of SQLite to the next.
  echoTable getExplanation(stmt)
