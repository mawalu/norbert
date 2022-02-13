import tables, strtabs, sequtils, nativesockets
import ../lib/dns

type
  RecordKey* = tuple
    name: string
    dtype: DnsType

type
  RecordsTable* = Table[RecordKey, seq[string]]

type
  AppConfig* = object
    users*: StringTableRef
    base*: string
    apiPort*: Port
    dnsPort*: Port

func trimName*(name: string): string =
  if name[^1] == '.':
    return name[0 .. ^2]
  else:
    return name

proc addRecord*(records: var RecordsTable, key: RecordKey, record: string) =
  if records.hasKey(key):
    records[key].add(record)
  else:
    records[key] = @[record]

proc delRecord*(records: var RecordsTable, key: RecordKey, record: string) =
  if not records.hasKey(key):
    return

  records[key].keepItIf(it != record)

  if len(records[key]) == 0:
    records.del(key)

# TODO: don't use a global for this
var records* {.threadvar.}: RecordsTable
records = initTable[RecordKey, seq[string]]()