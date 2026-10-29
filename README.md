# [L4D2] Lifetime Stats History & Match Activity Log

A comprehensive statistics, weapon mastery, and live narrative tracking engine for **Left 4 Dead 2** (SourceMod).

Unlike default Steam stats or basic kill counters, this plugin provides **two powerful systems in one**:
1. **Persistent Lifetime & Campaign Statistics:** Tracks human players across sessions via a local SQLite database, and independently monitors Survivor Bot companion stats across full campaigns.
2. **Real-Time Match Activity Timeline:** Generates a second-by-second chronological narrative of key events, pin saves, assists, special infected feats, and map interactions—streamed directly into the chat HUD, console, and disk log files.

---

## 🌟 Key Highlights

- **Persistent SQLite Database:** Player lifetime stats, weapon mastery, and damage logs automatically persist across reconnections and server restarts.
- **Smart Campaign Caching:** Stats are retained smoothly across chapter transitions and map changes without premature resets or duplicate counts.
- **Survivor Bot Companion Tracking:** Tracks AI bot teammates across 32 character slots (including custom bot names) for playtime, kills, assists, heals, feats, and damage taken.
- **Interactive Match Activity Log:** Chronological `[HH:MM:SS]` narrative tracking player saves, wallbang kills, combat distances, assist damage, item deliveries, prop explosions, and finale escapes.
- **Export, Import & Safety Backups:** Create manual savestates of your stats or rely on automatic safety backups before running reset commands.
- **Automated Match Summaries:** Generates clean, human-readable text logs at the end of each chapter or after escaping the finale.

---

## 📊 Comprehensive Tracking Breakdown

### 1. Game & Survival Stats
- **Playtime & Campaigns:** Total play hours/minutes, campaigns played, campaigns won, calculated win rate percentage (`%`), and chapter restarts/wipes.
- **Incapacitations & Deaths:** Permanent deaths tracked independently from incaps (defibrillator revives accurately deduct from the death count).
- **Health State Tracking:** Automatically announces when a player enters or recovers from **Black and White (Third Strike)** status.
- **Healing & Utility:** Medkits used and shared, pills consumed and shared, adrenaline used and shared, and defibrillators used (including times you were healed/defibbed by teammates).

### 2. Teamplay & Support Metrics
- **Revives & Protections:** Total revives and ledge pull-ups performed, closet rescues performed, and teammate protection milestones—complete with **personal best records** per campaign.
- **Rescue Closets:** Tracks both freeing teammates from rescue closets and being freed yourself.
- **Friendly Fire Tracking:** 
  - Friendly fire damage dealt and received.
  - Personal record single-campaign highs for both inflicting and absorbing FF.
  - Smart damage-accumulation debounce timer to keep friendly fire chat/logs clean.

### 3. Infected Slain & Boss Damage
- **Common & Special Infected:** Detailed counters for Common Infected, Smokers, Boomers, Hunters, Spitters, Jockeys, Chargers, Tanks, and Witches.
- **Tank & Witch Damage:** Exact health damage dealt to Tanks and Witches (prevents overcounting beyond maximum HP).
- **Damage Breakdowns:** Upon the death of a Tank or Witch, logs an exact damage-contribution roster across all contributing survivors.

### 4. Elite Combat Feats
- **Hunter Skeets:** Killing a lunging Hunter out of mid-air.
- **Hunter & Jockey Deadstops:** Shoving lunging Hunters and leaping Jockeys.
- **Witch Crowning:** Crowning a Witch with a shotgun, as well as detecting kills achieved **strictly using melee weapons**.
- **Smoker Mastery:** 
  - **Tongue Cuts:** Cutting a Smoker's tongue with a melee weapon.
  - **Self-Rescues:** Killing a Smoker while being actively constricted.
- **Charger Leveling:** Killing a charging Charger mid-charge.
- **Tank Rock Skeets:** Shooting/destroying incoming Tank rocks out of the sky.
- **Pre-Spat Spitters:** Killing a Spitter before she can spit acid.
- **Hazards & Disasters:** Startled Witches, car alarms triggered, and times vomited/boomed on (distinguishing direct vomits from proximity pop blasts).

