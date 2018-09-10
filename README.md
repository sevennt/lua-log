# lua log module

## Description

 lua-log is a log library based on openresty, it will write log on local file and send log message to kafka server.

## Quick Start

```bash
# add follow config into your nginx configuration file
log_by_lua_file {
    log.write();
}
```

```bash
local logger = log.new()
log.info("this is an log message")
```

## TODO

Add unit test.
