-- Main server logic for ez_money

-- Helper function to format numbers with commas
local function formatMoney(amount)
    if not amount then return "0" end
    local formatted = tostring(amount)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

-- Initialize database for money logging
if Config.Database.enabled then
    CreateTable()
end

-- Function to schedule daily leaderboard
local function ScheduleDailyLeaderboard()
    CreateThread(function()
        while true do
            local currentTime = os.date('%H:%M')
            if currentTime == Config.Leaderboard.sendTime then
                exports.ez_money:SendDailyLeaderboard()
                -- Wait 61 seconds to avoid sending multiple times in the same minute
                Wait(61000)
            end
            Wait(30000) -- Check every 30 seconds
        end
    end)
end

-- Function to clean up old logs periodically
local function ScheduleLogCleanup()
    if not Config.Database.enabled then return end
    CreateThread(function()
        while true do
            exports.ez_money:CleanupOldLogs()
            Wait(24 * 60 * 60 * 1000) -- Run once per day
        end
    end)
end

-- Start scheduled tasks
ScheduleDailyLeaderboard()
ScheduleLogCleanup()

-- Hook into QBox money functions for comprehensive logging
CreateThread(function()
    Wait(1000) -- Wait for QBox to fully load
    
    -- Try to hook into QBox Player functions
    local success, QBX = pcall(function()
        return exports.qbx_core
    end)
    
    if success and QBX then
        print('[ez_money] QBox detected - Using event-based money detection for compatibility')
        -- Note: Cannot directly modify QBX export functions due to export restrictions
        -- Money changes will be detected via events and universal detector instead
    else
        print('[ez_money] Warning: Could not hook into QBox money functions - using event-based logging only')
    end
end)

-- Universal money change detector - monitors all players every few seconds
CreateThread(function()
    local lastMoneyData = {}
    
    while true do
        Wait(5000) -- Check every 5 seconds
        
        if Config.MoneyLogging.enabled and Config.MoneyLogging.useUniversalDetector then
            for _, playerId in ipairs(GetPlayers()) do
                local success, playerData = pcall(function()
                    return exports.qbx_core:GetPlayer(tonumber(playerId))
                end)
                
                if success and playerData then
                    local citizenid = playerData.PlayerData.citizenid
                    local currentMoney = playerData.PlayerData.money
                    
                    -- Initialize player money data if not exists
                    if not lastMoneyData[citizenid] then
                        lastMoneyData[citizenid] = {
                            cash = currentMoney.cash or 0,
                            bank = currentMoney.bank or 0,
                            crypto = currentMoney.crypto or 0
                        }
                    else
                        -- Check for money changes
                        for moneyType, currentAmount in pairs(currentMoney) do
                            local lastAmount = lastMoneyData[citizenid][moneyType] or 0
                            local difference = currentAmount - lastAmount
                            
                            if math.abs(difference) >= Config.MoneyLogging.minAmount then
                                -- Money changed, log it
                                exports.ez_money:LogMoneyToDiscord(tonumber(playerId), moneyType, 
                                    difference > 0 and 'detected_add' or 'detected_remove', 
                                    difference, lastAmount, currentAmount, 
                                    'Universal Detector - Money Change')
                                
                                if Config.Database.enabled then
                                    exports.ez_money:LogMoneyChange(
                                        citizenid,
                                        string.format('%s %s', playerData.PlayerData.charinfo.firstname, playerData.PlayerData.charinfo.lastname),
                                        moneyType,
                                        difference > 0 and 'detected_add' or 'detected_remove',
                                        difference,
                                        lastAmount,
                                        currentAmount,
                                        'Universal Detector - Money Change',
                                        nil
                                    )
                                end
                            end
                            
                            -- Update last known amount
                            lastMoneyData[citizenid][moneyType] = currentAmount
                        end
                    end
                end
            end
        end
    end
end)