### 5. Weapon Mastery & Performance
- **Accuracy & Headshots:** Tracks shots fired, hits landed, kills, accuracy percentage (`Acc%`), and headshot percentage (`HS%`) per weapon.
- **Per-Weapon Breakdown:** Common kills, Special Infected breakdown per weapon, Tank/Witch damage per weapon, and weapon-specific combat feats.
- **Playstyle Analytics:** 
  - Ratio of **Firearms vs. Melee** kills.
  - Ratio of **Bullet Weapons vs. Shotgun Shell** kills.
  - **Favorite Weapons by Category:** Automatically calculates your most deadly weapon across Tier 1, Tier 2, Tier 3 / Special, and Secondary / Melee tiers.

### 6. Damage Received by Source
Tracks damage absorbed across 18 individual damage categories with tick-damage accumulation (acid, fire, and claws are condensed to prevent log spam):
- Common Infected, Witch Claws, Tank Punches, Tank Rocks.
- Smoker, Hunter, Boomer, Jockey, Charger, Spitter Acid.
- Friendly Fire, Fall Damage, Environmental Fire, Self-Inflicted Fire, Map Hazards (`trigger_hurt`), Incapacitation Bleed-out, Self Damage, and World / Physics Impacts.

<p align="center">
<img width="1072" height="798" alt="image" src="https://github.com/user-attachments/assets/1941ac02-0f63-4624-bd15-8cdd9216e49e" />
  <br>
  <em>https://www.youtube.com/watch?v=pqHlzEpTL8w</em>
  <br>
  <em>The video shows 2 zombies aligned enough for 1 pistol bullet killing them both with headshots.</em>
</p>


---

## 📜 Match Activity Log (Real-Time Narrative)

The activity engine logs events with timestamps `[HH:MM:SS]` into a chronological log file, console, and optional chat HUD:

```text
[00:04:12] Coach opened the starting checkpoint door.
[00:07:35] Ellis deployed Incendiary Ammo!
[00:09:18] Nick killed Hunter with AK-47 (Wallbang) (Distance: 742 units) (Dealt 250 dmg).
[00:11:02] Rochelle saved Coach by killing the Smoker with Combat Shotgun (Headshot) (Distance: 312 units) (Dealt 180 dmg | Assist: Nick: 70 dmg with M16 Rifle).
[00:14:45] Ellis cut a Smoker's tongue with Katana.
[00:16:20] Coach deadstopped a pouncing Hunter.
[00:18:04] Rochelle triggered a chain reaction exploding a Propane Tank.
[00:21:10] Tank Damage Breakdown -> Nick: 3410 HP | Ellis: 1980 HP | Coach: 610 HP
[00:23:40] Rescued Alive: Nick, Rochelle, Ellis, Coach
[00:23:40] The Gnome was successfully rescued!
```

### Advanced Activity Events Detected:
- **Pin & Rescue Resolution:** Smoker grabs, Hunter pounces, Jockey rides, and Charger carry/pummels—accurately detects who rescued whom, shoves, tongue severing, or self-clears.
- **Wallbang & Distance Logging:** Uses ray-trace collision testing to flag wallbang kills and measures the distance between the attacker and victim in units.
- **Damage Assists:** Displays exact damage contributions and assisting teammates' weapons on Special Infected kills.
- **Boomer Blast Logic:** Detects if a player was vomited on directly, popped a Boomer too close to themselves, or was biled because a teammate popped a Boomer nearby.
- **Objectives & World Interactions:**
  - Checkpoint safehouse door openings and end-of-map door closures (verifying all living survivors are inside).
  - Scavenge gas can pour completions and interruptions with remaining goal counts (`[Progress: 4/8 poured, 4 left]`).
  - Button interactions (instant presses, timed hold starts, completions, and cancellations).
  - Finale activations (standard triggers, elevator/bridge lowering consoles, gauntlets, and Survival mode starts).
  - Chain-reaction prop combustions vs. direct shots (Gas Cans, Propane, Oxygen Tanks, Fireworks Crates, Fuel Barrels).
- **Campaign Easter Eggs & Side Quests:**
  - **Dead Center:** Whitaker's Cola pickup, drops, and delivery completion.
  - **Dark Carnival:** Winning Gnome Chompski at the shooting gallery, ringing the Strongman bell, punching clowns, winning Stashwhacker, and escaping alive with the Gnome.
- **Roster Tracking:** Logs who survived vs. who died at chapter transitions, player-to-bot transitions, and finale rescue/death rosters.




<p align="center">
<img width="1068" height="810" alt="image" src="https://github.com/user-attachments/assets/68b5091c-7ac1-4789-8a5a-0536d13ff870" />
  <br>
  <em>https://www.youtube.com/watch?v=YkNhIbct9nM</em>
  <br>
  <em>On [00:18:23], I, Rei'sen II, got pounced by a Hunter and all three bots simultaneously shoved him. Seiran's shove killed him. Not in video.</em>
