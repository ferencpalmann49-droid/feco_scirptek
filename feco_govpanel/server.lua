local ESX

TriggerEvent('esx:getSharedObject', function(obj)
    ESX = obj
end)

local DATA_FILE = 'data/state.json'
local SharedState = {
    salaries = {},
    storePrices = {},
    allocations = {},
    tax = {},
    storeBasePrices = {}
}

local function dbFetchAll(query, params, cb)
    if MySQL and MySQL.Async and MySQL.Async.fetchAll then
        MySQL.Async.fetchAll(query, params, function(result)
            if cb then
                cb(result or {})
            end
        end)
    elseif MySQL and MySQL.Sync and MySQL.Sync.fetchAll then
        local result = MySQL.Sync.fetchAll(query, params)
        if cb then
            cb(result or {})
        end
    else
        print(('[feco_govpanel] Figyelem: mysql-async fetch nem érhető el (%s)'):format(query))
        if cb then
            cb({})
        end
    end
end

local function dbExecute(query, params, cb)
    if MySQL and MySQL.Async and MySQL.Async.execute then
        MySQL.Async.execute(query, params, function(rowsChanged)
            if cb then
                cb(rowsChanged or 0)
            end
        end)
    elseif MySQL and MySQL.Sync and MySQL.Sync.execute then
        local rowsChanged = MySQL.Sync.execute(query, params)
        if cb then
            cb(rowsChanged or 0)
        end
    else
        print(('[feco_govpanel] Figyelem: mysql-async execute nem érhető el (%s)'):format(query))
        if cb then
            cb(0)
        end
    end
end

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
    SharedState.storeBasePrices = SharedState.storeBasePrices or {}
    for category, data in pairs(Config.StoreCategories) do
        if SharedState.storePrices[category] == nil then
            SharedState.storePrices[category] = data.multiplier or 1.0
        end
        SharedState.storeBasePrices[category] = SharedState.storeBasePrices[category] or {}
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

local function ensureStoreBasePrices(category, cb)
    local categoryConfig = Config.StoreCategories[category]
    if not categoryConfig or not categoryConfig.targets or #categoryConfig.targets == 0 then
        if cb then cb() end
        return
    end

    SharedState.storeBasePrices = SharedState.storeBasePrices or {}
    SharedState.storeBasePrices[category] = SharedState.storeBasePrices[category] or {}

    local pending = 0
    local completed = false

    local function finishIfDone()
        if pending == 0 and not completed then
            completed = true
            if cb then cb() end
        end
    end

    for index, target in ipairs(categoryConfig.targets) do
        local targetKey = tostring(index)
        SharedState.storeBasePrices[category][targetKey] = SharedState.storeBasePrices[category][targetKey] or {}

        pending = pending + 1
        dbFetchAll(target.fetch, target.fetchParams, function(rows)
            local baseMap = SharedState.storeBasePrices[category][targetKey] or {}
            local updated = false

            if rows then
                for _, row in ipairs(rows) do
                    local keyValue = row[target.keyColumn]
                    local priceValue = tonumber(row[target.priceColumn])
                    if keyValue ~= nil and priceValue then
                        local mapKey = tostring(keyValue)
                        if baseMap[mapKey] == nil then
                            baseMap[mapKey] = priceValue
                            updated = true
                        end
                    end
                end
            end

            SharedState.storeBasePrices[category][targetKey] = baseMap
            if updated then
                saveState()
            end

            pending = pending - 1
            finishIfDone()
        end)
    end

    finishIfDone()
end

local function runSequentialUpdates(entries, index, applied, cb)
    if index > #entries then
        if cb then
            cb(applied)
        end
        return
    end

    local entry = entries[index]
    dbExecute(entry.query, entry.params, function(rowsChanged)
        local nextApplied = applied
        if rowsChanged and rowsChanged > 0 then
            nextApplied = true
        end

        runSequentialUpdates(entries, index + 1, nextApplied, cb)
    end)
end