-- Monitor for players leaving to clean up money data
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(source)
    if Config.MoneyLogging.logPlayerLeave then
        exports.ez_money:LogPlayerJoinLeave(source, 'leave')
    end
    
    -- Clean up money tracking data for disconnected player
    CreateThread(function()
        Wait(10000) -- Wait 10 seconds after disconnect
        local success, playerData = pcall(function()
            return exports.qbx_core:GetPlayer(source)
        end)
        
        if not success or not playerData then
            -- Player is truly disconnected, clean up data
            for citizenid, _ in pairs(lastMoneyData or {}) do
                local found = false
                for _, playerId in ipairs(GetPlayers()) do
                    local success2, pd = pcall(function()
                        return exports.qbx_core:GetPlayer(tonumber(playerId))
                    end)
                    
                    if success2 and pd and pd.PlayerData.citizenid == citizenid then
                        found = true
                        break
                    end
                end
                
                if not found then
                    lastMoneyData[citizenid] = nil
                end
            end
        end
    end)
end)

-- Event handlers for QBox money changes
RegisterNetEvent('QBCore:Server:MoneyChange', function(source, moneyType, amount, action, reason)
    if not Config.MoneyLogging.enabled then return end
    
    -- Check if we should log this money type
    if (moneyType == 'cash' and not Config.MoneyLogging.logCash) or
       (moneyType == 'bank' and not Config.MoneyLogging.logBank) or
       (moneyType == 'crypto' and not Config.MoneyLogging.logCrypto) then
        return
    end
    
    -- Check minimum amount
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    -- Try to get player data safely
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    local oldAmount = playerData.PlayerData.money[moneyType] - amount
    local newAmount = playerData.PlayerData.money[moneyType]
    
    -- Log to database
    if Config.Database.enabled then
        exports.ez_money:LogMoneyChange(
            playerData.PlayerData.citizenid,
            ('%s %s'):format(playerData.PlayerData.charinfo.firstname, playerData.PlayerData.charinfo.lastname),
            moneyType,
            action,
            amount,
            oldAmount,
            newAmount,
            reason,
            nil
        )
    end
    
    -- Log to Discord
    exports.ez_money:LogMoneyToDiscord(source, moneyType, action, amount, oldAmount, newAmount, reason)
end)

-- Hook into QBox player loading
RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    if Config.MoneyLogging.logPlayerJoin then
        exports.ez_money:LogPlayerJoinLeave(Player.PlayerData.source, 'join')
    end
end)

-- Hook into QBox player unloading  
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(source)
    if Config.MoneyLogging.logPlayerLeave then
        exports.ez_money:LogPlayerJoinLeave(source, 'leave')
    end
end)

-- Hook into inventory cash item changes
RegisterNetEvent('inventory:server:SetInventoryData', function(source, items)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logCash or not Config.MoneyLogging.logInventoryItems then return end
    
    -- Get player data safely
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    -- Check for cash items in inventory
    for slot, item in pairs(items or {}) do
        if item.name == 'cash' or item.name == 'money' then
            local amount = item.amount or item.count or 0
            if amount >= Config.MoneyLogging.minAmount then
                exports.ez_money:LogInventoryMoneyChange(source, 'inventory', 'cash', amount, 'inventory_update')
            end
        end
    end
end)

-- Hook into stash cash item changes
RegisterNetEvent('inventory:server:SaveStashItems', function(stashId, items)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logCash or not Config.MoneyLogging.logStashItems then return end
    
    -- Check for cash items in stash
    for slot, item in pairs(items or {}) do
        if item.name == 'cash' or item.name == 'money' then
            local amount = item.amount or item.count or 0
            if amount >= Config.MoneyLogging.minAmount then
                -- Try to find which player is accessing this stash
                for _, playerId in ipairs(GetPlayers()) do
                    local success, playerData = pcall(function()
                        return exports.qbx_core:GetPlayer(tonumber(playerId))
                    end)
                    
                    if success and playerData then
                        exports.ez_money:LogInventoryMoneyChange(tonumber(playerId), 'stash', 'cash', amount, 'stash_update', stashId)
                        break -- Only log for the first player found (could be improved)
                    end
                end
            end
        end
    end
end)

-- Hook into item giving/removing
RegisterNetEvent('QBCore:Server:GiveItem', function(source, item, amount, slot, info)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logCash or not Config.MoneyLogging.logAdminGiveItems then return end
    
    if item == 'cash' or item == 'money' then
        local itemAmount = amount or 1
        if itemAmount >= Config.MoneyLogging.minAmount then
            exports.ez_money:LogInventoryMoneyChange(source, 'give', 'cash', itemAmount, 'admin_give_item')
        end
    end
end)

