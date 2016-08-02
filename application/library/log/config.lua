local _M = {
    -- 日志级别文案 
    LVL_EMARGENCY = 'emargency',
    LVL_ALERT = 'alert',
    LVL_CRITICAL = 'critical',
    LVL_ERROR = 'error',
    LVL_WARNING = 'warning',
    LVL_NOTICE = 'notice',
    LVL_INFO = 'info',
    LVL_DEBUG = 'debug',
    -- 全局默认日志路径
    GLOBAL_LOG_FULL_PATH = '/home/leslie/luaLog/logs',
    -- 全局默认日志级别为info
    GLOBAL_LOG_LEVEL = 'info',
    -- 日志字段分隔符
    LOG_IFS = "\x01",
    -- 关键词字段分割符
    KEYWORD_IFS = "\x02",
    -- 全局关键字
    GLOBAL_KEYWORDS = ''
}
local shared = ngx.shared.logConfig
local logConfig = shared:get('logConfig')
function _M.getLogConfig(self, name)
    return logConfig[name]
end
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
	shared:set('GLOBAL_KEYWORDS', globalKeywords)
end
return _M
