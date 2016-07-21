local IdevzController = {}
local user_service = require 'models.service.user'
local bb = require 'bb'

function IdevzController:index()
    -- do return user_service:get() .. sprint_r(bb:idevzDo()) end
    local view = self:getView()
    local p = {}
    p['vanilla'] = 'Welcome To Vanilla...' .. user_service:get()
    p['zhoujing'] = 'Power by Openresty'
    -- view:assign(p)
    do return view:render('index/index.html', p) end
    return view:display()
end

-- curl http://localhost:9110/get?ok=yes
function IdevzController:get()
    local get = self:getRequest():getParams()
    print_r(get)
    do return 'get' end
end

-- curl -X POST http://localhost:9110/post -d '{"ok"="yes"}'
function IdevzController:post()
    local _, post = self:getRequest():getParams()
    print_r(post)
    do return 'post' end
end

-- curl -H 'accept: application/vnd.YOUR_APP_NAME.v1.json' http://localhost:9110/api?ok=yes
function IdevzController:api_get()
    local api_get = self:getRequest():getParams()
    print_r(api_get)
    do return 'api_get' end
end

return IdevzController
