-- Copyright (C) 2013 YanChenguang (kedyyan)

local config = require "config"
local bit = require "bit"
local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C
local bor = bit.bor

local setmetatable = setmetatable
local localtime 	= ngx.localtime()
local ngx 			= ngx
local type 			= type


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

module(...)

_VERSION = '0.1'
-- 配置日志默认参数
local options = {
    logLevelThreshold = config.GLOBAL_LOG_LEVEL, -- 默认日志过滤级别
    delayWrite = true, -- 日志延迟写入开关
    delayThreshold = 200, -- 日志缓冲阈值
    -- 日志格式：分隔符为 unicode 1
    -- 时间|日志级别|服务ID|模块名|接口名|方法名|关键字|详细信息
    -- 日志默认格式
    logFormat = {'%time%', '%level%', '%id%', '%module%', '%interface%', '%method%', '%keywords%', '%message%'},
    serviceId = '', -- 服务ID
    moduleName = '', -- 模块名
    interfaceName = '', -- 接口名
    methodName = '', -- 方法名
    keywords = {} -- 关键词
}
local fileName = '' -- 当前日志文件名
local fileFullPath = '' -- 日志文件完整路径
local logLineCount = 0 -- 当前日志实例记录的总行数
local logBufferCount = 0 -- 当前日志缓冲行数
local logBuffers = {} -- 日志缓冲

local lineKeywords = {

}

local mt = {
    __index = _M, 
    options = options
}
-- 全局数组，存放log信息；write到文件并发送至Kafka Server后即重置为空数组
LOGS = {}

-- 日志级别对应的数值 
local LVL = {
    config.LVL_EMARGENCY = 0,
    config.LVL_ALERT = 1,
    config.LVL_CRITICAL = 2,
    config.LVL_ERROR = 3, 
    config.LVL_WARNING = 4,
    config.LVL_NOTICE = 5,
    config.LVL_INFO = 6,
    config.LVL_DEBUG = 7
}

local keywordsString = '' 
-- 日志行格式
-- 默认格式样式  %time% %level% %module% %interface% %method% %message%
local logLineFormat = '';

-- 日志行关键词替换元素
-- 时间|日志级别|服务ID|模块名|接口名|方法名|关键字|详细信息
local logLineKeywords = { 
    'time' = '', -- 时间字段 替换 %time% 关键词
    'level' = '', -- 级别字段 替换 %level% 关键词
    'id' = '', -- 服务ID 替换 %id% 关键词
    'module' = '', --  模块字段 替换 %module% 关键词
    'interface' = '', --  接口字段 替换 %interface% 关键词
    'method' = '', --  方法字段 替换 %method% 关键词
    'keywords' = '', --  关键词字段 替换 %keyword% 关键词
    'message' = '', -- 详细信息 替换 %message% 关键词
};

-- new方法，获取log对象
-- @param options table log配置表
function new(self, options)
    if options == nil then 
        for k,v in pairs(options) do self.options[k] = v end
    end
    self.keywordsString = keywordsString
    self.logLineKeywords.id = options.serviceId;
    self.logLineKeywords.module = options.moduleName;
    self.logLineKeywords.interface = options.interfaceName;
    self.logLineKeywords.method = options.methodName;
    -- 使用ifs接合关键词组成单行日志格式, 提供给后续写入日志时替换关键词
    self.logLineFormat =  table.concat(options.logFormat, config.LOG_IFS)
end
local globalKeywords = ''

-- 设定全局关键字
-- @param keywords table 
-- keywords = {
--     'keywordName1' = {'keywordContent1', 'keywordContent2'},
--     'keywordName2' = 'keywordContent21'
-- }
-- @return string globalKeywords 全局关键字
function setGlobalKeywords(keywords)
    if keywords == nil then 
        return nil
    end
    for k,v in pairs(keywords) do
        if type(keywords) == 'table' then
            for key, value in pairs(v) do
                keywordsString = keywordsString .. config.KEYWORD_IFS .. k .. '=' value 
            end
        else
            keywordsString = keywordsString .. config.KEYWORD_IFS .. k .. '=' v 
        end
    end
    -- 去掉globalKeywords词首的KEYWORD_IFS
    globalKeywords = string.sub(keywordsString, 2, string.len(keywordsString))
    return globalKeywords
