const `static` {.booldefine.} = defined(windows)
const staticSqlite* {.booldefine.} = `static`
## Whether to bundle a copy of SQLite instead of searching for a dynamic library at runtime.
when staticSqlite:
  const sqliteThreadsafe {.booldefine.} = compileOption("threads")
    ## Measurable performance impact, but with it disabled SQLite can only be used on a single thread at a time.
  const sqliteCompFlags {.strdefine.} = (func: string =
    ## Options passed to the linker when compiling SQLite.
    ## More info: https://www.sqlite.org/compile.html
    result.add " -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1"
    result.add " -DSQLITE_LIKE_DOESNT_MATCH_BLOBS=1"
    result.add " -DSQLITE_DEFAULT_MEMSTATUS=0"
    result.add " -DSQLITE_DQS=0" # Disable the double-quoted string literal misfeature.
    result.add " -DSQLITE_OMIT_DEPRECATED=1"
    result.add " -DSQLITE_OMIT_DECLTYPE=1"
    result.add " -DSQLITE_OMIT_PROGRESS_CALLBACK=1"
    result.add " -DSQLITE_OMIT_SHARED_CACHE=1"
    when not sqliteThreadsafe:
      result.add " -DSQLITE_THREADSAFE=0"
    when not defined(windows):
      result.add " -DSQLITE_USE_ALLOCA=1"
    when not defined(release):
      result.add " -DSQLITE_ENABLE_API_ARMOR"
    elif defined(danger):
      result.add " -DSQLITE_MAX_EXPR_DEPTH=0")()
  {.compile("sqlite3.c", sqliteCompFlags).}
else:
  {.passl: "-lsqlite3".}


