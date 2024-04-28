## SQlite wrapper module.

import std/[macros, options, typetraits]
import skulite/[sqlite3c, shim]
export OpenFlag, SuperJournal, PrepareFlag, Datatype

when not defined(gcDestructors):
  {.error: "requires --mm:arc/orc".}

const checkSqliteUsage* {.booldefine.} = not defined(release)
## Whether to often do costly checking for correct usage of the SQLite API.

type
  SqliteError* = object of CatchableError

func raiseSqliteError*(err: ResultCode) {.inline, noreturn.} =
  raise newException(SqliteError, $sqlite3_errstr(err))

func sqliteCheck*(ret: ResultCode) {.inline, raises: [SqliteError].} =
  if unlikely ret != SQLITE_OK: raiseSqliteError(ret)


# We have "wrapped" objects for destructors but this module's procedures accept the underlying pointer (with implicit unwrapping via `converter`) to give users the option to create and use custom objects.

type
  Database* = ptr sqlite3
  DatabaseWrapper* = object
    raw*: Database

proc close*(db: var Database) {.inline.} =
  sqliteCheck sqlite3_close_v2(db)
  db = nil

proc `=copy`*(dest: var DatabaseWrapper; src: DatabaseWrapper) {.error.}
proc `=dup`*(x: DatabaseWrapper): DatabaseWrapper {.error.}
when defined(nimAllowNonVarDestructor):
  proc `=destroy`*(x: DatabaseWrapper) =
    discard sqlite3_close_v2(x.raw)
else:
  proc `=destroy`*(x: var DatabaseWrapper) =
    discard sqlite3_close_v2(x.raw)

proc openDatabase*(filename: cstring; flags = {ReadWrite, Create, ExResCode}; vfs: cstring = nil): DatabaseWrapper {.inline.} =
  sqliteCheck sqlite3_open_v2(filename, result.raw, flags, vfs)

template openDatabase*(filename: string; flags = {ReadWrite, Create, ExResCode}; vfs: cstring = nil): DatabaseWrapper =
  openDatabase(cstring filename, flags, vfs)

converter toRaw*(db: DatabaseWrapper): lent Database {.inline.} = db.raw
converter toRaw*(db: var DatabaseWrapper): var Database {.inline.} = db.raw

proc reopen*(db: var Database; filename: cstring; flags = {ReadWrite, Create, ExResCode}; vfs: cstring = nil) {.inline.} =
  sqliteCheck sqlite3_close_v2(db)
  sqliteCheck sqlite3_open_v2(filename, db, flags, vfs)

template reopen*(db: var Database; filename: string; flags = {ReadWrite, Create, ExResCode}; vfs: cstring = nil) =
  reopen(db, cstring filename, flags, vfs)

proc flush*(db: Database) {.inline.} =
  sqliteCheck sqlite3_db_cacheflush(db)


type
  Statement* = ptr sqlite3_stmt
  StatementWrapper* = object
    raw*: Statement

proc finalize*(stmt: var Statement) {.inline.} =
  sqliteCheck sqlite3_finalize(stmt)
  stmt = nil

proc `=copy`*(dest: var StatementWrapper; src: StatementWrapper) {.error.}
proc `=dup`*(x: StatementWrapper): StatementWrapper {.error.}
when defined(nimAllowNonVarDestructor):
  proc `=destroy`*(x: StatementWrapper) =
    discard sqlite3_finalize(x.raw)
else:
  proc `=destroy`*(x: var StatementWrapper) =
    discard sqlite3_finalize(x.raw)

proc prepStatement*(db: Database; sql: cstring and (not string); flags: set[PrepareFlag] = {}): StatementWrapper {.inline.} =
  sqliteCheck sqlite3_prepare_v3(db, sql, int32 sql.len, flags, result.raw, nil)

proc prepStatement*(db: Database; sql: openArray[char]; flags: set[PrepareFlag] = {}): StatementWrapper {.inline.} =
  sqliteCheck sqlite3_prepare_v3(db, cast[cstring](unsafeAddr sql), int32 sql.len, flags, result.raw, nil)

converter toRaw*(stmt: StatementWrapper): lent Statement {.inline.} = stmt.raw
converter toRaw*(stmt: var StatementWrapper): var Statement {.inline.} = stmt.raw

proc reprepare*(stmt: var Statement; db: Database; sql: cstring and (not string); flags: set[PrepareFlag] = {}) {.inline.} =
  sqliteCheck sqlite3_finalize(stmt)
  sqliteCheck sqlite3_prepare_v3(db, sql, int32 sql.len, flags, stmt, nil)

proc reprepare*(stmt: var Statement; db: Database; sql: openArray[char]; flags: set[PrepareFlag] = {}) {.inline.} =
  sqliteCheck sqlite3_finalize(stmt)
  sqliteCheck sqlite3_prepare_v3(db, cast[cstring](unsafeAddr sql), int32 sql.len, flags, stmt, nil)

template sql*(stmt: Statement): cstring =
  ## Returns `stmt`'s internal copy of the SQL text used to create it.
  sqlite3_sql(stmt)

template `$`*(stmt: Statement|StatementWrapper): string =
  $stmt.sql


proc step*(stmt: Statement): bool {.inline, discardable.} =
  ## Evaluate or "step" an SQL `stmt`. Returns `true` if the evaluation returned a row of data.
  let ret = sqlite3_step(stmt)
  case ret
  of SQLITE_ROW: return true
  of SQLITE_DONE: return false
  else: raiseSqliteError ret

proc exec*(stmt: Statement) {.inline.} =
  ## Execute an SQL `stmt`. Raises an exception if the execution returned a row of data. TODO: Should this Rollback?
  let ret = sqlite3_step(stmt)
  if unlikely ret != SQLITE_DONE:
    raiseSqliteError ret


