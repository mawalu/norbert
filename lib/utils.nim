func toUint8*(l: char): uint8 =
  return ord(l).uint8

func toUint16*(l: char, h: char): uint16 =
  return ord(l).uint16 or (ord(h).uint16 shl 8);

func uint16ToString*(n: uint16): string =
  return chr(n shr 8) & chr(n and 0b11111111)

func toUint32*(a: char, b: char, d: char, c: char): uint32 =
  return toUint16(a, b).uint32 or (toUint16(d, c).uint32 shl 16)

func uint32ToString*(n: uint32): string =
  return uint16ToString((n shr 16).uint16) & uint16ToString((n and 0b1111111111111111).uint16)

func sliceBit*(s: char, i: uint8): bool =
  assert i < 8
  return ((toUint8(s) shr (8 - i)) and 1) == 1
