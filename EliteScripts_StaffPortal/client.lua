local resourceName = GetCurrentResourceName()
local isOpen = false
local openMode = 'ticket'

local function setNui(open, mode)
  isOpen = open
  if open and mode then
    openMode = mode
  end
  SetNuiFocus(open, open)
  SendNUIMessage({ action = open and 'open' or 'close', mode = openMode })
  if open and openMode == 'staff' then
    TriggerServerEvent('staffportal:requestData')
    TriggerServerEvent('support:requestPortalTickets')
  end
end

RegisterCommand('openSupportTicket', function()
  setNui(true, 'ticket')
end, false)

RegisterKeyMapping('openSupportTicket', 'Open Support Ticket', 'keyboard', 'F5')

RegisterCommand('openStaffPortal', function()
  setNui(true, 'staff')
end, false)

RegisterKeyMapping('openStaffPortal', 'Open Staff Portal', 'keyboard', 'F1')

RegisterCommand('cancelSupportTicket', function()
  TriggerServerEvent('support:cancelTicket')
end, false)

RegisterKeyMapping('cancelSupportTicket', 'Cancel Support Ticket', 'keyboard', 'F7')

RegisterNUICallback('close', function(data, cb)
  setNui(false)
  cb({ ok = true })
end)

RegisterNUICallback('createSupportTicket', function(data, cb)
  TriggerServerEvent('support:createTicket', data.description, data.category)
  cb({ ok = true })
end)

RegisterNUICallback('createRank', function(data, cb)
  -- data: { name: string, permissions: string (comma-separated) }
  TriggerServerEvent('staffportal:createRank', data.name, data.permissions)
  cb({ ok = true })
end)

RegisterNUICallback('assignRank', function(data, cb)
  -- data: { identifier: string, rank: string }
  TriggerServerEvent('staffportal:assignRank', data.identifier, data.rank)
  cb({ ok = true })
end)

RegisterNUICallback('deleteRank', function(data, cb)
  TriggerServerEvent('staffportal:deleteRank', data.name)
  cb({ ok = true })
end)

RegisterNetEvent('support:ticketCreated')
AddEventHandler('support:ticketCreated', function(ticket)
  SendNUIMessage({ action = 'showPopup', ticket = ticket, cancelled = false })
  setNui(false)
end)

RegisterNetEvent('support:ticketCancelled')
AddEventHandler('support:ticketCancelled', function(ticket)
  SendNUIMessage({ action = 'showPopup', ticket = ticket, cancelled = true })
end)

RegisterNetEvent('support:ticketCreateFailed')
AddEventHandler('support:ticketCreateFailed', function(reason)
  SendNUIMessage({ action = 'showFailure', reason = reason })
end)

RegisterNetEvent('support:ticketCancelFailed')
AddEventHandler('support:ticketCancelFailed', function(reason)
  SendNUIMessage({ action = 'showFailure', reason = reason })
end)

-- Receive data from server
RegisterNetEvent('staffportal:receiveData')
AddEventHandler('staffportal:receiveData', function(ranks, assignments, isAdmin, permissions)
  SendNUIMessage({ action = 'update', ranks = ranks, assignments = assignments, isAdmin = isAdmin, permissions = permissions })
end)

RegisterNetEvent('support:receivePortalTickets')
AddEventHandler('support:receivePortalTickets', function(tickets, categories, canViewAll)
  SendNUIMessage({ action = 'updateTickets', tickets = tickets, categories = categories, canViewAll = canViewAll })
end)

-- Close UI on resource stop
AddEventHandler('onResourceStop', function(name)
  if name == resourceName then
    if isOpen then
      setNui(false)
    end
  end
end)