local function applyStoreMultiplier(category, cb)
    local categoryConfig = Config.StoreCategories[category]
    if not categoryConfig then
        if cb then cb(false) end
        return
    end

    ensureStoreBasePrices(category, function()
        if not categoryConfig.targets or #categoryConfig.targets == 0 then
            if cb then cb(true) end
            return
        end

        local multiplier = tonumber(SharedState.storePrices[category]) or categoryConfig.multiplier or 1.0
        if multiplier < 0 then multiplier = 0 end

        local pending = 0
        local applied = false
        local function done()
            if pending == 0 and cb then
                cb(applied)
            end
        end

        for index, target in ipairs(categoryConfig.targets) do
            local targetKey = tostring(index)
            local baseEntries = SharedState.storeBasePrices[category][targetKey]
            if baseEntries then
                local updates = {}
                for baseKey, basePrice in pairs(baseEntries) do
                    local original = tonumber(basePrice)
                    if original then
                        local newPrice = math.max(0, math.floor(original * multiplier + 0.5))
                        local params
                        if target.buildUpdateParams then
                            params = target.buildUpdateParams(newPrice, baseKey)
                        elseif target.updateParams then
                            params = target.updateParams(newPrice, baseKey)
                        else
                            params = { newPrice, baseKey }
                        end

                        updates[#updates + 1] = {
                            query = target.update,
                            params = params
                        }
                    end
                end

                if #updates > 0 then
                    pending = pending + 1
                    runSequentialUpdates(updates, 1, false, function(batchApplied)
                        if batchApplied then
                            applied = true
                        end
                        pending = pending - 1
                        done()
                    end)
                end
            end
        end

        if pending == 0 then
            done()
        end
    end)
end

local function refreshAllStoreMultipliers()
    for category in pairs(Config.StoreCategories) do
        applyStoreMultiplier(category)
    end
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
    local query = 'UPDATE job_grades SET salary = @salary WHERE job_name = @job_name AND grade = @grade'
    local params = {
        ['@salary'] = salary,
        ['@job_name'] = jobName,
        ['@grade'] = grade
    }

    dbExecute(query, params, function(rowsChanged)
        if (rowsChanged or 0) == 0 then
            print(('[feco_govpanel] Nem talált job_grades sor: %s %s'):format(jobName, grade))
        end
    end)

    if ESX then
        if ESX.RefreshJobs then
            ESX.RefreshJobs()
        else
            TriggerEvent('esx:refreshJobs')
        end
    end
end

local function issueTaxInvoice(xPlayer, amount)
    if not xPlayer then return end

    local playerSource = xPlayer.source
    if not playerSource then return end

    local invoiceAmount = tonumber(amount) or 0
    if ESX and ESX.Math and ESX.Math.Round then
        invoiceAmount = ESX.Math.Round(invoiceAmount)
    else
        invoiceAmount = math.floor(invoiceAmount + 0.5)
    end

    local label = Config.DefaultTax.label

    if xPlayer.identifier then
        dbExecute('DELETE FROM billing WHERE identifier = @identifier AND label = @label', {
            ['@identifier'] = xPlayer.identifier,
            ['@label'] = label
        })
    end

    TriggerEvent('esx_billing:sendBill', playerSource, Config.GovernmentJob.society, label, invoiceAmount)
    TriggerClientEvent('esx:showNotification', playerSource, ('%s számla érkezett: $%s'):format(label, invoiceAmount))
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

    for _, xPlayer in pairs(getOnlinePlayers()) do
        issueTaxInvoice(xPlayer, invoiceAmount)
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

    applyStoreMultiplier(category, function(applied)
        if applied then
            TriggerClientEvent('esx:showNotification', src, ("%s új szorzója: %.2f"):format(limits.label, multiplier))
        else
            TriggerClientEvent('esx:showNotification', src, string.format('%s szorzó frissítve (adatbázis változás nem szükséges vagy sikertelen).', limits.label))
        end
        sendStateToPlayer(src, true)
    end)
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
    refreshAllStoreMultipliers()
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
