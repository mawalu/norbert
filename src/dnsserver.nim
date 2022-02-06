import asyncnet, asyncdispatch, nativesockets
import strutils, options, tables, strformat
import ../lib/dns, state

proc handleDnsRequest(records: RecordsTable, data: string): Option[string] =
  let msg = parseMessage(data)

  echo msg

  if len(msg.questions) == 0:
    return

  let question = msg.questions[0]
  let response = mkResponse(
    msg.header.id,
    question,
    records.getOrDefault((name: question.qname.toLowerAscii(), dtype: question.qtype), @[])
  )

  echo response

  return some(packMessage(response))

proc serveDns*(config: AppConfig) {.async.} =
  let dns = newAsyncSocket(sockType=SockType.SOCK_DGRAM, protocol=Protocol.IPPROTO_UDP, buffered = false)
  dns.setSockOpt(OptReuseAddr, true)
  dns.bindAddr(config.dnsPort)

  echo &"DNS listening on port {config.dnsPort.int}"

  while true:
    try:
      let request = await dns.recvFrom(size=512)
      let response = handleDnsRequest(records, request.data)

      if (response.isSome):
        await dns.sendTo(request.address, request.port, response.unsafeGet)
    except:
      continue