-- 全局数组，存放log信息；write到文件并发送至Kafka Server后即重置为空数组
local logConfig = require 'lib.log.config'
logConfig:init()
