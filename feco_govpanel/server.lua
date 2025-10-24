local Config = Config

local ESX
TriggerEvent('esx:getSharedObject', function(obj)
    ESX = obj
end)

local DATA_FILE = 'data/state.json'
local SharedState = {
    salaries = {},
    storePrices = {},
    allocations = {},
    tax = {}
}

local function getOnlinePlayers()
    if ESX and ESX.GetExtendedPlayers then
        return ESX.GetExtendedPlayers()
    end

    if ESX and ESX.GetPlayers then
        local result = {}
        for _, playerId in ipairs(ESX.GetPlayers()) do
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                result[#result + 1] = xPlayer
            end
        end
        return result
    end

    return {}
end

local function ensureDefaults()
    SharedState.salaries = SharedState.salaries or {}
    for jobName, jobData in pairs(Config.PayManagedJobs) do
        SharedState.salaries[jobName] = SharedState.salaries[jobName] or {}
        for _, gradeData in ipairs(jobData.grades) do
            local gradeKey = tostring(gradeData.grade)
            if SharedState.salaries[jobName][gradeKey] == nil then
                SharedState.salaries[jobName][gradeKey] = gradeData.salary
            end
        end
    end

    SharedState.storePrices = SharedState.storePrices or {}
    for category, data in pairs(Config.StoreCategories) do
        if SharedState.storePrices[category] == nil then
            SharedState.storePrices[category] = data.multiplier or 1.0
        end
    end

    SharedState.allocations = SharedState.allocations or {}
    for jobName, allocation in pairs(Config.DailyAllocations) do
        if SharedState.allocations[jobName] == nil then
            SharedState.allocations[jobName] = allocation.amount
        end
    end

    SharedState.tax = SharedState.tax or {}
    SharedState.tax.amount = SharedState.tax.amount or Config.DefaultTax.amount
    SharedState.tax.interval = SharedState.tax.interval or Config.DefaultTax.intervalMinutes
end

local function loadState()
    local raw = LoadResourceFile(GetCurrentResourceName(), DATA_FILE)
    if raw then
        local decoded = json.decode(raw)
        if type(decoded) == 'table' then
            SharedState = decoded
        end
    end
    ensureDefaults()
end

local function saveState()
    ensureDefaults()
    local encoded = json.encode(SharedState)
    SaveResourceFile(GetCurrentResourceName(), DATA_FILE, encoded or '{}', -1)
end

local function getPanelData()
    return {
        salaries = SharedState.salaries,
        storePrices = SharedState.storePrices,
        allocations = SharedState.allocations,
        tax = SharedState.tax,
        config = {
            payManagedJobs = Config.PayManagedJobs,
            storeCategories = Config.StoreCategories,
            allocations = Config.DailyAllocations,
            salaryLimits = Config.SalaryLimits,
            defaultTax = Config.DefaultTax
        }
    }
end

local function isAuthorized(xPlayer)
    if not xPlayer then return false end
    local job = xPlayer.job
    if not job or job.name ~= Config.GovernmentJob.name then
        return false
    end
    return job.grade >= Config.GovernmentJob.minimumGrade
end

local function updateJobSalary(jobName, grade, salary)
    if MySQL and MySQL.update then
        MySQL.update('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', { salary, jobName, grade }, function(rowsChanged)
            if rowsChanged == 0 then
                print(('[feco_govpanel] Nem talált job_grades sor: %s %s'):format(jobName, grade))
            end
        end)
    elseif exports and exports.oxmysql and exports.oxmysql.update then
        exports.oxmysql:update('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', { salary, jobName, grade }, function(rowsChanged)
            if rowsChanged == 0 then
                print(('[feco_govpanel] Nem talált job_grades sor: %s %s'):format(jobName, grade))
            end
        end)
    else
        print('[feco_govpanel] Figyelem: nem található adatbázis modul (mysql-async vagy oxmysql). A fizetés változás csak memóriában történt meg.')
    end

    if ESX then
        if ESX.RefreshJobs then
            ESX.RefreshJobs()
        else
            TriggerEvent('esx:refreshJobs')
        end
    end
end

local function distributeAllocations()
    if not ESX then return end

    TriggerEvent('esx_addonaccount:getSharedAccount', Config.GovernmentJob.society, function(governmentAccount)
        if not governmentAccount then
            print('[feco_govpanel] Nem található government society számla.')
            return
        end

        for jobName, amount in pairs(SharedState.allocations) do
            local allocation = tonumber(amount)
            if allocation and allocation > 0 then
                TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. jobName, function(targetAccount)
                    if not targetAccount then
                        print(('[feco_govpanel] Nem található society számla: %s'):format(jobName))
                        return
                    end

                    if governmentAccount.money < allocation then
                        print(('[feco_govpanel] Nincs elegendő fedezet a government számlán (%s szükséges, %s elérhető).'):format(allocation, governmentAccount.money))
                        return
                    end

                    governmentAccount.removeMoney(allocation)
                    targetAccount.addMoney(allocation)
                end)
            end
        end
    end)
