return { 
    -- 日志级别文案 
    LVL_EMARGENCY = 'EMARGENCY',
    LVL_ALERT = 'ALERT',
    LVL_CRITICAL = 'CRITICAL',
    LVL_ERROR = 'ERROR',
    LVL_WARNING = 'WARNING',
    LVL_NOTICE = 'NOTICE',
    LVL_INFO = 'INFO',
    LVL_DEBUG = 'DEBUG',

    -- 全局默认日志级别为info
    GLOBAL_LOG_LEVEL = LVL_INFO,
    -- 日志字段分隔符
    LOG_IFS = "\x01",
    -- 关键词字段分割符
    KEYWORD_IFS = "\x02"

}
