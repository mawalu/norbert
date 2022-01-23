proc toUint8*(l: char): uint8 =
  return ord(l).uint8

proc toUint16*(l: char, h: char): uint16 =
  return ord(l).uint16 or (ord(h).uint16 shl 8);

proc sliceBit*(s: char, i: uint8): bool =
  assert i < 8
  return ((toUint8(s) shr (8 - i)) and 1) == 1