end

local function chargeTaxes()
    if not ESX then return end
    local invoiceAmount = tonumber(SharedState.tax.amount) or Config.DefaultTax.amount
    local society = Config.GovernmentJob.society

    local players = getOnlinePlayers()
    for _, xPlayer in pairs(players) do
        TriggerEvent('esx_billing:sendBill', xPlayer.source, society, Config.DefaultTax.label, invoiceAmount)
        TriggerClientEvent('esx:showNotification', xPlayer.source, ('%s számla érkezett: $%s'):format(Config.DefaultTax.label, invoiceAmount))
    end
end

local function startTimers()
    Citizen.CreateThread(function()
        while true do
            local interval = (tonumber(SharedState.tax.interval) or Config.DefaultTax.intervalMinutes) * 60000
            if interval < 60000 then
                interval = 60000
            end
            Citizen.Wait(interval)
            chargeTaxes()
        end
    end)

    Citizen.CreateThread(function()
        while true do
            local interval = (Config.AllocationIntervalMinutes or 1440) * 60000
            Citizen.Wait(interval)
            distributeAllocations()
        end
    end)
end

local function sendStateToPlayer(src, refresh)
    if refresh then
        TriggerClientEvent('feco_govpanel:updatePanel', src, getPanelData())
    else
        TriggerClientEvent('feco_govpanel:openPanel', src, getPanelData())
    end
end

RegisterNetEvent('feco_govpanel:requestOpen', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isAuthorized(xPlayer) then
        TriggerClientEvent('esx:showNotification', src, 'Nincs jogosultságod a panel megnyitásához.')
        return
    end
    sendStateToPlayer(src)
end)

RegisterNetEvent('feco_govpanel:updateSalary', function(jobName, grade, salary)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isAuthorized(xPlayer) then return end

    grade = tonumber(grade)
    salary = tonumber(salary)

    if not Config.PayManagedJobs[jobName] or not grade or not salary then
        return
    end

    if salary < Config.SalaryLimits.minimum or salary > Config.SalaryLimits.maximum then
        TriggerClientEvent('esx:showNotification', src, ('Fizetés csak %s és %s között állítható.'):format(Config.SalaryLimits.minimum, Config.SalaryLimits.maximum))
        return
    end

    SharedState.salaries[jobName][tostring(grade)] = salary
    saveState()
    updateJobSalary(jobName, grade, salary)

    TriggerClientEvent('esx:showNotification', src, ('%s %s fizetése beállítva: $%s'):format(Config.PayManagedJobs[jobName].label, grade, salary))
    sendStateToPlayer(src, true)
end)

RegisterNetEvent('feco_govpanel:updateStorePrice', function(category, multiplier)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isAuthorized(xPlayer) then return end

    if not Config.StoreCategories[category] then return end
    multiplier = tonumber(multiplier)
    if not multiplier then return end

    local limits = Config.StoreCategories[category]
    if multiplier < limits.minimum or multiplier > limits.maximum then
        TriggerClientEvent('esx:showNotification', src, ('Érték csak %.2f és %.2f között lehet.'):format(limits.minimum, limits.maximum))
        return
    end

    SharedState.storePrices[category] = multiplier
    saveState()

    TriggerClientEvent('esx:showNotification', src, ("%s új szorzója: %.2f"):format(limits.label, multiplier))
    sendStateToPlayer(src, true)
end)

RegisterNetEvent('feco_govpanel:updateAllocation', function(jobName, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isAuthorized(xPlayer) then return end

    if not Config.DailyAllocations[jobName] then return end
    amount = tonumber(amount)
    if not amount or amount < 0 then return end

    SharedState.allocations[jobName] = amount
    saveState()

    TriggerClientEvent('esx:showNotification', src, ('%s napi keret beállítva: $%s'):format(Config.DailyAllocations[jobName].label, amount))
    sendStateToPlayer(src, true)
end)

RegisterNetEvent('feco_govpanel:updateTax', function(amount, interval)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not isAuthorized(xPlayer) then return end

    amount = tonumber(amount)
    interval = tonumber(interval)
    if not amount or not interval then return end
    if amount < 0 then amount = 0 end
    if interval < 1 then interval = 1 end

    SharedState.tax.amount = amount
    SharedState.tax.interval = interval
    saveState()

    TriggerClientEvent('esx:showNotification', src, ('Adó frissítve: $%s / %s percenként'):format(amount, interval))
    sendStateToPlayer(src, true)
end)

AddEventHandler('playerConnecting', function()
    ensureDefaults()
end)

AddEventHandler('onResourceStart', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    loadState()
    startTimers()
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    saveState()
end)

exports('GetStoreMultiplier', function(category)
    return SharedState.storePrices[category]
end)

exports('GetJobSalary', function(jobName, grade)
    local job = SharedState.salaries[jobName]
    if not job then return nil end
    return job[tostring(grade)]
end)

exports('GetAllocation', function(jobName)
    return SharedState.allocations[jobName]
end)
