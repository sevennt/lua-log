<?php
namespace Douyu\Log;

use \Phalcon\Di\InjectionAwareInterface;

class Logger implements InjectionAwareInterface
{
    /**
     * DI对象
     * @var \Douyu\Core\Di
     */
    protected $di;

    /**
     * 配置参数数组
     * @var string
     */
    protected $options = [
        // 默认日志过滤级别
        'logLevelThreshold' => Config::INFO,
        // 日志延迟写入开关
        'delayWrite' => true,
        // 日志缓冲阈值
        'delayThreshold' => 200,
        // 日志格式：分隔符为 unicode 1
        // 时间|日志级别|服务ID|模块名|接口名|方法名|关键字|详细信息
        // 日志默认格式
        'logFormat' => ['%time%', '%level%', '%id%', '%module%', '%interface%', '%method%', '%keywords%', '%message%'],
        // 向CLI输出日志信息
        'outputToCli' => false,
        // 服务ID
        'serviceId' => '',
        // 模块名
        'moduleName' => '',
        // 接口名
        'interfaceName' => '',
        // 方法名
        'methodName' => '',
        // 关键词
        'keywords' => []
    ];
    /**
     * 当前日志文件名
     * @var string
     */
    protected $fileName = '';

    /**
     * 日志文件完整路径
     * @var string
     */
    protected $fileFullPath = '';

    /**
     * 记录当前是否为CLI环境
     * @var bool
     */
    protected $isCli = false;

    /**
     * 当前日志实例记录的总行数
     * @var int
     */
    protected $logLineCount = 0;
    /**
     * 当前日志缓冲行数
     * @var int
     */
    protected $logBufferCount = 0;

    /**
     * 日志缓冲
     * @var array
     */
    protected $logBuffers = [];

    /**
     * 错误级别数字化,用于输出控制
     * @var array
     */
    protected $logLevels = [
        Config::EMERGENCY => 0,
        Config::ALERT => 1,
        Config::CRITICAL => 2,
        Config::ERROR => 3,
        Config::WARNING => 4,
        Config::NOTICE => 5,
        Config::INFO => 6,
        Config::DEBUG => 7
    ];

    /**
     * 日志写入服务
     * @var WriterInterface;
     */
    protected $writer;

    /**
     * 日志配置对象
     * @var Config
     */
    protected $config;

    /**
     * 日志行格式
     *
     * 默认格式样式
     * %time% %level% %module% %interface% %method% %message%
     *
     * @see File::$logLineKeywords
     * @var string
     */
    protected $logLineFormat = '';

    /**
     * 日志行关键词替换元素
     * 时间|日志级别|服务ID|模块名|接口名|方法名|关键字|详细信息
     * @var
     */
    protected $logLineKeywords = [
        // 时间字段 替换 %time% 关键词
        'time' => '',
        // 级别字段 替换 %level% 关键词
        'level' => '',
        // 服务ID 替换 %id% 关键词
        'id' => '',
        // 模块字段 替换 %module% 关键词
        'module' => '',
        // 接口字段 替换 %interface% 关键词
        'interface' => '',
        // 方法字段 替换 %method% 关键词
        'method' => '',
        // 关键词字段 替换 %keyword% 关键词
        'keywords' => '',
        // 详细信息 替换 %message% 关键词
        'message' => '',
    ];

    /**
     * 记录时间对象
     * @var float
     */
    protected $startTime;

    /**
     * 构造函数
     *
     * @param \Douyu\Core\Di $di Di对象
     * @param array $options 配置参数
     * @throws \RuntimeException
     */
    public function __construct(\Douyu\Core\Di $di, array $options = [])
    {
        if (!empty($options)) {
            $this->options = array_merge($this->options, $options);
        }

        $this->di = $di;

        $this->config = $this->di->getLogConfig();

        $this->isCli = (php_sapi_name() === 'cli');
        
        $this->logLineKeywords['id'] = $this->options['serviceId'];
        $this->logLineKeywords['module'] = $this->options['moduleName'];
        $this->logLineKeywords['interface'] = $this->options['interfaceName'];
        $this->logLineKeywords['method'] = $this->options['methodName'];

        $this->generateKeywords();

        // 使用ifs接合关键词组成单行日志格式, 提供给后续写入日志时替换关键词
        $this->logLineFormat = implode(Config::LOG_IFS, $this->options['logFormat']);
    }

