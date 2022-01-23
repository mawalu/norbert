import asyncnet, asyncdispatch, nativesockets, strutils, lib/dns

proc handleDnsRequest(data: string) =
  let header = parseHeader(data[0 .. 11])
  var questions: seq[DnsQuestion] = @[]
  var offset = 12

  for i in (1.uint32)..header.qdcount:
    let (question, read) = parseQuestion(data[offset .. len(data) - 1])
    questions.add(question)
    offset += read.int

  let msg = DnsMessage(header: header, questions: questions)
  echo msg

proc serve() {.async.} =
  let server = newAsyncSocket(sockType=SockType.SOCK_DGRAM, protocol=Protocol.IPPROTO_UDP, buffered = false)
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12345))

  while true:
    echo "start loop"
    let request = await server.recvFrom(size=512)
    echo "received"
    handleDnsRequest(request.data)

proc main() =
  asyncCheck serve()
  runForever()

main()