RegisterNetEvent('QBCore:Server:RemoveItem', function(source, item, amount, slot)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logCash or not Config.MoneyLogging.logAdminGiveItems then return end
    
    if item == 'cash' or item == 'money' then
        local itemAmount = amount or 1
        if itemAmount >= Config.MoneyLogging.minAmount then
            exports.ez_money:LogInventoryMoneyChange(source, 'remove', 'cash', -itemAmount, 'admin_remove_item')
        end
    end
end)

-- Hook into Renewed-Banking events
RegisterNetEvent('Renewed-Banking:server:transfer', function(data)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logBank or not Config.MoneyLogging.logBankTransfers then return end
    
    local source = source
    local amount = data.amount or 0
    local targetAccount = data.toAccount or data.target
    local memo = data.memo or data.reason or 'Bank Transfer'
    
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    -- Get source player data
    local success, sourcePlayer = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not sourcePlayer then return end
    
    -- Try to find target player by account number or ID
    local targetPlayerId = nil
    for _, playerId in ipairs(GetPlayers()) do
        local success2, targetPlayer = pcall(function()
            return exports.qbx_core:GetPlayer(tonumber(playerId))
        end)
        
        if success2 and targetPlayer then
            local accountNumber = targetPlayer.PlayerData.charinfo.account or targetPlayer.PlayerData.citizenid
            if accountNumber == targetAccount or tonumber(playerId) == tonumber(targetAccount) then
                targetPlayerId = tonumber(playerId)
                break
            end
        end
    end
    
    -- Log for sender (money removed)
    exports.ez_money:LogBankTransfer(source, 'send', amount, sourcePlayer.PlayerData.money.bank, memo, targetPlayerId)
    
    -- Log for receiver if found online
    if targetPlayerId then
        local success3, targetPlayer = pcall(function()
            return exports.qbx_core:GetPlayer(targetPlayerId)
        end)
        
        if success3 and targetPlayer then
            exports.ez_money:LogBankTransfer(targetPlayerId, 'receive', amount, targetPlayer.PlayerData.money.bank, memo, source)
        end
    end
end)

-- Hook into Renewed-Banking ATM transactions
RegisterNetEvent('Renewed-Banking:server:deposit', function(data)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logBank or not Config.MoneyLogging.logATMTransactions then return end
    
    local source = source
    local amount = data.amount or 0
    
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogBankTransfer(source, 'deposit', amount, playerData.PlayerData.money.bank, 'ATM Deposit', nil)
end)

RegisterNetEvent('Renewed-Banking:server:withdraw', function(data)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logBank or not Config.MoneyLogging.logATMTransactions then return end
    
    local source = source
    local amount = data.amount or 0
    
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogBankTransfer(source, 'withdraw', amount, playerData.PlayerData.money.bank, 'ATM Withdrawal', nil)
end)

-- Hook into Renewed-Banking account creation
RegisterNetEvent('Renewed-Banking:server:createAccount', function(data)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logBank or not Config.MoneyLogging.logAccountCreation then return end
    
    local source = source
    local accountType = data.type or 'personal'
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogBankTransfer(source, 'account_created', 0, 0, string.format('Created %s account', accountType), nil)
end)

-- Hook into Renewed-Banking loan payments
RegisterNetEvent('Renewed-Banking:server:payLoan', function(data)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logBank or not Config.MoneyLogging.logLoanPayments then return end
    
    local source = source
    local amount = data.amount or 0
    
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogBankTransfer(source, 'loan_payment', amount, playerData.PlayerData.money.bank, 'Loan Payment', nil)
end)

-- Hook into additional QBox money events for complete coverage
RegisterNetEvent('qbx_core:server:addMoney', function(playerId, moneyType, amount, reason)
    if not Config.MoneyLogging.enabled then return end
    
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(playerId)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogMoneyToDiscord(playerId, moneyType, 'add', amount, 
        playerData.PlayerData.money[moneyType] - amount, 
        playerData.PlayerData.money[moneyType], 
        reason or 'Money Added')
end)

