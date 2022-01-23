from std/strutils import join
import utils

type
  Opcode* = enum
    QUERY = 0, IQUERY = 1, STATUS = 2

type
  Rcode* = enum
    NO_ERROR = 0, FORMAT_ERROR = 1, SERVER_FAULURE = 2, NAME_ERROR = 3,
    NOT_IMPLEMENTED = 4, REFUSED = 5

type
  DnsHeader* = object
    id*: uint16
    qr*: bool
    opcode*: Opcode
    aa*: bool
    tc*: bool
    rd*: bool
    ra*: bool
    z*: uint8
    rcode*: Rcode
    qdcount*: uint16
    ancount*: uint16
    nscount*: uint16
    arcount*: uint16

proc parseHeader*(data: string): DnsHeader =
  assert len(data) >= 12

  return DnsHeader(
    id: toUInt16(data[1], data[0]),
    qr: sliceBit(data[2], 0),
    opcode: Opcode((toUint8(data[2]) shr 3) and 0b00001111),
    aa: sliceBit(data[2], 5),
    tc: sliceBit(data[2], 6),
    rd: sliceBit(data[2], 7),
    ra: sliceBit(data[3], 0),
    z: (toUint8(data[3]) shr 4) and 0b00000111,
    rcode: Rcode(toUint8(data[3]) and 0b00001111),
    qdcount: toUint16(data[5], data[4]),
    ancount: toUint16(data[7], data[6]),
    nscount: toUint16(data[9], data[8]),
    arcount: toUint16(data[11], data[10])
  )

type
  DnsType* = enum
    A = 1, NS = 2, MD =3, MF =4, CNAME = 5, SOA = 6, MB = 7, MG = 8,
    MR = 9, NULL = 10, WKS = 11, PTR = 12, HINFO = 13, MINFO = 14, MX = 15,
    TXT = 16, AXFR = 252, MAILB = 253,  MAILA = 254, ANY = 255

type
  DnsClass* = enum
    IN = 1, CS = 2, CH = 3, HS = 4

type
  DnsQuestion* = object
    qname*: string
    qtype*: DnsType
    qclass*: DnsClass

proc parseQuestion*(data: string): (DnsQuestion, uint16) =
  var qname: seq[string] = @[]
  var len = toUint8(data[0])
  var offset: uint16 = 1

  while len > 0:
    qname.add(data[offset .. offset + len - 1])

    offset += len + 1
    len = toUint8(data[offset - 1])

  return (DnsQuestion(
    qname: qname.join("."),
    qtype: DnsType(toUint16(data[offset + 1], data[offset])),
    qclass: DnsClass(toUint16(data[offset + 3], data[offset + 2]))
  ), offset + 4)

type
  DnsRecord* = object
    name*: string
    rtype*: DnsType
    class*: DnsClass
    ttl*: uint32
    rdlength*: uint16
    rdata: string

type
  DnsMessage* = object
    header*: DnsHeader
    questions*: seq[DnsQuestion]
    answer*: seq[DnsRecord]
    authroity*: seq[DnsRecord]
    additional*: seq[DnsRecord]