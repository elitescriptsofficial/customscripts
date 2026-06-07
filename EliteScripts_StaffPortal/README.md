EliteScripts Staff Portal
=========================

Simple staff rank and permission manager for FiveM.

Setup
- edit `config.lua` and set `Config.defaultAdmin` to your default admin identifier (e.g. `steam:110000...`).

Commands (admin only)
- `/createrank <name> <perm1,perm2,...>` - create a rank
- `/assignrank <playerId|identifier> <rank>` - assign a rank to a player (player server id or identifier)
- `/listranks` - list ranks and permissions
- `/liststaff` - show current assignments

Exports (server)
- `hasPermission(identifier, permission)` -> bool
- `getRank(identifier)` -> rankName or nil
- `setRank(identifier, rankName)` -> bool
- `createRank(name, permissions)` -> bool
- `deleteRank(name)` -> bool
- `getAllRanks()` -> table
- `getAssignments()` -> table

Usage from another resource (server-side):
`local ok = exports['EliteScripts_StaffPortal']:hasPermission('steam:110000...', 'kick')`

Registering permissions from other resources
- Other server resources can register the permissions they provide so the Staff Portal can list them automatically in the UI.
- Example (server-side):
```
local perms = { 'kick', 'ban', 'teleport' }
exports['EliteScripts_StaffPortal']:registerPermissions(GetCurrentResourceName(), perms)
```
- To unregister on resource stop:
```
exports['EliteScripts_StaffPortal']:unregisterPermissions(GetCurrentResourceName())
```

