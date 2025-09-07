-- Database functions for money logging

local function CreateMoneyLogsTable()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `money_logs` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `player_name` varchar(100) NOT NULL,
            `money_type` enum('cash', 'bank', 'crypto') NOT NULL,
            `action` enum('add', 'remove', 'set') NOT NULL,
            `amount` int(11) NOT NULL,
            `old_amount` int(11) NOT NULL,
            `new_amount` int(11) NOT NULL,
            `reason` varchar(255) DEFAULT 'Unknown',
            `source_player` varchar(50) DEFAULT NULL,
            `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            INDEX `citizenid_index` (`citizenid`),
            INDEX `timestamp_index` (`timestamp`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(success)
        if success then
            print('[ez_money] Money logs table created successfully')
        else
            print('[ez_money] Failed to create money logs table')
        end
    end)
end

local function LogMoneyChange(citizenid, playerName, moneyType, action, amount, oldAmount, newAmount, reason, sourcePlayer)
    if not Config.Database.enabled then return end
    
    MySQL.Async.insert('INSERT INTO money_logs (citizenid, player_name, money_type, action, amount, old_amount, new_amount, reason, source_player) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        citizenid,
        playerName,
        moneyType,
        action,
        amount,
        oldAmount,
        newAmount,
        reason or 'Unknown',
        sourcePlayer
    }, function(insertId)
        if insertId then
            print(('[ez_money] Logged money change for %s (ID: %d)'):format(playerName, insertId))
        end
    end)
end

local function GetTopPlayersByMoney(moneyType, limit)
    -- For leaderboard, we want ALL players (online and offline) from database
    
    -- Use database query to get all players (online and offline)
    local success, result = pcall(function()
        return MySQL.Sync.fetchAll([[
            SELECT 
                p.citizenid,
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) as firstname,
                JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) as lastname,
                CASE 
                    WHEN ? = 'cash' THEN CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.money, '$.cash')), 0) AS SIGNED)
                    WHEN ? = 'bank' THEN CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.money, '$.bank')), 0) AS SIGNED)
                    WHEN ? = 'total' THEN (
                        CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.money, '$.cash')), 0) AS SIGNED) + 
                        CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.money, '$.bank')), 0) AS SIGNED)
                    )
                END as money_amount
            FROM players p 
            WHERE p.charinfo IS NOT NULL 
            AND JSON_VALID(p.money) = 1
            AND JSON_VALID(p.charinfo) = 1
            AND p.charinfo != '{}'
            AND p.money != '{}'
            ORDER BY money_amount DESC 
            LIMIT ?
        ]], {moneyType, moneyType, moneyType, limit})
    end)
    
    if success and result then
        return result
    else
        -- Fallback to online players if database fails
        local players = {}
        
        -- Get all active players
        for _, playerId in ipairs(GetPlayers()) do
            local playerData = exports.qbx_core:GetPlayer(tonumber(playerId))
            
            if playerData and playerData.PlayerData and playerData.PlayerData.money and playerData.PlayerData.charinfo then
                local money = playerData.PlayerData.money
                local moneyAmount = 0
                
                if moneyType == 'cash' then
                    moneyAmount = money.cash or 0
                elseif moneyType == 'bank' then
                    moneyAmount = money.bank or 0
                elseif moneyType == 'total' then
                    moneyAmount = (money.cash or 0) + (money.bank or 0)
                end
                
                table.insert(players, {
                    citizenid = playerData.PlayerData.citizenid,
                    firstname = playerData.PlayerData.charinfo.firstname or 'Unknown',
                    lastname = playerData.PlayerData.charinfo.lastname or 'Player',
                    money_amount = moneyAmount
                })
            end
        end
        
        -- Sort players by money amount
        table.sort(players, function(a, b)
            return a.money_amount > b.money_amount
        end)
        
        -- Return top players
        local result = {}
        for i = 1, math.min(limit, #players) do
            table.insert(result, players[i])
        end
        
        return result
    end
end

local function CleanupOldLogs()
    if not Config.Database.enabled then return end
    
    MySQL.Async.execute('DELETE FROM money_logs WHERE timestamp < DATE_SUB(NOW(), INTERVAL ? DAY)', {
        Config.Database.keepLogsDays
    }, function(affectedRows)
        if affectedRows > 0 then
            print(('[ez_money] Cleaned up %d old log entries'):format(affectedRows))
        end
    end)
end

-- Initialize database on resource start
CreateTable = CreateMoneyLogsTable
exports('LogMoneyChange', LogMoneyChange)
exports('GetTopPlayersByMoney', GetTopPlayersByMoney)
exports('CleanupOldLogs', CleanupOldLogs)