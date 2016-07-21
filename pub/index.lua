if ngx.var.VA_DEV == nil then

    local helpers = require "vanilla.v.libs.utils"
    function sprint_r( ... )
        return helpers.sprint_r(...)
    end

    function lprint_r( ... )
        local rs = sprint_r(...)
        print(rs)
    end

    function print_r( ... )
        local rs = sprint_r(...)
        ngx.say(rs)
    end

    function err_log(msg)
        ngx.log(ngx.ERR, "===zjdebug" .. msg .. "===")
    end
end

local vanilla_application = require 'vanilla.v.application'
local application_config = require 'config.application'
local boots = require 'application.bootstrap'

local App = {}

function App:run( ngx )
    vanilla_application:new(ngx, application_config):bootstrap(boots):run()
end

return App
