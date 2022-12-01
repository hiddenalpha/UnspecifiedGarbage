
Load testing for http server
============================

Here some notes about how to use scripts here to stress-test a HTTP server.


##  Example "How to kill gateleen"

```sh
curl -sSLOD- "https://github.com/hiddenalpha/UnspecifiedGarbage/raw/master/src/main/nodejs/HttpFlood/HttpFlood.js"
node HttpFlood.js --host 127.0.0.1 --port 7013 --path /tmp/your/path --max-parallel 128 --inter-request-gap 0
```


## Example "How to mock a queue consumer which prints request statistics"

```sh
curl -sSLOD- "https://github.com/hiddenalpha/UnspecifiedGarbage/raw/master/src/main/nodejs/HttpFlood/HttpNullsink.js"
node HttpNullsink.js --host 127.0.0.1 --port 8080
```


## Example "How to create a hook so gateleen uses our null-sink as queue consumer"

```sh
curl -sSLOD- "https://github.com/hiddenalpha/UnspecifiedGarbage/raw/master/src/main/nodejs/HttpFlood/SetGateleenHook.js"
node SetGateleenHook.js --host 127.0.0.1 --port 7013 --path /houston/tmp/your/path/to/hook --destination "127.0.0.1:8080/foo" --listener
```


## Example "How to test throughput of the tool itself"

HINT 1: Run the two node commands in separate terminals.

HINT 2: On windoof, this is slow (I only get around 12k request/sec). Use linux
        to get usable throughput.

```sh
curl -sSLOD- "https://github.com/hiddenalpha/UnspecifiedGarbage/raw/master/src/main/nodejs/HttpFlood/HttpFlood.js"
curl -sSLOD- "https://github.com/hiddenalpha/UnspecifiedGarbage/raw/master/src/main/nodejs/HttpFlood/HttpNullsink.js"
node HttpNullsink.js --host 127.0.0.1 --port 8080
node HttpFlood.js --host 127.0.0.1 --port 8080 --path /tmp/does/not/matter --max-parallel 128 --inter-request-gap 0
```

