from std/strutils import join, split
import std/sequtils
import utils

type
  Opcode* = enum
    QUERY = 0, IQUERY = 1, STATUS = 2

type
  Rcode* = enum
    NO_ERROR = 0, FORMAT_ERROR = 1, SERVER_FAULURE = 2, NAME_ERROR = 3,
    NOT_IMPLEMENTED = 4, REFUSED = 5

type
  DnsType* = enum
    A = 1, NS = 2, MD = 3, MF =4, CNAME = 5, SOA = 6, MB = 7, MG = 8,
    MR = 9, NULL = 10, WKS = 11, PTR = 12, HINFO = 13, MINFO = 14, MX = 15,
    TXT = 16, AAAA = 28, AXFR = 252, MAILB = 253,  MAILA = 254, ANY = 255

type
  DnsClass* = enum
    IN = 1, CS = 2, CH = 3, HS = 4

type
  DnsQr* = enum
    REQUEST = false, RESPONSE = true

type
  DnsQuestion* = object
    qname*: string
    qtype*: DnsType
    qclass*: DnsClass

type
  DnsHeader* = object
    id*: uint16
    qr*: DnsQr
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

type
  DnsRecord* = object
    name*: string
    rtype*: DnsType
    class*: DnsClass
    ttl*: uint32
    rdlength*: uint16
    rdata*: string

type
  DnsMessage* = object
    header*: DnsHeader
    questions*: seq[DnsQuestion]
    answer*: seq[DnsRecord]
    authroity*: seq[DnsRecord]
    additional*: seq[DnsRecord]

func parseNameField*(data: string, startOffset: uint16): (seq[string], uint16) =
  var names: seq[string] = @[]
  var len = toUint8(data[startOffset])
  var offset: uint16 = startOffset + 1

  while len > 0:
    names.add(data[offset .. offset + len - 1])

    offset += len + 1
    len = toUint8(data[offset - 1])

  return (names, offset)

func packNameField*(input: string): string =
  let names = input.split(".")
  var finalName = newStringofCap(len(input) + 1)

  for name in names:
    finalName.add(chr(len(name)))
    finalName = finalName & name

  finalName.add(chr(0))

  return finalName

func parseHeader*(data: string): DnsHeader =
  assert len(data) >= 12

  return DnsHeader(
    id: toUInt16(data[1], data[0]),
    qr: DnsQr(sliceBit(data[2], 0)),
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

func packHeader*(data: DnsHeader): string =
  var header = newStringOfCap(12)

  header.add(uint16ToString(data.id))
  header.add(chr(
    (data.qr.uint8 shl 7) or
    (data.opcode.uint8 shl 3) or
    (data.aa.uint8 shl 2) or
    (data.tc.uint8 shl 1) or
    data.rd.uint8
  ))

  header.add(chr(
    (data.ra.uint8 shl 7) or
    (data.z.uint8 shl 4) or
    data.rcode.uint8
  ))

  header.add(uint16ToString(data.qdcount))
  header.add(uint16ToString(data.ancount))
  header.add(uint16ToString(data.nscount))
  header.add(uint16ToString(data.arcount))

  return header

func parseQuestion*(data: string, startOffset: uint16): (DnsQuestion, uint16) =
  let (qnames, offset) = parseNameField(data, startOffset)

  return (DnsQuestion(
    qname: qnames.join("."),
    qtype: DnsType(toUint16(data[offset + 1], data[offset])),
    qclass: DnsClass(toUint16(data[offset + 3], data[offset + 2]))
  ), offset + 4)

func packQuestion*(data: DnsQuestion): string =
  var question = ""

  question.add(packNameField(data.qname))
  question.add(uint16ToString(data.qtype.uint16))
  question.add(uint16ToString(data.qclass.uint16))

  return question

# BROKEN
func parseResourceRecord*(data: string, startOffset: uint16): (DnsRecord, uint16) =
  let (names, offset) = parseNameField(data, startOffset)
  let dataLength = toUint16(data[offset + 9], data[offset + 8])

  return (DnsRecord(
    name: names.join("."),
    rtype: DnsType(toUint16(data[offset + 1], data[offset])),
    class: DnsClass(toUint16(data[offset + 3], data[offset + 2])),
    ttl: toUint32(data[offset + 5], data[offset + 4], data[offset + 7], data[offset + 6]),
    rdlength: dataLength,
    rdata: data[offset + 10 .. offset + 10 + dataLength]
  ), offset)

func packResourceRecord*(data: DnsRecord): string =
  var record = ""

  record.add(packNameField(data.name))
  record.add(uint16ToString(data.rtype.uint16))
  record.add(uint16ToString(data.class.uint16))
  record.add(uint32ToString(data.ttl.uint32))
  record.add(uint16ToString(data.rdlength.uint16))
  record.add(data.rdata)

  return record

func parseMessage*(data: string): DnsMessage =
  let header = parseHeader(data[0 .. 11])
  var questions: seq[DnsQuestion] = @[]
  var offset: uint16 = 12

  for i in (1.uint32)..header.qdcount:
    let parsed = parseQuestion(data, offset)
    questions.add(parsed[0])
    offset = parsed[1]

  return DnsMessage(header: header, questions: questions)

func packMessage*(message: DnsMessage): string =
  var encoded = packHeader(message.header)

  for question in message.questions:
    encoded.add(packQuestion(question))

  for answer in message.answer:
    encoded.add(packResourceRecord(answer))

  return encoded

func mkRecord*(rtype: DnsType, question: string, answer: string): DnsRecord =
  return DnsRecord(
    name: question,
    rtype: rtype,
    class: DnsClass.IN,
    ttl: 60,
    rdLength: (if rtype == DnsType.TXT: len(answer) + 1 else: len(answer)).uint16,
    rdata: (if rtype == DnsType.TXT: chr(len(answer)) & answer else: answer)
  )

func mkResponse*(id: uint16, question: DnsQuestion, answer: seq[string]): DnsMessage =
  return DnsMessage(
    header: DnsHeader(
      id: id,
      qr: DnsQr.RESPONSE,
      aa: true,
      rcode: Rcode.NO_ERROR,
      qdcount: 1,
      ancount: len(answer).uint16
    ),
    questions: @[question],
    answer: answer.map(proc (a: string): DnsRecord = mkRecord(question.qtype, question.qname, a))
  )