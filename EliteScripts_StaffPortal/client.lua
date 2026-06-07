local resourceName = GetCurrentResourceName()
local isOpen = false

local function setNui(open)
  isOpen = open
  SetNuiFocus(open, open)
  SendNUIMessage({ action = open and 'open' or 'close' })
  if open then
    TriggerServerEvent('staffportal:requestData')
  end
end

RegisterCommand('openstaffportal', function()
  setNui(true)
end, false)

RegisterKeyMapping('openstaffportal', 'Open Staff Portal', 'keyboard', 'F1')

RegisterNUICallback('close', function(data, cb)
  setNui(false)
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

-- Receive data from server
RegisterNetEvent('staffportal:receiveData')
AddEventHandler('staffportal:receiveData', function(ranks, assignments, isAdmin, permissions)
  SendNUIMessage({ action = 'update', ranks = ranks, assignments = assignments, isAdmin = isAdmin, permissions = permissions })
end)

-- Close UI on resource stop
AddEventHandler(('onResourceStop'), function(name)
  if name == resourceName then
    if isOpen then
      setNui(false)
    end
  end
end)
