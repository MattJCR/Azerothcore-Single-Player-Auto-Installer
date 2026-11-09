// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Descripciones en inglés de los parámetros de módulos de terceros (primera mitad).
export default {
  // ── mod-playerbots ────────────────────────────────────────────────────
  "Playerbots.Enabled": "Master switch; affects the bot population of the whole server.",
  "Playerbots.RandomBotAutologin": "Autologin of random bots.",
  "Playerbots.MinRandomBots": "A high number means high CPU/memory load; the current server uses its own value, different from the .dist, so check before touching it. With WorldBots.PlayerScale.Enable=1 (mod_world_bots.conf), mod-world-bots overrides it live every few seconds according to the connected players: editing it here has no effect while that is active.",
  "Playerbots.MaxRandomBots": "A high number means high CPU/memory load; the current server uses its own value, different from the .dist, so check before touching it. With WorldBots.PlayerScale.Enable=1 (mod_world_bots.conf), mod-world-bots overrides it live every few seconds according to the connected players: editing it here has no effect while that is active.",
  "Playerbots.RandomBotMinLevel": "Minimum level of random bots.",
  "Playerbots.RandomBotMaxLevel": "Maximum level of random bots.",
  "Playerbots.RandomBotCountMode": "How the number of connected bots changes: 0 fixed (rolled at start-up between Min and MaxRandomBots), 1 variable (re-rolled every so often), 2 scheduled (rises from Min to Max between RandomBotCountMinTime and RandomBotCountMaxTime). With WorldBots.PlayerScale.Enable=1 mod-world-bots sets Min = Max and the mode changes nothing.",

  // ── mod-autobalance ───────────────────────────────────────────────────
  "AutoBalance.Enable.Global": "Master switch for the whole module.",
  "AutoBalance.Enable.5M": "Enables or disables balancing in 5-player dungeons.",
  "AutoBalance.Enable.10M": "Enables or disables balancing in 10-player raids.",
  "AutoBalance.Enable.15M": "Enables or disables balancing in 15-player raids.",
  "AutoBalance.Enable.20M": "Enables or disables balancing in 20-player raids.",
  "AutoBalance.Enable.25M": "Enables or disables balancing in 25-player raids.",
  "AutoBalance.Enable.40M": "Enables or disables balancing in 40-player raids.",
  "AutoBalance.Enable.OtherNormal": "Enables or disables balancing in other normal instances.",
  "AutoBalance.Enable.5MHeroic": "Enables or disables balancing in 5-player heroic dungeons.",
  "AutoBalance.Enable.10MHeroic": "Enables or disables balancing in 10-player heroic raids.",
  "AutoBalance.Enable.25MHeroic": "Enables or disables balancing in 25-player heroic raids.",
  "AutoBalance.Enable.OtherHeroic": "Enables or disables balancing in other heroic instances.",
  "AutoBalance.MinPlayers": "Minimum players for balancing to apply.",
  "AutoBalance.MinPlayers.Heroic": "Minimum players for balancing in heroic.",
  "AutoBalance.MinPlayers.Raid": "Minimum players for balancing in a raid.",
  "AutoBalance.MinPlayers.RaidHeroic": "Minimum players for balancing in a heroic raid.",
  "AutoBalance.playerCountDifficultyOffset": "Shifts the calculated difficulty.",

  // ── mod-ah-bot-plus ───────────────────────────────────────────────────
  "AuctionHouseBot.EnableSeller": "Enables seller bots in the auction house.",
  "AuctionHouseBot.Buyer.Enabled": "Enables buyer bots in the auction house.",
  "AuctionHouseBot.MinutesBetweenBuyCycle": "Minutes between the bots' buying cycles.",
  "AuctionHouseBot.Buyer.BidAgainstPlayers": "Whether a bot can bid against real players.",

  // ── mod-dungeon-master ────────────────────────────────────────────────
  "DungeonMaster.Enable": "Master switch of the module.",
  "DungeonMaster.Rewards.BaseGold": "Economic impact: base gold reward, in copper.",
  "DungeonMaster.Rewards.GoldPerMob": "Economic impact: gold per defeated creature, in copper.",
  "DungeonMaster.Rewards.GoldPerBoss": "Economic impact: gold per defeated boss, in copper.",
  "DungeonMaster.Rewards.XPMultiplier": "Experience multiplier of the rewards.",
  "DungeonMaster.Rewards.ItemChance": "Chance of an item reward.",
  "DungeonMaster.Rewards.RareChance": "Chance that the reward item is rare.",
  "DungeonMaster.Rewards.EpicChance": "Chance that the reward item is epic.",
  "DungeonMaster.MaxConcurrentRuns": "Maximum simultaneous runs.",
  "DungeonMaster.Cooldown.Minutes": "Minutes to wait between runs.",
  "DungeonMaster.TimeLimit.Enable": "Enables the time limit per run.",
  "DungeonMaster.TimeLimit.Minutes": "Minutes of the time limit per run.",
  "DungeonMaster.Roguelike.Enable": "Enables the full progressive-difficulty mode.",

  // ── mod-dungeon-clear ─────────────────────────────────────────────────
  "DungeonClear.Enable": "Master switch; the .conf.dist itself confirms it is honoured on .reload config, although in this panel it is always treated as a restart.",
  "DungeonClear.LootMinQuality": "Minimum item quality dropped by the automatic clear.",
  "DungeonClear.RestHealthPct": "Percentage of health restored after the clear.",
  "DungeonClear.RestManaPct": "Percentage of mana restored after the clear.",
  "DungeonClear.SmartRest": "Adjusts the rest automatically according to the context.",

  // ── mod-transmog ──────────────────────────────────────────────────────
  "Transmogrification.Enable": "Master switch of transmog.",
  "Transmogrification.UseCollectionSystem": "Uses the appearance collection system.",
  "Transmogrification.ScaledCostModifier": "Economic cost of transmog.",
  "Transmogrification.CopperCost": "Fixed cost in copper per transmog.",
  "Transmogrification.RequireToken": "Requires a token item to transmogrify.",
  "Transmogrification.TokenEntry": "Item used as the transmog token.",
  "Transmogrification.TokenAmount": "Amount of token required per transmog.",
  "Transmogrification.AllowPoor": "Allows Poor quality items as the transmog source.",
  "Transmogrification.AllowCommon": "Allows Common quality items as the transmog source.",
  "Transmogrification.AllowUncommon": "Allows Uncommon quality items as the transmog source.",
  "Transmogrification.AllowRare": "Allows Rare quality items as the transmog source.",
  "Transmogrification.AllowEpic": "Allows Epic quality items as the transmog source.",
  "Transmogrification.AllowLegendary": "Allows Legendary quality items as the transmog source.",
  "Transmogrification.AllowArtifact": "Allows Artifact quality items as the transmog source.",
  "Transmogrification.AllowHeirloom": "Allows Heirloom quality items as the transmog source.",

  // ── mod-individual-progression ────────────────────────────────────────
  "IndividualProgression.Enable": "Master switch of the whole phased progression system.",
  "IndividualProgression.ProgressionLimit": "Artificially caps the accessible content.",
  "IndividualProgression.StartingProgression": "Progression phase new characters start with.",
  "IndividualProgression.DisableRDF": "Disables the random group finder.",
  "IndividualProgression.BotAccountsMaxLevel": "Maximum level allowed for bot accounts.",

  // ── mod-progression-skip ──────────────────────────────────────────────
  "ProgressionSkip.Enable": "General switch of the \"Chronicler of the Ages\" NPC. With 0 it stays in the world but offers no phase skip.",
  "ProgressionSkip.RequireNoGroup": "Requires leaving the group to confirm a skip. With 0 confirming while in a group is allowed.",

  // ── mod-challenge-modes ───────────────────────────────────────────────
  "ChallengeModes.Enable": "Master switch of the module.",
  "Hardcore.Enable": "Hardcore challenge mode.",
  "SemiHardcore.Enable": "Semi-Hardcore challenge mode.",
  "SelfCrafted.Enable": "Self-crafted challenge mode.",
  "ItemQualityLevel.Enable": "Limited item quality challenge mode.",
  "SlowXpGain.Enable": "Slow experience challenge mode.",
  "VerySlowXpGain.Enable": "Very slow experience challenge mode.",
  "QuestXpOnly.Enable": "Quest-only experience challenge mode.",
  "IronMan.Enable": "Iron Man challenge mode.",
  "SlowXpGain.XPMultiplier": "Experience multiplier of the slow experience mode.",
  "VerySlowXpGain.XPMultiplier": "Experience multiplier of the very slow experience mode.",

  // ── mod-instanced-worldbosses ─────────────────────────────────────────
  "ModInstancedWorldBosses.Enable": "Master switch of the module.",
  "ModInstancedWorldBosses.ResetTimerSecs": "Seconds until the boss resets (3 days by default).",
  "ModInstancedWorldBosses.RespawnTimerSecs": "Seconds until the boss respawns.",
  "ModInstancedWorldBosses.GracePeriodSecs": "Seconds of grace period before combat.",

  // ── mod-instance-reset ────────────────────────────────────────────────
  "instanceReset.Enable": "Master switch of the module.",
  "instanceReset.NormalModeOnly": "Limits the manual reset to normal difficulty.",
  "instanceReset.TransactionType": "Determines whether the reset costs money or a token.",
  "instanceReset.TokenID": "Price of the manual dungeon reset: token item.",
  "instanceReset.TokenCount": "Price of the manual dungeon reset: token amount.",
  "instanceReset.MoneyCount": "Price of the manual dungeon reset: copper.",

  // ── mod-1v1-arena ─────────────────────────────────────────────────────
  "Arena1v1.Enable": "Master switch of the module.",
  "Arena1v1.MinLevel": "Minimum level to enter 1v1 arena.",
  "Arena1v1.Costs": "Cost in copper of entering 1v1 arena.",
  "Arena1v1.ArenaPointsMulti": "Multiplier for arena points earned in 1v1.",
  "Arena1v1.PreventHealingTalents": "Prevents healing talents in 1v1 arena.",
  "Arena1v1.PreventTankTalents": "Prevents tank talents in 1v1 arena.",

  // ── mod-random-enchants ───────────────────────────────────────────────
  "RandomEnchants.Enable": "Master switch of the module.",
  "RandomEnchants.OnLoot": "Applies a random enchant when looting an item.",
  "RandomEnchants.OnCreate": "Applies a random enchant when creating an item.",
  "RandomEnchants.OnQuestReward": "Applies a random enchant to quest rewards.",
  "RandomEnchants.OnGroupRoll": "Applies a random enchant to group rolls.",
  "RandomEnchants.EnchantChance1": "Chance of a cascading enchant, first level.",
  "RandomEnchants.EnchantChance2": "Chance of a cascading enchant, second level.",
  "RandomEnchants.EnchantChance3": "Chance of a cascading enchant, third level.",

  // ── mod-token-turnin ──────────────────────────────────────────────────
  "TokenTurnIn.Enable": "Master switch of the module.",
  "TokenTurnIn.IncludeSelf": "Includes the account itself in the token hand-in.",
  "TokenTurnIn.IncludeRealPlayers": "Includes real players in the token hand-in.",

  // ── mod-world-buff-bots ───────────────────────────────────────────────
  "WorldBuffBots.Enable": "Master switch of the module.",
  "WorldBuffBots.BaseMinutes": "Base minutes between simulated world buffs.",
  "WorldBuffBots.VarianceMinutes": "Variation in minutes over the base interval.",
  "WorldBuffBots.Warchief.Enable": "Enables the Warchief world buff.",
  "WorldBuffBots.Dragonslayer.Enable": "Enables the Dragonslayer world buff.",
  "WorldBuffBots.Zandalar.Enable": "Enables the Zandalar world buff.",

  // ── mod-war-effort ────────────────────────────────────────────────────
  "ModWarEffort.Enable": "Master switch of the module.",
  "ModWarEffort.Id": "Changing it restarts the campaign.",
};
