# Norbert - DNS Server for ACMEv2 challenges

Norbert is a DNS server designed for use with the `DNS-01` ACME challenge and written in dependency-free [nim](https://nim-lang.org).
Norbert provides a HTTP API for managing TXT records and can handle multiple users, both useful if your primary DNS provider has no API or if you don't want to give full DNS API access to a webserver.

## Background

The ACME `DNS-01` challenge allows clients to verify the ownership of a domain by creating a TXT record with predefined content.
Using it instead of other challenges like `HTTP-01` is useful if the host that should use the certificate isn't public reachable or if you want to acquire a wildcard certificate.

Since most certificates issued using the ACME protocol are short-lived it is necessary to automate the renewal process including the creation of the required TXT record.
While most DNS providers offer an API and there exist many plugins for ACME clients like certbot most providers don't allow the creation of API credentials that are scoped to a limited set of records.
As a result, a webserver that has API access the DNS provider to complete the `DNS-01` challenge has full control over the domain in question.

Tools like Norbert, [acme-dns-server](https://github.com/pawitp/acme-dns-server) or [acme-dns](https://github.com/joohoi/acme-dns) solve this problem by running a dedicated DNS server responsible for a subset of the DNS zone that can be used to complete the ACME challenge.
A `CNAME` record is required to tell the ACME server that a subdomain managed by this server is the one holding the validation keys.

### Design

Norbert needs to bind to port `53` on a publicly accessible host and requires a dedicated subdomain like `*.acme.example.com`.
Every client configured in Norbert can create records in the `*.CLIENT-NAME.acme.exmple.com` namespace.

For this to work, two static DNS entries have to be created in the zone of the used domain:

```dns
acme.example.com                NS      host-running-norbert.example.com
_acme-challenge.exmaple.com     CNAME   example.com.CLIENT-NAME.acme.example.com
```

Now the client can use the Norbert API to set the verification TXT record on `example.com.CLIENT-NAME.acme.example.com` and the ACME server will read this record when querying `_acme-challenge.example.com`.

## Usage

### Installation

Norbert is written in nim.
A Dockerfile to build a container containing only a single static binary is included with the code.
Sample docker-compose config:

```yaml
version: "3"
services:
  norbert:
    build: ./norbert
    volumes:
      - ./norbert.conf:/config
    ports:
      - "53:15353/udp"
      - "18000:18000"
    command: "/config"
```

If you aren't using docker, the binary can be compiled manually using a recent version of the nim compiler:

```shell
nim c -d:release norbert.nim
```

Since Norbert needs to bind to the privileged port `53` the following option might be useful when running user systemd:

```
[Service]
AmbientCapabilities=CAP_NET_BIND_SERVICE
```

### DNS Setup

You'll need to create at least the two records described in [Design](#Design):
A `NS` record to specify your host running Norbert as the nameserver for the subdomain used, and a `CNAME` record to tell Let's Encrypt where to find your validation TXT records.
Norbert can be used for multiple domains, so multiple `CNAME` records for different domains can exist.

### Configuration

Norbert expects the path to a simple configuration file as its only argument.

```ini
# base domain for all records
baseDomain = "acme.example.com"
dnsPort = 15353
apiPort = 18000

# list of clients
# can create records for *.exampleuser.acme.example.com
[exampleuser]
password = "changeme"

[exampleuser2]
password = "changmetoo"
```

Only the base domain for which Norbert should resolve names and at least one client section are required.
If no port is specified, Norbert will fall back to `15353` & `18000`.

### HTTP API

Norbert's HTTP API provides only two routes and is designed with the [legos `HTTPREQ` DNS plugin](https://go-acme.github.io/lego/dns/httpreq/) in mind:

**Set a record**

```http request
POST /present

{
  "fqdn": "example.com",
  "value": "txt record content"
}
```

**Remove a record**

```http request
POST /cleanup

{
  "fqdn": "example.com",
  "value": "txt record content"
}
```

Records are only stored in memory and don't persist across restarts.

Both endpoints require HTTP basic auth using one of the credentials specified in the config file.
The `CLIENT-NAME.acme.example.com` suffix is automatically added and does not need to be specified in the `fqdn` field.

### Certbot example

Certbot provides the `--manual-auth-hook` and `--manual-cleanup-hook` options to specify custom scripts for challenges.
The `examples/` directory contains sample scripts that can be used here.

```shell
certbot certonly --manual \
  --manual-auth-hook norbert/examples/certbot-norbert-auth.sh \
  --manual-cleanup-hook norbert/examples/certbot-norbert-cleanup.sh \
  -d "example.com,*.example.com" \
  --preferred-challenges=dns \
  --renew-hook "systemctl reload nginx"
```

# License

MIT