RegisterNetEvent('qbx_core:server:removeMoney', function(playerId, moneyType, amount, reason)
    if not Config.MoneyLogging.enabled then return end
    
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(playerId)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogMoneyToDiscord(playerId, moneyType, 'remove', -amount, 
        playerData.PlayerData.money[moneyType] + amount, 
        playerData.PlayerData.money[moneyType], 
        reason or 'Money Removed')
end)

-- Hook into ox_inventory events for cash items
RegisterNetEvent('ox_inventory:setPlayerInventory', function(playerId, inventory)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logInventoryItems then return end
    
    for slot, item in pairs(inventory or {}) do
        if item.name == 'money' or item.name == 'cash' or item.name == 'black_money' then
            local amount = item.count or item.amount or 0
            if amount >= Config.MoneyLogging.minAmount then
                exports.ez_money:LogInventoryMoneyChange(playerId, 'inventory', item.name, amount, 'ox_inventory_update')
            end
        end
    end
end)

-- Hook into ESX money events (in case ESX is also present)
RegisterNetEvent('esx:addAccountMoney', function(playerId, account, amount)
    if not Config.MoneyLogging.enabled then return end
    
    if account == 'money' or account == 'bank' or account == 'black_money' then
        if math.abs(amount) >= Config.MoneyLogging.minAmount then
            exports.ez_money:LogMoneyToDiscord(playerId, account, 'add', amount, 0, amount, 'ESX Account Money Added')
        end
    end
end)

RegisterNetEvent('esx:removeAccountMoney', function(playerId, account, amount)
    if not Config.MoneyLogging.enabled then return end
    
    if account == 'money' or account == 'bank' or account == 'black_money' then
        if math.abs(amount) >= Config.MoneyLogging.minAmount then
            exports.ez_money:LogMoneyToDiscord(playerId, account, 'remove', -amount, amount, 0, 'ESX Account Money Removed')
        end
    end
end)

-- Hook into job salary payments
RegisterNetEvent('qb-bossmenu:server:withdrawMoney', function(amount)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logBank then return end
    
    local source = source
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogBankTransfer(source, 'job_withdraw', amount, playerData.PlayerData.money.bank, 'Job Money Withdrawal', nil)
end)

RegisterNetEvent('qb-bossmenu:server:depositMoney', function(amount)
    if not Config.MoneyLogging.enabled or not Config.MoneyLogging.logBank then return end
    
    local source = source
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogBankTransfer(source, 'job_deposit', amount, playerData.PlayerData.money.bank, 'Job Money Deposit', nil)
end)

-- Hook into vehicle sales/purchases
RegisterNetEvent('qb-vehicleshop:server:buyVehicle', function(vehicleData, amount)
    if not Config.MoneyLogging.enabled then return end
    
    local source = source
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogMoneyToDiscord(source, 'bank', 'vehicle_purchase', -amount, 
        playerData.PlayerData.money.bank + amount, 
        playerData.PlayerData.money.bank, 
        string.format('Vehicle Purchase: %s', vehicleData.model or 'Unknown'))
end)

-- Hook into housing purchases
RegisterNetEvent('qb-houses:server:buyHouse', function(houseId, amount)
    if not Config.MoneyLogging.enabled then return end
    
    local source = source
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogMoneyToDiscord(source, 'bank', 'house_purchase', -amount, 
        playerData.PlayerData.money.bank + amount, 
        playerData.PlayerData.money.bank, 
        string.format('House Purchase: %s', houseId or 'Unknown'))
end)

-- Hook into drug sales and illegal activities
RegisterNetEvent('qb-drugs:server:sellDrugs', function(drugType, amount, price)
    if not Config.MoneyLogging.enabled then return end
    
    local source = source
    if math.abs(price) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogMoneyToDiscord(source, 'cash', 'drug_sale', price, 
        playerData.PlayerData.money.cash - price, 
        playerData.PlayerData.money.cash, 
        string.format('Drug Sale: %s x%d', drugType or 'Unknown', amount or 1))
end)

-- Hook into generic money transactions
RegisterNetEvent('QBCore:Server:AddMoney', function(source, moneyType, amount, reason)
    if not Config.MoneyLogging.enabled then return end
    
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogMoneyToDiscord(source, moneyType, 'add', amount, 
        playerData.PlayerData.money[moneyType] - amount, 
        playerData.PlayerData.money[moneyType], 
        reason or 'Money Added')
end)

