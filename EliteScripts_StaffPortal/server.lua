local resource = GetCurrentResourceName()
local dataFile = Config.dataFile or "data/ranks.json"
local ticketFile = Config.ticketDataFile or "data/tickets.json"
local ticketCategories = Config.ticketCategories or {
  admin = { label = "Admin Tickets", permission = "support.admin", team = "Team" },
  legal = { label = "Legal Tickets", permission = "support.legal", team = "Legal Team" },
  gangs = { label = "Gangs Tickets", permission = "support.gangs", team = "Gangs Team" },
  sales = { label = "Sales Tickets", permission = "support.sales", team = "Sales Team" },
  pier = { label = "Pier Team Tickets", permission = "support.pier", team = "Pier Team" },
}

local ranksData = {
  ranks = {},
  assignments = {}
}

local ticketsData = {
  tickets = {},
  nextId = 1
}

local activeTicketByIdentifier = {}

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

local function loadTickets()
  local raw = LoadResourceFile(resource, ticketFile)
  if not raw or raw == '' then
    ticketsData = { tickets = {}, nextId = 1 }
    activeTicketByIdentifier = {}
    return
  end
  local ok, parsed = pcall(function() return json.decode(raw) end)
  if ok and type(parsed) == 'table' and type(parsed.tickets) == 'table' then
    ticketsData = parsed
    if type(ticketsData.nextId) ~= 'number' then ticketsData.nextId = #ticketsData.tickets + 1 end
  else
    ticketsData = { tickets = {}, nextId = 1 }
  end
  activeTicketByIdentifier = {}
  for _, ticket in ipairs(ticketsData.tickets) do
    if ticket.status == 'open' and ticket.identifier then
      activeTicketByIdentifier[ticket.identifier] = ticket.id
    end
  end
end

local function saveTickets()
  SaveResourceFile(resource, ticketFile, json.encode(ticketsData), -1)
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

local function getPlayerPrimaryIdentifier(src)
  if not src then return nil end
  local ids = GetPlayerIdentifiers(src)
  return ids and ids[1] or tostring(src)
end

local function getCategory(categoryId)
  if not categoryId then return nil end
  return ticketCategories[categoryId]
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

local function isSupportAdmin(identifier)
  if not identifier then return false end
  local rank = getRank(identifier)
  if rank == 'ADM' then
    return true
  end
  return hasPermission(identifier, 'support.viewall') or hasPermission(identifier, 'support.*') or hasPermission(identifier, '*')
end

local function canViewTickets(identifier)
  if not identifier then return false end
  if isSupportAdmin(identifier) then return true end
  for _, category in pairs(ticketCategories) do
    if hasPermission(identifier, category.permission) then
      return true
    end
  end
  return false
end

local function hasTicketPermission(identifier, categoryId)
  if not identifier or not categoryId then return false end
  if isSupportAdmin(identifier) then return true end
  local category = getCategory(categoryId)
  if not category then return false end
  return hasPermission(identifier, category.permission)
end

local function getTicketsForViewer(identifier)
  local out = {}
  if not identifier then return out end
  for _, ticket in ipairs(ticketsData.tickets) do
    if ticket.status == 'open' or ticket.status == 'cancelled' then
      if hasTicketPermission(identifier, ticket.category) then
        table.insert(out, ticket)
      end
    end
  end
  return out
end

local function createTicket(src, description, categoryId)
  local identifier = getPlayerPrimaryIdentifier(src)
  if not identifier then return nil, "invalid_identifier" end
  if activeTicketByIdentifier[identifier] then
    return nil, "already_has_ticket"
  end
  local category = getCategory(categoryId)
  if not category then
    return nil, "invalid_category"
  end
  local ticket = {
    id = ticketsData.nextId,
    source = src,
    identifier = identifier,
    category = categoryId,
    description = description,
    status = "open",
    createdAt = os.time(),
  }
  ticketsData.nextId = ticketsData.nextId + 1
  table.insert(ticketsData.tickets, ticket)
  activeTicketByIdentifier[identifier] = ticket.id
  saveTickets()
  return ticket
end

local function cancelTicket(src)
  local identifier = getPlayerPrimaryIdentifier(src)
  if not identifier then return nil, "invalid_identifier" end
  local ticketId = activeTicketByIdentifier[identifier]
  if not ticketId then
    return nil, "no_active_ticket"
  end
  for _, ticket in ipairs(ticketsData.tickets) do
    if ticket.id == ticketId then
      ticket.status = "cancelled"
      ticket.cancelledAt = os.time()
      activeTicketByIdentifier[identifier] = nil
      saveTickets()
      return ticket
    end
  end
  return nil, "ticket_not_found"
end

local function pushStaffUpdates()
  for _, playerSrc in ipairs(GetPlayers()) do
    local target = tonumber(playerSrc)
    if target then
      local identifier = getPlayerPrimaryIdentifier(target)
      if identifier and canViewTickets(identifier) then
        TriggerClientEvent('support:receivePortalTickets', target, getTicketsForViewer(identifier), ticketCategories, isSupportAdmin(identifier))
      end
    end
  end
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
loadTickets()

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

-- register internal support ticket permissions so they appear in the portal
registerPermissions(resource, {
  'support.admin',
  'support.legal',
  'support.gangs',
  'support.sales',
  'support.pier',
  'support.viewall',
  'support.*',
})

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

RegisterServerEvent('support:createTicket')
AddEventHandler('support:createTicket', function(description, categoryId)
  local src = source
  description = tostring(description or '')
  categoryId = tostring(categoryId or '')
  if description == '' or categoryId == '' then
    TriggerClientEvent('support:ticketCreateFailed', src, 'invalid_input')
    return
  end
  local ticket, err = createTicket(src, description, categoryId)
  if not ticket then
    TriggerClientEvent('support:ticketCreateFailed', src, err)
    return
  end
  TriggerClientEvent('support:ticketCreated', src, ticket)
  pushStaffUpdates()
end)

RegisterServerEvent('support:cancelTicket')
AddEventHandler('support:cancelTicket', function()
  local src = source
  local ticket, err = cancelTicket(src)
  if not ticket then
    TriggerClientEvent('support:ticketCancelFailed', src, err)
    return
  end
  TriggerClientEvent('support:ticketCancelled', src, ticket)
  pushStaffUpdates()
end)

RegisterServerEvent('support:requestPortalTickets')
AddEventHandler('support:requestPortalTickets', function()
  local src = source
  local identifier = getPlayerPrimaryIdentifier(src)
  if not identifier then return end
  TriggerClientEvent('support:receivePortalTickets', src, getTicketsForViewer(identifier), ticketCategories, isSupportAdmin(identifier))
end)
