-- Manual database setup for ez_money (optional - script will create automatically)

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

-- Optional: Add indexes for better performance on large datasets
-- CREATE INDEX `money_type_index` ON `money_logs` (`money_type`);
-- CREATE INDEX `action_index` ON `money_logs` (`action`);
-- CREATE INDEX `date_index` ON `money_logs` (DATE(`timestamp`));
