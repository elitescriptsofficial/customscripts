
fx_version 'cerulean'
game 'gta5'

author 'EliteScripts'
description 'Staff Portal - manage ranks and permissions'
version '1.1.0'

server_script 'config.lua'
server_script 'server.lua'

client_script 'client.lua'

ui_page 'ui/index.html'

files {
	'ui/index.html',
	'ui/app.js',
	'ui/styles.css'
}

server_export 'hasPermission'
server_export 'getRank'
server_export 'setRank'
server_export 'createRank'
server_export 'deleteRank'
server_export 'getAllRanks'
server_export 'getAssignments'
server_export 'registerPermissions'
server_export 'unregisterPermissions'
server_export 'getAvailablePermissions'