RegisterNetEvent('QBCore:Server:RemoveMoney', function(source, moneyType, amount, reason)
    if not Config.MoneyLogging.enabled then return end
    
    if math.abs(amount) < Config.MoneyLogging.minAmount then return end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    
    if not success or not playerData then return end
    
    exports.ez_money:LogMoneyToDiscord(source, moneyType, 'remove', -amount, 
        playerData.PlayerData.money[moneyType] + amount, 
        playerData.PlayerData.money[moneyType], 
        reason or 'Money Removed')
end)

-- Admin command to manually send leaderboard
RegisterCommand('sendleaderboard', function(source, args, rawCommand)
    if source == 0 then return end -- Console protection
    
    print(('[ez_money] Player %d attempted to use sendleaderboard command'):format(source))
    
    -- Check if player has admin permissions (simplified check)
    local hasPermission = IsPlayerAceAllowed(source, 'command') or IsPlayerAceAllowed(source, 'admin')
    
    if not hasPermission then
        print(('[ez_money] Player %d denied access - no admin permission'):format(source))
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'System', 'You do not have permission to use this command'}
        })
        return
    end
    
    print(('[ez_money] Player %d has admin permission, sending leaderboard'):format(source))
    exports.ez_money:SendDailyLeaderboard()
    
    -- Success message removed to avoid chat spam
end, true)

-- Admin command to check player money
RegisterCommand('checkmoney', function(source, args, rawCommand)
    if source == 0 then return end -- Console protection
    
    print(('[ez_money] Player %d attempted to use checkmoney command'):format(source))
    
    -- Check if player has admin permissions (simplified check)
    local hasPermission = IsPlayerAceAllowed(source, 'command') or IsPlayerAceAllowed(source, 'admin')
    
    if not hasPermission then
        print(('[ez_money] Player %d denied access - no admin permission'):format(source))
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'System', 'You do not have permission to use this command'}
        })
        return
    end
    
    if not args[1] then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 255, 0},
            args = {'System', 'Please specify a player ID: /checkmoney [playerid]'}
        })
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'System', 'Invalid player ID'}
        })
        return
    end
    
    -- Try to get player data - using pcall to handle errors safely
    local success, targetPlayer = pcall(function()
        return exports.qbx_core:GetPlayer(targetId)
    end)
    
    if not success or not targetPlayer then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'System', 'Player not found or not online'}
        })
        return
    end
    
    -- Safely access player data
    local money = targetPlayer.PlayerData and targetPlayer.PlayerData.money or {}
    local charinfo = targetPlayer.PlayerData and targetPlayer.PlayerData.charinfo or {}
    local playerName = string.format('%s %s', 
        charinfo.firstname or 'Unknown', 
        charinfo.lastname or 'Player'
    )
    
    TriggerClientEvent('chat:addMessage', source, {
        color = {255, 255, 0},
        multiline = true,
        args = {"Money Check", string.format([[
Player: %s (ID: %d)
Cash: $%s
Bank: $%s
Total: $%s
        ]], playerName, targetId, 
        formatMoney(money.cash or 0),
        formatMoney(money.bank or 0),
        formatMoney((money.cash or 0) + (money.bank or 0)))}
    })
    
    print(('[ez_money] Money check completed for player %d'):format(targetId))
end, true)

-- Admin command to manually clean logs (simplified)
RegisterCommand('cleanlogs', function(source, args, rawCommand)
    if source == 0 then return end -- Console protection
    
    print(('[ez_money] Player %d attempted to use cleanlogs command'):format(source))
    
    -- Check if player has admin permissions (simplified check)
    local hasPermission = IsPlayerAceAllowed(source, 'command') or IsPlayerAceAllowed(source, 'admin')
    
    if not hasPermission then
        print(('[ez_money] Player %d denied access - no admin permission'):format(source))
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'System', 'You do not have permission to use this command'}
        })
        return
    end
    
    if not Config.Database.enabled then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 255, 0},
            args = {'System', 'Database logging is disabled - nothing to clean'}
        })
        return
    end
    
    -- Try to clean logs safely
    local success, result = pcall(function()
        return exports.ez_money:CleanupOldLogs()
    end)
    
    if success then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            args = {'System', 'Old logs cleaned from database successfully'}
        })
        print(('[ez_money] Log cleanup completed by player %d'):format(source))
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'System', 'Failed to clean logs - check console for errors'}
        })
        print(('[ez_money] Log cleanup failed for player %d'):format(source))
    end
