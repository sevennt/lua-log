local APP_ROOT = ngx.var.document_root
local Appconf={}
Appconf.vanilla_root = '/usr/local/vanilla'
Appconf.vanilla_version = '0_1_0_rc5'
Appconf.name = 'luaLog'

Appconf.route='vanilla.v.routes.simple'
Appconf.bootstrap='application.bootstrap'

Appconf.app={}
Appconf.app.root=APP_ROOT

Appconf.controller={}
Appconf.controller.path=Appconf.app.root .. '/application/controllers/'

Appconf.view={}
Appconf.view.path=Appconf.app.root .. '/application/views/'
Appconf.view.suffix='.html'
Appconf.view.auto_render=true

return Appconf
