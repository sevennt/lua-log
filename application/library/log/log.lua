local config = require "application.library.log.config"

local _M = { _VERSION = '0.1' }

-- 配置日志默认参数
local _options = {
    fileName = '', -- 当前日志文件名
    fileFullPath = config.GLOBAL_LOG_FULL_PATH, -- 日志文件完整路径
    logLevelThreshold = config.GLOBAL_LOG_LEVEL, -- 默认日志过滤级别
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
    local options ={}
    if initOptions == nil then 
        for k,v in pairs(_options) do 
            options[k] = v 
        end
    else
        options = initOptions
    end
    self['keywordsString'] = '' 
    -- 日志行关键词替换元素
    -- 时间|日志级别|服务ID|模块名|接口名|方法名|关键字|详细信息
    self['logLineKeywords'] = { 
        time = '', -- 时间字段 替换 %time% 关键词
        level = '', -- 级别字段 替换 %level% 关键词
        id = options.serviceId or '', -- 服务ID 替换 %id% 关键词
        module = options.moduleName or '', --  模块字段 替换 %module% 关键词
        interface = options.interfaceName or '', --  接口字段 替换 %interface% 关键词
        method = options.methodName or '', --  方法字段 替换 %method% 关键词
        keywords = '', --  关键词字段 替换 %keyword% 关键词
        message = '', -- 详细信息 替换 %message% 关键词
    };
    -- 日志行格式
    -- 默认格式样式  %time% %level% %module% %interface% %method% %message%
    -- 使用ifs接合关键词组成单行日志格式, 提供给后续写入日志时替换关键词
    self['logLineFormat'] =  table.concat(options.logFormat, config.LOG_IFS)

    return setmetatable({
        options = options, 
        LVL = LVL
    }, mt)
end
local globalKeywords = ''

-- 设定全局关键字
-- @param keywords table 
-- keywords = {
--     'keywordName1' = {'keywordContent1', 'keywordContent2'},
--     'keywordName2' = 'keywordContent21'
-- }
-- @return string globalKeywords 全局关键字
function _M.setGlobalKeywords(self, keywords)
    if keywords == nil then 
        return nil
    end
    for k,v in pairs(keywords) do
        if type(keywords) == 'table' then
            for key, value in pairs(v) do
                keywordsString = keywordsString .. config.KEYWORD_IFS .. k .. '=' .. value 
            end
        else
            keywordsString = keywordsString .. config.KEYWORD_IFS .. k .. '=' .. v 
        end
    end
    -- 去掉globalKeywords词首的KEYWORD_IFS
    globalKeywords = string.sub(keywordsString, 2, string.len(keywordsString))
    return globalKeywords
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
        fileName = level .. '-' .. '' ..ngx.today() .. '.log'
    end
    -- 当日志level高于全局默认最低leve，或者高于本次对象实例化时设定最低level，则不记录   
    if LVL[level] >= LVL[config.GLOBAL_LOG_LEVEL] or LVL[level] >= LVL[self.options.logLevelThreshold] then 
        return nil
    end

    GLOBAL_LOG_BUFFERS[self.options.fileFullPath .. '/' .. fileName] = self.formatMessage(self, level, message, ...) 
end

-- 格式化消息内容
-- @param string level 日志级别
-- @param string message 日志内容
-- @param table args 日志参数
-- @return string message 格式化后的message 
function _M.formatMessage(self, level, message, ...)
    local lineKeywords = ''
    local argsCount = 0
    local args = {...}
    local message = ''
    -- 生成行级别关键词
    -- 如果传递了args参数，且args最后一个参数是table, 那么就把最后一个识别为行级关键词table处理
    if #args > 0  then 
        if type(args[#args]) == 'table' then
            for keywords, value in pairs(args(#args)) do
                -- 如果一个keyword定义了多个value
                if type(value) == 'table' then
                    for k, v in pairs(v) do
                        lineKeywords = lineKeywords .. config.KEYWORD_IFS .. keywords .. '=' .. v 
                    end
                end
                -- 如果一个keyword只定义了一个value
                lineKeywords = lineKeywords .. config.KEYWORD_IFS .. keywords .. '=' .. value
            end
        end 
        message = string.format(message, ...)
    end
    self.logLineKeywords.time = ngx.now() * 1000
    self.logLineKeywords.level = level
    self.logLineKeywords.message = message 
    local logLineString = self.logLineFormat
    local fullKeywords = '' 
    for k, v in pairs(self.logLineKeywords) do
        ngx.say(k, '====',v)
        -- 合并关键词
        if k == 'keywords' then
            -- 合并全局级别关键词
            fullKeywords = v .. config.KEYWORD_IFS .. self.globalKeywords
            -- 合并实例化对象级别关键词
            if v ~= nil or v ~= '' then
                fullKeywords = fullKeywords .. config.KEYWORD_IFS .. v 
            end
            -- 合并行级别关键词
            fullKeywords = fullKeywords .. config.KEYWORD_IFS .. lineKeywords
        end
    --ngx.say(print_r(config.KEYWORD_IFS, fullKeywords))
        logLineString = ngx.re.gsub(logLineString, '%' .. k  .. '%', fullKeywords)
    end
    return logLineString .. "\n";
end

function _M.emargency(self, message, fileName, ...)
    self.log(self, config.LVL_EMARGENCY, message, ...)
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
