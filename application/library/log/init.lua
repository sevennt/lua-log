-- 全局数组，存放log信息；write到文件并发送至Kafka Server后即重置为空数组
GLOBAL_LOG_BUFFERS = {
    --['/home/www/tttttt.log'] = 'test'
}
local logConfig = require 'application.library.log.config'
logConfig:init()
