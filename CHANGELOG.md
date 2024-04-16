# Changelog

## 1.2.x - Unreleased

* Adjust getColumn(T: seq[byte]) for 0-length blobs
* Bind array[0, byte] consistently on Nim <= 1.6.8
* Support for Nim 1.4.0
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
