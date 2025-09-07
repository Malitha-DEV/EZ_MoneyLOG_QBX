-- Discord webhook functions

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

local function SendDiscordMessage(webhook, embeds)
    if not webhook or webhook == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
        print('[ez_money] Discord webhook not configured')
        return
    end

    local data = {
        username = Config.Discord.botName,
        avatar_url = Config.Discord.avatar,
        embeds = embeds
    }

    PerformHttpRequest(webhook, function(statusCode, text, headers)
        if statusCode ~= 200 and statusCode ~= 204 then
            print(('[ez_money] Discord webhook error: %d - %s'):format(statusCode, text))
        end
    end, 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json'
    })
end

local function LogMoneyToDiscord(player, moneyType, action, amount, oldAmount, newAmount, reason)
    if not Config.Discord.enabled or not Config.MoneyLogging.enabled then return end
    
    local playerData = exports.qbx_core:GetPlayer(player)
    if not playerData then return end
    
    local playerName = ('%s %s'):format(playerData.PlayerData.charinfo.firstname, playerData.PlayerData.charinfo.lastname)
    local citizenId = playerData.PlayerData.citizenid
    
    local actionText = action == 'add' and Config.Lang.moneyAdded or Config.Lang.moneyRemoved
    local color = action == 'add' and 65280 or 16711680 -- Green for add, Red for remove
    
    local embed = {
        {
            title = actionText,
            color = color,
            fields = {
                {
                    name = Config.Lang.player,
                    value = ('%s (ID: %d)'):format(playerName, player),
                    inline = true
                },
                {
                    name = "Citizen ID",
                    value = citizenId,
                    inline = true
                },
                {
                    name = "Money Type",
                    value = moneyType:upper(),
                    inline = true
                },
                {
                    name = Config.Lang.amount,
                    value = ('$%s'):format(formatMoney(amount)),
                    inline = true
                },
                {
                    name = "Old Amount",
                    value = ('$%s'):format(formatMoney(oldAmount)),
                    inline = true
                },
                {
                    name = "New Amount",
                    value = ('$%s'):format(formatMoney(newAmount)),
                    inline = true
                },
                {
                    name = Config.Lang.reason,
                    value = reason or 'Unknown',
                    inline = false
                }
            },
            footer = {
                text = Config.Lang.time .. ': ' .. os.date('%Y-%m-%d %H:%M:%S')
            }
        }
    }
    
    SendDiscordMessage(Config.Discord.webhook, embed)
end

local function LogPlayerJoinLeave(player, action)
    if not Config.Discord.enabled then return end
    if (action == 'join' and not Config.MoneyLogging.logPlayerJoin) or 
       (action == 'leave' and not Config.MoneyLogging.logPlayerLeave) then return end
    
    local playerData = exports.qbx_core:GetPlayer(player)
    if not playerData then return end
    
    local playerName = ('%s %s'):format(playerData.PlayerData.charinfo.firstname, playerData.PlayerData.charinfo.lastname)
    local citizenId = playerData.PlayerData.citizenid
    local money = playerData.PlayerData.money
    
    local actionText = action == 'join' and Config.Lang.playerJoined or Config.Lang.playerLeft
    local color = action == 'join' and 3447003 or 10181046 -- Blue for join, purple for leave
    
    local embed = {
        {
            title = actionText,
            color = color,
            fields = {
                {
                    name = Config.Lang.player,
                    value = ('%s (ID: %d)'):format(playerName, player),
                    inline = true
                },
                {
                    name = "Citizen ID",
                    value = citizenId,
                    inline = true
                },
                {
                    name = Config.Lang.cash,
                    value = ('$%s'):format(formatMoney(money.cash or 0)),
                    inline = true
                },
                {
                    name = Config.Lang.bank,
                    value = ('$%s'):format(formatMoney(money.bank or 0)),
                    inline = true
                },
                {
                    name = Config.Lang.total,
                    value = ('$%s'):format(formatMoney((money.cash or 0) + (money.bank or 0))),
                    inline = true
                }
            },
            footer = {
                text = Config.Lang.time .. ': ' .. os.date('%Y-%m-%d %H:%M:%S')
            }
        }
    }
    
    SendDiscordMessage(Config.Discord.webhook, embed)
end

local function SendDailyLeaderboard()
    if not Config.Discord.enabled or not Config.Leaderboard.enabled then 
        return 
    end
    
    local webhook = Config.Discord.leaderboardWebhook ~= "YOUR_LEADERBOARD_WEBHOOK_URL_HERE" and Config.Discord.leaderboardWebhook or Config.Discord.webhook
    
    local leaderboards = {}
    
    if Config.Leaderboard.includeCash then
        leaderboards.cash = exports.ez_money:GetTopPlayersByMoney('cash', Config.Leaderboard.topCount)
    end
    
    if Config.Leaderboard.includeBank then
        leaderboards.bank = exports.ez_money:GetTopPlayersByMoney('bank', Config.Leaderboard.topCount)
    end
    
    if Config.Leaderboard.includeTotalMoney then
        leaderboards.total = exports.ez_money:GetTopPlayersByMoney('total', Config.Leaderboard.topCount)
    end
    
    local embeds = {}
    
    for moneyType, data in pairs(leaderboards) do
        if data and #data > 0 then
            local fields = {}
            
            for i, player in ipairs(data) do
                local playerName = ('%s %s'):format(player.firstname or 'Unknown', player.lastname or 'Player')
                table.insert(fields, {
                    name = ('#%d - %s'):format(i, playerName),
                    value = ('$%s'):format(formatMoney(player.money_amount)),
                    inline = true
                })
            end
            
            table.insert(embeds, {
                title = ('%s - %s %s'):format(Config.Lang.dailyLeaderboard, moneyType:upper(), moneyType == 'total' and 'MONEY' or ''),
                color = Config.Discord.color,
                fields = fields,
                footer = {
                    text = os.date('%Y-%m-%d %H:%M:%S')
                }
            })
        end
    end
    
    if #embeds > 0 then
        SendDiscordMessage(webhook, embeds)
    end
end

exports('LogMoneyToDiscord', LogMoneyToDiscord)
exports('LogPlayerJoinLeave', LogPlayerJoinLeave)
exports('SendDailyLeaderboard', SendDailyLeaderboard)