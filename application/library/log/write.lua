local bit = require "bit"
local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C
local bor = bit.bor

ffi.cdef[[
int write(int fd, const char *buf, int nbyte);
int open(const char *path, int access, int mode);
int close(int fd);
]]

local O_RDWR   = 0X0002
local O_CREAT  = 0x0040
local O_APPEND = 0x0400
local S_IRWXU  = 0x01C0
local S_IRGRP  = 0x0020
local S_IROTH  = 0x0004

-- 往本地文件写日志，并往Kafka Server发日志
local function write2file(file, message)
    local log_fd = C.open(file, bor(O_RDWR, O_CREAT, O_APPEND), bor(S_IRWXU, S_IRGRP, S_IROTH))
	C.write(log_fd, message, #message);
    C.close(log_fd)
end

local function write2kafka(message)
	local client = require "resty.kafka.client"
	local producer = require "resty.kafka.producer"
	local broker_list = require "application.library.log.kafkaConfig" 

	-- this is async producer_type and bp will be reused in the whole nginx worker
	local bp = producer:new(broker_list, { producer_type = "async" })
	local key = "key"
	local ok, err = bp:send('luaPoint', key, message)
	return ok, err
end

for file, message in pairs(GLOBAL_LOG_BUFFERS) do
    if file ~= nil and message ~= nil then
        write2file(file, message)
        write2kafka(message)
    end
end
