local ErrorController = {}
local ngx_log = ngx.log
local ngx_redirect = ngx.redirect
local os_getenv = os.getenv


function ErrorController:error()
    local env = os_getenv('VA_ENV') or 'development'
    if env == 'development' then
        local view = self:getView()
        view:assign(self.err)
        return view:display()
    else
        local helpers = require 'vanilla.v.libs.utils'
        ngx_log(ngx.ERR, helpers.sprint_r(self.err))
        -- return ngx_redirect("http://sina.cn?vt=4", ngx.HTTP_MOVED_TEMPORARILY)
        return helpers.sprint_r(self.err)
    end
end

return ErrorController
