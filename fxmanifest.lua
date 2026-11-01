fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vi-hud'
description 'GTA VI inspired minimap'
version '1.0.0'

ui_page 'html/index.html'

shared_script 'config.lua'
client_scripts {
    'bridge.lua',
    'settings.lua', -- per-player /hud settings; before the rest so they start with the player's values
    'client.lua',
    'radio.lua',
    'weapons.lua',
    'speedo.lua',
    'status.lua',
    'compass.lua',
    'mic.lua',
    'money.lua',
    'notify.lua',
    'pause.lua',
}

server_script 'server.lua'

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
