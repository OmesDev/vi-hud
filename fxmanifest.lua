fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vi-hud'
description 'GTA VI inspired minimap'
version '1.0.0'

ui_page 'html/index.html'

escrow_ignore {
    'config.lua',
}

shared_script 'config.lua'
client_scripts {
    'client/bridge.lua',
    'client/settings.lua', -- per-player /hud settings; before the rest so they start with the player's values
    'client/client.lua',
    'client/radio.lua',
    'client/weapons.lua',
    'client/speedo.lua',
    'client/status.lua',
    'client/compass.lua',
    'client/mic.lua',
    'client/money.lua',
    'client/notify.lua',
    'client/pause.lua',
}

server_script 'server/server.lua'

-- Theme for FiveM's chat resource (html/chat.css): matches the HUD, the chat itself is untouched
chat_theme 'vi-hud' {
    styleSheet = 'html/chat.css',
    msgTemplates = {
        default = '<b>{0}</b><span>{1}</span>', -- name + text styled apart (no "Name: ")
    },
}

files {
    'html/index.html',
    'html/*.css',
    'html/*.js',
    'html/stations/*.png',
    'html/weapons/*.png',
}


