import asyncnet, asyncdispatch, nativesockets
import strutils, options, tables
import lib/dns

const records = {
  DnsType.A: {"m5w.de": @["\127\0\0\1"]}.toTable,
  DnsType.TXT: {"m5w.de": @["hello world", "abc"]}.toTable
}.toTable

proc handleDnsRequest(data: string): Option[string] =
  let msg = parseMessage(data)

  if len(msg.questions) == 0:
    return

  let question = msg.questions[0]
  # todo: handle missing record
  let answer = records[question.qtype][question.qname]
  let response = mkResponse(msg.header.id, question, answer)

  return some(packMessage(response))

proc serve() {.async.} =
  let server = newAsyncSocket(sockType=SockType.SOCK_DGRAM, protocol=Protocol.IPPROTO_UDP, buffered = false)
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12345))

  while true:
    try:
      let request = await server.recvFrom(size=512)
      let response = handleDnsRequest(request.data)

      if (response.isSome):
        await server.sendTo(request.address, request.port, response.unsafeGet)
    except:
      continue

proc main() =
  asyncCheck serve()
  runForever()

main()