type
  DatabaseHandle* {.incompleteStruct.} = object # Database connection
  StatementHandle* {.incompleteStruct.} = object
  Database* = ptr DatabaseHandle
  Statement* = ptr StatementHandle
  Destructor* = proc (x: pointer) {.noconv, gcsafe, raises: [].}

  ResultCode* {.size: sizeof(int32).} = enum
    Ok,         ## Successful result
    Error,      ## Generic error
    Internal,   ## Internal logic error in sqlite
    Perm,       ## Access permission denied
    Abort,      ## Callback routine requested an abort
    Busy,       ## The database file is locked
    Locked,     ## A table in the database is locked
    Nomem,      ## A malloc() failed
    Readonly,   ## Attempt to write a readonly database
    Interrupt,  ## Operation terminated by sqlite3_interrupt()*
    Ioerr,      ## Some kind of disk io error occurred
    Corrupt,    ## The database disk image is malformed
    Notfound,   ## Unknown opcode in sqlite3_file_control()
    Full,       ## Insertion failed because database is full
    Cantopen,   ## Unable to open the database file
    Protocol,   ## Database lock protocol error
    Empty,      ## Internal use only
    Schema,     ## The database schema changed
    Toobig,     ## String or blob exceeds size limit
    Constraint, ## Abort due to constraint violation
    Mismatch,   ## Data type mismatch
    Misuse,     ## Library used incorrectly
    Nolfs,      ## Uses os features not supported on host
    Auth,       ## Authorization denied
    Format,     ## Not used
    Range,      ## 2nd parameter to sqlite3_bind out of range
    Notadb,     ## File opened that is not a database file
    Notice,     ## Notifications from sqlite3_log()
    Warning,    ## Warnings from sqlite3log()
    Row = 100,  ## sqlite3_step() has another row ready
    Done = 101, ## sqlite3_step() has finished executing
    ## Extended result codes
    OkLoadPermanently      = Ok.int or 1 shl 8,
    ErrorMissingCollseq    = Error.int or 1 shl 8,
    BusyRecovery           = Busy.int or 1 shl 8,
    LockedSharedcache      = Locked.int or 1 shl 8,
    ReadonlyRecovery       = Readonly.int or 1 shl 8,
    IoerrRead              = Ioerr.int or 1 shl 8,
    CorruptVtab            = Corrupt.int or 1 shl 8,
    CantopenNotempdir      = Cantopen.int or 1 shl 8,
    ConstraintCheck        = Constraint.int or 1 shl 8,
    AuthUser               = Auth.int or 1 shl 8,
    NoticeRecoverWal       = Notice.int or 1 shl 8,
    WarningAutoindex       = Warning.int or 1 shl 8,
    OkSymlink              = Ok.int or 2 shl 8, ## Internal Use Only
    ErrorRetry             = Error.int or 2 shl 8,
    AbortRollback          = Abort.int or 2 shl 8,
    BusySnapshot           = Busy.int or 2 shl 8,
    LockedVtab             = Locked.int or 2 shl 8,
    ReadonlyCantlock       = Readonly.int or 2 shl 8,
    IoerrShortRead         = Ioerr.int or 2 shl 8,
    CorruptSequence        = Corrupt.int or 2 shl 8,
    CantopenIsdir          = Cantopen.int or 2 shl 8,
    ConstraintCommithook   = Constraint.int or 2 shl 8,
    NoticeRecoverRollback  = Notice.int or 2 shl 8,
    ErrorSnapshot          = Error.int or 3 shl 8,
    BusyTimeout            = Busy.int or 3 shl 8,
    ReadonlyRollback       = Readonly.int or 3 shl 8,
    IoerrWrite             = Ioerr.int or 3 shl 8,
    CorruptIndex           = Corrupt.int or 3 shl 8,
    CantopenFullpath       = Cantopen.int or 3 shl 8,
    ConstraintForeignkey   = Constraint.int or 3 shl 8,
    NoticeRbu              = Notice.int or 3 shl 8,
    ReadonlyDbmoved        = Readonly.int or 4 shl 8,
    IoerrFsync             = Ioerr.int or 4 shl 8,
    CantopenConvpath       = Cantopen.int or 4 shl 8,
    ConstraintFunction     = Constraint.int or 4 shl 8,
    ReadonlyCantinit       = Readonly.int or 5 shl 8,
    IoerrDirFsync          = Ioerr.int or 5 shl 8,
    CantopenDirtywal       = Cantopen.int or 5 shl 8, ## Not Used
    ConstraintNotnull      = Constraint.int or 5 shl 8,
    ReadonlyDirectory      = Readonly.int or 6 shl 8,
    IoerrTruncate          = Ioerr.int or 6 shl 8,
    CantopenSymlink        = Cantopen.int or 6 shl 8,
    ConstraintPrimarykey   = Constraint.int or 6 shl 8,
    IoerrFstat             = Ioerr.int or 7 shl 8,
    ConstraintTrigger      = Constraint.int or 7 shl 8,
    IoerrUnlock            = Ioerr.int or 8 shl 8,
    ConstraintUnique       = Constraint.int or 8 shl 8,
    IoerrRdlock            = Ioerr.int or 9 shl 8,
    ConstraintVtab         = Constraint.int or 9 shl 8,
    IoerrDelete            = Ioerr.int or 10 shl 8,
    ConstraintRowid        = Constraint.int or 10 shl 8,
    IoerrBlocked           = Ioerr.int or 11 shl 8,
    ConstraintPinned       = Constraint.int or 11 shl 8,
    IoerrNomem             = Ioerr.int or 12 shl 8,
    ConstraintDatatype     = Constraint.int or 12 shl 8,
    IoerrAccess            = Ioerr.int or 13 shl 8,
    IoerrCheckreservedlock = Ioerr.int or 14 shl 8,
    IoerrLock              = Ioerr.int or 15 shl 8,
    IoerrClose             = Ioerr.int or 16 shl 8,
    IoerrDirClose          = Ioerr.int or 17 shl 8,
    IoerrShmopen           = Ioerr.int or 18 shl 8,
    IoerrShmsize           = Ioerr.int or 19 shl 8,
    IoerrShmlock           = Ioerr.int or 20 shl 8,
    IoerrShmmap            = Ioerr.int or 21 shl 8,
    IoerrSeek              = Ioerr.int or 22 shl 8,
    IoerrDeleteNoent       = Ioerr.int or 23 shl 8,
    IoerrMmap              = Ioerr.int or 24 shl 8,
    IoerrGettemppath       = Ioerr.int or 25 shl 8,
    IoerrConvpath          = Ioerr.int or 26 shl 8,
    IoerrVnode             = Ioerr.int or 27 shl 8,
    IoerrAuth              = Ioerr.int or 28 shl 8,
    IoerrBeginAtomic       = Ioerr.int or 29 shl 8,
    IoerrCommitAtomic      = Ioerr.int or 30 shl 8,
    IoerrRollbackAtomic    = Ioerr.int or 31 shl 8,
    IoerrData              = Ioerr.int or 32 shl 8,
    IoerrCorruptfs         = Ioerr.int or 33 shl 8,
    IoerrInPage            = Ioerr.int or 34 shl 8

