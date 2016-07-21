local simple = require 'vanilla.v.routes.simple'
local restful = require 'vanilla.v.routes.restful'

local Bootstrap = {}

function Bootstrap:initWaf()
    require('vanilla.sys.waf.acc'):check()
end

function Bootstrap:initErrorHandle()
    self.dispatcher:setErrorHandler({controller = 'error', action = 'error'})
end

function Bootstrap:initRoute()
    local router = self.dispatcher:getRouter()
    local simple_route = simple:new(self.dispatcher:getRequest())
    local restful_route = restful:new(self.dispatcher:getRequest())
    router:addRoute(restful_route, true)
    router:addRoute(simple_route)
    -- print_r(router:getRoutes())
end

function Bootstrap:initView()
end

function Bootstrap:initPlugin()
    local admin_plugin = require('plugins.admin'):new()
    self.dispatcher:registerPlugin(admin_plugin);
end

function Bootstrap:new(dispatcher)
    local instance = {
        dispatcher = dispatcher,
        boot_list = self.boot_list
    }
    setmetatable(instance, {__index=self})
    return instance
end

function Bootstrap:boot_list()
    return {
        -- Bootstrap.initWaf,
        -- Bootstrap.initErrorHandle,
        -- Bootstrap.initRoute,
        -- Bootstrap.initView,
        -- Bootstrap.initPlugin,
    }
end

return Bootstrap
