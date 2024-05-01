# Changelog

## 2.0.0 - Unreleased

* Change calling convention for sqlite3 bindings from `cdecl` to `noconv`
* Dynamically link sqlite3 using linker, not dynlib
* Remove reopen, close, reprepare, finalize
* Refactor raiseSqliteError → newException
* Refactor explain handling
  * Let setExplain accept static ints
  * Type explain level as int32 instead of int8
* Rename
  * (Database|Statement)Wrapper → *Obj
  * (Database|Statement).raw → *.ptr
  * internal sqlite3* types → Sqlite3*
  * isExplain → explainLevel
  * sqliteCheck → check

## 1.3.0 - April 28 2024

* Add `{.raises: [].}` to `sqlite3_destructor` type
* Add `lastInsertRowID`
* Add a `bindParam` for named parameters
* Make `-d:static` imply `-d:staticSqlite`

## 1.2.4 - 15 April 2024

* Support for Nim 1.2.0
* Adjust getColumn(T: seq[byte]) for 0-length blobs
* Bind array[0, byte] consistently on Nim <= 1.6.8
* Update SQLite source to version 3.45.3

## 1.2.3 - 14 April 2024

* Fix `unpack` when `T` is a `tuple`

## 1.2.2 - 13 April 2024

* Support for Nim 1.4.2

## 1.2.1 - 13 April 2024

* Fix bug in `getColumn(T: typedesc[Option])`

## 1.2.0 - 12 April 2024

* Support for Nim 1.6

## 1.1.0 - 12 April 2024

* Rename `open` and `prepare` to `reopen` and `reprepare`
* Fix a memory leak in `explain` and another in the test suite

## 1.0.0 - 9 April 2024

* Initial release
