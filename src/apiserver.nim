import asynchttpserver, asyncdispatch, json, strtabs, base64, strutils, strformat, options, tables
import ../lib/dns, state

const headers = {"Content-type": "text/plain; charset=utf-8"}
const authHeader = "authorization"

type
  NewRecordReq = object
    fqdn: string
    value: string

type
  Auth = tuple
    name: string
    password: string

proc handleAuth(req: Request, config: AppConfig): Option[Auth] =
  if not req.headers.hasKey(authHeader):
    return none(Auth)

  let token = req.headers[authHeader].split(" ")[1]
  let credentials = decode(token).split(":")

  let user = credentials[0]
  let pw = credentials[1]

  if not config.users.hasKey(user) or config.users[user] != pw:
    return none(Auth)

  return some((name: user, password: pw))

proc forbidden(req: Request): Future[void] =
  return req.respond(Http401, "forbidden", headers.newHttpHeaders())

proc ok(req: Request): Future[void] =
  return req.respond(Http200, "ok", headers.newHttpHeaders())

proc notFound(req: Request): Future[void] =
  return req.respond(Http404, "not found", headers.newHttpHeaders())

proc present(req: Request, auth: Auth, base: string): Future[void] {.async.} =
  let record = to(parseJson(req.body), NewRecordReq)
  let name = trimName(record.fqdn) & "." & auth.name & "." & base

  addRecord(
    records,
    (name: name, dtype: DnsType.TXT),
    record.value
  )

  await ok(req)

proc cleanup(req: Request, auth: Auth, base: string): Future[void] {.async.} =
  let record = to(parseJson(req.body), NewRecordReq)
  let name = trimName(record.fqdn) & "." & auth.name & "." & base

  delRecord(
    records,
    (name: name, dtype: DnsType.TXT),
    record.value
  )

  await ok(req)

proc serveApi*(config: AppConfig) {.async.} =
  let http = newAsyncHttpServer()

  proc cb(req: Request) {.async.} =
    let auth = handleAuth(req, config)

    if auth.isNone():
      await forbidden(req)
      return

    let user = auth.unsafeGet()

    if req.url.path == "/present":
      await present(req, user, config.base)
    elif req.url.path == "/cleanup":
      await cleanup(req, user, config.base)
    else:
      await notFound(req)

  http.listen(config.apiPort)
  echo &"API listening on port {config.apiPort.int}"

  while true:
    if http.shouldAcceptRequest():
      try:
        await http.acceptRequest(cb)
      except:
        continue
    else:
      await sleepAsync(500)