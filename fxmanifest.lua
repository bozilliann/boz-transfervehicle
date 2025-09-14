fx_version 'cerulean'
game 'gta5'

author 'YourName'
description 'Vehicle Transfer Script for QBCore + op-garages'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua', -- remove if you don’t use ox_lib
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}
