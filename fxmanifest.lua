fx_version 'cerulean'
game 'gta5'

name 'ez_money'
description 'QBox Money Logging and Leaderboard System'
author 'EZIOFK'
version '1.0.0'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/discord.lua',
    'server/main.lua'
}


dependencies {
    'qbx_core',
    'oxmysql'
}

lua54 'yes'