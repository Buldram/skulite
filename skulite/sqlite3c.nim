import std/macros

const staticSqlite {.booldefine.} = defined(windows)
## Whether to statically compile and bundle SQLite with the application.
when not staticSqlite:
  from std/strutils import `%`
  from std/os import DynlibFormat
  const sqliteLib {.strdefine.} = DynlibFormat % "sqlite3"
else:
  const sqliteThreadsafe {.booldefine.} = compileOption("threads")
    ## Measurable performance impact, but with it disabled SQLite can only be used on a single thread at a time.
  const sqliteCompFlags {.strdefine.} = block:
    ## Options passed to the linker when compiling SQLite.
    ## More info: https://www.sqlite.org/compile.html
    var opts: string
    opts.add " -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1"
    opts.add " -DSQLITE_LIKE_DOESNT_MATCH_BLOBS=1"
    opts.add " -DSQLITE_DEFAULT_MEMSTATUS=0"
    opts.add " -DSQLITE_DQS=0" # Disable the double-quoted string literal misfeature.
    opts.add " -DSQLITE_OMIT_DEPRECATED=1"
    opts.add " -DSQLITE_OMIT_DECLTYPE=1"
    opts.add " -DSQLITE_OMIT_PROGRESS_CALLBACK=1"
    opts.add " -DSQLITE_OMIT_SHARED_CACHE=1"
    when not sqliteThreadsafe:
      opts.add " -DSQLITE_THREADSAFE=0"
    when not defined(windows):
      opts.add " -DSQLITE_USE_ALLOCA=1"
    when not defined(release):
      opts.add " -DSQLITE_ENABLE_API_ARMOR"
    elif defined(danger):
      opts.add " -DSQLITE_MAX_EXPR_DEPTH=0"
    opts
  {.compile("sqlite3.c", sqliteCompFlags).}

proc importcSqliteImpl(name, body: NimNode): NimNode =
  body.addPragma:
    if name.kind == nnkEmpty:
      ident "importc"
    else:
      nnkExprColonExpr.newtree(ident "importc", name)
  body.addPragma ident "cdecl"
  when not staticSqlite:
    body.addPragma nnkExprColonExpr.newTree(ident "dynlib", newLit sqliteLib)
  body

macro importcSqlite*(name: untyped; body: untyped) =
  importcSqliteImpl(name, body)

macro importcSqlite*(body: untyped) =
  importcSqliteImpl(nnkEmpty.newNimNode(), body)


