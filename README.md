# 💰 EZ Money Logger - Comprehensive FiveM Money Tracking

**🔧 QBox Framework Compatible | 📊 Real-time Discord Logging**

## 📋 Overview

EZ Money is a comprehensive money logging system designed specifically for **QBox Framework** servers. This script monitors and logs **every single money transaction** happening on your server with real-time Discord notifications and optional database storage.

## 🚀 Key Features

### 💸 Complete Money Tracking
- Cash & Bank transactions (configurable minimum amount)
- Player-to-player money transfers
- Admin give/remove commands
- Job/boss menu transactions
- Vehicle & house purchases
- Universal detector for all QBox money changes

### 🎒 Inventory Integration
- ox_inventory cash item movements
- Stash/storage transactions
- Vehicle glovebox & trunk items
- Apartment storage logging
- Ground dropped item tracking

### 🏦 Banking System Support
- Full Renewed-Banking integration
- ATM transactions
- Bank transfers
- Loan payments
- Account creation logging

### 📈 Daily Leaderboards
- Top 20 richest players (configurable time)
- Separate Discord channel for leaderboards
- Cash, Bank, and Total money rankings

### 🛡️ Admin Features
- Monitor admin money actions
- Configurable admin groups
- Player join/leave logging
- Anti-cheat detection capabilities

## ⚙️ Installation

1. **Download & Extract**
   ```
   Download ez_money folder to your server's resources directory
   ```

2. **Configure Discord Webhooks**
   - Edit `config.lua`
   - Replace webhook URLs with your Discord channel webhooks
   - Set up separate channels for transactions and leaderboards

3. **Database Setup (Optional)**
   ```sql
   -- SQL table will be created automatically if database logging is enabled
   ```

4. **Server Configuration**
   ```cfg
   # Add to your server.cfg
   ensure ez_money
   ```

## 🔧 Configuration

### Discord Settings
```lua
Config.Discord = {
    enabled = true,
    webhook = "YOUR_TRANSACTION_WEBHOOK_HERE",
    botName = "Money Logger",
    avatar = "https://i.imgur.com/4M34hi2.png",
    color = 16776960, -- Yellow color
    leaderboardWebhook = "YOUR_LEADERBOARD_WEBHOOK_HERE",
}
```

### Money Logging Options
```lua
Config.MoneyLogging = {
    enabled = true,
    logCash = true,
    logBank = true,
    minAmount = 100, -- Minimum amount to log
    logInventoryItems = true,
    logStashItems = true,
    logVehicleGloveboxItems = true,
    logVehicleTrunkItems = true,
    logApartmentStorage = true,
    logGroundItems = true,
    logBankTransfers = true,
    logATMTransactions = true,
    -- ... and many more options
}
```

### Leaderboard Settings
```lua
Config.Leaderboard = {
    enabled = true,
    sendTime = "12:00", -- 24h format
    topCount = 20,
    includeCash = true,
    includeBank = true,
    includeTotalMoney = true,
}
```

## 📊 What Gets Logged

### 💰 Money Transactions
- ✅ Cash additions/removals
- ✅ Bank deposits/withdrawals
- ✅ Admin money commands
- ✅ Player-to-player transfers
- ✅ Job salary payments
- ✅ Vehicle/house purchases

### 🎒 Inventory Items
- ✅ Cash items in player inventory
- ✅ Stash/storage movements
- ✅ Vehicle storage (glovebox/trunk)
- ✅ Apartment storage
- ✅ Ground dropped items

### 🏦 Banking Activities
- ✅ Renewed-Banking transfers
- ✅ ATM transactions
- ✅ Loan payments
- ✅ Account creation

### 📈 Player Activity
- ✅ Player join/leave events
- ✅ Daily money leaderboards
- ✅ Real-time balance tracking

## 🔗 Discord Integration

### Transaction Notifications
Rich embed messages containing:
- Player name and ID
- Transaction type and amount
- Before/after balances
- Reason/source of transaction
- Timestamp

### Daily Leaderboards
Automated daily posts showing:
- Top 20 richest players
- Cash, Bank, and Total rankings
- Player names and amounts
- Position changes

## 🛠️ Dependencies

### Required
- **QBox Core** - Main framework
- **ox_inventory** - For inventory item logging

### Optional
- **Renewed-Banking** - For advanced banking features
- **MySQL** - For database logging (oxmysql)

## 📋 Commands & Exports

### Server Exports
```lua
-- Log custom money transaction
exports.ez_money:LogMoneyToDiscord(source, moneyType, actionType, amount, oldBalance, newBalance, reason)

-- Log to database
exports.ez_money:LogMoneyChange(citizenid, playerName, moneyType, actionType, amount, oldBalance, newBalance, reason, targetPlayer)

-- Send daily leaderboard
exports.ez_money:SendDailyLeaderboard()

-- Clean up old logs
exports.ez_money:CleanupOldLogs()
```

## 🎯 Use Cases

- **Server Administration**: Monitor all money movements
- **Anti-Cheat**: Detect suspicious transactions
- **Economy Analysis**: Track server financial health
- **Player Engagement**: Daily leaderboard competitions
- **Transparency**: Public money transaction logs

## 🔒 Security Features

- **Safe Player Data Access**: Uses pcall for error handling
- **Configurable Minimums**: Avoid spam with minimum transaction amounts
- **Admin Group Control**: Restrict sensitive features to admins
- **Event-Based Detection**: Compatible with QBox export restrictions

## 📝 Support & Updates

- **Framework**: QBox Core Compatible
- **Version**: Latest (2025)
- **Status**: Actively Maintained
- **Compatibility**: FiveM Server builds 2023+

## 🎮 Perfect For

- QBox Framework servers
- Roleplay servers requiring economy monitoring
- Servers with active trading/business systems
- Admins wanting complete financial oversight
- Communities requiring transparency

---

## 🚀 Quick Start

1. Configure Discord webhooks in `config.lua`
2. Add `ensure ez_money` to server.cfg
3. Restart server
4. Watch real-time money logs in Discord!

**Need help?** Check the configuration options in `config.lua` - everything is documented and customizable!
- Check that `Config.Discord.enabled = true`
- Verify the time format is correct (24-hour format)
- Check that `Config.Leaderboard.enabled = true`
- Ensure you have player data in QBox
- Use `/sendleaderboard` command to test manually
- Check server console for error messages

### Discord Webhook Issues
- Ensure oxmysql is properly installed and configured
- Check that your database connection is working
- Verify QBox is running correctly

## Support

For support and updates, please check the documentation and ensure you're using the latest version of QBox.

The script is production-ready and focuses solely on providing daily money leaderboards to Discord. Individual transaction logging has been disabled to keep the script lightweight and focused.

## License

For support and updates, please check the documentation and ensure you're using the latest version of QBox.

## License

This script is provided as-is for use with QBox framework. Modify as needed for your server.