    /**
     * 获取当前DI对象
     * @return \Phalcon\DiInterface
     */
    public function getDi()
    {
        return $this->di;
    }

    /**
     * 获取DI对象
     * @param \Phalcon\DiInterface $di
     */
    public function setDi(\Phalcon\DiInterface $di)
    {
        $this->di = $di;
    }

    /**
     * 获取日志写入对象
     * @param WriterInterface $writer
     */
    public function setWriter(WriterInterface $writer)
    {
        $this->writer = $writer;
    }

    /**
     * 生成关键词
     */
    protected function generateKeywords()
    {
        $keywords = [];
        if ($this->options['keywords']) {
            foreach ($this->options['keywords'] as $key => $words) {
                foreach ($words as $word) {
                    $keywords[] = $key . '=' . $word;
                }
            }
        }

        if ($keywords) {
            $this->logLineKeywords['keywords'] = implode(Config::KEYWORD_IFS, $keywords);
        }
    }

    /**
     * 设定服务ID
     * @param string $id
     */
    public function setServiceId($id)
    {
        $this->options['serviceId'] = $id;
        $this->logLineKeywords['id'] = $id;
    }

    /**
     * 设定模块名
     * @param string $name
     */
    public function setModuleName($name)
    {
        $this->options['moduleName'] = $name;
        $this->logLineKeywords['module'] = $name;
    }

    /**
     * 设定日志接口名
     * @param string $name
     */
    public function setInterfaceName($name)
    {
        $this->options['interfaceName'] = $name;
        $this->logLineKeywords['interface'] = $name;
    }


    /**
     * 设定日志方法名
     * @param string $name
     */
    public function setMethodName($name)
    {
        $this->options['methodName'] = $name;
        $this->logLineKeywords['method'] = $name;
    }

    /**
     * 设定关键词
     * 注意此方法是直接覆盖当前类的关键词设定
     * 关键词数据格式
     * [
     *    '关键词名称' => ['关键词内容', '关键词内容']
     * ]
     * @param array $keywords 关键词
     */
    public function setKeywords(array $keywords)
    {
        if (!$keywords) {
            return;
        }
        // 字符转数组
        foreach ($keywords as &$keyword) {
            if (is_string($keyword)) {
                $keyword = [$keyword];
            }
        }
        $this->options['keywords'] = $keywords;
        $this->generateKeywords();
    }

    /**
     * 增加一个关键词
     *
     * @param string $key 关键词名称
     * @param string $value 关键词内容
     */
    public function addKeyword($key, $value)
    {
        if (isset($this->options['keywords'][$key])) {
            $this->options['keywords'][$key][] = $value;
        } else {
            $this->options['keywords'][$key] = [$value];
        }
        $this->generateKeywords();
    }

    /**
     * 删除一个关键词
     *
     * @param string $key 关键词名称
     */
    public function removeKeyword($key)
    {
        if (!isset($this->options['keywords'][$key])) {
            return;
        }
        unset($this->options['keywords'][$key]);
        $this->generateKeywords();
    }


    /**
     * 类销毁时自动把缓冲的日志写入到日志文件中
     */
    public function __destruct()
    {
        $this->write();
    }

    /**
     * 开始计时器
     *
     * @param string $level 计时器信息日志级别
     */
    public function startTimer($level = Config::DEBUG)
    {
        $this->log($level, '计时器开始');
        $this->startTime = microtime(true);
    }

    /**
     * 停止日志计时器
     *
     * @param string $level 计时器信息日志级别
     */
    public function stopTimer($level = Config::DEBUG)
    {
        $this->startTime = 0;
        $this->log($level, '计时器结束');
    }

