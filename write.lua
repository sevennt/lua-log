-- kafka point名称 
local point = 'luaPoint'
local ffi = require "lib.ffi"

-- 往本地文件写日志，并往Kafka Server发日志
local function write2file(file, messages)
    ffi.write(file, messages)
end

local function write2kafka(message)
    local client = require "resty.kafka.client"
    local producer = require "resty.kafka.producer"
    local broker_list = require "lib.log.kafkaConfig"

    -- this is async producer_type and bp will be reused in the whole nginx worker
    local bp = producer:new(broker_list, { producer_type = "async" })
    local ok, err = bp:send(point, nil, message)
    return ok, err
end

if type(ngx.ctx['GLOBAL_LOG_BUFFERS']) ~= 'table' then
    return nil
end

for file, messages in pairs(ngx.ctx['GLOBAL_LOG_BUFFERS']) do
    if file ~= nil and messages ~= nil then
        fileMessages = ''
        for k, message in pairs(messages) do
            -- 添加额外信息
            local cjson = require "cjson"
            local util = require "sys.util"
            message['src'] = util.getClientIp();
            message['remote'] = ngx.var.server_addr;
            message['host'] = ngx.var.hostname;
            message['uri'] = ngx.var.uri;
            message['params'] = ngx.var.QUERY_STRING;
            message['requestMethod'] = ngx.var.request_method;
            message = cjson.encode(message);

            fileMessages = fileMessages .. message .. "\n"
            write2kafka(message)
        end
        write2file(file, fileMessages)
    end
end