const
  StaticDestructor* = cast[Destructor](0)
  TransientDestructor* = cast[Destructor](-1)

func errstr*(code: ResultCode): cstring {.noconv, importc: "sqlite3_errstr".}
func errcode*(db: Database): ResultCode {.noconv, importc: "sqlite3_errcode".}

type OpenFlag* {.size: sizeof(int32).} = enum
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

const
  SuperJournal* = MasterJournal

when defined(nimHasOutParams):
  proc open_v2*(filename: cstring; db: out Database; flags: int32|set[OpenFlag]; vfs: cstring): ResultCode {.noconv, sideEffect, importc: "sqlite3_open_v2".}
else:
  proc open_v2*(filename: cstring; db: var Database; flags: int32|set[OpenFlag]; vfs: cstring): ResultCode {.noconv, sideEffect, importc: "sqlite3_open_v2".}

proc close_v2*(db: Database): ResultCode {.noconv, sideEffect, importc: "sqlite3_close_v2".}
proc db_cache_flush*(db: Database): ResultCode {.noconv, sideEffect, importc: "sqlite3_db_cacheflush".}
func last_insert_rowid*(db: Database): int64 {.noconv, importc: "sqlite3_last_insert_rowid".}


type PrepareFlag* {.size: sizeof(uint32).} = enum
  Persistent,
  Normalize,
  NoVtab

when defined(nimHasOutParams):
  proc prepare_v3*(db: Database; sql: cstring; len: int32; prepFlags: uint32|set[PrepareFlag]; stmt: out Statement; tail: ptr cstring): ResultCode {.noconv, sideEffect, importc: "sqlite3_prepare_v3".}
else:
  proc prepare_v3*(db: Database; sql: cstring; len: int32; prepFlags: uint32|set[PrepareFlag]; stmt: var Statement; tail: ptr cstring): ResultCode {.noconv, sideEffect, importc: "sqlite3_prepare_v3".}

proc finalize*(stmt: Statement): ResultCode {.noconv, sideEffect, importc: "sqlite3_finalize".}
proc step*(stmt: Statement): ResultCode {.noconv, sideEffect, importc: "sqlite3_step".}
proc reset*(stmt: Statement): ResultCode {.noconv, sideEffect, importc: "sqlite3_reset".}
proc clear_bindings*(stmt: Statement): ResultCode {.noconv, sideEffect, importc: "sqlite3_clear_bindings".}
proc stmt_explain*(stmt: Statement; mode: int32): ResultCode {.noconv, importc: "sqlite3_stmt_explain".}

func bind_parameter_count*(stmt: Statement): int32 {.noconv, importc: "sqlite3_bind_parameter_count".}
func column_count*(stmt: Statement): int32 {.noconv, importc: "sqlite3_column_count".}
func data_count*(stmt: Statement): int32 {.noconv, importc: "sqlite3_data_count".}
func stmt_readonly*(stmt: Statement): bool {.noconv, importc: "sqlite3_stmt_readonly".}
func stmt_isexplain*(stmt: Statement): range[0'i32..2'i32] {.noconv, importc: "sqlite3_stmt_isexplain".}
proc stmt_busy*(stmt: Statement): bool {.noconv, importc: "sqlite3_stmt_busy".}
func db_handle*(stmt: Statement): Database {.noconv, importc: "sqlite3_db_handle".}
func sql*(stmt: Statement): cstring {.noconv, importc: "sqlite3_sql".}
proc next_stmt*(db: Database; stmt: Statement): Statement {.noconv, importc: "sqlite3_next_stmt".}
proc free*(p: pointer) {.noconv, sideEffect, importc: "sqlite3_free".}
proc expanded_sql*(stmt: Statement): cstring {.noconv, sideEffect, importc: "sqlite3_expanded_sql".}

