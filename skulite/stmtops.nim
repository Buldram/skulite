#                                           Statement Ops
#                                             Ordinals

proc bindParam*(stmt: Statement; index: Positive32; val: SomeOrdinal) {.inline.} =
  sqliteCheck sqlite3_bind_int64(stmt, index, cast[int64](val))

template canConvert(val: int64; T: typedesc[SomeOrdinal]): bool =
  ## Whether `val` is convertable to the ordinal type `T`.
  when $T in ["int64", "uint64"]:
    true
  elif T is enum:
    cast[T](val) in T.low .. T.high
  elif T is uint64:
    cast[uint64](val) in T.low .. T.high
  else:
    val in int64(T.low) .. int64(T.high)

proc getColumn*(stmt: Statement; index: Natural32; T: typedesc[SomeOrdinal]): T {.inline.} =
  when T is int: {.warning: "Use `int64` instead of `int` for compatability with lower bit-width architectures".}
  let res =
    when uint64(T.high) > uint64(int32.high) or int64(T.low) < int64(int32.low):
      sqlite3_column_int64(stmt, index)
    else:
      sqlite3_column_int(stmt, index)
  if res == 0: checkUsage(stmt)
  when compileOption("rangechecks"):
    if not canConvert(res, T):
      raise newException(ValueError, "Invalid value `" & $res & "` for conversion to type `" & $T & '`')
  cast[T](res)


#                                              float

proc bindParam*(stmt: Statement; index: Positive32; val: float|float64) {.inline.} =
  sqliteCheck sqlite3_bind_double(stmt, index, val)

template bindParam*(stmt: Statement; index: Positive32; val: float32) =
  bindParam(stmt, index, float64 val)

proc getColumn*(stmt: Statement; index: Natural32; T: typedesc[float|float64]): T {.inline.} =
  result = sqlite3_column_double(stmt, index)
  if result == 0: checkUsage(stmt)

template getColumn*(stmt: Statement; index: Natural32; T: typedesc[float32]): T =
  float32(getColumn(stmt, index, float64))


#                                              string

proc bindText(stmt: Statement; index: Positive32; val: cstring; len: int32; destructor: sqlite3_destructor) {.inline.} =
  sqliteCheck sqlite3_bind_text(stmt, index, val, len, destructor)

template bindParam*(stmt: Statement; index: Positive32; val: cstring and (not string)) =
  bindText(stmt, index, val, int32 val.len, SQLITE_TRANSIENT)

proc bindParam*(stmt: Statement; index: Positive32; val: openArray[char]) {.inline.} =
  bindText(stmt, index, cast[cstring](unsafeAddr val), int32 val.len, SQLITE_TRANSIENT)

proc getColumn*(stmt: Statement; index: Natural32; T: typedesc[cstring]): cstring {.inline.} =
  ## Warning: Copy-less access, freed when 1. `stmt` is finalized/freed (and finalized by `=destroy`) 2. `stmt` is stepped 3. `stmt` is reset.
  result = sqlite3_column_text(stmt, index)
  if unlikely isNil(result): checkForError(stmt)

proc getColumnLen*(stmt: Statement; index: Natural32): int32 {.inline.} =
  result = sqlite3_column_bytes(stmt, index)
  if unlikely result == 0: checkForError(stmt)

proc getColumn*(stmt: Statement; index: Natural32; T: typedesc[string|seq[char]]; optForLong = false): T {.inline.} =
  ## With `optForLong` set to `false` (the default), O(n) `len[cstring]` is used to get the text's length,
  ## if you're expecting the column's text to be long (> 500 chars), consider setting `optForLong` to `true`.
  let p = getColumn(stmt, index, cstring)
  if likely(not isNil(p)):
    let len =
      if not optForLong: p.len
      else: stmt.getColumnLen(index)
    if likely len != 0:
      result = when T is string: newStringUninit(len) else: newSeqUninit[char](len)
      copyMem(addr result[0], p, len)

template getColumn*(stmt: Statement; index: Natural32; T: typedesc[openArray[char]]; optForLong = false): T =
  ## Warning: Copy-less access, freed when 1. `stmt` is finalized/freed (and finalized by `=destroy`) 2. `stmt` is stepped 3. `stmt` is reset.
  ##
  ## With `optForLong` set to `false` (the default), O(n) `len[cstring]` is used to get the text's length,
  ## if you're expecting the column's text to be long (> 500 chars), consider setting `optForLong` to `true`.
  let p = getColumn(stmt, index, cstring)
  let len =
    if unlikely(isNil(p)): 0
    elif optForLong: stmt.getColumnLen(index)
    else: p.len
  p.toOpenArray(0, len-1)

