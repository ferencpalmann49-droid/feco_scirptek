fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'feco_govpanel'
description 'Government control panel for ESX 1.1'
author 'OpenAI Assistant'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