template db*(stmt: Statement): Database =
  ## Returns the database connection to which `stmt` belongs.
  sqlite3_db_handle(stmt)

func checkForError(db: Database) {.inline.} =
  let err = sqlite3_errcode(db)
  if unlikely err notin {SQLITE_OK, SQLITE_ROW, SQLITE_DONE}:
    raiseSqliteError err

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
  sqlite3_bind_parameter_index(stmt, name)

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
  sqliteCheck sqlite3_reset(stmt)

proc clearParams*(stmt: Statement) {.inline.} =
  sqliteCheck sqlite3_clear_bindings(stmt)


#                                       Statement utilities

proc getColumnName*(stmt: Statement; index: Natural32): cstring {.inline.} =
  ## Warning: Copy-less access, freed when 1. `stmt` is finalized/freed (and finalized by `=destroy`) 2. `stmt` is stepped 3. `stmt` is reset.
  result = sqlite3_column_name(stmt, index)
  if unlikely isNil(result): checkForError(stmt)

template numParams*(stmt: Statement): int32 =
  sqlite3_bind_parameter_count(stmt)

template numColumns*(stmt: Statement): int32 =
  sqlite3_column_count(stmt)

template numValues*(stmt: Statement): int32 =
  ## Same as `numColumns`, but returns 0 if `stmt` hasn't been stepped yet.
  sqlite3_data_count(stmt)

type
  SqliteAlloc[T: pointer|ptr|cstring] = object ## Wrapper with a `=destroy` hook which calls `sqlite3_free`
    val*: T
when defined(nimAllowNonVarDestructor):
  proc `=destroy`*[T](x: SqliteAlloc[T]) =
    sqlite3_free(x.val)
else:
  proc `=destroy`*[T](x: var SqliteAlloc[T]) =
    sqlite3_free(x.val)
proc `=copy`*[T](dest: var SqliteAlloc[T]; src: SqliteAlloc[T]) {.error.}
proc `=dup`*[T](x: SqliteAlloc[T]): SqliteAlloc[T] {.error.}
converter get*[T](sqliteAlloc: SqliteAlloc[T]): lent T {.inline.} = sqliteAlloc.val
converter get*[T](sqliteAlloc: var SqliteAlloc[T]): var T {.inline.} = sqliteAlloc.val
template `$`*[T](wrapped: SqliteAlloc[T]): string = $wrapped.val

template expandedSql*(stmt: Statement): SqliteAlloc[cstring] =
  ## Computes and returns the SQL text of `stmt` after parameter substitution.
  SqliteAlloc[cstring](val: sqlite3_expanded_sql(stmt))

template readonly*(stmt: Statement): bool =
  sqlite3_stmt_readonly(stmt)

template busy*(stmt: Statement): bool =
  sqlite3_stmt_busy(stmt)

template lastInsertRowID*(db: Database): int64 =
  ## Returns the ROWID of the most recent insert, or 0 if there has never been a successful insert into a ROWID table on this connection.
  sqlite3_last_insert_rowid(db)

template lastStatement*(db: Database; stmt: Statement = nil): Statement =
  ## Returns the last `Statement` prepared before `stmt`, or if `stmt` is `nil`, the last `Statement` prepared.
  sqlite3_next_stmt(db, stmt)


#                                  Readable high-level interface

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

template prepStatement*(db: Database; sql: auto; params: auto; flags: set[PrepareFlag] = {}): StatementWrapper =
  # Template so that we can pass a tuple literal to `bindParams`
  let result = prepStatement(db, sql, flags)
  result.bindParams(params)
  result

template exec*(db: Database; sql: auto; params: auto = (); flags: set[PrepareFlag] = {}) =
  exec prepStatement(db, sql, params, flags)

template step*(db: Database; sql: auto; params: auto = (); flags: set[PrepareFlag] = {}): StatementWrapper =
  let result = prepStatement(db, sql, params, flags)
  step result
  result


proc unpack*[t](stmt: Statement; T: typedesc[t]): t {.inline.} =
  when T isnot tuple:
    getColumn(stmt, 0, T)
  elif T isnot tuple[]:
    var i = 0'i32
    for field in result.fields:
      field = getColumn(stmt, i, typeof field)
      inc i


template query*[t](db: Database; sql: auto; T: typedesc[t]; params: auto = (); flags: set[PrepareFlag] = {}): t =
  let stmt = db.prepStatement(sql, params, flags)
  step stmt
  unpack(stmt, T)

iterator query*[t](db: Database; sql: auto; T: typedesc[t]; params: auto|static[auto] = (); flags: set[PrepareFlag] = {}): t =
  let stmt = db.prepStatement(sql, params, flags)
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

proc isExplain*(stmt: Statement): range[0'i8 .. 2'i8] {.inline.} =
  ## Returns 0 if `stmt` is not an "EXPLAIN" statement, 1 otherwise, and 2 if `stmt` is an "EXPLAIN QUERY PLAN" statement.
  sqlite3_stmt_isexplain(stmt)

proc setExplain*(stmt: Statement; mode: bool|range[0'i8 .. 2'i8] = true) {.inline.} =
  ## Change the EXPLAIN flag for `stmt` so that it acts as if it was/wasn't prefixed with "EXPLAIN" or "EXPLAIN QUERY PLAN".
  if stmt.busy: restart stmt
  sqliteCheck sqlite3_stmt_explain(stmt, int32 mode)

proc getExplanation(stmt: Statement): seq[seq[string]] {.inline.} =
  let origExplain = stmt.isExplain
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
