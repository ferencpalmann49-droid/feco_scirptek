local ESX
local PlayerData = {}

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj)
            ESX = obj
        end)
        Citizen.Wait(100)
    end
    PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    if PlayerData then
        PlayerData.job = job
    end
end)

local function isAuthorized()
    if not PlayerData or not PlayerData.job then return false end
    return PlayerData.job.name == Config.GovernmentJob.name and PlayerData.job.grade >= Config.GovernmentJob.minimumGrade
end

RegisterCommand('opengov', function()
    if not isAuthorized() then
        if ESX then
            ESX.ShowNotification('Nincs jogosultságod a panel megnyitásához.')
        end
        return
    end

    TriggerServerEvent('feco_govpanel:requestOpen')
end)

RegisterKeyMapping('opengov', 'Kormány panel megnyitása', 'keyboard', 'F9')

local panelOpen = false

RegisterNetEvent('feco_govpanel:openPanel', function(data)
    if not data then return end
    SetNuiFocus(true, true)
    panelOpen = true
    SendNUIMessage({
        type = 'open',
        payload = data
    })
end)

RegisterNetEvent('feco_govpanel:updatePanel', function(data)
    if not panelOpen then return end
    SendNUIMessage({
        type = 'refresh',
        payload = data
    })
end)

RegisterNUICallback('close', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('updateSalary', function(data, cb)
    TriggerServerEvent('feco_govpanel:updateSalary', data.jobName, data.grade, data.salary)
    cb('ok')
end)

RegisterNUICallback('updateStorePrice', function(data, cb)
    TriggerServerEvent('feco_govpanel:updateStorePrice', data.category, data.multiplier)
    cb('ok')
end)

RegisterNUICallback('updateAllocation', function(data, cb)
    TriggerServerEvent('feco_govpanel:updateAllocation', data.jobName, data.amount)
    cb('ok')
end)

RegisterNUICallback('updateTax', function(data, cb)
    TriggerServerEvent('feco_govpanel:updateTax', data.amount, data.interval)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if panelOpen then
        SetNuiFocus(false, false)
    end
end)