    /**
     * 设置时间格式
     *
     * @param string $dateFormat 时间格式, 参考 date() 函数
     */
    public function setDateFormat($dateFormat)
    {
        $this->options['dateFormat'] = $dateFormat;
    }

    /**
     * 设置日志等级
     *
     * @param string $logLevelThreshold 日志等级
     */
    public function setLogLevelThreshold($logLevelThreshold)
    {
        $this->options['logLevelThreshold'] = $logLevelThreshold;
    }

    /**
     * 开启向cli输出日志
     */
    public function enableOutputToCli()
    {
        $this->options['outputToCli'] = true;
    }

    /**
     * 关闭向cli输出日志
     */
    public function disableOutputToCli()
    {
        $this->options['outputToCli'] = false;
    }


    /**
     * 开启日志缓冲
     * 注意:
     * 开启后,写入日志必须触发write方法才会把缓冲区里面的日志写入
     */
    public function enableDelayWrite()
    {
        $this->options['delayWrite'] = true;
    }

    /**
     * 关闭日志缓冲
     * 注意:
     * 关闭时, 先前已经缓冲的日志会写入到文件中
     */
    public function disableDelayWrite()
    {
        $this->options['delayWrite'] = false;
        $this->write();
    }

    /**
     * 记录日志
     *
     * @param mixed $level
     * @param string $message
     * @param array $args
     * @return null
     */
    public function log($level, $message, array $args = [])
    {
        $globalLevel = $this->config->getGlobalLogLevel();

        if ($this->logLevels[$globalLevel] < $this->logLevels[$level]) {
            return;
        }

        // 当前类级别限制, 自动忽略比配置的级别低的日志
        if ($this->logLevels[$this->options['logLevelThreshold']] < $this->logLevels[$level]) {
            return;
        }
        $this->logLineCount++;

        // 运行计时
        $elapsedTime = null;
        if ($this->startTime) {
            $elapsedTime = (float)microtime(true) - $this->startTime;
        }

        $message = $this->formatMessage($level, $message, $args);

        // 记录运行时间
        if ($elapsedTime) {
            $message = rtrim($message, PHP_EOL) . ' (' . sprintf("%.9f", $elapsedTime) . ')' . PHP_EOL;
        }

        // CLI环境输出到控制台
        if ($this->isCli && $this->options['outputToCli']) {
            echo $message;
        }

        // 延迟写入
        if ($this->options['delayWrite']) {
            $this->logBufferCount++;
            $this->logBuffers[] = ['level' => $level, 'msg' => $message];
            // 缓冲的日志数量达到日志缓冲阈值就触发写入文件并清空日志缓冲计数
            if ($this->logBufferCount == $this->options['delayThreshold']) {
                $this->write();
                $this->logBufferCount = 0;
            }
            return;
        }
        $this->write();
    }

    /**
     * 紧急级别日志快捷方法
     * @param string $msg 消息内容
     */
    public function emergency($msg)
    {
        $this->log(Config::EMERGENCY, $msg, func_get_args());
    }

    /**
     * 报警级别日志快捷方法
     * @param string $msg 消息内容
     */
    public function alert($msg)
    {
        $this->log(Config::ALERT, $msg, func_get_args());
    }

    /**
     * 严重级别日志快捷方法
     * @param string $msg 消息内容
     */
    public function critical($msg)
    {
        $this->log(Config::CRITICAL, $msg, func_get_args());
    }

    /**
     * 错误级别日志快捷方法
     * @param string $msg 消息内容
     */
    public function error($msg)
    {
        $this->log(Config::ERROR, $msg, func_get_args());
    }

    /**
     * 警告级别日志快捷方法
     * @param string $msg 消息内容
     */
    public function warning($msg)
    {
        $this->log(Config::WARNING, $msg, func_get_args());
    }

    /**
     * 提示级别日志快捷方法
     * @param string $msg 消息内容
     */
    public function notice($msg)
    {
        $this->log(Config::NOTICE, $msg, func_get_args());
    }