type
  sqlite3* {.incompleteStruct.} = object
  sqlite3_stmt* {.incompleteStruct.} = object
  sqlite3_value* {.incompleteStruct.} = object
  sqlite3_destructor* = proc (x: pointer) {.cdecl, gcsafe.}

  ResultCode* {.size: sizeof(int32).} = enum
    SQLITE_OK,         ## Successful result
    SQLITE_ERROR,      ## Generic error
    SQLITE_INTERNAL,   ## Internal logic error in SQLite
    SQLITE_PERM,       ## Access permission denied
    SQLITE_ABORT,      ## Callback routine requested an abort
    SQLITE_BUSY,       ## The database file is locked
    SQLITE_LOCKED,     ## A table in the database is locked
    SQLITE_NOMEM,      ## A malloc() failed
    SQLITE_READONLY,   ## Attempt to write a readonly database
    SQLITE_INTERRUPT,  ## Operation terminated by sqlite3_interrupt()*/
    SQLITE_IOERR,      ## Some kind of disk I/O error occurred
    SQLITE_CORRUPT,    ## The database disk image is malformed
    SQLITE_NOTFOUND,   ## Unknown opcode in sqlite3_file_control()
    SQLITE_FULL,       ## Insertion failed because database is full
    SQLITE_CANTOPEN,   ## Unable to open the database file
    SQLITE_PROTOCOL,   ## Database lock protocol error
    SQLITE_EMPTY,      ## Internal use only
    SQLITE_SCHEMA,     ## The database schema changed
    SQLITE_TOOBIG,     ## String or BLOB exceeds size limit
    SQLITE_CONSTRAINT, ## Abort due to constraint violation
    SQLITE_MISMATCH,   ## Data type mismatch
    SQLITE_MISUSE,     ## Library used incorrectly
    SQLITE_NOLFS,      ## Uses OS features not supported on host
    SQLITE_AUTH,       ## Authorization denied
    SQLITE_FORMAT,     ## Not used
    SQLITE_RANGE,      ## 2nd parameter to sqlite3_bind out of range
    SQLITE_NOTADB,     ## File opened that is not a database file
    SQLITE_NOTICE,     ## Notifications from sqlite3_log()
    SQLITE_WARNING,    ## Warnings from sqlite3_log()
    SQLITE_ROW = 100,  ## sqlite3_step() has another row ready
    SQLITE_DONE = 101, ## sqlite3_step() has finished executing
    ## Extended result codes
    SQLITE_OK_LOAD_PERMANENTLY     = SQLITE_OK.int or 1 shl 8,
    SQLITE_ERROR_MISSING_COLLSEQ   = SQLITE_ERROR.int or 1 shl 8,
    SQLITE_BUSY_RECOVERY           = SQLITE_BUSY.int or 1 shl 8,
    SQLITE_LOCKED_SHAREDCACHE      = SQLITE_LOCKED.int or 1 shl 8,
    SQLITE_READONLY_RECOVERY       = SQLITE_READONLY.int or 1 shl 8,
    SQLITE_IOERR_READ              = SQLITE_IOERR.int or 1 shl 8,
    SQLITE_CORRUPT_VTAB            = SQLITE_CORRUPT.int or 1 shl 8,
    SQLITE_CANTOPEN_NOTEMPDIR      = SQLITE_CANTOPEN.int or 1 shl 8,
    SQLITE_CONSTRAINT_CHECK        = SQLITE_CONSTRAINT.int or 1 shl 8,
    SQLITE_AUTH_USER               = SQLITE_AUTH.int or 1 shl 8,
    SQLITE_NOTICE_RECOVER_WAL      = SQLITE_NOTICE.int or 1 shl 8,
    SQLITE_WARNING_AUTOINDEX       = SQLITE_WARNING.int or 1 shl 8,
    SQLITE_OK_SYMLINK              = SQLITE_OK.int or 2 shl 8, ## Internal use only
    SQLITE_ERROR_RETRY             = SQLITE_ERROR.int or 2 shl 8,
    SQLITE_ABORT_ROLLBACK          = SQLITE_ABORT.int or 2 shl 8,
    SQLITE_BUSY_SNAPSHOT           = SQLITE_BUSY.int or 2 shl 8,
    SQLITE_LOCKED_VTAB             = SQLITE_LOCKED.int or 2 shl 8,
    SQLITE_READONLY_CANTLOCK       = SQLITE_READONLY.int or 2 shl 8,
    SQLITE_IOERR_SHORT_READ        = SQLITE_IOERR.int or 2 shl 8,
    SQLITE_CORRUPT_SEQUENCE        = SQLITE_CORRUPT.int or 2 shl 8,
    SQLITE_CANTOPEN_ISDIR          = SQLITE_CANTOPEN.int or 2 shl 8,
    SQLITE_CONSTRAINT_COMMITHOOK   = SQLITE_CONSTRAINT.int or 2 shl 8,
    SQLITE_NOTICE_RECOVER_ROLLBACK = SQLITE_NOTICE.int or 2 shl 8,
    SQLITE_ERROR_SNAPSHOT          = SQLITE_ERROR.int or 3 shl 8,
    SQLITE_BUSY_TIMEOUT            = SQLITE_BUSY.int or 3 shl 8,
    SQLITE_READONLY_ROLLBACK       = SQLITE_READONLY.int or 3 shl 8,
    SQLITE_IOERR_WRITE             = SQLITE_IOERR.int or 3 shl 8,
    SQLITE_CORRUPT_INDEX           = SQLITE_CORRUPT.int or 3 shl 8,
    SQLITE_CANTOPEN_FULLPATH       = SQLITE_CANTOPEN.int or 3 shl 8,
    SQLITE_CONSTRAINT_FOREIGNKEY   = SQLITE_CONSTRAINT.int or 3 shl 8,
    SQLITE_NOTICE_RBU              = SQLITE_NOTICE.int or 3 shl 8,
    SQLITE_READONLY_DBMOVED        = SQLITE_READONLY.int or 4 shl 8,
    SQLITE_IOERR_FSYNC             = SQLITE_IOERR.int or 4 shl 8,
    SQLITE_CANTOPEN_CONVPATH       = SQLITE_CANTOPEN.int or 4 shl 8,
    SQLITE_CONSTRAINT_FUNCTION     = SQLITE_CONSTRAINT.int or 4 shl 8,
    SQLITE_READONLY_CANTINIT       = SQLITE_READONLY.int or 5 shl 8,
    SQLITE_IOERR_DIR_FSYNC         = SQLITE_IOERR.int or 5 shl 8,
    SQLITE_CANTOPEN_DIRTYWAL       = SQLITE_CANTOPEN.int or 5 shl 8, ## Not used
    SQLITE_CONSTRAINT_NOTNULL      = SQLITE_CONSTRAINT.int or 5 shl 8,
    SQLITE_READONLY_DIRECTORY      = SQLITE_READONLY.int or 6 shl 8,
    SQLITE_IOERR_TRUNCATE          = SQLITE_IOERR.int or 6 shl 8,
    SQLITE_CANTOPEN_SYMLINK        = SQLITE_CANTOPEN.int or 6 shl 8,
    SQLITE_CONSTRAINT_PRIMARYKEY   = SQLITE_CONSTRAINT.int or 6 shl 8,
    SQLITE_IOERR_FSTAT             = SQLITE_IOERR.int or 7 shl 8,
    SQLITE_CONSTRAINT_TRIGGER      = SQLITE_CONSTRAINT.int or 7 shl 8,
    SQLITE_IOERR_UNLOCK            = SQLITE_IOERR.int or 8 shl 8,
    SQLITE_CONSTRAINT_UNIQUE       = SQLITE_CONSTRAINT.int or 8 shl 8,
    SQLITE_IOERR_RDLOCK            = SQLITE_IOERR.int or 9 shl 8,
    SQLITE_CONSTRAINT_VTAB         = SQLITE_CONSTRAINT.int or 9 shl 8,
    SQLITE_IOERR_DELETE            = SQLITE_IOERR.int or 10 shl 8,
    SQLITE_CONSTRAINT_ROWID        = SQLITE_CONSTRAINT.int or 10 shl 8,
    SQLITE_IOERR_BLOCKED           = SQLITE_IOERR.int or 11 shl 8,
    SQLITE_CONSTRAINT_PINNED       = SQLITE_CONSTRAINT.int or 11 shl 8,
    SQLITE_IOERR_NOMEM             = SQLITE_IOERR.int or 12 shl 8,
    SQLITE_CONSTRAINT_DATATYPE     = SQLITE_CONSTRAINT.int or 12 shl 8,
    SQLITE_IOERR_ACCESS            = SQLITE_IOERR.int or 13 shl 8,
    SQLITE_IOERR_CHECKRESERVEDLOCK = SQLITE_IOERR.int or 14 shl 8,
    SQLITE_IOERR_LOCK              = SQLITE_IOERR.int or 15 shl 8,
    SQLITE_IOERR_CLOSE             = SQLITE_IOERR.int or 16 shl 8,
    SQLITE_IOERR_DIR_CLOSE         = SQLITE_IOERR.int or 17 shl 8,
    SQLITE_IOERR_SHMOPEN           = SQLITE_IOERR.int or 18 shl 8,
    SQLITE_IOERR_SHMSIZE           = SQLITE_IOERR.int or 19 shl 8,
    SQLITE_IOERR_SHMLOCK           = SQLITE_IOERR.int or 20 shl 8,
    SQLITE_IOERR_SHMMAP            = SQLITE_IOERR.int or 21 shl 8,
    SQLITE_IOERR_SEEK              = SQLITE_IOERR.int or 22 shl 8,
    SQLITE_IOERR_DELETE_NOENT      = SQLITE_IOERR.int or 23 shl 8,
    SQLITE_IOERR_MMAP              = SQLITE_IOERR.int or 24 shl 8,
    SQLITE_IOERR_GETTEMPPATH       = SQLITE_IOERR.int or 25 shl 8,
    SQLITE_IOERR_CONVPATH          = SQLITE_IOERR.int or 26 shl 8,
    SQLITE_IOERR_VNODE             = SQLITE_IOERR.int or 27 shl 8,
    SQLITE_IOERR_AUTH              = SQLITE_IOERR.int or 28 shl 8,
    SQLITE_IOERR_BEGIN_ATOMIC      = SQLITE_IOERR.int or 29 shl 8,
    SQLITE_IOERR_COMMIT_ATOMIC     = SQLITE_IOERR.int or 30 shl 8,
    SQLITE_IOERR_ROLLBACK_ATOMIC   = SQLITE_IOERR.int or 31 shl 8,
    SQLITE_IOERR_DATA              = SQLITE_IOERR.int or 32 shl 8,
    SQLITE_IOERR_CORRUPTFS         = SQLITE_IOERR.int or 33 shl 8,
    SQLITE_IOERR_IN_PAGE           = SQLITE_IOERR.int or 34 shl 8

  OpenFlag* {.size: sizeof(int32).} = enum
    ReadOnly,      ## Ok for sqlite3_open_v2()
    ReadWrite,     ## Ok for sqlite3_open_v2()
    Create,        ## Ok for sqlite3_open_v2()
    DeleteOnClose, ## VFS only
    Exclusive,     ## VFS only
    AutoProxy,     ## VFS only
    URI,           ## Ok for sqlite3_open_v2()
    Memory,        ## Ok for sqlite3_open_v2()
    MainDB,        ## VFS only
    TempDB,        ## VFS only
    TransientDB,   ## VFS only
    MainJournal,   ## VFS only
    TempJournal,   ## VFS only
    SubJournal,    ## VFS only
    MasterJournal, ## VFS only, also called SuperJournal
    NoMutex,       ## Ok for sqlite3_open_v2()
    FullMutex,     ## Ok for sqlite3_open_v2()
    SharedCache,   ## Ok for sqlite3_open_v2()
    PrivateCache,  ## Ok for sqlite3_open_v2()
    WAL,           ## VFS only
    NoFollow,      ## Ok for sqlite3_open_v2()
    ExResCode      ## Extended result codes

  PrepareFlag* {.size: sizeof(uint32).} = enum
    Persistent,
    Normalize,
    NoVtab

  Datatype* {.size: sizeof(int32).} = enum
    SqliteInteger = 1,
    SqliteFloat,
    SqliteText,
    SqliteBlob,
    SqliteNull

