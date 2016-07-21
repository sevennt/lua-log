<?php
namespace Douyu\Log;

use \Phalcon\Di\InjectionAwareInterface;

class Config implements InjectionAwareInterface
{
    // 错误级别
    const EMERGENCY = 'EMERGENCY';
    const ALERT = 'ALERT';
    const CRITICAL = 'CRITICAL';
    const ERROR = 'ERROR';
    const WARNING = 'WARNING';
    const NOTICE = 'NOTICE';
    const INFO = 'INFO';
    const DEBUG = 'DEBUG';
    /**
     * 日志字段分隔符
     */
    const LOG_IFS = "\x01";
    /**
     * 关键词字段分割符
     */
    const KEYWORD_IFS = "\x02";

    /**
     * DI对象
     * @var \Phalcon\DiInterface
     */
    protected $di;

    /**
     * 全局关键词
     * [
     *    '关键词名称' => '关键词内容'
     * ]
     * @var array
     */
    protected $keywords = [];
    /**
     * 全局关键词文本
     * @var string
     */
    protected $keywordsString = '';

    /**
     * 当前的URI
     * @var string
     */
    protected $currentUri;

    /**
     * 全局日志级别
     * @var string
     */
    protected $globalLogLevel = self::INFO;

    /**
     * 构造函数
     */
    public function __construct()
    {
        $this->currentUri = $this->detectUri();
        // 全局级别限制
        if (defined('LOG_LEVEL')) {
            $this->globalLogLevel = strtoupper(LOG_LEVEL);
        }
    }

    /**
     * 获取全局日志级别
     * @return string
     */
    public function getGlobalLogLevel()
    {
        return $this->globalLogLevel;
    }

    /**
     * 设定全局日志级别
     *
     * @param string $level
     */
    public function setGlobalLogLevel($level)
    {
        $this->globalLogLevel = $level;
    }

    /**
     * 获取当前的URI地址
     * @return string
     */
    public function getCurrentUri()
    {
        return $this->currentUri;
    }

    /**
     * 设置ID对象
     * 配置依赖注入时会自动注入di对象
     *
     * @param \Phalcon\DiInterface $dependencyInjector
     */
    public function setDI(\Phalcon\DiInterface $dependencyInjector)
    {
        $this->di = $dependencyInjector;
    }

    /**
     * 获取DI独享
     * @return \Phalcon\DiInterface
     */
    public function getDI()
    {
        return $this->di;
    }

    /**
     * 生成全局关键词组
     */
    protected function generateGlobalKeywords()
    {
        $keywords = [];
        if ($this->keywords) {
            foreach ($this->keywords as $key => $words) {
                if (is_array($words)) {
                    foreach ($words as $word) {
                        $keywords[] = $key . '=' . $word;
                    }
                    continue;
                }
                if (is_string($words)) {
                    $keywords[] = $key . '=' . $words;
                }
            }
        }
        if ($keywords) {
            $this->keywordsString = implode(self::KEYWORD_IFS, $keywords);
        }
    }

    /**
     * 返回全局关键词组
     *
     * @return string
     */
    public function getGlobalKeywords()
    {
        return $this->keywordsString;
    }

    /**
     * 添加一个全局关键词
     *
     * @param string $key 关键词名称
     * @param string $value 关键词数据
     */
    public function addGlobalKeyword($key, $value)
    {
        if (isset($this->keywords[$key])) {
            $this->keywords[$key][] = $value;
        } else {
            $this->keywords[$key] = [$value];
        }
        $this->generateGlobalKeywords();
    }

    /**
     * 删除一个全局关键词
     *
     * @param string $key 关键词名称
     */
    public function removeGlobalKeyword($key)
    {
        if (!isset($this->keywords['keywords'][$key])) {
            return;
        }
        unset($this->keywords[$key]);
        $this->generateGlobalKeywords();
    }

    /**
     * 设置全局关键词
     * 关键词数据格式
     * [
     *    '关键词名称' => ['关键词内容', '关键词内容']
     * ]
     *
     * @param array $keywords
     */
    public function setGlobalKeywords(array $keywords)
    {
        if (!$keywords) {
            return;
        }

        // 字符,数字,布尔数据转数组
        foreach ($keywords as &$keyword) {
            if (is_string($keyword) || is_numeric($keyword) || is_bool($keyword)) {
                $keyword = [$keyword];
            }
        }

        $this->keywords = $keywords;
        $this->generateGlobalKeywords();
    }


    /**
     * 获取当前的URI
     *
     * @return string
     */
    protected function detectUri()
    {
        if (!isset($_SERVER['REQUEST_URI']) OR !isset($_SERVER['SCRIPT_NAME'])) {
            return '';
        }

        $uri = $_SERVER['REQUEST_URI'];
        if (strpos($uri, $_SERVER['SCRIPT_NAME']) === 0) {
            $uri = substr($uri, strlen($_SERVER['SCRIPT_NAME']));
        } elseif (strpos($uri, dirname($_SERVER['SCRIPT_NAME'])) === 0) {
            $uri = substr($uri, strlen(dirname($_SERVER['SCRIPT_NAME'])));
        }

        // This section ensures that even on servers that require the URI to be in the query string (Nginx) a correct
        // URI is found, and also fixes the QUERY_STRING server var and $_GET array.
        if (strncmp($uri, '?/', 2) === 0) {
            $uri = substr($uri, 2);
        }
        $parts = preg_split('#\?#i', $uri, 2);
        $uri = $parts[0];

        if ($uri == '/' || empty($uri)) {
            return '/';
        }

        $uri = parse_url($uri, PHP_URL_PATH);

        // Do some final cleaning of the URI and return it
        return str_replace(array('//', '../'), '/', trim($uri, '/'));
    }
}