    /**
     * 消息级别日志快捷方法
     * @param string $msg 消息内容
     */
    public function info($msg)
    {
        $this->log(Config::INFO, $msg, func_get_args());
    }

    /**
     * 调试级别日志快捷方法
     * @param string $msg 消息内容
     */
    public function debug($msg)
    {
        $this->log(Config::DEBUG, $msg, func_get_args());
    }

    /**
     * 将缓冲区的日志写入到日志文件中
     */
    public function write()
    {
        if (empty($this->logBuffers)) {
            return;
        }
        $msgContent = '';
        // 组合日志信息一次写入
        foreach ($this->logBuffers as $log) {
            $msgContent .= $log['msg'];
        }

        $this->writer->write($msgContent);
        // 清空日志缓存
        $this->logBuffers = [];
    }

    /**
     * 格式化消息内容
     *
     * @param  string $level 日志错误级别
     * @param  string $message 日志信息
     * @param  array $args 日志格式化变量参数
     * @return string
     */
    protected function formatMessage($level, $message, $args)
    {
        // 行级关键词
        $lineKeywords = '';
        $argsLength = count($args);
        // 如果有格式化参数, 采用vsprintf格式化处理
        if ($argsLength > 1) {
            // 移除第一个参数
            array_shift($args);
            // 如果有2个以上的参数,且最后一个参数是数组, 那么就把最后一个识别为行级关键词数组处理
            if (is_array(end($args))) {
                $tmpKeywords = array_pop($args);
                foreach ($tmpKeywords as $keyword => $words) {
                    if (is_array($words)) {
                        foreach ($words as $word) {
                            $lineKeywords .= Config::KEYWORD_IFS . $keyword . '=' . $word;
                        }
                        continue;
                    }
                    $lineKeywords .= Config::KEYWORD_IFS . $keyword . '=' . $words;
                }
            }
            $message = vsprintf($message, $args);
        }
        // 获取毫秒
        list($microSeconds, $timestamp) = explode(' ', microtime());

        $this->logLineKeywords['time'] = intval(($timestamp + $microSeconds) * 1000);
        $this->logLineKeywords['level'] = strtoupper($level);
        $this->logLineKeywords['message'] = $message;

        // 使用配置的日志分隔符接合日志格式
        $logLineString = $this->logLineFormat;

        $globalKeywords = $this->config->getGlobalKeywords();

        foreach ($this->logLineKeywords as $part => $value) {
            // 合并关键词
            if ($part == 'keywords') {
                $keywords = [];
                // 全局关键词
                if ($globalKeywords) {
                    $keywords[] = $globalKeywords;
                }
                // 当前日志关键词
                if ($value) {
                    $keywords[] = $value;
                }
                // 行级关键词
                if ($lineKeywords) {
                    $keywords[] = substr($lineKeywords, 1);
                }
                $value = implode(Config::KEYWORD_IFS, $keywords);
            }
            $logLineString = str_replace('%' . $part . '%', $value, $logLineString);
        }

        return $logLineString . PHP_EOL;
    }

    /**
     * 记录异常对象信息到当前日志
     *
     * @param \Exception $e 需要记录的异常对象实例
     * @param bool $logStackTrace 记录栈追踪信息, 默认为true
     * @throws \RuntimeException
     */
    public function logException(\Exception $e, $logStackTrace = true)
    {
        $pid = getmypid();
        // 容错
        if ($pid === false) {
            $pid = 0;
        }
        // 约定日志格式
        // 进程ID|请求地址|异常名称|异常信息|异常码|文件|行数|栈追踪
        $columns = [
            $pid,
            $this->config->getCurrentUri(),
            get_class($e),
            $e->getMessage(),
            $e->getCode(),
            $e->getFile(),
            $e->getLine()
        ];

        if ($logStackTrace) {
            $columns[] = str_replace(chr(10), '', $e->getTraceAsString());
        }

        // 消息采用 Record Separator 0x1C 来分割, 方便分析
        $msg = implode("\x1C", $columns);
        $this->error($msg);
    }
}