const
  SuperJournal* = MasterJournal

const
  SQLITE_STATIC* = cast[sqlite3_destructor](-1)
  SQLITE_TRANSIENT* = cast[sqlite3_destructor](-1)

func sqlite3_errstr*(code: ResultCode): cstring {.importcSqlite.}
func sqlite3_errcode*(db: ptr sqlite3): ResultCode {.importcSqlite.}

proc sqlite3_open_v2*(filename: cstring; db: out ptr sqlite3; flags: set[OpenFlag]; vfs: cstring): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_close_v2*(db: ptr sqlite3): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_db_cacheflush*(db: ptr sqlite3): ResultCode {.importcSqlite, sideEffect.}

proc sqlite3_prepare_v3*(db: ptr sqlite3; sql: cstring; len: int32; prepFlags: set[PrepareFlag]; stmt: out ptr sqlite3_stmt; tail: ptr cstring): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_finalize*(stmt: ptr sqlite3_stmt): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_step*(stmt: ptr sqlite3_stmt): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_reset*(stmt: ptr sqlite3_stmt): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_clear_bindings*(stmt: ptr sqlite3_stmt): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_stmt_explain*(stmt: ptr sqlite3_stmt; mode: int32): ResultCode {.importcSqlite.}

func sqlite3_bind_parameter_count*(stmt: ptr sqlite3_stmt): int32 {.importcSqlite.}
func sqlite3_column_count*(stmt: ptr sqlite3_stmt): int32 {.importcSqlite.}
func sqlite3_data_count*(stmt: ptr sqlite3_stmt): int32 {.importcSqlite.}
func sqlite3_stmt_readonly*(stmt: ptr sqlite3_stmt): bool {.importcSqlite.}
func sqlite3_stmt_isexplain*(stmt: ptr sqlite3_stmt): range[0'i8 .. 2'i8] {.importcSqlite.}
proc sqlite3_stmt_busy*(stmt: ptr sqlite3_stmt): bool {.importcSqlite.}
func sqlite3_db_handle*(stmt: ptr sqlite3_stmt): ptr sqlite3 {.importcSqlite.}
func sqlite3_sql*(stmt: ptr sqlite3_stmt): cstring {.importcSqlite.}
proc sqlite3_next_stmt*(db: ptr sqlite3; stmt: ptr sqlite3_stmt): ptr sqlite3_stmt {.importcSqlite.}
proc sqlite3_free*(p: pointer) {.importcSqlite, sideEffect.}
proc sqlite3_expanded_sql*(stmt: ptr sqlite3_stmt): cstring {.importcSqlite, sideEffect.}