proc bind_int64*(stmt: Statement; index: int32; val: int64): ResultCode {.noconv, sideEffect, importc: "sqlite3_bind_int64".}
proc bind_double*(stmt: Statement; index: int32; val: float64): ResultCode {.noconv, sideEffect, importc: "sqlite3_bind_double".}
proc bind_text*(stmt: Statement; index: int32; val: cstring; len: int32; destructor: Destructor): ResultCode {.noconv, sideEffect, importc: "sqlite3_bind_text".}
proc bind_blob*(stmt: Statement; index: int32; val: pointer; len: int32; destructor: Destructor): ResultCode {.noconv, sideEffect, importc: "sqlite3_bind_blob".}
proc bind_null*(stmt: Statement; index: int32): ResultCode {.noconv, sideEffect, importc: "sqlite3_bind_null".}
proc bind_parameter_index*(stmt: Statement, name: cstring): int32 {.noconv, sideEffect, importc: "sqlite3_bind_parameter_index".}

proc column_int*(stmt: Statement; index: int32): int32 {.noconv, sideEffect, importc: "sqlite3_column_int".}
proc column_int64*(stmt: Statement; index: int32): int64 {.noconv, sideEffect, importc: "sqlite3_column_int64".}
proc column_double*(stmt: Statement; index: int32): float64 {.noconv, sideEffect, importc: "sqlite3_column_double".}
proc column_text*(stmt: Statement; index: int32): cstring {.noconv, sideEffect, importc: "sqlite3_column_text".}
proc column_blob*(stmt: Statement; index: int32): ptr UncheckedArray[byte] {.noconv, sideEffect, importc: "sqlite3_column_blob".}
proc column_bytes*(stmt: Statement; index: int32): int32 {.noconv, sideEffect, importc: "sqlite3_column_bytes".}
proc column_name*(stmt: Statement; index: int32): cstring {.noconv, sideEffect, importc: "sqlite3_column_name".}

type Datatype* {.size: sizeof(int32).} = enum
  SqliteInteger = 1,
  SqliteFloat,
  SqliteText,
  SqliteBlob,
  SqliteNull

proc column_type*(stmt: Statement; index: int32): Datatype {.noconv, sideEffect, importc: "sqlite3_column_type".}


type ConfigOp* = enum
  Singlethread = 1.int32 ## nil
  Multithread = 2 ## nil
  Serialized = 3 ## nil
  Malloc = 4 ## sqlite3_mem_methods*
  Getmalloc = 5 ## sqlite3_mem_methods*
  Scratch = 6 ## no longer used
  Pagecache = 7 ## void*, int sz, int n
  Heap = 8 ## void*, int nbyte, int min
  Memstatus = 9 ## boolean
  Mutex = 10 ## sqlite3_mutex_methods*
  Getmutex = 11 ## sqlite3_mutex_methods*
  Chunkalloc = 12 ## now unused
  Lookaside = 13 ## int int
  Pcache = 14 ## no-op
  Getpcache = 15 ## no-op
  Log = 16 ## xfunc, void*
  Uri = 17 ## int
  Pcache2 = 18 ## sqlite3_pcache_methods2*
  Getpcache2 = 19 ## sqlite3_pcache_methods2*
  CoveringIndexScan = 20 ## int
  Sqllog = 21 ## xSqllog, void*
  MmapSize = 22 ## sqlite3_int64, sqlite3_int64
  Win32Heapsize = 23 ## int nByte
  PcacheHdrsz = 24 ## int *psz
  Pmasz = 25 ## unsigned int szpma
  StmtjrnlSpill = 26 ## int nbyte
  SmallMalloc = 27 ## boolean
  SorterrefSize = 28 ## int nbyte
  MemdbMaxsize = 29 ## sqlite3_int64
  RowidInView = 30 ## int*

proc config*(op: ConfigOp): ResultCode {.noconv, sideEffect, varargs, importc: "sqlite3_config".}