</p>


---

## 🤖 Survivor Bot Tracking

Bot companions are fully tracked across the campaign:
- Tracks individual bot character identities (Nick, Rochelle, Coach, Ellis, Bill, Zoey, Francis, Louis, or expanded survivor slots).
- Compatible with my custom bot naming plugin (`l4d2_custom_bot_name_*`).
- Displays bot accuracy, kills, revives, medkits shared, throwables, damage dealt, damage taken, and feats via `!showbotsstatsforcampaign`.

---

## ⌨️ Commands

### Player Commands
| Command | Description |
| :--- | :--- |
| `!showstatshistory` | Prints your full lifetime statistics to the console. |
| `!showstatsforcampaign` | Prints your current campaign statistics to the console. |
| `!showbotsstatsforcampaign` | Prints current campaign performance for AI bot companions to the console. |
| `!printstatshistory` | Generates a formatted lifetime stats document in `logs/stats_history/`. |
| `!printstatsforcampaign` | Generates a formatted campaign stats document in `logs/stats_history/`. |
| `!showmatchactivity` | Prints the current match activity log to the console. |
| `!printmatchactivity` | Manually writes the match activity log to `logs/match_activity/`. |
| `!savestatsforme` | Manually synchronizes and saves your stats to the SQLite database. |
| `!resetstatsforme` | Resets your personal stats (automatically creates a safety backup first). |
| `!exportstatshistory [label]` | Exports your lifetime profile to a KeyValues file in `logs/stats_history/`. |
| `!importstatshistory <profile>` | Restores lifetime stats from a previously exported `.cfg` profile. |

### Admin Commands (Root Flag Required)
| Command | Description |
| :--- | :--- |
| `sm_savestatshistory` | Forces a database sync and save for all currently connected players. |
| `sm_resetstatshistory` | Wipes the entire database (creates automatic backups for all online players if enabled). |

---

## ⚙️ Configuration (CVars)

The configuration file is automatically generated at `cfg/sourcemod/l4d2_stats_history.cfg`:

```sourcepawn
// Enable or disable the Stats History & Activity plugin.
l4d2_stats_history_enable "1"

// Auto-print stats files to logs/stats_history/:
// 0 = Disabled, 1 = On Finale Win, 2 = End of every chapter & Finale Win.
l4d2_stats_history_print_mode "2"

// Automatically create a safety backup before resetting player stats? (0=No, 1=Yes)
l4d2_stats_history_reset_backup "1"

// Save player stats to the database immediately when they disconnect? (0=No, 1=Yes)
l4d2_stats_history_save_disconnect "1"

// Include weapon statistics breakdown in print files and console outputs? (0=No, 1=Yes)
l4d2_stats_history_print_weapon_stats "1"

// Include damage received breakdown in print files and console outputs? (0=No, 1=Yes)
l4d2_stats_history_print_damage_received "1"

// Enable or disable writing activity timeline logs to logs/match_activity/? (0=No, 1=Yes)
l4d2_stats_history_activity_logs_enable "1"

// Display activity events live in the in-game chat HUD? (0=No, 1=Yes)
l4d2_stats_history_activity_chat "1"
```

---

## 📁 File Structure

```text
left4dead2/
└── addons/
    └── sourcemod/
        ├── configs/
        ├── data/
        │   └── sqlite/
        │       └── l4d2_stats_history.db      <-- SQLite database storing player lifetime stats
        ├── logs/
        │   ├── match_activity/                 <-- Narrative timeline logs per chapter/finale
        │   └── stats_history/                  <-- Export profiles, backups, and summary sheets
        └── plugins/
            └── l4d2_stats_history.smx
```

---

## 🔧 Requirements & Installation

1. **[SourceMod](https://www.sourcemod.net/)** (v1.11 or higher recommended)
2. **[Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696)**

### Installation:
1. Place the compiled `l4d2_stats_history.smx` into your server's `addons/sourcemod/plugins/` directory.
2. Restart your server or run `sm plugins load l4d2_stats_history` in the server console.
3. Configure settings via `cfg/sourcemod/l4d2_stats_history.cfg`.

*(Optional)* Supports **[L4D2 Custom Survivor Bot Names](https://github.com/grotovu/L4D2-Custom-Survivor-Bot-Names)** for dynamic bot name integration.
