local resource = GetCurrentResourceName()
local dataFile = Config.dataFile or "data/ranks.json"

local ranksData = {
  ranks = {},
  assignments = {}
}

-- registry for permissions provided by other resources
local permissionsRegistry = {}

function registerPermissions(resourceName, perms)
  if not resourceName then return false end
  permissionsRegistry[resourceName] = perms or {}
  return true
end

function unregisterPermissions(resourceName)
  permissionsRegistry[resourceName] = nil
  return true
end

function getAvailablePermissions()
  local map = {}
  for _, list in pairs(permissionsRegistry) do
    if type(list) == 'table' then
      for _, p in ipairs(list) do map[p] = true end
    end
  end
  local out = {}
  for p, _ in pairs(map) do table.insert(out, p) end
  return out
end

local function reply(src, msg)
  if src == 0 then
    print("[StaffPortal] " .. msg)
  else
    TriggerClientEvent('chat:addMessage', src, { args = { '^1StaffPortal', msg } })
  end
end

local function loadRanks()
  local raw = LoadResourceFile(resource, dataFile)
  if not raw or raw == '' then
    ranksData = { ranks = {}, assignments = {} }
    return
  end
  local ok, parsed = pcall(function() return json.decode(raw) end)
  if ok and type(parsed) == 'table' then
    ranksData = parsed
  else
    ranksData = { ranks = {}, assignments = {} }
  end
end

local function saveRanks()
  local encoded = json.encode(ranksData)
  SaveResourceFile(resource, dataFile, encoded, -1)
end

local function isAdminSource(src)
  if src == 0 then return true end
  if Config.defaultAdmin == nil or Config.defaultAdmin == "replace_with_admin_identifier" then
    return false
  end
  local ids = GetPlayerIdentifiers(src)
  for _, id in ipairs(ids) do
    if id == Config.defaultAdmin then return true end
  end
  return false
end

-- Helper: resolve identifier from argument (player server id or identifier string)
local function resolveIdentifier(arg)
  if not arg then return nil end
  local n = tonumber(arg)
  if n then
    local ids = GetPlayerIdentifiers(n)
    return ids and ids[1] or nil
  end
  return arg
end

-- Permission check: supports wildcard '*' permission on rank
function hasPermission(identifier, permission)
  if not identifier or not permission then return false end
  local rank = ranksData.assignments[identifier]
  if not rank then return false end
  local r = ranksData.ranks[rank]
  if not r or not r.permissions then return false end
  for _, p in ipairs(r.permissions) do
    if p == '*' or p == permission then return true end
  end
  return false
end

function getRank(identifier)
  return ranksData.assignments[identifier]
end

function setRank(identifier, rankName)
  ranksData.assignments[identifier] = rankName
  saveRanks()
  return true
end

function createRank(name, permissions)
  if ranksData.ranks[name] then return false, "rank_exists" end
  ranksData.ranks[name] = { permissions = permissions or {} }
  saveRanks()
  return true
end

function deleteRank(name)
  ranksData.ranks[name] = nil
  -- remove assignments of this rank
  for id, r in pairs(ranksData.assignments) do
    if r == name then ranksData.assignments[id] = nil end
  end
  saveRanks()
  return true
end

function getAllRanks()
  return ranksData.ranks
end

function getAssignments()
  return ranksData.assignments
end

-- Commands for default admin
RegisterCommand('createrank', function(src, args)
  if not isAdminSource(src) then reply(src, "Not authorized") return end
  local name = args[1]
  local perms = args[2] or ''
  if not name then reply(src, "Usage: /createrank <name> <perm1,perm2,...>") return end
  local permissions = {}
  for p in string.gmatch(perms, '([^,]+)') do table.insert(permissions, p) end
  local ok, err = createRank(name, permissions)
  if ok then reply(src, "Rank '"..name.."' created") else reply(src, "Failed to create rank: "..tostring(err)) end
end, false)

RegisterCommand('assignrank', function(src, args)
  if not isAdminSource(src) then reply(src, "Not authorized") return end
  local target = args[1]
  local rank = args[2]
  if not target or not rank then reply(src, "Usage: /assignrank <playerId|identifier> <rank>") return end
  local id = resolveIdentifier(target)
  if not id then reply(src, "Could not resolve identifier") return end
  if not ranksData.ranks[rank] then reply(src, "Rank does not exist") return end
  setRank(id, rank)
  reply(src, "Assigned rank '"..rank.."' to "..id)
end, false)

RegisterCommand('listranks', function(src, args)
  if not isAdminSource(src) then reply(src, "Not authorized") return end
  for name, def in pairs(ranksData.ranks) do
    local perms = table.concat(def.permissions, ',')
    reply(src, name .. ' => ' .. perms)
  end
end, false)

RegisterCommand('liststaff', function(src, args)
  if not isAdminSource(src) then reply(src, "Not authorized") return end
  for id, rank in pairs(ranksData.assignments) do
    reply(src, id .. ' => ' .. rank)
  end
end, false)

-- Initialize
loadRanks()

-- ensure owner rank and default admin assignment
if Config.defaultAdmin and Config.defaultAdmin ~= "replace_with_admin_identifier" then
  if not ranksData.ranks['owner'] then
    ranksData.ranks['owner'] = { permissions = {'*'} }
  end
  if not ranksData.assignments[Config.defaultAdmin] then
    ranksData.assignments[Config.defaultAdmin] = 'owner'
  end
  saveRanks()
else
  print("[StaffPortal] Warning: Config.defaultAdmin not set. Set it in config.lua to enable default admin features.")
end

-- NUI / client integration
RegisterServerEvent('staffportal:requestData')
AddEventHandler('staffportal:requestData', function()
  local src = source
  loadRanks()
  local isAdmin = isAdminSource(src)
  TriggerClientEvent('staffportal:receiveData', src, ranksData.ranks, ranksData.assignments, isAdmin, getAvailablePermissions())
end)

RegisterServerEvent('staffportal:createRank')
AddEventHandler('staffportal:createRank', function(name, perms)
  local src = source
  if not isAdminSource(src) then return end
  local permissions = {}
  if type(perms) == 'string' then
    for p in string.gmatch(perms, '([^,]+)') do table.insert(permissions, p) end
  elseif type(perms) == 'table' then
    permissions = perms
  end
  createRank(name, permissions)
  loadRanks()
  TriggerClientEvent('staffportal:receiveData', src, ranksData.ranks, ranksData.assignments, true, getAvailablePermissions())
end)

RegisterServerEvent('staffportal:assignRank')
AddEventHandler('staffportal:assignRank', function(identifier, rank)
  local src = source
  if not isAdminSource(src) then return end
  local id = resolveIdentifier(identifier) or identifier
  if not ranksData.ranks[rank] then return end
  setRank(id, rank)
  loadRanks()
  TriggerClientEvent('staffportal:receiveData', src, ranksData.ranks, ranksData.assignments, true, getAvailablePermissions())
end)

RegisterServerEvent('staffportal:deleteRank')
AddEventHandler('staffportal:deleteRank', function(name)
  local src = source
  if not isAdminSource(src) then return end
  deleteRank(name)
  loadRanks()
  TriggerClientEvent('staffportal:receiveData', src, ranksData.ranks, ranksData.assignments, true, getAvailablePermissions())
end)
