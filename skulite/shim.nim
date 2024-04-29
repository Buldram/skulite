## Shim for Nim <= 2.0

{.used.}

when not declared(newSeqUninit):
  func newSeqUninit*[T](len: Natural): seq[T] {.inline.} =
    ## Creates an uninitialzed seq.
    when nimvm:
      result = newSeq[T](len)
    else:
      result = newSeqOfCap[T](len)
      result.setLen(len)

when not declared(newStringUninit):
  func newStringUninit*(len: Natural): string {.inline.} =
    ## Creates an uninitialzed string.
    when nimvm:
      result = newString(len)
    else:
      result = newStringOfCap(len)
      result.setLen(len)