end, true)

-- Test command to verify script functionality
RegisterCommand('ezmoneytest', function(source, args, rawCommand)
    if source == 0 then return end -- Console protection
    
    print(('[ez_money] Player %d requested functionality test'):format(source))
    
    TriggerClientEvent('chat:addMessage', source, {
        color = {0, 255, 255},
        multiline = true,
        args = {'EZ Money Test', string.format([[
Script Status: ACTIVE
Leaderboard: %s
Database: %s
Discord: %s

Available Commands:
- /sendleaderboard (Admin)
- /checkmoney [id] (Admin)
- /cleanlogs (Admin)
- /ezmoneytest (Anyone)

Next scheduled leaderboard: %s
        ]], 
        Config.Leaderboard.enabled and 'ENABLED' or 'DISABLED',
        Config.Database.enabled and 'ENABLED' or 'DISABLED', 
        Config.Discord.enabled and 'ENABLED' or 'DISABLED',
        Config.Leaderboard.sendTime or 'Not Set')}
    })
end, false)

print('[ez_money] Leaderboard-only system initialized successfully')

-- Export functions for other scripts to use
exports('LogMoneyToDiscord', function(player, moneyType, action, amount, oldAmount, newAmount, reason)
    -- Get player data safely
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(player)
    end)
    
    if not success or not playerData then return end
    
    local webhook = Config.Discord.webhook
    if not webhook or webhook == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
        print('[ez_money] Individual transaction webhook not configured')
        return
    end

    local playerName = string.format('%s %s', 
        playerData.PlayerData.charinfo.firstname or 'Unknown', 
        playerData.PlayerData.charinfo.lastname or 'Player'
    )
    
    local color = (amount > 0) and 65280 or 16711680 -- Green for positive, red for negative
    local actionText = (amount > 0) and "+" or ""
    
    local embed = {
        title = "💰 Money Transaction",
        color = color,
        fields = {
            {
                name = "Player",
                value = string.format("%s (ID: %d)", playerName, player),
                inline = true
            },
            {
                name = "Type",
                value = moneyType:upper(),
                inline = true
            },
            {
                name = "Action",
                value = action or "Unknown",
                inline = true
            },
            {
                name = "Amount",
                value = string.format("%s$%s", actionText, formatMoney(math.abs(amount))),
                inline = true
            },
            {
                name = "Before",
                value = string.format("$%s", formatMoney(oldAmount)),
                inline = true
            },
            {
                name = "After",
                value = string.format("$%s", formatMoney(newAmount)),
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    if reason and reason ~= "" then
        table.insert(embed.fields, {
            name = "Reason",
            value = reason,
            inline = false
        })
    end
    
    local data = {
        username = Config.Discord.botName,
        avatar_url = Config.Discord.avatar,
        embeds = {embed}
    }

    PerformHttpRequest(webhook, function(statusCode, text, headers)
        if statusCode ~= 200 and statusCode ~= 204 then
            print(('[ez_money] Discord webhook error: %d - %s'):format(statusCode, text))
        end
    end, 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json'
    })
end)

exports('LogPlayerJoinLeave', function(player, action)
    if not Config.Discord.enabled or not Config.MoneyLogging.enabled then return end
    
    -- Get player data safely
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(player)
    end)
    
    if not success or not playerData then return end
    
    local webhook = Config.Discord.webhook
    if not webhook or webhook == "YOUR_DISCORD_WEBHOOK_URL_HERE" then return end

    local playerName = string.format('%s %s', 
        playerData.PlayerData.charinfo.firstname or 'Unknown', 
        playerData.PlayerData.charinfo.lastname or 'Player'
    )
    
    local color = (action == 'join') and 65280 or 16711680 -- Green for join, red for leave
    local title = (action == 'join') and "👋 Player Joined" or "👋 Player Left"
    
    local embed = {
        title = title,
        color = color,
        fields = {
            {
                name = "Player",
                value = string.format("%s (ID: %d)", playerName, player),
                inline = true
            },
            {
                name = "Cash",
                value = string.format("$%s", formatMoney(playerData.PlayerData.money.cash or 0)),
                inline = true
            },
            {
                name = "Bank",
                value = string.format("$%s", formatMoney(playerData.PlayerData.money.bank or 0)),
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    local data = {
        username = Config.Discord.botName,
        avatar_url = Config.Discord.avatar,
        embeds = {embed}
    }

    PerformHttpRequest(webhook, function(statusCode, text, headers)
        if statusCode ~= 200 and statusCode ~= 204 then
            print(('[ez_money] Discord webhook error: %d - %s'):format(statusCode, text))
        end
    end, 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json'
    })
end)

exports('LogInventoryMoneyChange', function(player, actionType, moneyType, amount, reason, extra)
    if not Config.Discord.enabled or not Config.MoneyLogging.enabled then return end
    
    -- Get player data safely
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(player)
    end)
    
    if not success or not playerData then return end
    
    local webhook = Config.Discord.webhook
    if not webhook or webhook == "YOUR_DISCORD_WEBHOOK_URL_HERE" then return end

    local playerName = string.format('%s %s', 
        playerData.PlayerData.charinfo.firstname or 'Unknown', 
        playerData.PlayerData.charinfo.lastname or 'Player'
    )
    
    local color = (amount > 0) and 3066993 or 15158332 -- Blue for positive, orange for negative
    local actionText = (amount > 0) and "+" or ""
    
    local title = "📦 Inventory Cash Change"
    if actionType == 'stash' then
        title = "🏦 Stash Cash Change"
    elseif actionType == 'give' then
        title = "➕ Cash Item Given"
    elseif actionType == 'remove' then
        title = "➖ Cash Item Removed"
    end
    
    local embed = {
        title = title,
        color = color,
        fields = {
            {
                name = "Player",
                value = string.format("%s (ID: %d)", playerName, player),
                inline = true
            },
            {
                name = "Action",
                value = actionType:upper(),
                inline = true
            },
            {
                name = "Amount",
                value = string.format("%s$%s", actionText, formatMoney(math.abs(amount))),
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    if reason and reason ~= "" then
        table.insert(embed.fields, {
            name = "Reason",
            value = reason,
            inline = false
        })
    end
    
    if extra and extra ~= "" then
        table.insert(embed.fields, {
            name = "Details",
            value = extra,
            inline = false
        })
    end
    
    -- Log to database
    if Config.Database.enabled then
        exports.ez_money:LogMoneyChange(
            playerData.PlayerData.citizenid,
            playerName,
            'cash_item',
            actionType,
            amount,
            0, -- oldAmount not available for inventory items
            amount, -- newAmount same as amount for items
            reason,
            extra
        )
    end
    
    local data = {
        username = Config.Discord.botName,
        avatar_url = Config.Discord.avatar,
        embeds = {embed}
    }

    PerformHttpRequest(webhook, function(statusCode, text, headers)
        if statusCode ~= 200 and statusCode ~= 204 then
            print(('[ez_money] Discord webhook error: %d - %s'):format(statusCode, text))
        end
    end, 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json'
    })
end)

exports('LogBankTransfer', function(player, actionType, amount, currentBalance, memo, otherPlayerId)
    if not Config.Discord.enabled or not Config.MoneyLogging.enabled then return end
    
    -- Get player data safely
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayer(player)
    end)
    
    if not success or not playerData then return end
    
    local webhook = Config.Discord.webhook
    if not webhook or webhook == "YOUR_DISCORD_WEBHOOK_URL_HERE" then return end

    local playerName = string.format('%s %s', 
        playerData.PlayerData.charinfo.firstname or 'Unknown', 
        playerData.PlayerData.charinfo.lastname or 'Player'
    )
    
    -- Get other player name if available
    local otherPlayerName = "Unknown Player"
    if otherPlayerId then
        local success2, otherPlayerData = pcall(function()
            return exports.qbx_core:GetPlayer(otherPlayerId)
        end)
        
        if success2 and otherPlayerData then
            otherPlayerName = string.format('%s %s (ID: %d)', 
                otherPlayerData.PlayerData.charinfo.firstname or 'Unknown', 
                otherPlayerData.PlayerData.charinfo.lastname or 'Player',
                otherPlayerId
            )
        else
            otherPlayerName = string.format("Player ID: %d", otherPlayerId)
        end
    end
    
    local color = 255 -- Default blue
    local actionText = ""
    local title = "🏦 Bank Transaction"
    
    if actionType == 'send' then
        color = 16711680 -- Red for sending money
        actionText = "-"
        title = "💸 Bank Transfer Sent"
    elseif actionType == 'receive' then
        color = 65280 -- Green for receiving money
        actionText = "+"
        title = "💰 Bank Transfer Received"
    elseif actionType == 'deposit' then
        color = 3066993 -- Blue for deposit
        actionText = "+"
        title = "🏦 Bank Deposit"
    elseif actionType == 'withdraw' then
        color = 15158332 -- Orange for withdrawal
        actionText = "-"
        title = "🏧 Bank Withdrawal"
    elseif actionType == 'account_created' then
        color = 9936031 -- Purple for account creation
        actionText = ""
        title = "🆕 Bank Account Created"
    elseif actionType == 'loan_payment' then
        color = 16776960 -- Yellow for loan payment
        actionText = "-"
        title = "💳 Loan Payment"
    end
    
    local embed = {
        title = title,
        color = color,
        fields = {
            {
                name = "Player",
                value = string.format("%s (ID: %d)", playerName, player),
                inline = true
            },
            {
                name = "Action",
                value = actionType:upper(),
                inline = true
            },
            {
                name = "Amount",
                value = string.format("%s$%s", actionText, formatMoney(math.abs(amount))),
                inline = true
            },
            {
                name = "Balance After",
                value = string.format("$%s", formatMoney(currentBalance)),
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    if actionType == 'send' or actionType == 'receive' then
        table.insert(embed.fields, {
            name = (actionType == 'send') and "To" or "From",
            value = otherPlayerName,
            inline = true
        })
    end
    
    if memo and memo ~= "" then
        table.insert(embed.fields, {
            name = "Memo",
            value = memo,
            inline = false
        })
    end
    
    -- Log to database
    if Config.Database.enabled then
        local oldBalance = currentBalance
        local newBalance = currentBalance
        
        if actionType == 'send' or actionType == 'withdraw' then
            oldBalance = currentBalance + amount
        elseif actionType == 'receive' or actionType == 'deposit' then
            oldBalance = currentBalance - amount
        end
        
        exports.ez_money:LogMoneyChange(
            playerData.PlayerData.citizenid,
            playerName,
            'bank',
            actionType,
            (actionType == 'send' or actionType == 'withdraw') and -amount or amount,
            oldBalance,
            newBalance,
            memo,
            otherPlayerId and tostring(otherPlayerId) or nil
        )
    end
    
    local data = {
        username = Config.Discord.botName,
        avatar_url = Config.Discord.avatar,
        embeds = {embed}
    }

    PerformHttpRequest(webhook, function(statusCode, text, headers)
        if statusCode ~= 200 and statusCode ~= 204 then
            print(('[ez_money] Discord webhook error: %d - %s'):format(statusCode, text))
        end
    end, 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json'
    })
end)

exports('LogMoneyChange', function(citizenid, playerName, moneyType, action, amount, oldAmount, newAmount, reason, targetId)
    if not Config.Database.enabled then return end
    
    exports.oxmysql:execute('INSERT INTO money_logs (citizenid, player_name, money_type, action, amount, old_amount, new_amount, reason, target_id, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
        citizenid,
        playerName,
        moneyType,
        action,
        amount,
        oldAmount,
        newAmount,
        reason,
        targetId
    })
end)

exports('CleanupOldLogs', function()
    if not Config.Database.enabled then return false end
    
    local daysToKeep = Config.Database.keepLogsDays or 30
    exports.oxmysql:execute('DELETE FROM money_logs WHERE timestamp < DATE_SUB(NOW(), INTERVAL ? DAY)', {daysToKeep})
    return true
end)