proc getColumn*[N](stmt: Statement; index: Natural32; T: typedesc[array[N, char]]): T {.inline.} =
  let p = sqlite3_column_text(stmt, index)
  if likely(not isNil(p)):
    copyMem(addr result[0], p, 1 + N.high - N.low)
  else: checkForError(stmt)


#                                          "blobs" / bytes

proc bindBlob(stmt: Statement; index: int32; val: pointer; len: int32; destructor: sqlite3_destructor) {.inline.} =
  # sqlite3_bind_blob64 does exist and accepts uint64 for len, but SQLite does not support blob values of len > int32.high (about 2.1GiB)
  sqliteCheck sqlite3_bind_blob(stmt, index, val, len, destructor)

proc bindParam*(stmt: Statement; index: Positive32; val: openArray[byte]) {.inline.} =
  bindBlob(stmt, index, unsafeAddr val, int32 val.len, SQLITE_TRANSIENT)

proc getColumn*(stmt: Statement; index: Natural32; T: typedesc[ptr UncheckedArray[byte]]): T {.inline.} =
  ## Warning: Copy-less access, freed when 1. `stmt` is finalized/freed (and finalized by `=destroy`) 2. `stmt` is stepped 3. `stmt` is reset.
  result = sqlite3_column_blob(stmt, index)
  if unlikely isNil(result): checkForError(stmt)

template getColumn*(stmt: Statement; index: Natural32; T: typedesc[openArray[byte]]): T =
  ## Warning: Copy-less access, freed when 1. `stmt` is finalized/freed (and finalized by `=destroy`) 2. `stmt` is stepped 3. `stmt` is reset.
  let p = getColumn(stmt, index, ptr UncheckedArray[byte])
  let len =
    if unlikely(isNil(p)):
      0
    else:
      stmt.getColumnLen(index)
  p.toOpenArray(0, len-1)

proc getColumn*(stmt: Statement; index: Natural32; T: typedesc[seq[byte]]): T {.inline.} =
  let p = getColumn(stmt, index, ptr UncheckedArray[byte])
  if likely(not isNil(p)):
    let len = stmt.getColumnLen(index)
    result = newSeqUninit[byte](len)
    copyMem(addr result[0], p, len)

proc getColumn*[N](stmt: Statement; index: Natural32; T: typedesc[array[N, byte]]): T {.inline.} =
  let p = getColumn(stmt, index, ptr UncheckedArray[byte])
  if likely(not isNil(p)):
    copyMem(addr result[0], p, 1 + N.high - N.low)


#                                             Option

proc bindParam*(stmt: Statement; index: Positive32; val: typeof(nil)) {.inline.} =
  sqliteCheck sqlite3_bind_null(stmt, index)

proc bindParam*[T](stmt: Statement; index: Positive32; val: Option[T]) {.inline.} =
  if val.isNone: bindParam(stmt, index, nil)
  else: bindParam(stmt, index, unsafeGet val)

proc getColumnType*(stmt: Statement; index: Natural32): Datatype {.inline.} =
  ## Get the initial SQLite data type of the result column at `index` of `stmt`.
  result = sqlite3_column_type(stmt, index)
  if result == SqliteNull: checkUsage(stmt)

proc columnIsNil*(stmt: Statement; index: Natural32): bool {.inline.} =
  getColumnType(stmt, index) == SqliteNull

proc getColumn*[V](stmt: Statement; index: Natural32; T: typedesc[Option[V]]): T {.inline.} =
  if columnIsNil(stmt, 0):
    none V
  else:
    some getColumn(stmt, index, V)


#                                     Generic copyMem fallback

type
  CopyMemable = concept type T
    supportsCopyMem(T)
    T isnot openArray|array # To avoid overloading conversions to openArray
 
proc bindParam*[T: CopyMemable](stmt: Statement; index: Positive32; val: T) {.inline.} =
  bindBlob(stmt, index, unsafeAddr val, int32 sizeof(T), SQLITE_TRANSIENT)

proc getColumn*[t: CopyMemable](stmt: Statement; index: Natural32; T: typedesc[t]): t {.inline.} =
  let p = getColumn(stmt, index, ptr UncheckedArray[byte])
  if likely(not isNil(p)):
    copyMem(addr result, p, sizeof(T))