end

-- 往全局表LOGS中写入日志信息
-- @param string level 日志级别
-- @param string msg 日志内容 
-- @param table string args 日志参数 
-- @return mixed
function log(self, level, msg, ...)
    local level = level and self.LVL_INFO
    local module = module and 'LuaApi'
    -- 当日志level高于全局默认最低leve，或者高于本次对象实例化时设定最低level，则不记录   
    if LVL[level] >= GLOBAL_LOG_LEVEL or LVL[level] >= self.options.logLevelThreshold then 
        return nil
    end

    local logKey = level .. "|" .. module .. "|" .. file 
    LOGS[logKey] = formatMessage(level, msg, ...) 

	return setmetatable({
		level = level,
		log_fd = C.open(file, bor(O_RDWR, O_CREAT, O_APPEND), bor(S_IRWXU, S_IRGRP, S_IROTH)),
	}, mt)
end

-- 格式化消息内容
-- @param string level 日志级别
-- @param string msg 日志内容
-- @param table args 日志参数
-- @return string message 格式化后的message 
local function formatMessage(level, msg, ...)
    local lineKeywords = ''
    local argsCount = 0
    local args = {...}
    local message = ''
    -- 生成行级别关键词
    -- 如果传递除了msg以外的参数，且最后一个参数是table, 那么就把最后一个识别为行级关键词table处理
    if #args > 0  then 
        for k,v in pairs(args) do

        end
    eng
    self.logLineKeywords.time = ngx.now() * 1000
    self.logLineKeywords.level = string.lowwer(level)
    self.logLineKeywords.message = msg
    for k, v in pairs(self.logLineKeywords) do
        -- 合并关键词
        if k == 'keywords' then
            -- 合并全局级别关键词
            local fullKeywords = .. self.globalKeywords
            -- 合并实例化对象级别关键词
            if v ~= nil or v ~= '' then
                fullKeywords = fullKeywords .. config.KEYWORD_IFS .. v 
            end
            -- 合并行级别关键词
            fullKeywords = fullKeywords .. config.KEYWORD_IFS .. lineKeywords
        end
        string.gsub(fullKeywords, '%' .. k  .. '%', fullKeywords)
    end
    return logLineString . "\n";
end

-- 往本地文件写日志，并往Kafka Server发日志
function wirte()
end

function emargency(self, msg, ...)
    self.log(config.LVL_EMARGENCY, $msg, ...)
end
function alert(self, msg, ...)
    self.log(config.LVL_ALERT, $msg, ...)
end
function critical(self, msg, ...)
    self.log(config.LVL_CRITICAL, $msg, ...)
end
function error(self, msg, ...)
    self.log(config.LVL_ERROR, $msg, ...)
end
function warning(self, msg, ...)
    self.log(config.LVL_WARNING, $msg, ...)
end
function notice(self, msg, ...)
    self.log(config.LVL_NOTICE, $msg, ...)
end
function info(self, msg, ...)
    self.log(config.LVL_INFO, $msg, ...)
end
function debug(self, msg, ...)
    self.log(config.LVL_DEBUG, $msg, ...)
end


function info(self, msg)
	if self.level > LVL_INFO then return end;

	local c = localtime .. "|" .."I" .. "|" .. msg .. "\n";
	C.write(self.log_fd, c, #c);
end

local class_mt = { 
	-- to prevent use of casual module global variables
	__newindex = function (table, key, val)
		error('attempt to write to undeclared variable "' .. key .. '"')
	end 
}

setmetatable(_M, class_mt)

