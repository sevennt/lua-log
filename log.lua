local config = require "lib.log.config"

local _M = { _VERSION = '0.1' }

-- 配置日志默认参数
local _options = {
    fileName = '', -- 当前日志文件名
    fileFullPath = config.GLOBAL_LOG_FULL_PATH, -- 日志文件完整路径
    logLevelThreshold = config.GLOBAL_LOG_LEVEL, -- 默认日志过滤级别
    -- 日志格式：分隔符为 unicode 1
    -- 时间|日志级别|服务ID|模块名|接口名|方法名|关键字|详细信息
    -- 日志默认格式
    logFormat = {
        time = '',
        level = '',
        id = '',
        module = '',
        interface = '',
        method = '',
        keywords = {},
        message = ''
    },
    serviceId = '', -- 服务ID
    moduleName = '', -- 模块名
    interfaceName = '', -- 接口名
    methodName = '', -- 方法名
    keywords = {} -- 关键词
}

local mt = {
    __index = _M
}

-- 日志级别对应的数值 
local LVL = {
    [config.LVL_EMARGENCY] = 0,
    [config.LVL_ALERT] = 1,
    [config.LVL_CRITICAL] = 2,
    [config.LVL_ERROR] = 3,
    [config.LVL_WARNING] = 4,
    [config.LVL_NOTICE] = 5,
    [config.LVL_INFO] = 6,
    [config.LVL_DEBUG] = 7
}

-- new方法，获取log对象
-- @param options table log配置表
function _M.new(self, initOptions)
    local options = {}
    if initOptions ~= nil then
        for k, v in pairs(_options) do
            if initOptions[k] ~= nil then
                options[k] = initOptions[k]
            else
                options[k] = v
            end
        end
    else
        options = initOptions
    end

    -- 日志对象级别关键词替换元素
    -- 时间|日志级别|服务ID|模块名|接口名|方法名|关键字|详细信息
    self['objectKeywords'] = {
        time = '', -- 时间字段 替换 %time% 关键词
        level = '', -- 级别字段 替换 %level% 关键词
        id = options.serviceId or '', -- 服务ID 替换 %id% 关键词
        module = options.moduleName or '', --  模块字段 替换 %module% 关键词
        interface = options.interfaceName or '', --  接口字段 替换 %interface% 关键词
        method = options.methodName or '', --  方法字段 替换 %method% 关键词
        keywords = options.keywords, --  关键词字段 替换 %keyword% 关键词
        message = '', -- 详细信息 替换 %message% 关键词
    };
    self['keywordsString'] = ''
    -- 日志行格式
    -- 默认格式样式  %time% %level% %module% %interface% %method% %message%
    -- 使用ifs接合关键词组成单行日志格式, 提供给后续写入日志时替换关键词
    -- self['logLineFormat'] =  table.concat(options.logFormat, config.LOG_IFS)
    self['logLineFormat'] = options.logFormat

    return setmetatable({
        options = options,
        LVL = LVL
    }, mt)
end

function print_r (t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    sub_print_r(t, "  ")
end

-- 往全局表LOGS中写入日志信息
-- @param string level 日志级别
-- @param string message 日志内容 
-- @param table string args 日志参数 
-- @return mixed
function _M.log(self, level, message, fileName, ...)
    local level = level or config.LVL_INFO
    local fileName = fileName or self.options.fileName
    if fileName == "" then
        fileName = level .. '-' .. '' .. ngx.today() .. '.log'
    end
    -- 当日志level高于全局默认最低leve，或者高于本次对象实例化时设定最低level，则不记录   
    if LVL[level] > LVL[config.GLOBAL_LOG_LEVEL] or LVL[level] > LVL[self.options.logLevelThreshold] then
        return nil
    end
    if ngx.ctx['GLOBAL_LOG_BUFFERS'][self.options.fileFullPath .. '/' .. fileName] == nil or type(ngx.ctx['GLOBAL_LOG_BUFFERS'][self.options.fileFullPath .. '/' .. fileName]) ~= 'table' then
        ngx.ctx['GLOBAL_LOG_BUFFERS'][self.options.fileFullPath .. '/' .. fileName] = { self.formatMessage(self, level, message, ...) }
    else
        table.insert(ngx.ctx['GLOBAL_LOG_BUFFERS'][self.options.fileFullPath .. '/' .. fileName], self.formatMessage(self, level, message, ...))
    end
end

-- 格式化消息内容
-- @param string level 日志级别
-- @param string message 日志内容
-- @param table args 日志参数
-- @return string message 格式化后的message 
function _M.formatMessage(self, level, message, ...)
    local lineKeywords = {}
    local argsCount = 0
    local args = { ... }
    -- 生成行级别关键词
    -- 如果传递了args参数，且args最后一个参数是table, 那么就把最后一个识别为行级关键词table处理
    if #args > 0 then
        if type(args[#args]) == 'table' then
            for lineKeyword, value in pairs(args[#args]) do
                lineKeywords[lineKeyword] = value
            end
        end
        message = string.format(message, ...)
    end
    self.objectKeywords.time = ngx.now() * 1000
    self.objectKeywords.level = level
    self.objectKeywords.message = message
    local sysutil = require "sys.util"
    local logLineString = sysutil.deepcopy(self.logLineFormat)

    for k, v in pairs(self.objectKeywords) do
        local value = v
        -- 合并关键词
        if k == 'keywords' then
            -- 合并全局级别关键词
            local cjson = require "cjson"
            local globalKeywords = cjson.decode(config:get('GLOBAL_KEYWORDS'))
            for gkey, gval in pairs(globalKeywords) do
                logLineString[k][gkey] = gval
            end
            -- 合并对象级别关键词
            if v ~= nil or v ~= '' then
                for okey, oval in pairs(v) do
                    logLineString[k][okey] = oval
                end
            end
            -- 合并行级别关键词
            for lkey, lval in pairs(lineKeywords) do
                logLineString[k][lkey] = lval
            end
        else
            logLineString[k] = value
        end
    end
    return logLineString;
end

function _M.emargency(self, message, fileName, ...)
    self.log(self, config.LVL_EMARGENCY, message, fileName, ...)
end

function _M.alert(self, message, ...)
    self.log(self, config.LVL_ALERT, message, fileName, ...)
end

function _M.critical(self, message, ...)
    self.log(self, config.LVL_CRITICAL, message, fileName, ...)
end

function _M.error(self, message, ...)
    self.log(self, config.LVL_ERROR, message, fileName, ...)
end

function _M.warning(self, message, ...)
    self.log(self, config.LVL_WARNING, message, fileName, ...)
end

function _M.notice(self, message, ...)
    self.log(self, config.LVL_NOTICE, message, fileName, ...)
end

function _M.info(self, message, ...)
    self.log(self, config.LVL_INFO, message, fileName, ...)
end

function _M.debug(self, message, ...)
    self.log(self, config.LVL_DEBUG, message, fileName, ...)
end

--local class_mt = { 
--	-- to prevent use of casual module global variables
--	__newindex = function (table, key, val)
--		error('attempt to write to undeclared variable "' .. key .. '"')
--	end 
--}
--
--setmetatable(_M, class_mt)
return _M
