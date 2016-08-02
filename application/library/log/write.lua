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
    local log_fd = C.open(file, bor(O_RDWR, O_CREAT, O_APPEND), bor(S_IRWXU, S_IRGRP, S_IROTH)),
    ngx.log(ngx.ERR, file)
    ngx.log(ngx.ERR, message)
    --ngx.log(ngx.ERR, #message)
	C.write(log_fd, message, #message);
end
local function write2kafka(message)
end

for filePath, log in pairs(GLOBAL_LOG_BUFFERS) do
    --ngx.log(ngx.ERR, filePath)
    --ngx.log(ngx.ERR, log)
    write2file(filePath, log)
    -- write2kafka(log)
end
