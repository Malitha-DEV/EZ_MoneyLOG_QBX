Config = {}

-- Discord webhook settings
Config.Discord = {
    enabled = true,
    webhook = "https://discord.com/api/webhooks/1414355211975397627/3-KPXmE6UJnoY-yYlluKI_btfMNJDph8Gydl994Kt4awbsxMEQcdjl_SLh-c5z9staZO", -- Replace with your Discord webhook URL
    botName = "Money Logger",
    avatar = "https://i.imgur.com/4M34hi2.png",
    color = 16776960, -- Yellow color
    leaderboardWebhook = "https://discord.com/api/webhooks/1414355277985349714/rfZlLrazQ1nt66lIgpwjtqoo5m9C4dR8tidJ9tW_8xohnvKMB5PsKPu912_4buImLi0u", -- Separate webhook for leaderboard (optional)
}

-- Money logging settings
Config.MoneyLogging = {
    enabled = true, -- Enable individual money transaction logging
    logCash = true,
    logBank = true,
    logCrypto = false, -- If QBox has crypto support
    minAmount = 100, -- Minimum amount to log (to avoid spam)
    logPlayerJoin = true, -- Enable player join logging
    logPlayerLeave = true, -- Enable player leave logging
    logInventoryItems = true, -- Enable ox_inventory cash item logging
    logStashItems = true, -- Enable ox_inventory stash logging
    logVehicleGloveboxItems = true, -- Enable vehicle glovebox cash item logging
    logVehicleTrunkItems = true, -- Enable vehicle trunk cash item logging
    logApartmentStorage = true, -- Enable apartment storage cash item logging
    logGroundItems = true, -- Enable ground dropped cash item logging
    logAdminGiveItems = true, -- Enable QB admin item commands (money give/remove)
    logPlayerGiveItems = true, -- Enable player-to-player money give/remove
    logBankTransfers = true, -- Enable Renewed-Banking transfers
    logATMTransactions = true, -- Enable Renewed-Banking ATM
    logLoanPayments = true, -- Enable Renewed-Banking loans
    logAccountCreation = true, -- Enable Renewed-Banking accounts
    logJobTransactions = true, -- Enable boss menu transactions
    logVehiclePurchases = true, -- Enable vehicle shop scripts
    logHousePurchases = true, -- Enable housing scripts
    logDrugSales = false, -- Disable drug scripts
    logESXTransactions = false, -- Disable ESX compatibility
    useUniversalDetector = true, -- Keep universal detector for QBox money changes
}

-- Leaderboard settings
Config.Leaderboard = {
    enabled = true,
    sendTime = "12:00", -- Time to send daily leaderboard (24h format)
    topCount = 20, -- How many top players to show
    includeCash = true,
    includeBank = true,
    includeTotalMoney = true,
}

-- Database settings
Config.Database = {
    enabled = false, -- Enable database logging for transaction storage
    tableName = "money_logs",
    keepLogsDays = 30, -- How many days to keep logs in database
}

-- Admin settings
Config.Admin = {
    logAdminActions = true, -- Log when admins give/take money
    adminGroups = {"admin", "superadmin", "mod"}, -- QBox admin groups
}

-- Language settings
Config.Lang = {
    moneyAdded = "💰 Money Added",
    moneyRemoved = "💸 Money Removed", 
    playerJoined = "📥 Player Joined",
    playerLeft = "📤 Player Left",
    dailyLeaderboard = "🏆 Daily Money Leaderboard",
    cash = "Cash",
    bank = "Bank",
    total = "Total",
    position = "Position",
    player = "Player",
    amount = "Amount",
    reason = "Reason",
    time = "Time",
}