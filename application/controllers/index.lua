local IndexController = {}
local user_service = require 'models.service.user'
local aa = require 'aa'
local log = require 'application.library.log.log'

function IndexController:index()
    local log = log:new() 
    log:error('11111')
    ngx.say(print_r(GLOBAL_LOG_BUFFERS))
    do return user_service:get() .. sprint_r(aa:idevzDo()) end
    local view = self:getView()
    local p = {}
    p['vanilla'] = 'Welcome To Vanilla...' .. service:get()
    p['zhoujing'] = 'Power by Openresty'
    view:assign(p)
    return view:display()
end

-- curl http://localhost:9110/get?ok=yes
function IndexController:get()
    local get = self:getRequest():getParams()
    print_r(get)
    do return 'get' end
end

-- curl -X POST http://localhost:9110/post -d '{"ok"="yes"}'
function IndexController:post()
    local _, post = self:getRequest():getParams()
    print_r(post)
    do return 'post' end
end

-- curl -H 'accept: application/vnd.YOUR_APP_NAME.v1.json' http://localhost:9110/api?ok=yes
function IndexController:api_get()
    local api_get = self:getRequest():getParams()
    print_r(api_get)
    do return 'api_get' end
end

return IndexController
