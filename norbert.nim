import asyncdispatch, nativesockets, strtabs, parsecfg, os, parseUtils, strformat
import src/dnsserver, src/apiserver, src/state

proc initConfig(): AppConfig =
  const exampleConfig = readFile("example.config")

  if paramCount() != 1:
    echo "Usage: norbert ./path/to/config"
    echo ""
    echo "Example config:"
    echo ""
    echo exampleConfig
    quit 0

  try:
    let configFile = loadConfig(paramStr(1))
    var apiPort: int
    var dnsPort: int

    if parseInt(configFile.getSectionValue("", "apiPort", "18000"), apiPort) == 0 or
      parseInt(configFile.getSectionValue("", "dnsPort", "15353"), dnsPort) == 0:
      echo "Error parsing port config"
      quit 1

    let config = AppConfig(
      base: configFile.getSectionValue("", "baseDomain"),
      users: newStringTable(),
      apiPort: Port(apiPort),
      dnsPort: Port(dnsPort)
    )

    for user in configFile.sections:
      if user == "":
        continue

      echo &"Loading user {user}"
      let password = configFile.getSectionValue(user, "password")

      if password == "":
        echo &"Password missing for user {user}"
        quit 1

      config.users[user] = password

    return config

  except IOError:
    echo "Could not read config"
    quit 1

proc main() =
  let config = initConfig()

  asyncCheck serveDns(config)
  asyncCheck serveApi(config)

  runForever()

main()