proc sqlite3_bind_int64*(stmt: ptr sqlite3_stmt; index: int32; val: int64): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_bind_double*(stmt: ptr sqlite3_stmt; index: int32; val: float64): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_bind_text*(stmt: ptr sqlite3_stmt; index: int32; val: cstring; len: int32; destructor: sqlite3_destructor): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_bind_blob*(stmt: ptr sqlite3_stmt; index: int32; val: pointer; len: int32; destructor: sqlite3_destructor): ResultCode {.importcSqlite, sideEffect.}
proc sqlite3_bind_null*(stmt: ptr sqlite3_stmt; index: int32): ResultCode {.importcSqlite, sideEffect.}

proc sqlite3_column_int*(stmt: ptr sqlite3_stmt; index: int32): int32 {.importcSqlite, sideEffect.}
proc sqlite3_column_int64*(stmt: ptr sqlite3_stmt; index: int32): int64 {.importcSqlite, sideEffect.}
proc sqlite3_column_double*(stmt: ptr sqlite3_stmt; index: int32): float64 {.importcSqlite, sideEffect.}
proc sqlite3_column_text*(stmt: ptr sqlite3_stmt; index: int32): cstring {.importcSqlite, sideEffect.}
proc sqlite3_column_blob*(stmt: ptr sqlite3_stmt; index: int32): ptr UncheckedArray[byte] {.importcSqlite, sideEffect.}
proc sqlite3_column_bytes*(stmt: ptr sqlite3_stmt; index: int32): int32 {.importcSqlite, sideEffect.}
proc sqlite3_column_type*(stmt: ptr sqlite3_stmt; index: int32): Datatype {.importcSqlite, sideEffect.}
proc sqlite3_column_name*(stmt: ptr sqlite3_stmt; index: int32): cstring {.importcSqlite, sideEffect.}
