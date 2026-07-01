# [L4D2] Lifetime Stats History
A SourceMod plugin for Left 4 Dead 2. It tracks detailed stats for both human players and bots. Player stats are saved to a local database so they carry over between play sessions. The plugin can also write stats into text files in your server folder when a round ends, when you change maps, or when you win a campaign.

Also logs activity with timestamps that persists throughout a campaign and resets in a new campaign. Use the command to print to console. Automatically creates a log file per chapter or after finale rescue.


Why I made this:
Steam's stats tracker is buggy. To satisfy my addiction to accurate lifetime and campaign data, I built this.

# Features
- Keeps lifetime stats for human players in a local SQLite database.
- Prevents stats from resetting when a new map loads during a campaign.
- Keeps track of bot stats for the campaign (like kills, weapons used, throwables, and feats).
- Saves text logs in the logs/stats_history/ folder.
- Logs activity throughout the campaign (ex. who saved whom).
- Saves activity logs in the logs/match_activity/ folder

# What It Tracks
**Game & Team Stats**
- Playtime, campaigns played, campaign wins, restarts, incapacitations, and deaths.
- Healing items used and shared (Medkits, Pills, Adrenaline, Defibrillators).
- Team actions (Revives, Protections, Ledge Grabs, and Ledge Rescues).
- Friendly fire damage (dealt and received).

**Kills & Damage**
- Common Infected killed.
- Special Infected killed (and a breakdown of each type).
- Damage dealt to Tanks and Witches.

**Special Feats**
- Hunter Skeets and Jockey Deadstops.
- Witch Crowns and Witches startled.
- Tongue Cuts (cutting a Smoker tongue) and Self-Rescues (killing a Smoker pulling you).
- Charger Levels and Tank Rock Skeets (shooting rocks out of the air).
- Spitters killed before they spit, and times you got boomed on.

**Weapon Stats**
- Shots fired, hits, headshots, and kills for every weapon.

**Damage Taken**
- Tracks how much damage you took and what hit you (Common Infected, Witch claws, Tank punches, friendly fire, fall damage, etc.).

# Commands For Players
- !showstatshistory - Prints your lifetime stats in the console.
- !showstatsforcampaign - Prints your current campaign stats in the console.
- !showbotsstatsforcampaign - Prints campaign stats for the bots in the console.
- !printstatshistory - Saves your lifetime stats to a text file.
- !printstatsforcampaign - Saves your campaign stats to a text file.
- !savestatsforme - Manually saves your current stats to the database.
- !resetstatsforme - Deletes your own stats from the database (cannot be undone).
- !showmatchactivity - Print current campaign activity log to the console.
- !printmatchactivity - Manually write current campaign activity log to file in logs/match_activity/ folder

# Commands For Admins (Root flags required)
- sm_savestatshistory - Force-saves stats for all players currently in the server.
- sm_resetstatshistory - Wipes the entire database (deletes everyone's stats).

# Requirements
- sourcemod
- left4dhooks

**Optional:**
- L4D2 Custom Survivor Bot Names: https://github.com/grotovu/L4D2-Custom-Survivor-Bot-Names

# Configuration
An example of the config file at cfg/sourcemod/l4d2_stats_history.cfg
```
// Enable or disable writing activity logs to files? (0=No, 1=Yes)
// -
// Default: "1"
l4d2_stats_history_activity_logs_enable "1"

// Enable the Stats History tracking plugin?
// -
// Default: "1"
l4d2_stats_history_enable "1"

// Should damage received statistics be printed in show commands and log sheets? (0=No, 1=Yes)
// -
// Default: "1"
l4d2_stats_history_print_damage_received "1"

// 0=Disabled, 1=Print at Finale Win, 2=Print at end of every chapter.
// -
// Default: "2"
l4d2_stats_history_print_mode "2"

// Should weapon statistics be printed in show commands and log sheets? (0=No, 1=Yes)
// -
// Default: "1"
l4d2_stats_history_print_weapon_stats "1"

// Should a safety backup be created automatically before running reset commands? (0=No, 1=Yes)
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
l4d2_stats_history_reset_backup "1"

// Should stats be saved to the database when a player disconnects? (Set to 0 during testing/modding)
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
l4d2_stats_history_save_disconnect "1"
```

Disclaimer: AI tools were used to help write, optimize, and debug parts of this plugin's code and documentation.
