/*
*	Stats History (Lifetime Tracker) and Activity Log (Per Campaign)
*   Developed with the help of AI assistance.
*/

#define PLUGIN_VERSION		"1.0.0"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3
#define MAX_BOT_CHARS 32
#define MAX_ENTITIES_TRACKED 8192

#define WPNID_PAINKILLERS 15
#define WPNID_ADRENALINE   23

#define DMG_SOURCE_COMMON       0
#define DMG_SOURCE_WITCH        1
#define DMG_SOURCE_TANK_PUNCH   2
#define DMG_SOURCE_TANK_ROCK    3
#define DMG_SOURCE_HUNTER       4
#define DMG_SOURCE_SMOKER       5
#define DMG_SOURCE_JOCKEY       6
#define DMG_SOURCE_CHARGER      7
#define DMG_SOURCE_SPITTER      8
#define DMG_SOURCE_BOOMER       9
#define DMG_SOURCE_FF           10
#define DMG_SOURCE_FALL         11
#define DMG_SOURCE_ENV_FIRE     12
#define DMG_SOURCE_HAZARD       13
#define DMG_SOURCE_SELF         14
#define DMG_SOURCE_INCAP_DECAY  15
#define DMG_SOURCE_WORLD        16
#define MAX_DMG_SOURCES         17 

#define ADD_STAT(%1,%2) do{if(!g_bIsBot[%1]){if(g_bStatsLoaded[%1]){g_Lifetime[%1].%2++;g_Campaign[%1].%2++;}}else{if(g_iClientChar[%1]>=0&&g_iClientChar[%1]<MAX_BOT_CHARS){g_BotCampaign[g_iClientChar[%1]].%2++;}}}while(g_bMacroLoopFalse)

#define ADD_STAT_VAL(%1,%2,%3) do{if(!g_bIsBot[%1]){if(g_bStatsLoaded[%1]){g_Lifetime[%1].%2+=%3;g_Campaign[%1].%2+=%3;}}else{if(g_iClientChar[%1]>=0&&g_iClientChar[%1]<MAX_BOT_CHARS){g_BotCampaign[g_iClientChar[%1]].%2+=%3;}}}while(g_bMacroLoopFalse)

#define SUB_STAT(%1,%2) do{if(!g_bIsBot[%1]){if(g_bStatsLoaded[%1]){if(g_Lifetime[%1].%2>0)g_Lifetime[%1].%2--;if(g_Campaign[%1].%2>0)g_Campaign[%1].%2--;}}else{if(g_iClientChar[%1]>=0&&g_iClientChar[%1]<MAX_BOT_CHARS){if(g_BotCampaign[g_iClientChar[%1]].%2>0)g_BotCampaign[g_iClientChar[%1]].%2--;}}}while(g_bMacroLoopFalse)

// ====================================================================================================
//					OPTIMIZED STATIC CACHES
// ====================================================================================================

char g_sDamageSourceKeys[MAX_DMG_SOURCES][32] = {
    "infected", "witch_claw", "tank_punch", "tank_rock", "hunter",
    "smoker", "jockey", "charger", "spitter", "boomer",
    "friendly_fire", "fall_damage", "env_fire", "map_hazard", "self_damage", "incap_decay", "world_damage"
};

WeaponStats g_WeaponLifetimeCache[MAXPLAYERS + 1][128];
WeaponStats g_WeaponCampaignCache[MAXPLAYERS + 1][128];
WeaponStats g_WeaponBotCampaignCache[MAX_BOT_CHARS][128];

int g_iDamageLifetimeCache[MAXPLAYERS + 1][MAX_DMG_SOURCES];
int g_iDamageCampaignCache[MAXPLAYERS + 1][MAX_DMG_SOURCES];
int g_iDamageBotCampaignCache[MAX_BOT_CHARS][MAX_DMG_SOURCES];

int g_iClientActiveWeaponID[MAXPLAYERS + 1] = { -1, ... };

bool g_bMacroLoopFalse = false;

// ====================================================================================================
//					WEAPON KILL CACHE GLOBALS
// ====================================================================================================
StringMap g_smCleanToID;
char g_sCleanWeaponNames[128][64];
int g_iCleanWeaponCount = 0;

int g_iCachedCommonKills[MAXPLAYERS + 1][128];
int g_iCachedTotalKills[MAXPLAYERS + 1][128];

// ====================================================================================================
//					STRUCTS
// ====================================================================================================
enum struct LifetimeStats
{
	int   totalSeconds;
	int   campaignsPlayed;
	int   campaignsWon;
	int   totalRestarts;
	
	int   incaps;
	int   deaths;
	
	int   medkitsUsed;
	int   medkitsShared;
	int   healedByTeammate;
	int   pillsUsed;
	int   pillsShared;
	int   adrenalineUsed;
	int   adrenalineShared;
	int   defibsUsed;
	int   defibbedByTeammate;

	int   revivesTotal;
	int   revivesRecord;
	int   revivedByTeammate;
	int   revivedByTeammateRecord;
	
	int   protectionsTotal;
	int   protectionsRecord;
	int   protectedByTeammate;
	int   protectedByTeammateRecord;
	
	int   ledgeGrabs;
	int   ledgeRescues;
	
	int   ffDamageTotal;
	int   ffDamageRecord;
	int   ffReceivedTotal;
	int   ffReceivedRecord;
	
	int   molotovsThrown;
	int   molotovKills;
	int   pipesThrown;
	int   pipeKills;
	int   bilesThrown;
	int   bileHits;
	
	int   killsCommon;
	int   killsTank;
	int   killsWitch;
	int   killsSmoker;
	int   killsHunter;
	int   killsBoomer;
	int   killsCharger;
	int   killsJockey;
	int   killsSpitter;
	
	int   tankDamage;
	int   witchDamage;
	
	int   hunterSkeets;
	int   witchCrowns;
	int   tongueCuts;
	int   selfRescues;
	int   chargerLevels;
	int   rockSkeets;
	int   spitterKilledPreSpat;
	int   jockeyDeadstops;
	int   hunterDeadstops;
	
	int   witchesStartled;
	int   timesBoomed;
	int   carAlarmsTriggered;

	void Init() {
		this.Reset();
	}

	void Reset() {
		this.totalSeconds = 0; this.campaignsPlayed = 0; this.campaignsWon = 0; this.totalRestarts = 0;
		this.incaps = 0; this.deaths = 0;
		
		this.medkitsUsed = 0; this.medkitsShared = 0; this.healedByTeammate = 0; this.pillsUsed = 0; this.pillsShared = 0;
		this.adrenalineUsed = 0; this.adrenalineShared = 0; this.defibsUsed = 0; this.defibbedByTeammate = 0;
		
		this.revivesTotal = 0; this.revivesRecord = 0;
		this.revivedByTeammate = 0; this.revivedByTeammateRecord = 0;
		
		this.protectionsTotal = 0; this.protectionsRecord = 0;
		this.protectedByTeammate = 0; this.protectedByTeammateRecord = 0;
		
		this.ledgeGrabs = 0;
		this.ledgeRescues = 0;
		
		this.ffDamageTotal = 0; this.ffDamageRecord = 0;
		this.ffReceivedTotal = 0; this.ffReceivedRecord = 0;
		
		this.molotovsThrown = 0; this.molotovKills = 0;
		this.pipesThrown = 0; this.pipeKills = 0;
		this.bilesThrown = 0; this.bileHits = 0;
		
		this.killsCommon = 0;
		this.killsTank = 0;
		this.killsWitch = 0;
		this.killsSmoker = 0;
		this.killsHunter = 0;
		this.killsBoomer = 0;
		this.killsCharger = 0;
		this.killsJockey = 0;
		this.killsSpitter = 0;
		
		this.tankDamage = 0;
		this.witchDamage = 0;
		
		this.hunterSkeets = 0;
		this.witchCrowns = 0;
		this.tongueCuts = 0;
		this.selfRescues = 0;
		this.chargerLevels = 0;
		this.rockSkeets = 0;
		this.spitterKilledPreSpat = 0;
		this.jockeyDeadstops = 0;
		this.hunterDeadstops = 0;
		
		this.witchesStartled = 0;
		this.timesBoomed = 0;
		this.carAlarmsTriggered = 0;
	}
	
	void Destroy() {
	
	}
}

enum struct WeaponStats
{
	int fired;
	int hits;
	int kills;
	int headshots;

	int killsCommon;
	int killsSmoker;
	int killsBoomer;
	int killsHunter;
	int killsSpitter;
	int killsJockey;
	int killsCharger;
	int killsTank;
	int killsWitch;

	int tankDamage;
	int witchDamage;
	
	int hunterSkeets;
	int witchCrowns;
	int tongueCuts;
	int chargerLevels;
	int rockSkeets;
	int spitterKilledPreSpat;
}

// ====================================================================================================
//					GLOBALS
// ====================================================================================================
char g_sAuthID[MAXPLAYERS + 1][64];

ArrayList g_hActivityLog;

LifetimeStats g_Lifetime[MAXPLAYERS + 1];
LifetimeStats g_Campaign[MAXPLAYERS + 1];

bool g_bStatsLoaded[MAXPLAYERS + 1];

bool g_bPrintedThisRound = false;

int g_iLastHitTick[MAXPLAYERS + 1];
int g_iLastHeadshotTick[MAXPLAYERS + 1];
bool g_bIsWitchHeadshot[MAX_ENTITIES_TRACKED];

int g_iLastDeathTick[MAXPLAYERS + 1];
char g_sLastDeathWeapon[MAXPLAYERS + 1][64];
char g_sLastCleanWeapon[MAXPLAYERS + 1][64];

int g_iPendingSkeetAttacker[MAXPLAYERS + 1];
float g_fLastSkeetTime[MAXPLAYERS + 1];

bool g_bTankAlive[MAXPLAYERS + 1];
int  g_iTankLastHealth[MAXPLAYERS + 1];
int g_iDamageToTank[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iLastRockSkeetTick[MAXPLAYERS + 1] = { -1, ... };

int  g_iWitchDamageAwarded[MAX_ENTITIES_TRACKED];
int g_iWitchFirstHitTick[MAX_ENTITIES_TRACKED];
bool g_bIsWitchEntity[MAX_ENTITIES_TRACKED];
int g_iDamageToWitch[MAX_ENTITIES_TRACKED][MAXPLAYERS + 1];

bool g_bIsCommonEntity[MAX_ENTITIES_TRACKED];

int g_iPinnedBy[MAXPLAYERS + 1];
int g_iLastPinnedBy[MAXPLAYERS + 1];
float g_fPinEndTime[MAXPLAYERS + 1];
bool g_bPinResolutionLogged[MAXPLAYERS + 1] = { false, ... };
char g_sLastDamageSource[MAXPLAYERS + 1][64];

bool g_bTongueCutThisFrame[MAXPLAYERS + 1] = { false, ... };
float g_fCarryEndTime[MAXPLAYERS + 1] = { 0.0, ... };

int g_iLastBoomerPopper = 0;
float g_fLastBoomerExplodeTime = 0.0;

bool g_bSpitterHasSpit[MAXPLAYERS + 1] = { false, ... };
float g_fLastSpitEntryTime[MAXPLAYERS + 1] = { 0.0, ... };

int g_iLastShover[MAXPLAYERS + 1];
float g_fLastShoveTime[MAXPLAYERS + 1];

int g_iCansPoured = 0;
bool g_bIsPressingButton[MAXPLAYERS + 1] = { false, ... };
float g_fLastButtonPressTime[MAX_ENTITIES_TRACKED];
float g_fLastButtonCompleteTime[MAX_ENTITIES_TRACKED];
float g_fLastButtonCancelTime[MAX_ENTITIES_TRACKED];
float g_fLastFinaleTriggerTime;

float g_fLastGameTime;
Handle g_hSecondTimer = null;

char g_sCurrentCampaignID[64];
char g_sPlayerLastCampaignID[MAXPLAYERS + 1][64];

bool g_bIsTransitionOrRestart = false;

StringMap g_smPlayerLastCampaign;
bool g_bHasWonCampaign[MAXPLAYERS + 1];

StringMap g_smWeaponMap;
char g_sLastRawWeapon[MAXPLAYERS + 1][64];

StringMap g_smGuns;
StringMap g_smMelees;
StringMap g_smCarryables;

int g_iClientChar[MAXPLAYERS + 1];
bool g_bIsBot[MAXPLAYERS + 1];

LifetimeStats g_BotCampaign[MAX_BOT_CHARS];

ConVar g_cvEnable;
ConVar g_cvPrintMode;
ConVar g_cvSaveOnDisconnect;
ConVar g_cvPrintDamageReceived;
ConVar g_cvResetBackup;
ConVar g_cvPrintWeaponStats;
ConVar g_cvActivityLogsEnable;
ConVar g_cvActivityChatEnable;

Database g_hDatabase = null;
bool g_bIsDatabaseSaving = false;
KeyValues g_kvCampaignCache = null;

// for activity log
int g_iCampaignTime;
ConVar g_cvDifficulty;
ConVar g_cvBotNames[8] = { null, ... };
ConVar g_cvPillsDecay = null;
char g_sCachedBotNames[8][64];
bool g_bTankBurnt[MAXPLAYERS + 1];
bool g_bWitchBurnt[MAX_ENTITIES_TRACKED];
int g_iLastFFAttacker[MAXPLAYERS + 1];
bool g_bIsBlackAndWhite[MAXPLAYERS + 1] = { false, ... };

int g_iPreDamageHealth[MAXPLAYERS + 1];

int g_iAccumulatedDamage[MAXPLAYERS + 1][MAX_DMG_SOURCES];
int g_iPreAccumHealth[MAXPLAYERS + 1][MAX_DMG_SOURCES];
Handle g_hDamageTimer[MAXPLAYERS + 1][MAX_DMG_SOURCES];

// ====================================================================================================
//					PLUGIN START & END
// ====================================================================================================
public Plugin myinfo =
{
	name        = "[L4D2] Stats History and Activity Log",
	author      = "EagleRaviOrange",
	version     = PLUGIN_VERSION
}

public void OnPluginStart()
{
	g_smPlayerLastCampaign = new StringMap();
	g_smCleanToID = new StringMap();
	g_kvCampaignCache = new KeyValues("CampaignCache");
	
	g_hActivityLog = new ArrayList(512);
	g_cvDifficulty = FindConVar("z_difficulty");
	g_cvPillsDecay = FindConVar("pain_pills_decay_rate");
	
	g_smGuns = new StringMap();
    static const char guns[][] = { "m16_rifle", "rifle_ak47", "rifle_desert", "rifle_sg552", "smg", "smg_silenced", "smg_mp5", "pumpshotgun", "shotgun_chrome", "autoshotgun", "shotgun_spas", "hunting_rifle", "sniper_military", "sniper_awp", "sniper_scout", "pistol", "pistol_magnum", "m60", "grenade_launcher" };
    for (int i = 0; i < sizeof(guns); i++) g_smGuns.SetValue(guns[i], true);

    g_smMelees = new StringMap();
    static const char melees[][] = { "fireaxe", "katana", "machete", "baseball_bat", "crowbar", "cricket_bat", "tonfa", "electric_guitar", "frying_pan", "golfclub", "knife", "pitchfork", "shovel", "riot_shield", "melee", "chainsaw", "guitar" };
    for (int i = 0; i < sizeof(melees); i++) g_smMelees.SetValue(melees[i], true);

    g_smCarryables = new StringMap();
    static const char carryables[][] = { "gascan", "propanetank", "oxygentank", "fireworkcrate", "gnome", "cola_bottles", "adrenaline", "pain_pills" };
    for (int i = 0; i < sizeof(carryables); i++) g_smCarryables.SetValue(carryables[i], true);
	
	char sDir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sDir, sizeof(sDir), "logs/stats_history");
	if (!DirExists(sDir)) CreateDirectory(sDir, 511);
	
	BuildPath(Path_SM, sDir, sizeof(sDir), "logs/match_activity");
	if (!DirExists(sDir)) CreateDirectory(sDir, 511);
	
	BuildPath(Path_SM, sDir, sizeof(sDir), "data");
	if (!DirExists(sDir)) CreateDirectory(sDir, 511);
	
	g_cvEnable = CreateConVar("l4d2_stats_history_enable", "1", "Enable the Stats History tracking plugin?");
	g_cvPrintMode = CreateConVar("l4d2_stats_history_print_mode", "2", "0=Disabled, 1=Print at Finale Win, 2=Print at end of every chapter.");
	g_cvResetBackup = CreateConVar("l4d2_stats_history_reset_backup", "1", "Should a safety backup be created automatically before running reset commands? (0=No, 1=Yes)", _, true, 0.0, true, 1.0);
	g_cvSaveOnDisconnect = CreateConVar("l4d2_stats_history_save_disconnect", "1", "Should stats be saved to the database when a player disconnects? (Set to 0 during testing/modding)", _, true, 0.0, true, 1.0);
	g_cvPrintWeaponStats = CreateConVar("l4d2_stats_history_print_weapon_stats", "1", "Should weapon statistics be printed in show commands and log sheets? (0=No, 1=Yes)");
	g_cvPrintDamageReceived = CreateConVar("l4d2_stats_history_print_damage_received", "1", "Should damage received statistics be printed in show commands and log sheets? (0=No, 1=Yes)");	
	g_cvActivityLogsEnable = CreateConVar("l4d2_stats_history_activity_logs_enable", "1", "Enable or disable writing activity logs to files? (0=No, 1=Yes)");
	g_cvActivityChatEnable = CreateConVar("l4d2_stats_history_activity_chat", "1", "Display activity logs in the in-game chat HUD? (0=No, 1=Yes)");
	
	g_cvBotNames[0] = FindConVar("l4d2_custom_bot_name_nick");
	g_cvBotNames[1] = FindConVar("l4d2_custom_bot_name_rochelle");
	g_cvBotNames[2] = FindConVar("l4d2_custom_bot_name_coach");
	g_cvBotNames[3] = FindConVar("l4d2_custom_bot_name_ellis");
	g_cvBotNames[4] = FindConVar("l4d2_custom_bot_name_bill");
	g_cvBotNames[5] = FindConVar("l4d2_custom_bot_name_zoey");
	g_cvBotNames[6] = FindConVar("l4d2_custom_bot_name_francis");
	g_cvBotNames[7] = FindConVar("l4d2_custom_bot_name_louis");
	
	for (int i = 0; i < 8; i++) {
		if (g_cvBotNames[i] != null) {
			g_cvBotNames[i].AddChangeHook(OnBotNameCVarChanged);
		}
	}
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPostAdminCheck(i);
		}
	}

	RegAdminCmd("sm_resetstatshistory", CmdResetHistory, ADMFLAG_ROOT);
	RegAdminCmd("sm_savestatshistory", CmdSaveHistory, ADMFLAG_ROOT, "Saves all currently loaded player stats to the database.");
	RegConsoleCmd("sm_resetstatsforme", CmdResetStatsForMe);
	RegConsoleCmd("sm_showstatshistory", CmdShowHistory);
	RegConsoleCmd("sm_showstatsforcampaign", CmdShowCampaignHistory);
	RegConsoleCmd("sm_exportstatshistory", CmdExportHistory);
	RegConsoleCmd("sm_importstatshistory", CmdImportHistory);
	RegConsoleCmd("sm_printstatshistory", CmdPrintHistory);
	RegConsoleCmd("sm_printstatsforcampaign", CmdPrintCampaignHistory);
	RegConsoleCmd("sm_showbotsstatsforcampaign", CmdShowBotsCampaignHistory);
	RegConsoleCmd("sm_savestatsforme", CmdSaveForMe, "Manually syncs your current stats to the database.");
	
	RegConsoleCmd("sm_showmatchactivity", CmdShowMatchActivity, "Print current campaign activity log to the console.");
	RegConsoleCmd("sm_printmatchactivity", CmdPrintMatchActivity, "Manually write current campaign activity log to file.");

	HookEvent("player_death",       Event_PlayerDeath);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("weapon_fire",        Event_WeaponFire);
	HookEvent("player_hurt",        Event_PlayerHurt);
	HookEvent("witch_killed", 		Event_WitchKilled);
	HookEvent("finale_win",         Event_FinaleWin);
	HookEvent("map_transition",     Event_MapTransition);
	HookEvent("mission_lost",       Event_MissionLost);
	HookEvent("round_end",          Event_RoundEnd);
	HookEvent("round_start",        Event_RoundStart);
	HookEvent("heal_success",       Event_HealSuccess);
	HookEvent("pills_used",         Event_PillsUsed);
	HookEvent("adrenaline_used",    Event_AdrenalineUsed);
	HookEvent("defibrillator_used", Event_DefibUsed);
	HookEvent("revive_success",     Event_ReviveSuccess);
	HookEvent("award_earned",       Event_AwardEarned);
	HookEvent("weapon_given", 		Event_WeaponGiven);
	HookEvent("infected_hurt",        Event_InfectedHurt);
	HookEvent("tank_spawn",           Event_TankSpawn);
	HookEvent("tank_rock_killed", 	  Event_TankRockKilled);
	HookEvent("player_spawn",         Event_PlayerSpawn);
	HookEvent("player_bot_replace",   Event_BotReplacedPlayer);
	HookEvent("bot_player_replace",   Event_PlayerReplacedBot);
	
	HookEvent("boomer_exploded", 	  Event_BoomerExploded);
	HookEvent("ability_use",          Event_AbilityUse);
	
    HookEvent("tongue_grab",          Event_PinStart);
    HookEvent("lunge_pounce",         Event_PinStart);
    HookEvent("jockey_ride",          Event_PinStart);
	HookEvent("charger_carry_start",  Event_PinStart);
    HookEvent("charger_pummel_start", Event_PinStart);

    HookEvent("tongue_release",       Event_PinStop);
	HookEvent("choke_stopped",        Event_PinStop);
	
    HookEvent("tongue_pull_stopped",  Event_PinStop);
    HookEvent("pounce_stopped",       Event_PinStop);
    HookEvent("jockey_ride_end",      Event_PinStop);
	HookEvent("charger_carry_end",    Event_PinStop);
    HookEvent("charger_pummel_end",   Event_PinStop);
	
	HookEvent("charger_impact", 	  Event_ChargerImpact);
	HookEvent("entered_spit", 		  Event_EnteredSpit);

	HookEvent("tongue_pull_stopped",  Event_TonguePullStopped);
	HookEvent("player_shoved",        Event_PlayerShoved);
	
	HookEvent("hunter_punched", 	  Event_HunterPunched);
	HookEvent("jockey_punched", 	  Event_JockeyPunched);
	
	HookEvent("witch_harasser_set",   Event_WitchHarasserSet);
	HookEvent("player_now_it",        Event_PlayerNowIt);
	HookEvent("player_ledge_grab",    Event_PlayerLedgeGrab);
	
	HookEvent("strongman_bell_knocked_off", Event_StrongmanBellKnockedOff);
    HookEvent("stashwhacker_game_won",      Event_StashwhackerGameWon);
    HookEvent("punched_clown",              Event_PunchedClown);
	
	HookEvent("triggered_car_alarm", Event_TriggeredCarAlarm);
	
	HookEvent("finale_start", Event_FinaleStart, EventHookMode_PostNoCopy);
	HookEvent("gauntlet_finale_start", Event_GauntletFinaleStart, EventHookMode_PostNoCopy);
	HookEvent("finale_bridge_lowering", Event_FinaleBridgeLowering);
	
	HookEvent("survival_round_start", Event_SurvivalRoundStart, EventHookMode_PostNoCopy);
	
	HookEvent("gascan_pour_completed", Event_GasCanPourCompleted);
	HookEvent("gascan_pour_interrupted", Event_GasCanPourInterrupted);
	
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("weapon_drop", Event_WeaponDrop);
	HookEvent("weapon_drop_to_prop", Event_WeaponDrop);

	HookEntityOutput("func_button", "OnPressed", Output_OnButtonInstant);
	HookEntityOutput("func_button_timed", "OnPressed", Output_OnButtonStartHold);
	HookEntityOutput("func_button_timed", "OnTimeUp", Output_OnButtonCompleteHold);
	HookEntityOutput("func_button_timed", "OnUnpressed", Output_OnButtonCancelHold);
	HookEntityOutput("trigger_finale", "OnFirstStageStart", Output_OnFinaleTriggered);
	HookEntityOutput("trigger_finale", "OnStartFinale", Output_OnFinaleTriggered);
	HookEntityOutput("trigger_finale", "OnTrigger", Output_OnFinaleTriggered);
	HookEntityOutput("trigger_finale", "OnFinaleStart", Output_OnFinaleTriggered);
	
	HookEntityOutput("point_prop_use_target", "OnUseFinished", Output_OnUseFinished);
	HookEntityOutput("point_script_use_target", "OnUseFinished", Output_OnUseFinished);
	
	UserMsg pzDmgMsg = GetUserMessageId("PZDmgMsg");
    if (pzDmgMsg != INVALID_MESSAGE_ID) {
        HookUserMessage(pzDmgMsg, Msg_PZDmgMsg, true);
    }
	
	if (g_hSecondTimer == null) {
		g_hSecondTimer = CreateTimer(1.0, Timer_SecondTicker, _, TIMER_REPEAT);
	}
	
	AutoExecConfig(true, "l4d2_stats_history");
	
	for (int i = 0; i < MAX_BOT_CHARS; i++) {
		g_BotCampaign[i].Init();
	}
	
	InitWeaponMap();
	InitDatabase();
}

void InitWeaponMap()
{
    if (g_smWeaponMap != null) delete g_smWeaponMap;
    g_smWeaponMap = new StringMap();

    MapWeapon("pistol", "pistol");
    MapWeapon("weapon_pistol", "pistol");
	MapWeapon("dual_pistols", "pistol");
    MapWeapon("pistol_magnum", "pistol_magnum");
    MapWeapon("weapon_pistol_magnum", "pistol_magnum");
    MapWeapon("magnum", "pistol_magnum");
    MapWeapon("weapon_magnum", "pistol_magnum");

    MapWeapon("smg", "smg");
    MapWeapon("weapon_smg", "smg");
    MapWeapon("uzi", "smg");
    MapWeapon("smg_silenced", "smg_silenced");
    MapWeapon("weapon_smg_silenced", "smg_silenced");
    MapWeapon("smg_mp5", "smg_mp5");
    MapWeapon("weapon_smg_mp5", "smg_mp5");

    MapWeapon("rifle", "m16_rifle");
    MapWeapon("weapon_rifle", "m16_rifle");
    MapWeapon("rifle_ak47", "rifle_ak47");
    MapWeapon("weapon_rifle_ak47", "rifle_ak47");
    MapWeapon("rifle_desert", "rifle_desert");
    MapWeapon("weapon_rifle_desert", "rifle_desert");
    MapWeapon("rifle_sg552", "rifle_sg552");
    MapWeapon("weapon_rifle_sg552", "rifle_sg552");
    MapWeapon("rifle_m60", "m60");
    MapWeapon("weapon_rifle_m60", "m60");

    MapWeapon("pumpshotgun", "pumpshotgun");
    MapWeapon("weapon_pumpshotgun", "pumpshotgun");
    MapWeapon("shotgun_chrome", "shotgun_chrome");
    MapWeapon("weapon_shotgun_chrome", "shotgun_chrome");
    MapWeapon("autoshotgun", "autoshotgun");
    MapWeapon("weapon_autoshotgun", "autoshotgun");
    MapWeapon("shotgun_spas", "shotgun_spas");
    MapWeapon("weapon_shotgun_spas", "shotgun_spas");

    MapWeapon("hunting_rifle", "hunting_rifle");
    MapWeapon("weapon_hunting_rifle", "hunting_rifle");
    MapWeapon("sniper_military", "sniper_military");
    MapWeapon("weapon_sniper_military", "sniper_military");
    MapWeapon("sniper_scout", "sniper_scout");
    MapWeapon("weapon_sniper_scout", "sniper_scout");
    MapWeapon("sniper_awp", "sniper_awp");
    MapWeapon("weapon_sniper_awp", "sniper_awp");

    MapWeapon("grenade_launcher", "grenade_launcher");
    MapWeapon("weapon_grenade_launcher", "grenade_launcher");
    MapWeapon("chainsaw", "chainsaw");
    MapWeapon("weapon_chainsaw", "chainsaw");
	
    MapWeapon("molotov", "fire");
	MapWeapon("entityflame", "fire");
	MapWeapon("inferno", "fire");
	MapWeapon("gascan", "fire");
	MapWeapon("weapon_gascan", "fire");
    MapWeapon("weapon_molotov", "fire");
	MapWeapon("Fireworkcrate", "fire");
	MapWeapon("fire_cracker_blast", "fire");
	
	MapWeapon("pipe_bomb", "pipe_bomb");
    MapWeapon("pipe_bomb_projectile", "pipe_bomb");
    MapWeapon("weapon_pipe_bomb", "pipe_bomb");
    MapWeapon("propanetank", "pipe_bomb");
    MapWeapon("weapon_propanetank", "pipe_bomb");
    MapWeapon("oxygentank", "pipe_bomb");
    MapWeapon("weapon_oxygentank", "pipe_bomb");    
	
    MapWeapon("vomitjar", "vomitjar");
    MapWeapon("weapon_vomitjar", "vomitjar");

    MapWeapon("fireaxe", "fireaxe");
    MapWeapon("katana", "katana");
    MapWeapon("machete", "machete");
    MapWeapon("baseball_bat", "baseball_bat");
    MapWeapon("crowbar", "crowbar");
    MapWeapon("cricket_bat", "cricket_bat");
    MapWeapon("tonfa", "tonfa");
    MapWeapon("frying_pan", "frying_pan");
    MapWeapon("golfclub", "golfclub");
    MapWeapon("knife", "knife");
    MapWeapon("pitchfork", "pitchfork");
    MapWeapon("shovel", "shovel");
    MapWeapon("electric_guitar", "guitar");
    MapWeapon("guitar", "guitar");
    MapWeapon("riot_shield", "riot_shield");
    MapWeapon("riotshield", "riot_shield");
}

void MapWeapon(const char[] raw, const char[] clean)
{
    char rawLower[64], cleanLower[64];
    strcopy(rawLower, sizeof(rawLower), raw);
    StringToLowerCase(rawLower);
    strcopy(cleanLower, sizeof(cleanLower), clean);
    StringToLowerCase(cleanLower);

    g_smWeaponMap.SetString(rawLower, cleanLower);
    
    int id;
    if (!g_smCleanToID.GetValue(cleanLower, id)) {
        if (g_iCleanWeaponCount < 128) {
            id = g_iCleanWeaponCount;
            strcopy(g_sCleanWeaponNames[id], sizeof(g_sCleanWeaponNames[]), cleanLower);
            g_smCleanToID.SetValue(cleanLower, id);
            g_iCleanWeaponCount++;
        }
    }
}

void InitDatabase()
{
    char sError[255];
    KeyValues kv = new KeyValues("connection");
    kv.SetString("driver", "sqlite");
    kv.SetString("database", "l4d2_stats_history.db");

    g_hDatabase = SQL_ConnectCustom(kv, sError, sizeof(sError), true);
    delete kv;

    if (g_hDatabase == null) {
        LogError("[Stats SQLite] Database connection failed: %s", sError);
        return;
    }

    g_hDatabase.Query(SQL_Callback_GenericError, "PRAGMA journal_mode = WAL;");
    g_hDatabase.Query(SQL_Callback_GenericError, "PRAGMA synchronous = NORMAL;");
    g_hDatabase.Query(SQL_Callback_GenericError, "PRAGMA busy_timeout = 5000;");

    g_hDatabase.Query(SQL_Callback_TableCreated, 
        "CREATE TABLE IF NOT EXISTS player_stats ("
        ... "steamid TEXT PRIMARY KEY, "
        ... "seconds_played INTEGER DEFAULT 0, campaigns_played INTEGER DEFAULT 0, campaigns_won INTEGER DEFAULT 0, restarts INTEGER DEFAULT 0, "
        ... "incaps INTEGER DEFAULT 0, deaths INTEGER DEFAULT 0, "
        ... "medkits_used INTEGER DEFAULT 0, medkits_shared INTEGER DEFAULT 0, healed_by_teammate INTEGER DEFAULT 0, pills_used INTEGER DEFAULT 0, "
        ... "pills_shared INTEGER DEFAULT 0, adrenaline_used INTEGER DEFAULT 0, adrenaline_shared INTEGER DEFAULT 0, defibs_used INTEGER DEFAULT 0, "
        ... "defibbed_by_teammate INTEGER DEFAULT 0, revives_total INTEGER DEFAULT 0, revives_record INTEGER DEFAULT 0, revived_by_teammate INTEGER DEFAULT 0, "
        ... "revived_by_teammate_record INTEGER DEFAULT 0, protections_total INTEGER DEFAULT 0, protections_record INTEGER DEFAULT 0, protected_by_teammate INTEGER DEFAULT 0, ledge_grabs INTEGER DEFAULT 0, ledge_rescues INTEGER DEFAULT 0, "
        ... "protected_by_teammate_record INTEGER DEFAULT 0, ff_damage_total INTEGER DEFAULT 0, ff_damage_record INTEGER DEFAULT 0, ff_received_total INTEGER DEFAULT 0, "
        ... "ff_received_record INTEGER DEFAULT 0, molotovs_thrown INTEGER DEFAULT 0, molotov_kills INTEGER DEFAULT 0, pipes_thrown INTEGER DEFAULT 0, "
        ... "pipe_kills INTEGER DEFAULT 0, biles_thrown INTEGER DEFAULT 0, bile_hits INTEGER DEFAULT 0, kills_common INTEGER DEFAULT 0, "
        ... "kills_tank INTEGER DEFAULT 0, kills_witch INTEGER DEFAULT 0, kills_smoker INTEGER DEFAULT 0, kills_hunter INTEGER DEFAULT 0, "
        ... "kills_boomer INTEGER DEFAULT 0, kills_charger INTEGER DEFAULT 0, kills_jockey INTEGER DEFAULT 0, kills_spitter INTEGER DEFAULT 0, "
        ... "tank_damage INTEGER DEFAULT 0, witch_damage INTEGER DEFAULT 0, hunter_skeets INTEGER DEFAULT 0, witch_crowns INTEGER DEFAULT 0, "
        ... "tongue_cuts INTEGER DEFAULT 0, self_rescues INTEGER DEFAULT 0, charger_levels INTEGER DEFAULT 0, rock_skeets INTEGER DEFAULT 0, spitter_killed_pre_spat INTEGER DEFAULT 0, "
        ... "jockey_deadstops INTEGER DEFAULT 0, hunter_deadstops INTEGER DEFAULT 0,"
		 ... "witches_startled INTEGER DEFAULT 0, times_boomed INTEGER DEFAULT 0, car_alarms_triggered INTEGER DEFAULT 0"
        ... ");"
    );

    g_hDatabase.Query(SQL_Callback_TableCreated,
        "CREATE TABLE IF NOT EXISTS weapon_stats ("
        ... "steamid TEXT, weapon TEXT, fired INTEGER DEFAULT 0, hits INTEGER DEFAULT 0, kills INTEGER DEFAULT 0, headshots INTEGER DEFAULT 0, "
        ... "kills_common INTEGER DEFAULT 0, kills_smoker INTEGER DEFAULT 0, kills_boomer INTEGER DEFAULT 0, kills_hunter INTEGER DEFAULT 0, "
        ... "kills_spitter INTEGER DEFAULT 0, kills_jockey INTEGER DEFAULT 0, kills_charger INTEGER DEFAULT 0, kills_tank INTEGER DEFAULT 0, "
        ... "kills_witch INTEGER DEFAULT 0, tank_damage INTEGER DEFAULT 0, witch_damage INTEGER DEFAULT 0, "
        ... "hunter_skeets INTEGER DEFAULT 0, witch_crowns INTEGER DEFAULT 0, tongue_cuts INTEGER DEFAULT 0, "
        ... "charger_levels INTEGER DEFAULT 0, rock_skeets INTEGER DEFAULT 0, spitter_killed_pre_spat INTEGER DEFAULT 0, "
        ... "PRIMARY KEY (steamid, weapon)"
        ... ");"
    );
	
    g_hDatabase.Query(SQL_Callback_TableCreated,
        "CREATE TABLE IF NOT EXISTS damage_received_stats ("
        ... "steamid TEXT, source TEXT, damage INTEGER DEFAULT 0, PRIMARY KEY (steamid, source)"
        ... ");"
    );
}

public void SQL_Callback_TableCreated(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null) {
        LogError("[Stats SQLite] Table creation failed: %s", error);
    }
}

public void OnPluginEnd()
{
    SaveAndWriteAllStats();
    
    if (g_smGuns != null) { delete g_smGuns; g_smGuns = null; }
    if (g_smMelees != null) { delete g_smMelees; g_smMelees = null; }
    if (g_smCarryables != null) { delete g_smCarryables; g_smCarryables = null; }
    
    for (int i = 1; i <= MaxClients; i++) {
        g_Lifetime[i].Destroy();
        g_Campaign[i].Destroy();
    }
    
    if (g_smPlayerLastCampaign != null) {
        delete g_smPlayerLastCampaign;
        g_smPlayerLastCampaign = null;
    }
    
    if (g_hSecondTimer != null) {
        KillTimer(g_hSecondTimer);
        g_hSecondTimer = null;
    }
    
    for (int i = 0; i < MAX_BOT_CHARS; i++) {
        g_BotCampaign[i].Destroy();
    }
    
    if (g_kvCampaignCache != null) {
        delete g_kvCampaignCache;
        g_kvCampaignCache = null;
    }
    
    if (g_hActivityLog != null) {
        delete g_hActivityLog;
        g_hActivityLog = null;
    }
    
    g_hDatabase = null;

    if (g_smCleanToID != null) {
        delete g_smCleanToID;
        g_smCleanToID = null;
    }
    
    if (g_smWeaponMap != null) {
        delete g_smWeaponMap;
        g_smWeaponMap = null;
    }
}

public Action Timer_SecondTicker(Handle timer)
{
    if (!g_cvEnable.BoolValue) return Plugin_Continue;

    float fCurrentTime = GetGameTime();
    if (fCurrentTime == g_fLastGameTime) return Plugin_Continue;
    g_fLastGameTime = fCurrentTime;

    // if (!L4D_HasAnySurvivorLeftSafeArea()) return Plugin_Continue;
	
	g_iCampaignTime++;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR) { 
            ADD_STAT(i, totalSeconds);
            
            if (!IsFakeClient(i) && !L4D_IsSurvivalMode() && !StrEqual(g_sPlayerLastCampaignID[i], g_sCurrentCampaignID)) {
                ADD_STAT(i, campaignsPlayed);
                strcopy(g_sPlayerLastCampaignID[i], sizeof(g_sPlayerLastCampaignID[]), g_sCurrentCampaignID);
                if (g_sAuthID[i][0] != '\0') {
                    g_smPlayerLastCampaign.SetString(g_sAuthID[i], g_sCurrentCampaignID);
                }
            }

            if (IsPlayerAlive(i) && !L4D_IsPlayerIncapacitated(i)) {
                bool isBW = view_as<bool>(GetEntProp(i, Prop_Send, "m_bIsOnThirdStrike"));
                if (isBW && !g_bIsBlackAndWhite[i]) {
                    g_bIsBlackAndWhite[i] = true;
                    char sName[32];
                    GetPlayerNameSafe(i, sName, sizeof(sName));
                    LogActivity("%s is now Black and White!", sName);
                }
                else if (!isBW && g_bIsBlackAndWhite[i]) {
                    g_bIsBlackAndWhite[i] = false;
                    char sName[32];
                    GetPlayerNameSafe(i, sName, sizeof(sName));
                    LogActivity("%s is no longer Black and White.", sName);
                }
            }
        }
    }
    return Plugin_Continue;
}

// ====================================================================================================
//					FILE LOADING & SAVING
// ====================================================================================================
void SaveAndWriteAllStats()
{
    if (g_hDatabase == null || g_bIsDatabaseSaving) return;
    
	FlushAllCaches();
	
    g_bIsDatabaseSaving = true;
    Transaction hTr = new Transaction();
    int count = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (g_bStatsLoaded[i] && IsClientInGame(i)) {
            AddPlayerToTransaction(i, hTr);
            count++;
        }
    }
    
    if (count > 0) {
        SQL_ExecuteTransaction(g_hDatabase, hTr, SQL_SaveSuccess, SQL_SaveFailure, 0, DBPrio_Low);
    } else {
        delete hTr;
        g_bIsDatabaseSaving = false;
    }
}

public void SQL_SaveSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    g_bIsDatabaseSaving = false;
}

public void SQL_SaveFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    g_bIsDatabaseSaving = false;
    LogError("[Stats History] Transaction failed: %s", error);
}

public void OnClientPostAdminCheck(int client)
{
    g_sLastDamageSource[client][0] = '\0';
	g_iClientActiveWeaponID[client] = -1;
    g_sPlayerLastCampaignID[client][0] = '\0';
	g_sLastRawWeapon[client][0] = '\0';
	
	g_iLastDeathTick[client] = -1;
	g_sLastDeathWeapon[client][0] = '\0';
	g_sLastCleanWeapon[client][0] = '\0';
	
	g_fCarryEndTime[client] = 0.0;
	g_fLastSpitEntryTime[client] = 0.0;
	
	g_bTongueCutThisFrame[client] = false;
	g_bPinResolutionLogged[client] = false;
	g_bSpitterHasSpit[client] = false;

	UpdateClientCacheDelayed(client);

	for (int i = 0; i < 128; i++) {
        g_iCachedCommonKills[client][i] = 0;
        g_iCachedTotalKills[client][i] = 0;
		g_iLastRockSkeetTick[client] = -1;
    }

    if (!IsFakeClient(client))
    {
        g_Lifetime[client].Init();
        g_bStatsLoaded[client] = false;
        g_bHasWonCampaign[client] = false;
        
        g_Campaign[client].Init();

        CreateTimer(1.0, Timer_LoadStats, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }	
}

public void OnClientPutInServer(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamage, OnPlayerTakeDamage);

    SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public Action Timer_LoadStats(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Stop;

    if (GetClientAuthId(client, AuthId_SteamID64, g_sAuthID[client], sizeof(g_sAuthID[]))) {
        if (!g_smPlayerLastCampaign.GetString(g_sAuthID[client], g_sPlayerLastCampaignID[client], sizeof(g_sPlayerLastCampaignID[]))) {
            g_sPlayerLastCampaignID[client][0] = '\0';
        }

        RestoreCampaignStats(client, g_sAuthID[client]);

        LoadPlayerStats(client, g_sAuthID[client]);
    } else {
        CreateTimer(2.0, Timer_LoadStats, userid, TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    g_bTankAlive[client] = false;
    g_iTankLastHealth[client] = 0;
    g_iPinnedBy[client] = 0;
    g_iLastPinnedBy[client] = 0;
    g_fPinEndTime[client] = 0.0;
	g_iPendingSkeetAttacker[client] = 0;
	g_bIsPressingButton[client] = false;
	g_bIsBlackAndWhite[client] = false;
	g_bTongueCutThisFrame[client] = false;
	g_bPinResolutionLogged[client] = false;
	g_bSpitterHasSpit[client] = false;
	
	FlushKillsCache(client);
	
	SDKUnhook(client, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
    SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);

    if (g_bStatsLoaded[client]) {
        if (g_cvSaveOnDisconnect.BoolValue && !g_bIsTransitionOrRestart) {
            SavePlayerStatsToDB(client);
        }
        g_bStatsLoaded[client] = false;
    }

    if (g_bIsTransitionOrRestart && g_sAuthID[client][0] != '\0') {
        CacheCampaignStats(client, g_sAuthID[client]);
    }

    g_Lifetime[client].Destroy();
	
    if (!g_bIsTransitionOrRestart) {
        g_Campaign[client].Destroy();
    }

	for (int i = 0; i < MAX_DMG_SOURCES; i++)
	{
		if (g_hDamageTimer[client][i] != null)
		{
			KillTimer(g_hDamageTimer[client][i]);
			g_hDamageTimer[client][i] = null;
		}
		g_iAccumulatedDamage[client][i] = 0;
	}
	
    g_sAuthID[client][0] = '\0';
}

void LoadPlayerStats(int client, const char[] auth)
{
    if (g_hDatabase == null) return;

    int userId = GetClientUserId(client);
    char sQuery[2048];
    
    g_hDatabase.Format(sQuery, sizeof(sQuery), 
        "SELECT seconds_played, campaigns_played, campaigns_won, restarts, " ...
        "incaps, deaths, " ...
        "medkits_used, medkits_shared, healed_by_teammate, pills_used, pills_shared, " ...
        "adrenaline_used, adrenaline_shared, defibs_used, defibbed_by_teammate, " ...
        "revives_total, revives_record, revived_by_teammate, revived_by_teammate_record, " ...
        "protections_total, protections_record, protected_by_teammate, protected_by_teammate_record, ledge_grabs, ledge_rescues, " ...
        "ff_damage_total, ff_damage_record, ff_received_total, ff_received_record, " ...
        "molotovs_thrown, molotov_kills, pipes_thrown, pipe_kills, biles_thrown, bile_hits, " ...
        "kills_common, kills_tank, kills_witch, kills_smoker, kills_hunter, kills_boomer, " ...
        "kills_charger, kills_jockey, kills_spitter, tank_damage, witch_damage, " ...
        "hunter_skeets, witch_crowns, tongue_cuts, self_rescues, charger_levels, rock_skeets, " ...
        "spitter_killed_pre_spat, jockey_deadstops, hunter_deadstops, " ...
		"witches_startled, times_boomed, car_alarms_triggered " ...
        "FROM player_stats WHERE steamid = '%s';", auth);
        
    SQL_TQuery(g_hDatabase, SQL_Callback_LoadPlayerStats, sQuery, userId);
}

public void SQL_Callback_LoadPlayerStats(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientOfUserId(data);
    if (client == 0) return;
    if (results == null) {
        LogError("[Stats SQLite] Error loading player stats for %N: %s", client, error);
		g_bStatsLoaded[client] = true;
        return;
    }

    if (results.FetchRow()) {
        int col = 0;
        g_Lifetime[client].totalSeconds              = results.FetchInt(col++);
        g_Lifetime[client].campaignsPlayed           = results.FetchInt(col++);
        g_Lifetime[client].campaignsWon              = results.FetchInt(col++);
        g_Lifetime[client].totalRestarts             = results.FetchInt(col++);
		g_Lifetime[client].incaps                    = results.FetchInt(col++);
        g_Lifetime[client].deaths                    = results.FetchInt(col++);
        g_Lifetime[client].medkitsUsed               = results.FetchInt(col++);
        g_Lifetime[client].medkitsShared             = results.FetchInt(col++);
        g_Lifetime[client].healedByTeammate          = results.FetchInt(col++);
        g_Lifetime[client].pillsUsed                 = results.FetchInt(col++);
        g_Lifetime[client].pillsShared               = results.FetchInt(col++);
        g_Lifetime[client].adrenalineUsed            = results.FetchInt(col++);
        g_Lifetime[client].adrenalineShared          = results.FetchInt(col++);
        g_Lifetime[client].defibsUsed                = results.FetchInt(col++);
        g_Lifetime[client].defibbedByTeammate        = results.FetchInt(col++);
        g_Lifetime[client].revivesTotal              = results.FetchInt(col++);
        g_Lifetime[client].revivesRecord             = results.FetchInt(col++);
        g_Lifetime[client].revivedByTeammate         = results.FetchInt(col++);
        g_Lifetime[client].revivedByTeammateRecord   = results.FetchInt(col++);
        g_Lifetime[client].protectionsTotal          = results.FetchInt(col++);
        g_Lifetime[client].protectionsRecord         = results.FetchInt(col++);
        g_Lifetime[client].protectedByTeammate       = results.FetchInt(col++);
        g_Lifetime[client].protectedByTeammateRecord = results.FetchInt(col++);
		g_Lifetime[client].ledgeGrabs                = results.FetchInt(col++);
        g_Lifetime[client].ledgeRescues              = results.FetchInt(col++);
        g_Lifetime[client].ffDamageTotal             = results.FetchInt(col++);
        g_Lifetime[client].ffDamageRecord            = results.FetchInt(col++);
        g_Lifetime[client].ffReceivedTotal           = results.FetchInt(col++);
        g_Lifetime[client].ffReceivedRecord          = results.FetchInt(col++);
        g_Lifetime[client].molotovsThrown            = results.FetchInt(col++);
        g_Lifetime[client].molotovKills              = results.FetchInt(col++);
        g_Lifetime[client].pipesThrown               = results.FetchInt(col++);
        g_Lifetime[client].pipeKills                 = results.FetchInt(col++);
        g_Lifetime[client].bilesThrown               = results.FetchInt(col++);
        g_Lifetime[client].bileHits                  = results.FetchInt(col++);
        g_Lifetime[client].killsCommon               = results.FetchInt(col++);
        g_Lifetime[client].killsTank                 = results.FetchInt(col++);
        g_Lifetime[client].killsWitch                = results.FetchInt(col++);
        g_Lifetime[client].killsSmoker               = results.FetchInt(col++);
        g_Lifetime[client].killsHunter               = results.FetchInt(col++);
        g_Lifetime[client].killsBoomer               = results.FetchInt(col++);
        g_Lifetime[client].killsCharger              = results.FetchInt(col++);
        g_Lifetime[client].killsJockey               = results.FetchInt(col++);
        g_Lifetime[client].killsSpitter              = results.FetchInt(col++);
        g_Lifetime[client].tankDamage                = results.FetchInt(col++);
        g_Lifetime[client].witchDamage               = results.FetchInt(col++);
        g_Lifetime[client].hunterSkeets              = results.FetchInt(col++);
        g_Lifetime[client].witchCrowns               = results.FetchInt(col++);
        g_Lifetime[client].tongueCuts                = results.FetchInt(col++);
		g_Lifetime[client].selfRescues               = results.FetchInt(col++);
        g_Lifetime[client].chargerLevels             = results.FetchInt(col++);
        g_Lifetime[client].rockSkeets                = results.FetchInt(col++);
        g_Lifetime[client].spitterKilledPreSpat      = results.FetchInt(col++);
        g_Lifetime[client].jockeyDeadstops           = results.FetchInt(col++);
        g_Lifetime[client].hunterDeadstops           = results.FetchInt(col++);
		g_Lifetime[client].witchesStartled           = results.FetchInt(col++);
        g_Lifetime[client].timesBoomed               = results.FetchInt(col++);
		g_Lifetime[client].carAlarmsTriggered        = results.FetchInt(col++);
		
		if (g_Lifetime[client].campaignsPlayed < g_Lifetime[client].campaignsWon) {
            g_Lifetime[client].campaignsPlayed = g_Lifetime[client].campaignsWon;
        }
    }

    char auth[64];
    if (GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth))) {
        char sQuery[512];
        g_hDatabase.Format(sQuery, sizeof(sQuery), 
            "SELECT weapon, fired, hits, kills, headshots, kills_common, kills_smoker, kills_boomer, " ...
            "kills_hunter, kills_spitter, kills_jockey, kills_charger, kills_tank, kills_witch, " ...
            "tank_damage, witch_damage, hunter_skeets, witch_crowns, tongue_cuts, charger_levels, " ...
            "rock_skeets, spitter_killed_pre_spat FROM weapon_stats WHERE steamid = '%s';", auth);
        SQL_TQuery(g_hDatabase, SQL_Callback_LoadWeaponStats, sQuery, data);
    }
}

public void SQL_Callback_LoadWeaponStats(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientOfUserId(data);
    if (client == 0 || results == null) return;
	
	if (results == null) {
        LogError("[Stats SQLite] Error loading weapon stats for %N: %s", client, error);
        g_bStatsLoaded[client] = true;
        return;
    }

    for (int i = 0; i < 128; i++) {
        g_WeaponLifetimeCache[client][i].fired = 0;
        g_WeaponLifetimeCache[client][i].hits = 0;
        g_WeaponLifetimeCache[client][i].kills = 0;
        g_WeaponLifetimeCache[client][i].headshots = 0;
        g_WeaponLifetimeCache[client][i].killsCommon = 0;
        g_WeaponLifetimeCache[client][i].killsSmoker = 0;
        g_WeaponLifetimeCache[client][i].killsBoomer = 0;
        g_WeaponLifetimeCache[client][i].killsHunter = 0;
        g_WeaponLifetimeCache[client][i].killsSpitter = 0;
        g_WeaponLifetimeCache[client][i].killsJockey = 0;
        g_WeaponLifetimeCache[client][i].killsCharger = 0;
        g_WeaponLifetimeCache[client][i].killsTank = 0;
        g_WeaponLifetimeCache[client][i].killsWitch = 0;
        g_WeaponLifetimeCache[client][i].tankDamage = 0;
        g_WeaponLifetimeCache[client][i].witchDamage = 0;
        g_WeaponLifetimeCache[client][i].hunterSkeets = 0;
        g_WeaponLifetimeCache[client][i].witchCrowns = 0;
        g_WeaponLifetimeCache[client][i].tongueCuts = 0;
        g_WeaponLifetimeCache[client][i].chargerLevels = 0;
        g_WeaponLifetimeCache[client][i].rockSkeets = 0;
        g_WeaponLifetimeCache[client][i].spitterKilledPreSpat = 0;
    }

    while (results.FetchRow()) {
        char weapon[64];
        results.FetchString(0, weapon, sizeof(weapon));

        int id;
        if (g_smCleanToID.GetValue(weapon, id)) {
            g_WeaponLifetimeCache[client][id].fired                 = results.FetchInt(1);
            g_WeaponLifetimeCache[client][id].hits                  = results.FetchInt(2);
            g_WeaponLifetimeCache[client][id].kills                 = results.FetchInt(3);
            g_WeaponLifetimeCache[client][id].headshots             = results.FetchInt(4);
            g_WeaponLifetimeCache[client][id].killsCommon           = results.FetchInt(5);
            g_WeaponLifetimeCache[client][id].killsSmoker           = results.FetchInt(6);
            g_WeaponLifetimeCache[client][id].killsBoomer           = results.FetchInt(7);
            g_WeaponLifetimeCache[client][id].killsHunter           = results.FetchInt(8);
            g_WeaponLifetimeCache[client][id].killsSpitter          = results.FetchInt(9);
            g_WeaponLifetimeCache[client][id].killsJockey           = results.FetchInt(10);
            g_WeaponLifetimeCache[client][id].killsCharger          = results.FetchInt(11);
            g_WeaponLifetimeCache[client][id].killsTank             = results.FetchInt(12);
            g_WeaponLifetimeCache[client][id].killsWitch            = results.FetchInt(13);
            g_WeaponLifetimeCache[client][id].tankDamage            = results.FetchInt(14);
            g_WeaponLifetimeCache[client][id].witchDamage           = results.FetchInt(15);
            g_WeaponLifetimeCache[client][id].hunterSkeets          = results.FetchInt(16);
            g_WeaponLifetimeCache[client][id].witchCrowns           = results.FetchInt(17);
            g_WeaponLifetimeCache[client][id].tongueCuts            = results.FetchInt(18);
            g_WeaponLifetimeCache[client][id].chargerLevels         = results.FetchInt(19);
            g_WeaponLifetimeCache[client][id].rockSkeets            = results.FetchInt(20);
            g_WeaponLifetimeCache[client][id].spitterKilledPreSpat  = results.FetchInt(21);
        }
    }

    char auth[64];
    if (GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth))) {
        char sQuery[256];
        g_hDatabase.Format(sQuery, sizeof(sQuery), "SELECT source, damage FROM damage_received_stats WHERE steamid = '%s';", auth);
        SQL_TQuery(g_hDatabase, SQL_Callback_LoadDamageReceivedStats, sQuery, data);
    } else {
        g_bStatsLoaded[client] = true;
    }
}

public void SQL_Callback_LoadDamageReceivedStats(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientOfUserId(data);
    if (client == 0) return;

    if (results == null) {
        LogError("[Stats SQLite] Error loading damage received stats: %s", error);
		g_bStatsLoaded[client] = true;
        return;
    }

    for (int i = 0; i < MAX_DMG_SOURCES; i++) {
        g_iDamageLifetimeCache[client][i] = 0;
    }

    while (results.FetchRow()) {
        char source[64];
        results.FetchString(0, source, sizeof(source));
        int dmgVal = results.FetchInt(1);

        int sourceID = GetDamageSourceID(source);
        g_iDamageLifetimeCache[client][sourceID] = dmgVal;
    }

    g_bStatsLoaded[client] = true;
}

void AddPlayerToTransaction(int client, Transaction hTr)
{
    if (g_hDatabase == null || !g_bStatsLoaded[client] || hTr == null) return;
	
    FlushKillsCache(client);

    char auth[64];
    if (!GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth))) return;

	if (g_Lifetime[client].campaignsPlayed < g_Lifetime[client].campaignsWon) {
        g_Lifetime[client].campaignsPlayed = g_Lifetime[client].campaignsWon;
    }
    if (g_Campaign[client].campaignsPlayed < g_Campaign[client].campaignsWon) {
        g_Campaign[client].campaignsPlayed = g_Campaign[client].campaignsWon;
    }

    char sQuery[8192]; 
    char sSmallQuery[1024];

    g_hDatabase.Format(sQuery, sizeof(sQuery), 
        "INSERT OR REPLACE INTO player_stats (" ...
        "steamid, seconds_played, campaigns_played, campaigns_won, restarts, " ...
		"incaps, deaths, " ...
        "medkits_used, medkits_shared, healed_by_teammate, pills_used, pills_shared, " ...
        "adrenaline_used, adrenaline_shared, defibs_used, defibbed_by_teammate, " ...
        "revives_total, revives_record, revived_by_teammate, revived_by_teammate_record, " ...
        "protections_total, protections_record, protected_by_teammate, protected_by_teammate_record, ledge_grabs, ledge_rescues, " ...
        "ff_damage_total, ff_damage_record, ff_received_total, ff_received_record, " ...
        "molotovs_thrown, molotov_kills, pipes_thrown, pipe_kills, biles_thrown, bile_hits, " ...
        "kills_common, kills_tank, kills_witch, kills_smoker, kills_hunter, kills_boomer, " ...
        "kills_charger, kills_jockey, kills_spitter, tank_damage, witch_damage, " ...
        "hunter_skeets, witch_crowns, tongue_cuts, self_rescues, charger_levels, rock_skeets, " ...
        "spitter_killed_pre_spat, jockey_deadstops, hunter_deadstops, " ...
		"witches_startled, times_boomed, car_alarms_triggered " ...
        ") VALUES ('%s', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d);",
        auth, 
        g_Lifetime[client].totalSeconds, g_Lifetime[client].campaignsPlayed, g_Lifetime[client].campaignsWon, g_Lifetime[client].totalRestarts,
		g_Lifetime[client].incaps, g_Lifetime[client].deaths,
        g_Lifetime[client].medkitsUsed, g_Lifetime[client].medkitsShared, g_Lifetime[client].healedByTeammate, g_Lifetime[client].pillsUsed, 
        g_Lifetime[client].pillsShared, g_Lifetime[client].adrenalineUsed, g_Lifetime[client].adrenalineShared, g_Lifetime[client].defibsUsed, 
        g_Lifetime[client].defibbedByTeammate, g_Lifetime[client].revivesTotal, g_Lifetime[client].revivesRecord, g_Lifetime[client].revivedByTeammate, 
        g_Lifetime[client].revivedByTeammateRecord, g_Lifetime[client].protectionsTotal, g_Lifetime[client].protectionsRecord, g_Lifetime[client].protectedByTeammate, 
        g_Lifetime[client].protectedByTeammateRecord, g_Lifetime[client].ledgeGrabs, g_Lifetime[client].ledgeRescues, g_Lifetime[client].ffDamageTotal, g_Lifetime[client].ffDamageRecord, g_Lifetime[client].ffReceivedTotal, 
        g_Lifetime[client].ffReceivedRecord, g_Lifetime[client].molotovsThrown, g_Lifetime[client].molotovKills, g_Lifetime[client].pipesThrown, 
        g_Lifetime[client].pipeKills, g_Lifetime[client].bilesThrown, g_Lifetime[client].bileHits, g_Lifetime[client].killsCommon, 
        g_Lifetime[client].killsTank, g_Lifetime[client].killsWitch, g_Lifetime[client].killsSmoker, g_Lifetime[client].killsHunter, 
        g_Lifetime[client].killsBoomer, g_Lifetime[client].killsCharger, g_Lifetime[client].killsJockey, g_Lifetime[client].killsSpitter, 
        g_Lifetime[client].tankDamage, g_Lifetime[client].witchDamage, g_Lifetime[client].hunterSkeets, g_Lifetime[client].witchCrowns, 
        g_Lifetime[client].tongueCuts, g_Lifetime[client].selfRescues, g_Lifetime[client].chargerLevels, g_Lifetime[client].rockSkeets, g_Lifetime[client].spitterKilledPreSpat,
        g_Lifetime[client].jockeyDeadstops, g_Lifetime[client].hunterDeadstops,
		g_Lifetime[client].witchesStartled, g_Lifetime[client].timesBoomed, g_Lifetime[client].carAlarmsTriggered
    );
    hTr.AddQuery(sQuery);

    for (int i = 0; i < g_iCleanWeaponCount; i++) {
        WeaponStats wS;
		wS = g_WeaponLifetimeCache[client][i];
        if (wS.fired == 0 && wS.kills == 0) continue;

        char wName[64];
        strcopy(wName, sizeof(wName), g_sCleanWeaponNames[i]);

        g_hDatabase.Format(sSmallQuery, sizeof(sSmallQuery),
            "INSERT OR REPLACE INTO weapon_stats (" ...
            "steamid, weapon, fired, hits, kills, headshots, kills_common, kills_smoker, kills_boomer, " ...
            "kills_hunter, kills_spitter, kills_jockey, kills_charger, kills_tank, kills_witch, " ...
            "tank_damage, witch_damage, hunter_skeets, witch_crowns, tongue_cuts, charger_levels, " ...
            "rock_skeets, spitter_killed_pre_spat" ...
            ") VALUES ('%s', '%s', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d);",
            auth, wName, wS.fired, wS.hits, wS.kills, wS.headshots,
            wS.killsCommon, wS.killsSmoker, wS.killsBoomer, wS.killsHunter, wS.killsSpitter, wS.killsJockey, wS.killsCharger, wS.killsTank, wS.killsWitch,
            wS.tankDamage, wS.witchDamage, wS.hunterSkeets, wS.witchCrowns, wS.tongueCuts, wS.chargerLevels, wS.rockSkeets, wS.spitterKilledPreSpat
        );	
        hTr.AddQuery(sSmallQuery);
    }

    for (int i = 0; i < MAX_DMG_SOURCES; i++) {
        int dmgVal = g_iDamageLifetimeCache[client][i];
        if (dmgVal == 0) continue;

        g_hDatabase.Format(sSmallQuery, sizeof(sSmallQuery),
            "INSERT OR REPLACE INTO damage_received_stats (steamid, source, damage) VALUES ('%s', '%s', %d);",
            auth, g_sDamageSourceKeys[i], dmgVal
        );
        hTr.AddQuery(sSmallQuery);
    }
}

void SavePlayerStatsToDB(int client)
{
    if (g_hDatabase == null || !g_bStatsLoaded[client]) return;
    
    Transaction hTr = new Transaction();
    AddPlayerToTransaction(client, hTr);
    SQL_ExecuteTransaction(g_hDatabase, hTr, SQL_Transaction_Success, SQL_Transaction_Failure, GetClientUserId(client), DBPrio_Low);
    
    g_bStatsLoaded[client] = false; 
}

public void SQL_Transaction_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{

}

public void SQL_Transaction_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    int client = GetClientOfUserId(data);
    if (client > 0)
    {
        LogError("[Stats History] Transaction failed for player %N at query index %d: %s", client, failIndex, error);
    }
    else
    {
        LogError("[Stats History] Transaction failed for a disconnected player at query index %d: %s", failIndex, error);
    }
}

// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnMapStart() 
{
    g_fLastGameTime = 0.0;
	g_iCansPoured = 0;
	g_fLastFinaleTriggerTime = 0.0;
    
    for (int i = 1; i <= MaxClients; i++) {
        g_bHasWonCampaign[i] = false;
		g_iLastShover[i] = 0;
        g_fLastShoveTime[i] = 0.0;
		g_fLastButtonPressTime[i] = 0.0;
		g_fLastButtonCompleteTime[i] = 0.0;
		g_fLastButtonCancelTime[i] = 0.0;
    }
	for (int i = 1; i <= MaxClients; i++) {
		g_bIsPressingButton[i] = false;
	}
    
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));

    if (!g_bIsTransitionOrRestart && (L4D_IsFirstMapInScenario() || g_sCurrentCampaignID[0] == '\0')) 
    {
        Format(g_sCurrentCampaignID, sizeof(g_sCurrentCampaignID), "%s_%d", mapName, GetTime());
        
        if (g_smPlayerLastCampaign != null) {
            g_smPlayerLastCampaign.Clear();
        }
        
        if (g_kvCampaignCache != null) {
            delete g_kvCampaignCache;
            g_kvCampaignCache = new KeyValues("CampaignCache");
        }
        
        for (int i = 1; i <= MaxClients; i++) {
            g_Campaign[i].Reset();
        }

        WeaponStats zeroWeapon;
        for (int i = 0; i < MAX_BOT_CHARS; i++) {
            g_BotCampaign[i].Reset();
            for (int w = 0; w < 128; w++) {
                g_WeaponBotCampaignCache[i][w] = zeroWeapon;
            }
            for (int d = 0; d < MAX_DMG_SOURCES; d++) {
                g_iDamageBotCampaignCache[i][d] = 0;
            }
        }
        g_hActivityLog.Clear();
    }
	
    if (g_hSecondTimer != null) {
        KillTimer(g_hSecondTimer);
        g_hSecondTimer = null;
    }
    g_hSecondTimer = CreateTimer(1.0, Timer_SecondTicker, _, TIMER_REPEAT);
	
	LogActivity(">>> Map: %s <<<", mapName);
	
	HookColaBuyerEntity();
}

public void OnMapEnd()
{
    g_bIsTransitionOrRestart = true;
	if (g_hSecondTimer != null) {
        KillTimer(g_hSecondTimer);
        g_hSecondTimer = null;
    }
}

public void OnGameFrame()
{
    float curTime = GetGameTime();
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_iPinnedBy[i] > 0)
        {
            if (!IsReallyPinnedBy(i, g_iPinnedBy[i]))
            {
                int attacker = g_iPinnedBy[i];
                
                g_iPinnedBy[i] = 0;
                g_fPinEndTime[i] = curTime;

                int rescuer = 0;
                if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && g_iLastShover[attacker] > 0 && IsClientInGame(g_iLastShover[attacker]))
                {
                    if ((curTime - g_fLastShoveTime[attacker]) < 0.8)
                    {
                        rescuer = g_iLastShover[attacker];
                    }
                }

                DataPack pack;
                CreateDataTimer(0.1, Timer_ResolvePinStop, pack, TIMER_FLAG_NO_MAPCHANGE);
                pack.WriteCell(GetClientUserId(i));
                pack.WriteCell(attacker > 0 ? GetClientUserId(attacker) : 0);
                pack.WriteCell(rescuer > 0 ? GetClientUserId(rescuer) : 0);
                pack.WriteString("programmatic_break");
            }
        }
    }
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {    
    g_bPrintedThisRound = false;
	g_bIsTransitionOrRestart = false;
	g_iCansPoured = 0;
	g_fLastFinaleTriggerTime = 0.0;
	
	for (int i = 1; i <= MaxClients; i++) {
        g_bTankAlive[i] = false;
        g_bTankBurnt[i] = false;
        g_iTankLastHealth[i] = 0;
		g_iLastRockSkeetTick[i] = -1;
		g_iPinnedBy[i] = 0;
        g_iLastPinnedBy[i] = 0;
        g_fPinEndTime[i] = 0.0;
		g_fLastButtonPressTime[i] = 0.0;
		g_fLastButtonCompleteTime[i] = 0.0;
		g_fLastButtonCancelTime[i] = 0.0;
		g_fCarryEndTime[i] = 0.0;
		g_fLastSpitEntryTime[i] = 0.0;
    }
	for (int i = 1; i <= MaxClients; i++) {
		g_bIsPressingButton[i] = false;
	}

    for (int w = 0; w < MAX_ENTITIES_TRACKED; w++) {
        g_iWitchDamageAwarded[w] = 0;
        g_bWitchBurnt[w] = false;
    }
}

void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast) {
    if (!g_cvEnable.BoolValue || L4D_IsSurvivalMode()) return;

    g_bIsTransitionOrRestart = true;
    
    char rescuedRoster[512], deceasedRoster[512];
    rescuedRoster[0] = '\0';
    deceasedRoster[0] = '\0';

    bool bGnomeRescued = false;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR) {
            char sName[32];
            GetPlayerNameSafe(i, sName, sizeof(sName));
            
            if (IsPlayerEscaped(i)) {
                if (rescuedRoster[0] == '\0') {
                    strcopy(rescuedRoster, sizeof(rescuedRoster), sName);
                } else {
                    Format(rescuedRoster, sizeof(rescuedRoster), "%s, %s", rescuedRoster, sName);
                }
                
                if (IsCarryingGnome(i)) {
                    bGnomeRescued = true;
                }
            } else {
                if (deceasedRoster[0] == '\0') {
                    strcopy(deceasedRoster, sizeof(deceasedRoster), sName);
                } else {
                    Format(deceasedRoster, sizeof(deceasedRoster), "%s, %s", deceasedRoster, sName);
                }
            }
        }
    }

    if (rescuedRoster[0] != '\0') {
        LogActivity("Rescued Alive: %s", rescuedRoster);
    }
    if (deceasedRoster[0] != '\0') {
        LogActivity("Deceased / Left for Dead: %s", deceasedRoster);
    }
    if (bGnomeRescued) {
        LogActivity("The Gnome was successfully rescued!");
    }

    WriteActivityLog();

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR) {
            
            if (!IsFakeClient(i) && !StrEqual(g_sPlayerLastCampaignID[i], g_sCurrentCampaignID)) {
                ADD_STAT(i, campaignsPlayed);
                strcopy(g_sPlayerLastCampaignID[i], sizeof(g_sPlayerLastCampaignID[]), g_sCurrentCampaignID);
                if (g_sAuthID[i][0] != '\0') {
                    g_smPlayerLastCampaign.SetString(g_sAuthID[i], g_sCurrentCampaignID);
                }
            }

            if (IsPlayerEscaped(i)) {
                ADD_STAT(i, campaignsWon);
                
                if (!IsFakeClient(i) && !g_bHasWonCampaign[i]) {
                    g_bHasWonCampaign[i] = true;
                    if (g_cvPrintMode.IntValue >= 1) {
                        GeneratePrintFile(i, true);
                        GenerateCampaignPrintFile(i);
                    }
                }
            }
        }
    }
    SaveAndWriteAllStats();
}

bool IsPlayerInRescueArea(int client)
{
    float pos[3];
    GetClientAbsOrigin(client, pos);

    int trigger = -1;
    bool foundTrigger = false;
    
    while ((trigger = FindEntityByClassname(trigger, "trigger_escape")) != -1)
    {
        foundTrigger = true;
        
        float mins[3], maxs[3], origin[3];
        GetEntPropVector(trigger, Prop_Send, "m_Collision.m_vecMins", mins);
        GetEntPropVector(trigger, Prop_Send, "m_Collision.m_vecMaxs", maxs);
        GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", origin);

        float absMins[3], absMaxs[3];
        absMins[0] = mins[0] + origin[0];
        absMins[1] = mins[1] + origin[1];
        absMins[2] = mins[2] + origin[2];
        
        absMaxs[0] = maxs[0] + origin[0];
        absMaxs[1] = maxs[1] + origin[1];
        absMaxs[2] = maxs[2] + origin[2];

        if (pos[0] >= absMins[0] && pos[0] <= absMaxs[0] &&
            pos[1] >= absMins[1] && pos[1] <= absMaxs[1] &&
            pos[2] >= absMins[2] && pos[2] <= absMaxs[2])
        {
            return true;
        }
    }
    
    return !foundTrigger;
}

bool IsPlayerEscaped(int client)
{
    if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
    {
        return false;
    }
    
    if (GetEntProp(client, Prop_Send, "m_isIncapacitated") || GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
    {
        return false;
    }
    
    return IsPlayerInRescueArea(client);
}

bool IsCarryingGnome(int client)
{
    if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
    {
        return false;
    }
    
    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (activeWeapon > 0 && IsValidEntity(activeWeapon))
    {
        char classname[64];
        GetEntityClassname(activeWeapon, classname, sizeof(classname));
        if (strcmp(classname, "weapon_gnome") == 0)
        {
            return true;
        }
    }
    
    for (int i = 0; i < 56; i++)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
        if (weapon > 0 && IsValidEntity(weapon))
        {
            char classname[64];
            GetEntityClassname(weapon, classname, sizeof(classname));
            if (strcmp(classname, "weapon_gnome") == 0)
            {
                return true;
            }
        }
    }
    return false;
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) {
    if (!g_cvEnable.BoolValue) return; 

    g_bIsTransitionOrRestart = true;

    char safehouseRoster[512];
    safehouseRoster[0] = '\0';

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i)) {
            char sName[32];
            GetPlayerNameSafe(i, sName, sizeof(sName));
            if (safehouseRoster[0] == '\0') {
                strcopy(safehouseRoster, sizeof(safehouseRoster), sName);
            } else {
                Format(safehouseRoster, sizeof(safehouseRoster), "%s, %s", safehouseRoster, sName);
            }
        }
    }

    if (safehouseRoster[0] != '\0') {
        LogActivity("Reached Safehouse Alive: %s", safehouseRoster);
    } else {
        LogActivity("No survivors reached the safehouse alive.");
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (g_bStatsLoaded[i] && g_cvPrintMode.IntValue >= 2) {
            GeneratePrintFile(i, true);
            GenerateCampaignPrintFile(i);
        }
    }
    SaveAndWriteAllStats();
    WriteActivityLog();
}

void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) {
    g_bIsTransitionOrRestart = true;

    LogActivity(">>> Chapter Restarted (Mission Lost) <<<");

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR) {
            ADD_STAT(i, totalRestarts);
        }
    }
    SaveAndWriteAllStats();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if (!g_cvEnable.BoolValue) return;

    if (L4D_IsSurvivalMode()) {
        if (g_bPrintedThisRound) return; 
        g_bPrintedThisRound = true;
        
        g_bIsTransitionOrRestart = true;
		
		LogActivity(">>> Survival Map Restarted <<<");

        for (int i = 1; i <= MaxClients; i++) {
            if (g_bStatsLoaded[i] && IsValidSurvivor(i)) {
                if (g_cvPrintMode.IntValue >= 1) {
                    GeneratePrintFile(i, true);
                    GenerateCampaignPrintFile(i);
                }
            }
        }
        SaveAndWriteAllStats();
    }
}

public void L4D2_OnSurvivalStart()
{
    int initiator = -1;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidSurvivor(i))
        {
            int useEnt = GetEntPropEnt(i, Prop_Send, "m_hUseEntity");
            if (useEnt > 0 && IsValidEntity(useEnt))
            {
                char classname[64];
                GetEntityClassname(useEnt, classname, sizeof(classname));
                if (strcmp(classname, "trigger_finale") == 0 || strcmp(classname, "func_button") == 0)
                {
                    initiator = i;
                    break;
                }
            }
        }
    }

    char sName[32];
    if (initiator != -1)
    {
        GetPlayerNameSafe(initiator, sName, sizeof(sName));
        LogActivity("%s triggered the console and started Survival!", sName);
    }
    else
    {
        LogActivity("Survival Mode has been started!");
    }
}

public void Event_SurvivalRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    L4D2_OnSurvivalStart();
}

void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR) return;
    
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    if (strcmp(weapon, g_sLastRawWeapon[client]) != 0) {
        strcopy(g_sLastRawWeapon[client], sizeof(g_sLastRawWeapon[]), weapon);
        
        char clean[64];
        GetCleanWeaponName(client, weapon, clean, sizeof(clean));
        
        int weaponID = -1;
        if (g_smCleanToID.GetValue(clean, weaponID)) {
            g_iClientActiveWeaponID[client] = weaponID;
        } else {
            g_iClientActiveWeaponID[client] = -1;
        }
    }
    
    int weaponID = g_iClientActiveWeaponID[client];
    if (weaponID != -1) {
        UpdateWeaponStatID(client, weaponID, 0);
    }
    
    int idx = (weapon[0] == 'w' && strncmp(weapon, "weapon_", 7) == 0) ? 7 : 0;
    
    switch (weapon[idx]) {
        case 'm': {
            if (strcmp(weapon[idx], "molotov") == 0) {
                ADD_STAT(client, molotovsThrown);
				
				char sPlayerName[32];
                GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));
                LogActivity("%s threw a Molotov.", sPlayerName);
            }
        }
        case 'p': {
            if (strcmp(weapon[idx], "pipe_bomb") == 0) {
                ADD_STAT(client, pipesThrown);
				
				char sPlayerName[32];
                GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));
                LogActivity("%s threw a Pipe-Bomb.", sPlayerName);
            }
        }
        case 'v': {
            if (strcmp(weapon[idx], "vomitjar") == 0) {
                ADD_STAT(client, bilesThrown);
				
				char sPlayerName[32];
                GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));
                LogActivity("%s threw a Vomit Jar.", sPlayerName);
            }
        }
    }
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim)) return;
    
    int victimTeam = GetClientTeam(victim);
    
    if (victimTeam == TEAM_SURVIVOR) {
        int postHealth = GetSurvivorTotalHealth(victim);
        int dmg = g_iPreDamageHealth[victim] - postHealth;
        
        int preHealth = g_iPreDamageHealth[victim];
        g_iPreDamageHealth[victim] = postHealth;
        
        if (dmg <= 0) return;
        
        char src[64];
        strcopy(src, sizeof(src), g_sLastDamageSource[victim]);
        if (src[0] == '\0') {
            strcopy(src, sizeof(src), "world_damage");
        }       
        
        UpdateDamageReceivedStat(victim, src, dmg);
        
        bool isAttackerSurvivor = (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR);
        
        if (isAttackerSurvivor && attacker != victim) {
            ADD_STAT_VAL(attacker, ffDamageTotal, dmg);
            
            if (!IsFakeClient(attacker)) {
                if (g_Campaign[attacker].ffDamageTotal > g_Lifetime[attacker].ffDamageRecord)
                    g_Lifetime[attacker].ffDamageRecord = g_Campaign[attacker].ffDamageTotal;
            }
            
            ADD_STAT_VAL(victim, ffReceivedTotal, dmg);
            
            if (!IsFakeClient(victim)) {
                if (g_Campaign[victim].ffReceivedTotal > g_Lifetime[victim].ffReceivedRecord)
                    g_Lifetime[victim].ffReceivedRecord = g_Campaign[victim].ffReceivedTotal;
            }
        }

        if (!isAttackerSurvivor || attacker == victim) 
        {
            ProcessDamageLog(victim, dmg, src, preHealth);
        }
        else
        {
            ProcessDamageLog(victim, dmg, "friendly_fire", preHealth, attacker);
        }
        
        int health = event.GetInt("health");
        if (health > 0) {
            g_sLastDamageSource[victim][0] = '\0';
        }
    }    
    else if (victimTeam == TEAM_INFECTED) {
        if (GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)
        {
            if (g_bTankAlive[victim])
            {
                int currentHealth = GetClientHealth(victim);
                if (currentHealth < 0) currentHealth = 0;

                int actualDmg = g_iTankLastHealth[victim] - currentHealth;
                if (actualDmg > 0) 
                {
                    if (IsSurvivor(attacker))
                    {
                        ADD_STAT_VAL(attacker, tankDamage, actualDmg);
                        
                        g_iDamageToTank[victim][attacker] += actualDmg;
                        
                        int weaponID = g_iClientActiveWeaponID[attacker];
                        if (weaponID != -1) {
                            UpdateWeaponStatID(attacker, weaponID, 13, actualDmg);
                        }
                    }
                    g_iTankLastHealth[victim] = currentHealth;
                }
            }
        }

        if (!IsSurvivor(attacker)) return;
        
        int weaponID = g_iClientActiveWeaponID[attacker];
        if (weaponID != -1) {
            char clean[64];
            strcopy(clean, sizeof(clean), g_sCleanWeaponNames[weaponID]);
            
            if (strcmp(clean, "fire") != 0 && strcmp(clean, "pipe_bomb") != 0 && strcmp(clean, "vomitjar") != 0) {
                int tick = GetGameTickCount();
                if (g_iLastHitTick[attacker] != tick) { 
                    UpdateWeaponStatID(attacker, weaponID, 1); 
                    g_iLastHitTick[attacker] = tick; 
                }
                
                if (event.GetInt("hitgroup") == 1 && g_iLastHeadshotTick[attacker] != tick) { 
                    UpdateWeaponStatID(attacker, weaponID, 2); 
                    g_iLastHeadshotTick[attacker] = tick; 
                }
            }
        }
    }
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
	
	char weapon[64], clean[64];
    bool bIsSpecialFeat = false;
	
	event.GetString("weapon", weapon, sizeof(weapon));
    if (attacker > 0 && IsClientInGame(attacker)) {
        int tick = GetGameTickCount();
        if (tick == g_iLastDeathTick[attacker] && strcmp(weapon, g_sLastDeathWeapon[attacker]) == 0) {
            strcopy(clean, sizeof(clean), g_sLastCleanWeapon[attacker]);
        } else {
            GetCleanWeaponName(attacker, weapon, clean, sizeof(clean));
            g_iLastDeathTick[attacker] = tick;
            strcopy(g_sLastDeathWeapon[attacker], sizeof(g_sLastDeathWeapon[]), weapon);
            strcopy(g_sLastCleanWeapon[attacker], sizeof(g_sLastCleanWeapon[]), clean);
        }
    } else {
        clean[0] = '\0';
    }

    if (victim == 0)
    {
        char victimName[64];
        event.GetString("victimname", victimName, sizeof(victimName));
        if (StrContains(victimName, "witch", false) != -1) {
            return;
        }

        if (IsSurvivor(attacker))
        {            
            CacheCommonKill(attacker, clean);

            if (IsMelee(clean)) {
                UpdateWeaponStat(attacker, clean, 1);
            }

            if (event.GetBool("headshot")) {
                UpdateWeaponStat(attacker, clean, 2);
            }

            if (strcmp(clean, "fire") == 0) {
                ADD_STAT(attacker, molotovKills);
            }
            else if (strcmp(clean, "pipe_bomb") == 0) {
                ADD_STAT(attacker, pipeKills);
            }
            
            ADD_STAT(attacker, killsCommon);
        }
        return;
    }

    if (victim > 0 && victim <= MaxClients) {
        g_bTankAlive[victim] = false;
		g_bIsBlackAndWhite[victim] = false;
        
        if (IsClientInGame(victim) && GetClientTeam(victim) == TEAM_SURVIVOR) {
            ADD_STAT(victim, deaths);

            char sVictim[32];
            GetPlayerNameSafe(victim, sVictim, sizeof(sVictim));
			
			char sCause[64], sPrettyCause[64];
            strcopy(sCause, sizeof(sCause), g_sLastDamageSource[victim]);
            if (sCause[0] == '\0') {
                strcopy(sCause, sizeof(sCause), "world_damage");
            }
            GetPrettySourceName(sCause, sPrettyCause, sizeof(sPrettyCause));

            LogActivity("%s died from %s.", sVictim, sPrettyCause);			
			
			g_sLastDamageSource[victim][0] = '\0';
        }
    }

    if (victim > 0 && victim <= MaxClients && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_INFECTED)
    {
        int pinnedSurvivor = GetPinnedVictim(victim);
        
        if (pinnedSurvivor > 0 && pinnedSurvivor <= MaxClients && IsClientInGame(pinnedSurvivor))
        {
            int rescuer = attacker;
            if (rescuer > 0 && rescuer <= MaxClients && IsClientInGame(rescuer) && GetClientTeam(rescuer) == TEAM_SURVIVOR)
            {
                if (rescuer != pinnedSurvivor)
                {
                    ADD_STAT(pinnedSurvivor, protectedByTeammate);
                    
                    char sVictim[32], sRescuer[32], sInfected[16], prettyWPN[64];
                    GetPlayerNameSafe(pinnedSurvivor, sVictim, sizeof(sVictim));
                    GetPlayerNameSafe(rescuer, sRescuer, sizeof(sRescuer));
                    GetPrettyWeaponName(clean, prettyWPN, sizeof(prettyWPN));
                    
                    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
                    switch (zombieClass) {
                        case 1: strcopy(sInfected, sizeof(sInfected), "Smoker");
                        case 3: strcopy(sInfected, sizeof(sInfected), "Hunter");
                        case 5: strcopy(sInfected, sizeof(sInfected), "Jockey");
                        case 6: strcopy(sInfected, sizeof(sInfected), "Charger");
                        default: strcopy(sInfected, sizeof(sInfected), "Infected");
                    }
                    
                    if (event.GetBool("headshot")) {
                        LogActivity("%s saved %s by killing the %s with %s (Headshot).", sRescuer, sVictim, sInfected, prettyWPN);
                    } else {
                        LogActivity("%s saved %s by killing the %s with %s.", sRescuer, sVictim, sInfected, prettyWPN);
                    }
                    
                    bIsSpecialFeat = true;
                    
                    if (!IsFakeClient(pinnedSurvivor))
                    {
                        if (g_Campaign[pinnedSurvivor].protectedByTeammate > g_Lifetime[pinnedSurvivor].protectedByTeammateRecord)
                            g_Lifetime[pinnedSurvivor].protectedByTeammateRecord = g_Campaign[pinnedSurvivor].protectedByTeammate;
                    }
                }
                else
                {
                    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
                    if (zombieClass == 1)
                    {
                        ADD_STAT(rescuer, selfRescues);
                        
                        char sName[32], prettyWPN[64];
                        GetPlayerNameSafe(rescuer, sName, sizeof(sName));
                        GetPrettyWeaponName(clean, prettyWPN, sizeof(prettyWPN));
                        LogActivity("%s self-rescued by killing the Smoker with %s.", sName, prettyWPN);
                        
                        bIsSpecialFeat = true;
                    }
                }
            }
            g_iPinnedBy[pinnedSurvivor] = 0;
        }
    }

    if (!IsSurvivor(attacker)) return;
    if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim) || GetClientTeam(victim) != TEAM_INFECTED) return;
    
    UpdateWeaponStat(attacker, clean, 3);

    if (strcmp(clean, "fire") == 0) {
        ADD_STAT(attacker, molotovKills);
    }
    else if (strcmp(clean, "pipe_bomb") == 0) {
        ADD_STAT(attacker, pipeKills);
    }
	
    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	
	if ((zombieClass == 3 || zombieClass == 6) && g_iPendingSkeetAttacker[victim] == attacker && (GetGameTime() - g_fLastSkeetTime[victim]) < 0.2) {
        bIsSpecialFeat = true;
    }

    if (zombieClass >= 1 && zombieClass <= 6) {
        if (!bIsSpecialFeat) {
            char sAttacker[32], sVictim[32], prettyWPN[64], sInfected[16];
            GetPlayerNameSafe(attacker, sAttacker, sizeof(sAttacker));
            GetPlayerNameSafe(victim, sVictim, sizeof(sVictim));
            GetPrettyWeaponName(clean, prettyWPN, sizeof(prettyWPN));

            bool isHeadshot = event.GetBool("headshot");

            if (zombieClass == 4) {
                bool hasSpit = g_bSpitterHasSpit[victim];
                g_bSpitterHasSpit[victim] = false;

                if (!hasSpit) {
                    ADD_STAT(attacker, spitterKilledPreSpat);
                    UpdateWeaponStat(attacker, clean, 20);
                    
                    if (isHeadshot) {
                        LogActivity("%s killed a Spitter before she could spit with %s (Headshot).", sAttacker, prettyWPN);
                    } else {
                        LogActivity("%s killed a Spitter before she could spit with %s.", sAttacker, prettyWPN);
                    }
                } else {
                    if (isHeadshot) {
                        LogActivity("%s killed %s (Spitter) with %s (Headshot).", sAttacker, sVictim, prettyWPN);
                    } else {
                        LogActivity("%s killed %s (Spitter) with %s.", sAttacker, sVictim, prettyWPN);
                    }
                }
            }
			else {
                switch (zombieClass) {
                    case 1: strcopy(sInfected, sizeof(sInfected), "Smoker");
                    case 2: strcopy(sInfected, sizeof(sInfected), "Boomer");
                    case 3: strcopy(sInfected, sizeof(sInfected), "Hunter");
                    case 5: strcopy(sInfected, sizeof(sInfected), "Jockey");
                    case 6: strcopy(sInfected, sizeof(sInfected), "Charger");
                }

                if (isHeadshot) {
                    LogActivity("%s killed %s (%s) with %s (Headshot).", sAttacker, sVictim, sInfected, prettyWPN);
                } else {
                    LogActivity("%s killed %s (%s) with %s.", sAttacker, sVictim, sInfected, prettyWPN);
                }
            }
        }
    }
	
    switch (zombieClass) {
        case 1: 
        { 
            ADD_STAT(attacker, killsSmoker); 
            UpdateWeaponStat(attacker, clean, 5);
        }
        case 2: 
        { 
            ADD_STAT(attacker, killsBoomer); 
            UpdateWeaponStat(attacker, clean, 6); 
        }
        case 3:
        {
            ADD_STAT(attacker, killsHunter);
            UpdateWeaponStat(attacker, clean, 7);
            
            if (g_iPendingSkeetAttacker[victim] == attacker && (GetGameTime() - g_fLastSkeetTime[victim]) < 0.2) {
                ADD_STAT(attacker, hunterSkeets);
                UpdateWeaponStat(attacker, clean, 15);
                
                char sAttacker[32], prettyWPN[64];
                GetPlayerNameSafe(attacker, sAttacker, sizeof(sAttacker));
                GetPrettyWeaponName(clean, prettyWPN, sizeof(prettyWPN));
                LogActivity("%s skeeted a Hunter with %s.", sAttacker, prettyWPN);
            }
        }
        case 4: 
        { 
            ADD_STAT(attacker, killsSpitter); 
            UpdateWeaponStat(attacker, clean, 8);
        }
        case 5: 
        { 
            ADD_STAT(attacker, killsJockey); 
            UpdateWeaponStat(attacker, clean, 9); 
        }
        case 6:
        {
            ADD_STAT(attacker, killsCharger);
            UpdateWeaponStat(attacker, clean, 10);
            
            if (g_iPendingSkeetAttacker[victim] == attacker && (GetGameTime() - g_fLastSkeetTime[victim]) < 0.2) {
                ADD_STAT(attacker, chargerLevels);
                UpdateWeaponStat(attacker, clean, 18);
                
                char sAttacker[32], prettyWPN[64];
                GetPlayerNameSafe(attacker, sAttacker, sizeof(sAttacker));
                GetPrettyWeaponName(clean, prettyWPN, sizeof(prettyWPN));
                LogActivity("%s leveled a Charger with %s.", sAttacker, prettyWPN);
            }
        }
        case 8: 
        { 
            ADD_STAT(attacker, killsTank); 
            UpdateWeaponStat(attacker, clean, 11); 
            char sName[32];
            GetPlayerNameSafe(attacker, sName, sizeof(sName));
            LogActivity("%s dealt the finishing blow to the Tank.", sName);
			
			LogTankDamageBreakdown(victim);
        }
    }
	
    g_iPendingSkeetAttacker[victim] = 0;
}

void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR) {
        ADD_STAT(client, incaps);
        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        
        char sCause[64];
		strcopy(sCause, sizeof(sCause), g_sLastDamageSource[client]);
		if (sCause[0] == '\0') 
		{
			strcopy(sCause, sizeof(sCause), "world_damage");
		}
		
		char sPrettyCause[64];
		GetPrettySourceName(sCause, sPrettyCause, sizeof(sPrettyCause));
		
		LogActivity("%s was incapacitated by %s (HP: %d -> 0).", sName, sPrettyCause, g_iPreDamageHealth[client]);

        g_iPreDamageHealth[client] = GetSurvivorTotalHealth(client);
    }
}

void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!IsSurvivor(attacker)) return;
    
    int victim = event.GetInt("entityid");
    if (victim <= 0 || victim >= MAX_ENTITIES_TRACKED || !IsValidEntity(victim)) return;

    int type = event.GetInt("type");
    bool isWitch = g_bIsWitchEntity[victim];
    bool isBulletOrMelee = ((type & 2) != 0);

    if (!isWitch && !isBulletOrMelee) return;

    char clean[64];
    clean[0] = '\0';
    bool cleanResolved = false;

    if (isWitch)
    {
        if (!cleanResolved) {
            int wEnt = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
            if (wEnt > 0 && IsValidEntity(wEnt)) {
                char clsName[64]; GetEntityClassname(wEnt, clsName, sizeof(clsName));
                GetCleanWeaponName(attacker, clsName, clean, sizeof(clean), wEnt);
            } else {
                strcopy(clean, sizeof(clean), "melee");
            }
            cleanResolved = true;
        }

        int tick = GetGameTickCount();
        if (g_iWitchFirstHitTick[victim] == 0) {
            g_iWitchFirstHitTick[victim] = tick;
        }
        
        int maxHealth = GetEntProp(victim, Prop_Data, "m_iMaxHealth");
        if (maxHealth <= 0) maxHealth = 1000; 

        int alreadyAwarded = g_iWitchDamageAwarded[victim];
        if (alreadyAwarded < maxHealth)
        {
            int amount = event.GetInt("amount");
            int toAward = amount;

            if (alreadyAwarded + toAward > maxHealth)
                toAward = maxHealth - alreadyAwarded;

            ADD_STAT_VAL(attacker, witchDamage, toAward);
			g_iDamageToWitch[victim][attacker] += toAward;
            g_iWitchDamageAwarded[victim] += toAward;
            
            UpdateWeaponStat(attacker, clean, 14, toAward);

            if (g_iLastHitTick[attacker] != tick) {
                UpdateWeaponStat(attacker, clean, 1);
                g_iLastHitTick[attacker] = tick;
            }

            if (g_bIsWitchHeadshot[victim] && g_iLastHeadshotTick[attacker] != tick) {
                UpdateWeaponStat(attacker, clean, 2);
                g_iLastHeadshotTick[attacker] = tick;
                g_bIsWitchHeadshot[victim] = false;
            }
        }
    }

    if (isBulletOrMelee)
    {
        int weaponID = g_iClientActiveWeaponID[attacker];
        if (weaponID != -1) {
            int tick = GetGameTickCount();
            if (g_iLastHitTick[attacker] != tick) {
                UpdateWeaponStatID(attacker, weaponID, 1);
                g_iLastHitTick[attacker] = tick;
            }
        }
    }
}

void Event_HunterPunched(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int attacker = GetClientOfUserId(event.GetInt("userid"));
    bool isLunging = event.GetBool("islunging");

    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && isLunging)
    {
        ADD_STAT(attacker, hunterDeadstops);

        char sAttacker[32];
        GetPlayerNameSafe(attacker, sAttacker, sizeof(sAttacker));
        LogActivity("%s deadstopped a pouncing Hunter.", sAttacker);
    }
}

void Event_JockeyPunched(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int attacker = GetClientOfUserId(event.GetInt("userid"));
    bool isLunging = event.GetBool("islunging");

    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && isLunging)
    {
        ADD_STAT(attacker, jockeyDeadstops);

        char sAttacker[32];
        GetPlayerNameSafe(attacker, sAttacker, sizeof(sAttacker));
        LogActivity("%s deadstopped a leaping Jockey.", sAttacker);
    }
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int witch = event.GetInt("witchid");
    
    if (IsSurvivor(attacker)) {
        ADD_STAT(attacker, killsWitch);

		int weaponID = g_iClientActiveWeaponID[attacker];
		if (weaponID != -1) {
			UpdateWeaponStatID(attacker, weaponID, 3);
			UpdateWeaponStatID(attacker, weaponID, 12);
			
			if (event.GetBool("oneshot")) {
				ADD_STAT(attacker, witchCrowns);
				UpdateWeaponStatID(attacker, weaponID, 16);
				
				char sName[32];
				GetPlayerNameSafe(attacker, sName, sizeof(sName));
				LogActivity("%s crowned the Witch.", sName);
				LogWitchDamageBreakdown(witch);
				return;
			}
		}
        char sName[32];
        GetPlayerNameSafe(attacker, sName, sizeof(sName));
        LogActivity("%s killed the Witch.", sName);
		LogWitchDamageBreakdown(witch);
    }
}

public void L4D2_Infected_HitByVomitJar_Post(int victim, int attacker)
{
    if (IsSurvivor(attacker))
    {
        ADD_STAT(attacker, bileHits);
    }
}

public void L4D2_OnHitByVomitJar_Post(int victim, int attacker)
{
    if (IsSurvivor(attacker))
    {
        ADD_STAT(attacker, bileHits);
    }
}

public void OnEntityCreated(int entity, const char[] classname)
{    
    if (entity > 0 && entity < MAX_ENTITIES_TRACKED) {
        if (classname[0] == 'i' && strcmp(classname, "infected") == 0) {
            g_bIsCommonEntity[entity] = true;
        }
    }

    if (classname[0] == 'w' && StrEqual(classname, "witch"))
    {
        if (entity > 0 && entity < MAX_ENTITIES_TRACKED) {
            g_iWitchDamageAwarded[entity] = 0;
            g_iWitchFirstHitTick[entity] = 0;
            g_bIsWitchHeadshot[entity] = false;
            g_bIsWitchEntity[entity] = true;
			g_bWitchBurnt[entity] = false;
            SDKHook(entity, SDKHook_TraceAttack, OnWitchTraceAttack);
            SDKHook(entity, SDKHook_OnTakeDamage, OnWitchTakeDamage);
			
			for (int i = 1; i <= MaxClients; i++) {
                g_iDamageToWitch[entity][i] = 0;
            }
        }
    }
}

public void OnEntityDestroyed(int entity)
{    
    if (entity > 0 && entity < MAX_ENTITIES_TRACKED) {
        g_bIsCommonEntity[entity] = false;
        g_iWitchDamageAwarded[entity] = 0;
        g_iWitchFirstHitTick[entity] = 0;
        g_bIsWitchHeadshot[entity] = false;
        g_bIsWitchEntity[entity] = false;
		
		for (int i = 1; i <= MaxClients; i++) {
            g_iDamageToWitch[entity][i] = 0;
        }
    }
}

public Action OnPlayerTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damageCustom)
{
    if (damage <= 0.0 || victim <= 0 || victim > MaxClients || !IsClientInGame(victim)) return Plugin_Continue;

    int victimTeam = GetClientTeam(victim);
	
	g_iPreDamageHealth[victim] = GetSurvivorTotalHealth(victim);
	
    if (victimTeam == TEAM_SURVIVOR && damage > 0.0)
    {
        char src[64];
        
		if (L4D_IsPlayerIncapacitated(victim) && (attacker <= 0 || attacker == victim) && !(damagetype & 32) && !(damagetype & 8))
        {
            strcopy(src, sizeof(src), "incap_decay");
        }
        else if (damagetype & 32) 
        {
            strcopy(src, sizeof(src), "fall_damage");
        }
        else if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
        {
            if (attacker == victim)
            {
                strcopy(src, sizeof(src), "self_damage");
            }
            else
            {
                int attackerTeam = GetClientTeam(attacker);
                if (attackerTeam == TEAM_INFECTED)
                {
                    int zombieClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
                    switch (zombieClass) {
                        case 1: strcopy(src, sizeof(src), "smoker");
                        case 2: strcopy(src, sizeof(src), "boomer");
                        case 3: strcopy(src, sizeof(src), "hunter");
                        case 4: strcopy(src, sizeof(src), "spitter");
                        case 5: strcopy(src, sizeof(src), "jockey");
                        case 6: strcopy(src, sizeof(src), "charger");
                        case 8: {
							if (inflictor > 0 && inflictor != attacker && IsValidEntity(inflictor)) {
								char infClass[64]; GetEntityClassname(inflictor, infClass, sizeof(infClass));
								if (infClass[0] == 't' && strcmp(infClass, "tank_rock") == 0) {
									strcopy(src, sizeof(src), "tank_rock");
								} 
								else if (strncmp(infClass, "prop_", 5) == 0) {
									strcopy(src, sizeof(src), "world_damage");
								} 
								else {
									strcopy(src, sizeof(src), "tank_punch");
								}
							} else {
								strcopy(src, sizeof(src), "tank_punch");
							}
						}	
                        default: strcopy(src, sizeof(src), "generic_hit");
                    }
                }
                else if (attackerTeam == TEAM_SURVIVOR)
                {
                    strcopy(src, sizeof(src), "friendly_fire");
                }
            }
        }
        else
        {
            if (attacker > 0 && attacker < MAX_ENTITIES_TRACKED && IsValidEntity(attacker))
            {
                if (g_bIsWitchEntity[attacker]) {
                    strcopy(src, sizeof(src), "witch_claw");
                } else if (g_bIsCommonEntity[attacker]) {
                    strcopy(src, sizeof(src), "infected");
                } else {
                    char cls[64]; GetEntityClassname(attacker, cls, sizeof(cls));
                    if (cls[0] == 't' && strcmp(cls, "tank_rock") == 0) {
                        strcopy(src, sizeof(src), "tank_rock");
                    } 
                    else if (damagetype & 8) { 
                        strcopy(src, sizeof(src), "env_fire");
                    } 
                    else if (strcmp(cls, "trigger_hurt") == 0) {
                        strcopy(src, sizeof(src), "map_hazard");
                    } 
                    else if (strcmp(cls, "env_fire") == 0 || strcmp(cls, "entityflame") == 0) {
                        strcopy(src, sizeof(src), "env_fire");
                    } 
                    else {
                        strcopy(src, sizeof(src), "world_damage");
                    }
                }
            }
            else
            {
                if (damagetype & 8) { 
                    strcopy(src, sizeof(src), "env_fire");
                } else {
                    strcopy(src, sizeof(src), "world_damage");
                }
            }
        }

        strcopy(g_sLastDamageSource[victim], sizeof(g_sLastDamageSource[]), src);
    }

    if (victimTeam == TEAM_INFECTED)
    {
        if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker)) return Plugin_Continue;
        if (!IsSurvivor(attacker)) return Plugin_Continue;
    
        int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
                
        if (zombieClass == 3) {
            if (!(GetEntityFlags(victim) & FL_ONGROUND) && GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce")) {
                g_iPendingSkeetAttacker[victim] = attacker;
                g_fLastSkeetTime[victim] = GetGameTime();
            }
        }
        if (zombieClass == 6) {
            int ability = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
            if (ability > 0 && IsValidEntity(ability)) {
                if (GetEntProp(ability, Prop_Send, "m_isCharging")) {
                    g_iPendingSkeetAttacker[victim] = attacker;
                    g_fLastSkeetTime[victim] = GetGameTime();
                }
            }
        }
		if (zombieClass == 8) {
            if (damagetype & 8 && !g_bTankBurnt[victim]) {
                g_bTankBurnt[victim] = true;
                char sAttacker[32];
                GetPlayerNameSafe(attacker, sAttacker, sizeof(sAttacker));
                LogActivity("%s set the tank on fire.", sAttacker);
            }
        }
    }
    return Plugin_Continue;
}

int GetSurvivorTotalHealth(int client)
{
    if (client <= 0 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
    {
        return 0;
    }
    
    int perm = GetClientHealth(client);
    
    if (L4D_IsPlayerIncapacitated(client))
    {
        return perm;
    }

    float fBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    float fBufferTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
    float fGameTime = GetGameTime();

    float fDecayRate = 0.27;
    if (g_cvPillsDecay != null)
    {
        fDecayRate = g_cvPillsDecay.FloatValue;
    }

    float fDecayedTemp = fBuffer - ((fGameTime - fBufferTime) * fDecayRate);
    if (fDecayedTemp < 0.0)
    {
        fDecayedTemp = 0.0;
    }

    return perm + RoundToFloor(fDecayedTemp);
}

void ProcessDamageLog(int victim, int damage, const char[] source, int preHealth, int attacker = 0)
{
    if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim) || damage <= 0) return;

    int sourceID = GetDamageSourceID(source);
	
	if (sourceID == DMG_SOURCE_INCAP_DECAY || sourceID == DMG_SOURCE_WORLD) return;

    if (sourceID == DMG_SOURCE_FF && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
    {
        g_iLastFFAttacker[victim] = attacker;
    }

    if (IsSpammySource(sourceID))
    {
        if (g_iAccumulatedDamage[victim][sourceID] == 0)
        {
            g_iPreAccumHealth[victim][sourceID] = preHealth;
            any timerData = EncodeTimerData(victim, sourceID);
            g_hDamageTimer[victim][sourceID] = CreateTimer(1.5, Timer_LogAccumulatedDamage, timerData, TIMER_FLAG_NO_MAPCHANGE);
        }
        g_iAccumulatedDamage[victim][sourceID] += damage;
    }
    else
    {
        int postHealth = GetSurvivorTotalHealth(victim);
        
        char sVictim[32], sPrettyCause[64];
        GetPlayerNameSafe(victim, sVictim, sizeof(sVictim));
        GetPrettySourceName(source, sPrettyCause, sizeof(sPrettyCause));
        
        if (sourceID == DMG_SOURCE_FF && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
        {
            char sAttacker[32];
            GetPlayerNameSafe(attacker, sAttacker, sizeof(sAttacker));
            LogActivity("%s took %d Friendly Fire damage from %s (HP: %d -> %d).", sVictim, damage, sAttacker, preHealth, postHealth);
        }
        else
        {
            LogActivity("%s took %d damage from %s (HP: %d -> %d).", sVictim, damage, sPrettyCause, preHealth, postHealth);
        }
    }
}

public Action Timer_LogAccumulatedDamage(Handle timer, any data)
{
    int client, sourceID;
    DecodeTimerData(data, client, sourceID);

    if (client <= 0 || !IsClientInGame(client)) return Plugin_Stop;

    g_hDamageTimer[client][sourceID] = null;

    int damage = g_iAccumulatedDamage[client][sourceID];
    if (damage > 0)
    {
        int preHealth = g_iPreAccumHealth[client][sourceID];
        
        int postHealth = preHealth - damage;
        if (postHealth < 0) postHealth = 0;

        char sName[32], sPrettyCause[64];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        GetPrettySourceName(g_sDamageSourceKeys[sourceID], sPrettyCause, sizeof(sPrettyCause));

        if (sourceID == DMG_SOURCE_FF)
        {
            int attacker = g_iLastFFAttacker[client];
            char sAttacker[32];
            if (attacker > 0 && IsClientInGame(attacker))
            {
                GetPlayerNameSafe(attacker, sAttacker, sizeof(sAttacker));
                LogActivity("%s took %d Friendly Fire damage from %s (HP: %d -> %d).", sName, damage, sAttacker, preHealth, postHealth);
            }
            else
            {
                LogActivity("%s took %d damage from Friendly Fire (HP: %d -> %d).", sName, damage, preHealth, postHealth);
            }
            g_iLastFFAttacker[client] = 0;
        }
        else
        {
            LogActivity("%s took %d damage from %s (HP: %d -> %d).", sName, damage, sPrettyCause, preHealth, postHealth);
        }

        g_iAccumulatedDamage[client][sourceID] = 0;
    }
    return Plugin_Stop;
}

bool IsSpammySource(int sourceID)
{
    return (sourceID == DMG_SOURCE_COMMON 
         || sourceID == DMG_SOURCE_SPITTER 
         || sourceID == DMG_SOURCE_ENV_FIRE 
         || sourceID == DMG_SOURCE_SELF 
		 || sourceID == DMG_SOURCE_WITCH
         || sourceID == DMG_SOURCE_FF
         || sourceID == DMG_SOURCE_INCAP_DECAY);
}

any EncodeTimerData(int client, int sourceID)
{
    return (client << 8) | sourceID;
}

void DecodeTimerData(any data, int &client, int &sourceID)
{
    client = (data >> 8) & 0xFF;
    sourceID = data & 0xFF;
}

public Action OnWitchTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (victim > 0 && victim < sizeof(g_bIsWitchHeadshot))
    {
        g_bIsWitchHeadshot[victim] = (hitgroup == 1);
    }
    return Plugin_Continue;
}

public Action OnWitchTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damageCustom)
{
    if (victim > 0 && victim < MAX_ENTITIES_TRACKED)
    {
        if (damagetype & 8 && !g_bWitchBurnt[victim])
        {
            if (IsValidSurvivor(attacker))
            {
                g_bWitchBurnt[victim] = true;
                char sName[32];
                GetPlayerNameSafe(attacker, sName, sizeof(sName));
                LogActivity("%s set the Witch on fire.", sName);
            }
        }
    }
    return Plugin_Continue;
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client >= 1 && client <= MaxClients && IsClientInGame(client)) { 
		g_bTankAlive[client] = true;
		g_bTankBurnt[client] = false;
		g_iTankLastHealth[client] = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		
		for (int i = 1; i <= MaxClients; i++) {
			g_iDamageToTank[client][i] = 0;
		}
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));	
    if (client < 1 || client > MaxClients || !IsClientInGame(client)) return;

	if (GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
		g_bTankAlive[client] = true;
		g_bTankBurnt[client] = false;
		g_iTankLastHealth[client] = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	}
	UpdateClientCacheDelayed(client);
}

void Event_BotReplacedPlayer(Event event, const char[] name, bool dontBroadcast) {
	int p = GetClientOfUserId(event.GetInt("player")), b = GetClientOfUserId(event.GetInt("bot"));
	if (p <= 0 || p > MaxClients || b <= 0 || b > MaxClients) return;
	
	UpdateClientCache(b);

	if (IsClientInGame(b) && GetClientTeam(b) == TEAM_INFECTED && GetEntProp(b, Prop_Send, "m_zombieClass") == 8) {
		g_bTankAlive[p] = false;
		g_bTankAlive[b] = true;
		g_bTankBurnt[b] = g_bTankBurnt[p];
		g_iTankLastHealth[b] = g_iTankLastHealth[p];
		
		for (int i = 1; i <= MaxClients; i++) {
			g_iDamageToTank[b][i] = g_iDamageToTank[p][i];
			g_iDamageToTank[p][i] = 0;
		}
	}
}

void Event_PlayerReplacedBot(Event event, const char[] name, bool dontBroadcast) {
	int p = GetClientOfUserId(event.GetInt("player")), b = GetClientOfUserId(event.GetInt("bot"));
	if (p <= 0 || p > MaxClients || b <= 0 || b > MaxClients) return;
	
	UpdateClientCache(p);

	if (IsClientInGame(p) && GetClientTeam(p) == TEAM_INFECTED && GetEntProp(p, Prop_Send, "m_zombieClass") == 8) {
		g_bTankAlive[b] = false;
		g_bTankAlive[p] = true;
		g_bTankBurnt[p] = g_bTankBurnt[b];
		g_iTankLastHealth[p] = g_iTankLastHealth[b];
		
		for (int i = 1; i <= MaxClients; i++) {
			g_iDamageToTank[p][i] = g_iDamageToTank[b][i];
			g_iDamageToTank[b][i] = 0;
		}
	}
}

public void OnWeaponSwitchPost(int client, int weapon)
{
    if (client <= 0 || !IsClientInGame(client) || weapon <= 0 || !IsValidEntity(weapon)) {
        g_iClientActiveWeaponID[client] = -1;
        return;
    }
	
	g_sLastRawWeapon[client][0] = '\0';

    char clsName[64], clean[64];
    GetEntityClassname(weapon, clsName, sizeof(clsName));

    GetCleanWeaponName(client, clsName, clean, sizeof(clean), weapon);

    int id;
    if (g_smCleanToID.GetValue(clean, id)) {
        g_iClientActiveWeaponID[client] = id;
    } else {
        g_iClientActiveWeaponID[client] = -1;
    }
}

void Event_TankRockKilled(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR) return;

    int tick = GetGameTickCount();
    if (g_iLastRockSkeetTick[client] == tick) return;
    g_iLastRockSkeetTick[client] = tick;

    ADD_STAT(client, rockSkeets);

    char clean[64];
    int wEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (wEnt > 0 && IsValidEntity(wEnt)) {
        char cls[64]; 
        GetEntityClassname(wEnt, cls, sizeof(cls));
        GetCleanWeaponName(client, cls, clean, sizeof(clean), wEnt);
    } else {
        clean[0] = '\0';
    }

    if (clean[0] != '\0') {
        UpdateWeaponStat(client, clean, 19);

        char sAttacker[32], prettyWPN[64];
        GetPlayerNameSafe(client, sAttacker, sizeof(sAttacker));
        GetPrettyWeaponName(clean, prettyWPN, sizeof(prettyWPN));
        LogActivity("%s skeeted a Tank rock with %s.", sAttacker, prettyWPN);
    }
}

public Action Timer_ResetTongueCut(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0)
    {
        g_bTongueCutThisFrame[client] = false;
    }
    return Plugin_Stop;
}

void Event_TonguePullStopped(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("victim")); 
    int cleanser = GetClientOfUserId(event.GetInt("userid")); 

    if (IsSurvivor(victim)) {
        if (cleanser == victim) {
            int weaponID = g_iClientActiveWeaponID[victim];
            if (weaponID != -1) {
                char clean[64];
                strcopy(clean, sizeof(clean), g_sCleanWeaponNames[weaponID]);
                if (IsMelee(clean)) {
                    g_bTongueCutThisFrame[victim] = true;
                    
                    CreateTimer(0.2, Timer_ResetTongueCut, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
                    
                    ADD_STAT(victim, tongueCuts);
                    UpdateWeaponStatID(victim, weaponID, 17);
                    
                    char sVictim[32], prettyWPN[64];
                    GetPlayerNameSafe(victim, sVictim, sizeof(sVictim));
                    GetPrettyWeaponName(clean, prettyWPN, sizeof(prettyWPN));
                    LogActivity("%s cut a Smoker's tongue with %s.", sVictim, prettyWPN);
                }
            }
        }
    }
}

void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsSurvivor(client)) {
        ADD_STAT(client, witchesStartled);
        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        LogActivity("%s startled the Witch.", sName);
    }
}

public void Event_PlayerNowIt(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsSurvivor(client) && event.GetBool("by_boomer")) {
        ADD_STAT(client, timesBoomed);
        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        
        if (event.GetBool("exploded")) {
            float curTime = GetGameTime();
            int popper = g_iLastBoomerPopper;
            
            if (popper > 0 && popper <= MaxClients && IsClientInGame(popper) && GetClientTeam(popper) == TEAM_SURVIVOR && (curTime - g_fLastBoomerExplodeTime) < 0.1) {
                char sPopperName[32];
                GetPlayerNameSafe(popper, sPopperName, sizeof(sPopperName));
                
                if (popper == client) {
                    LogActivity("%s popped a Boomer too close and biled themselves.", sName);
                } else {
                    LogActivity("%s was biled because %s popped a Boomer nearby!", sName, sPopperName);
                }
            } else {
                LogActivity("%s was biled by an exploding Boomer.", sName);
            }
        } else {
            LogActivity("%s was directly vomited on by a Boomer.", sName);
        }
    }
}

public void Event_BoomerExploded(Event event, const char[] name, bool dontBroadcast) {
    g_iLastBoomerPopper = GetClientOfUserId(event.GetInt("attacker"));
    g_fLastBoomerExplodeTime = GetGameTime();
}

public void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int charger = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));

    if (charger > 0 && charger <= MaxClients && IsClientInGame(charger) &&
        victim > 0 && victim <= MaxClients && IsClientInGame(victim))
    {
        char sChargerName[32], sVictimName[32];
        GetPlayerNameSafe(charger, sChargerName, sizeof(sChargerName));
        GetPlayerNameSafe(victim, sVictimName, sizeof(sVictimName));

        LogActivity("%s was sent flying by %s's charge impact.", sVictimName, sChargerName);
    }
}

public void Event_EnteredSpit(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR) return;

    float curTime = GetGameTime();
    if (curTime - g_fLastSpitEntryTime[client] < 8.0)
    {
        return;
    }
    g_fLastSpitEntryTime[client] = curTime;

    char sPlayerName[32];
    GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));

    LogActivity("%s stepped into Spitter acid.", sPlayerName);
}

public void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        char sAbility[32];
        event.GetString("ability", sAbility, sizeof(sAbility));
        if (strcmp(sAbility, "ability_spit") == 0)
        {
            g_bSpitterHasSpit[client] = true;
        }
    }
}

void Event_PlayerLedgeGrab(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsSurvivor(client)) {
        ADD_STAT(client, ledgeGrabs);
        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        LogActivity("%s is hanging from a ledge.", sName);
    }
}

void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (attacker > 0 && victim > 0 && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_INFECTED) {
        g_iLastShover[victim] = attacker;
        g_fLastShoveTime[victim] = GetGameTime();
    }
}

void Event_PillsUsed(Event event, const char[] n, bool d) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR) { 
        ADD_STAT(client, pillsUsed);
		
		g_iPreDamageHealth[client] = GetSurvivorTotalHealth(client);
		
        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        LogActivity("%s used Pain Pills.", sName);
    }
}

void Event_AdrenalineUsed(Event event, const char[] n, bool d) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR) { 
        ADD_STAT(client, adrenalineUsed);
		
		g_iPreDamageHealth[client] = GetSurvivorTotalHealth(client);
		
        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        LogActivity("%s used Adrenaline.", sName);
    }
}

void Event_WeaponGiven(Event event, const char[] name, bool dontBroadcast) {
    int giver = GetClientOfUserId(event.GetInt("giver"));
    if (giver <= 0 || !IsClientInGame(giver)) return;

    int receiver = GetClientOfUserId(event.GetInt("userid"));
    int weaponId = event.GetInt("weapon");

    char sGiver[32], sReceiver[32];
    GetPlayerNameSafe(giver, sGiver, sizeof(sGiver));
    GetPlayerNameSafe(receiver, sReceiver, sizeof(sReceiver));

    if (weaponId == WPNID_PAINKILLERS) {
        ADD_STAT(giver, pillsShared);
        LogActivity("%s shared Pain Pills with %s.", sGiver, sReceiver);
    } 
    else if (weaponId == WPNID_ADRENALINE) {
        ADD_STAT(giver, adrenalineShared);
        LogActivity("%s shared Adrenaline with %s.", sGiver, sReceiver);
    }
}

void Event_DefibUsed(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    int subject = GetClientOfUserId(event.GetInt("subject"));
    
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR) {
        if (subject > 0 && subject <= MaxClients && IsClientInGame(subject) && GetClientTeam(subject) == TEAM_SURVIVOR && client != subject) {
            ADD_STAT(client, defibsUsed);
        }
    }
    
    if (subject > 0 && subject <= MaxClients && IsClientInGame(subject) && GetClientTeam(subject) == TEAM_SURVIVOR) {
        if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && client != subject) {
            ADD_STAT(subject, defibbedByTeammate);
        }
        
        SUB_STAT(subject, deaths);

        char sActor[32], sRecipient[32];
        GetPlayerNameSafe(client, sActor, sizeof(sActor));
        GetPlayerNameSafe(subject, sRecipient, sizeof(sRecipient));
        LogActivity("%s defibrillated %s.", sActor, sRecipient);
		
		g_iPreDamageHealth[subject] = GetSurvivorTotalHealth(subject);
    }
}

void Event_HealSuccess(Event event, const char[] n, bool d) {
    int h = GetClientOfUserId(event.GetInt("userid"));
    int s = GetClientOfUserId(event.GetInt("subject"));
    
    if (h > 0 && h <= MaxClients && IsClientInGame(h) && GetClientTeam(h) == TEAM_SURVIVOR) {
        char sHealer[32], sSubject[32];
        GetPlayerNameSafe(h, sHealer, sizeof(sHealer));
        GetPlayerNameSafe(s, sSubject, sizeof(sSubject));

        if (h == s) {
            ADD_STAT(h, medkitsUsed);
            LogActivity("%s healed themselves with a First Aid Kit.", sHealer);
        } else if (s > 0 && s <= MaxClients && IsClientInGame(s) && GetClientTeam(s) == TEAM_SURVIVOR) {
            ADD_STAT(h, medkitsShared);
            LogActivity("%s healed %s.", sHealer, sSubject);
        }
		
		g_iPreDamageHealth[s] = GetSurvivorTotalHealth(s);
    }
    
    if (s > 0 && s <= MaxClients && IsClientInGame(s) && GetClientTeam(s) == TEAM_SURVIVOR) {
        if (h > 0 && h <= MaxClients && IsClientInGame(h) && GetClientTeam(h) == TEAM_SURVIVOR && h != s) {
            ADD_STAT(s, healedByTeammate);
        }
    }
}

void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    int subject = GetClientOfUserId(event.GetInt("subject"));
    bool isLedgePullUp = event.GetBool("ledge_hang");
    
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR) {
        if (client != subject) {
            ADD_STAT(client, revivesTotal);
            
            if (isLedgePullUp) {
                ADD_STAT(client, ledgeRescues);
            }
            
            if (!IsFakeClient(client)) {
                if (g_Campaign[client].revivesTotal > g_Lifetime[client].revivesRecord) 
                    g_Lifetime[client].revivesRecord = g_Campaign[client].revivesTotal;
            }
        }
    }
    
    if (subject > 0 && subject <= MaxClients && IsClientInGame(subject) && GetClientTeam(subject) == TEAM_SURVIVOR) {
        if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && client != subject) {
            ADD_STAT(subject, revivedByTeammate);
            
            if (!IsFakeClient(subject)) {
                if (g_Campaign[subject].revivedByTeammate > g_Lifetime[subject].revivedByTeammateRecord) {
                    g_Lifetime[subject].revivedByTeammateRecord = g_Campaign[subject].revivedByTeammate;
                }
            }
        }
    }

    if (IsSurvivor(client) && IsSurvivor(subject)) {
        char sActor[32], sRecipient[32];
        GetPlayerNameSafe(client, sActor, sizeof(sActor));
        GetPlayerNameSafe(subject, sRecipient, sizeof(sRecipient));
        
        if (client == subject) {
            LogActivity("%s got up on their own.", sRecipient);
        } else {
            if (isLedgePullUp) {
                LogActivity("%s pulled %s back up from a ledge.", sActor, sRecipient);
            } else {
                LogActivity("%s revived %s.", sActor, sRecipient);
            }
        }
        
        g_iPreDamageHealth[subject] = GetSurvivorTotalHealth(subject);
    }
}

void Event_AwardEarned(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    int awardId = event.GetInt("award");
    
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR) {
        if (awardId == 67) {
            ADD_STAT(client, protectionsTotal);
			
			if (!IsFakeClient(client)) {
                if (g_Campaign[client].protectionsTotal > g_Lifetime[client].protectionsRecord)
                    g_Lifetime[client].protectionsRecord = g_Campaign[client].protectionsTotal;
            }
        }
    }
}

void Event_PinStart(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("victim"));
    int attacker = GetClientOfUserId(event.GetInt("userid"));

    if (victim > 0 && victim <= MaxClients && attacker > 0 && attacker <= MaxClients)
    {
        if (g_iPinnedBy[victim] == attacker) return;

        g_iPinnedBy[victim] = attacker;
        g_iLastPinnedBy[victim] = attacker;

        char sVictim[32], sInfected[16];
        GetPlayerNameSafe(victim, sVictim, sizeof(sVictim));

        if (StrEqual(name, "tongue_grab")) strcopy(sInfected, sizeof(sInfected), "Smoker");
        else if (StrEqual(name, "lunge_pounce")) strcopy(sInfected, sizeof(sInfected), "Hunter");
        else if (StrEqual(name, "jockey_ride")) strcopy(sInfected, sizeof(sInfected), "Jockey");
        else if (StrEqual(name, "charger_pummel_start") || StrEqual(name, "charger_carry_start")) strcopy(sInfected, sizeof(sInfected), "Charger");
        else return;

        g_bPinResolutionLogged[victim] = false;
        LogActivity("%s got pinned by a %s.", sVictim, sInfected);
    }
}

void Event_PinStop(Event event, const char[] name, bool dontBroadcast)
{
    int victim, attacker, rescuer;
    GetPinEventPlayers(event, name, victim, attacker, rescuer);

    if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim)) return;

    int originalAttacker = g_iPinnedBy[victim];
    if (originalAttacker <= 0) return;

    if (attacker <= 0 || !IsClientInGame(attacker)) {
        attacker = originalAttacker;
    }
	
	if (StrEqual(name, "charger_carry_end"))
    {
        g_fCarryEndTime[victim] = GetGameTime();

        if (attacker > 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker))
        {
            return;
        }
    }

    bool isTongueCut = false;
    if (StrEqual(name, "tongue_pull_stopped"))
    {
        int weaponID = g_iClientActiveWeaponID[victim];
        if (weaponID != -1 && IsMelee(g_sCleanWeaponNames[weaponID]))
        {
            isTongueCut = true;
        }
    }

    g_iPinnedBy[victim] = 0;
    g_fPinEndTime[victim] = GetGameTime();

    if (isTongueCut) return;

    DataPack pack;
    CreateDataTimer(0.1, Timer_ResolvePinStop, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(GetClientUserId(victim));
    pack.WriteCell(attacker > 0 ? GetClientUserId(attacker) : 0);
    pack.WriteCell(rescuer > 0 ? GetClientUserId(rescuer) : 0);
    pack.WriteString(name);
}

public Action Timer_ResolvePinStop(Handle timer, DataPack pack)
{
    pack.Reset();
    int victim = GetClientOfUserId(pack.ReadCell());
    int attacker = GetClientOfUserId(pack.ReadCell());
    int rescuer = GetClientOfUserId(pack.ReadCell());
    char eventName[64];
    pack.ReadString(eventName, sizeof(eventName));

    if (victim <= 0 || !IsClientInGame(victim)) return Plugin_Stop;

    if (g_bTongueCutThisFrame[victim]) {
        g_bTongueCutThisFrame[victim] = false;
        return Plugin_Stop;
    }

    if (g_iPinnedBy[victim] == attacker) return Plugin_Stop;

    if (attacker <= 0 || !IsClientInGame(attacker) || !IsPlayerAlive(attacker) || GetClientHealth(attacker) <= 0)
    {
        return Plugin_Stop;
    }

    if (rescuer <= 0 || !IsClientInGame(rescuer))
    {
        float pinEndTime = g_fPinEndTime[victim];
        if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && g_iLastShover[attacker] > 0 && IsClientInGame(g_iLastShover[attacker]))
        {
            float diff = g_fLastShoveTime[attacker] - pinEndTime;
            if (diff >= -0.2 && diff < 0.8)
            {
                rescuer = g_iLastShover[attacker];
            }
        }
    }

    int zombieClass = 0;
    if (attacker > 0 && IsClientInGame(attacker) && GetClientTeam(attacker) == TEAM_INFECTED) {
        zombieClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
    }

    char sInfected[16];
    if (zombieClass == 1 || StrContains(eventName, "tongue") != -1 || StrContains(eventName, "choke") != -1) strcopy(sInfected, sizeof(sInfected), "Smoker");
    else if (zombieClass == 3 || StrContains(eventName, "pounce") != -1) strcopy(sInfected, sizeof(sInfected), "Hunter");
    else if (zombieClass == 5 || StrContains(eventName, "jockey") != -1) strcopy(sInfected, sizeof(sInfected), "Jockey");
    else if (zombieClass == 6 || StrContains(eventName, "charger") != -1 || StrContains(eventName, "carry") != -1) strcopy(sInfected, sizeof(sInfected), "Charger");
    else strcopy(sInfected, sizeof(sInfected), "Infected");

    char sVictim[32];
    GetPlayerNameSafe(victim, sVictim, sizeof(sVictim));

    if (rescuer > 0 && rescuer <= MaxClients && IsClientInGame(rescuer) && GetClientTeam(rescuer) == TEAM_SURVIVOR && rescuer != victim)
    {
        ADD_STAT(victim, protectedByTeammate);

        if (!IsFakeClient(victim))
        {
            if (g_Campaign[victim].protectedByTeammate > g_Lifetime[victim].protectedByTeammateRecord)
                g_Lifetime[victim].protectedByTeammateRecord = g_Campaign[victim].protectedByTeammate;
        }

        char sRescuer[32];
        GetPlayerNameSafe(rescuer, sRescuer, sizeof(sRescuer));
        LogActivity("%s saved %s from a %s.", sRescuer, sVictim, sInfected);
        
        g_bPinResolutionLogged[victim] = true;
    }
    else
    {
        LogActivity("%s became free from the %s.", sVictim, sInfected);
        
        g_bPinResolutionLogged[victim] = true;
    }

    return Plugin_Stop;
}

void Event_TriggeredCarAlarm(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        ADD_STAT(client, carAlarmsTriggered);

        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        LogActivity("%s triggered the car alarm!", sName);
    }
}

public void Event_StrongmanBellKnockedOff(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
    {
        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        LogActivity("%s rang the Strongman strength-test bell!", sName);
    }
}

public void Event_PunchedClown(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client))
    {
        char sName[32];
        GetPlayerNameSafe(client, sName, sizeof(sName));
        LogActivity("%s punched a clown!", sName);
    }
}

public void Event_StashwhackerGameWon(Event event, const char[] name, bool dontBroadcast)
{
    int closest = -1;
    int proxy = event.GetInt("subject");
    if (proxy > 0 && IsValidEntity(proxy))
    {
        float proxyPos[3];
        GetEntPropVector(proxy, Prop_Send, "m_vecOrigin", proxyPos);
        
        float minDistance = 999999.0;
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidSurvivor(i) && IsPlayerAlive(i))
            {
                float plyPos[3];
                GetClientAbsOrigin(i, plyPos);
                float dist = GetVectorDistance(plyPos, proxyPos);
                if (dist < minDistance)
                {
                    minDistance = dist;
                    closest = i;
                }
            }
        }
    }
    
    if (closest > 0)
    {
        char sName[32];
        GetPlayerNameSafe(closest, sName, sizeof(sName));
        LogActivity("%s won a game of Stashwhacker!", sName);
    }
    else
    {
        LogActivity("The Stashwhacker game was won!");
    }
}

public Action Msg_PZDmgMsg(UserMsg msg_id, BfRead msg, const int[] players, int numPlayers, bool reliable, bool init)
{    
    int type = msg.ReadByte();
    if (type == 18)
    {
        int protector = msg.ReadByte();
        int victim = msg.ReadByte();
        
        if (victim > 0 && victim <= MaxClients && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
        {
            if (protector > 0 && protector <= MaxClients && IsClientInGame(protector) && GetClientTeam(protector) == TEAM_SURVIVOR && protector != victim)
            {
                ADD_STAT(victim, protectedByTeammate);

                char sVictim[32], sRescuer[32];
                GetPlayerNameSafe(victim, sVictim, sizeof(sVictim));
                GetPlayerNameSafe(protector, sRescuer, sizeof(sRescuer));
                LogActivity("%s saved %s from a pinning Infected.", sRescuer, sVictim);

                if (!IsFakeClient(victim))
                {
                    if (g_Campaign[victim].protectedByTeammate > g_Lifetime[victim].protectedByTeammateRecord)
                        g_Lifetime[victim].protectedByTeammateRecord = g_Campaign[victim].protectedByTeammate;
                }
            }
        }
    }
    return Plugin_Continue;
}

// ====================================================================================================
//					HELPERS
// ====================================================================================================
void UpdateWeaponStatID(int client, int weaponID, int type, int value = 1) {
    if (!g_cvEnable.BoolValue || weaponID < 0 || weaponID >= 128) return;

    if (client > 0 && client <= MaxClients && IsClientInGame(client)) {
        if (!g_bIsBot[client]) {
            if (g_bStatsLoaded[client]) {
                UpdateSingleWeaponArray(g_WeaponLifetimeCache[client][weaponID], type, value);
                UpdateSingleWeaponArray(g_WeaponCampaignCache[client][weaponID], type, value);
            }
        } else {
            int charID = g_iClientChar[client];
            if (charID >= 0 && charID < MAX_BOT_CHARS) {
                UpdateSingleWeaponArray(g_WeaponBotCampaignCache[charID][weaponID], type, value);
            }
        }
    }
}

void UpdateWeaponStat(int client, const char[] weapon, int type, int value = 1) {
    if (StrEqual(weapon, "world") || weapon[0] == '\0') return;
    int id;
    if (g_smCleanToID.GetValue(weapon, id)) {
        UpdateWeaponStatID(client, id, type, value);
    }
}

void UpdateSingleWeaponArray(WeaponStats wS, int type, int value) {
    switch (type) {
        case 0: wS.fired += value;
        case 1: wS.hits += value;
        case 2: wS.headshots += value;
        case 3: wS.kills += value;
        case 4: wS.killsCommon += value;
        case 5: wS.killsSmoker += value;
        case 6: wS.killsBoomer += value;
        case 7: wS.killsHunter += value;
        case 8: wS.killsSpitter += value;
        case 9: wS.killsJockey += value;
        case 10: wS.killsCharger += value;
        case 11: wS.killsTank += value;
        case 12: wS.killsWitch += value;
        case 13: wS.tankDamage += value;
        case 14: wS.witchDamage += value;
        case 15: wS.hunterSkeets += value;
        case 16: wS.witchCrowns += value;
        case 17: wS.tongueCuts += value;
        case 18: wS.chargerLevels += value;
        case 19: wS.rockSkeets += value;
        case 20: wS.spitterKilledPreSpat += value;
    }
}

int GetDamageSourceID(const char[] source) {
    for (int i = 0; i < MAX_DMG_SOURCES; i++) {
        if (StrEqual(source, g_sDamageSourceKeys[i], false)) {
            return i;
        }
    }
    return DMG_SOURCE_WORLD;
}

void GetCleanWeaponName(int client, const char[] weapon, char[] buffer, int maxlen, int weaponEnt = -1) {
    if (weapon[0] == '\0') {
        strcopy(buffer, maxlen, "melee");
        return;
    }

    if (g_smWeaponMap.GetString(weapon, buffer, maxlen)) {
        return;
    }

    char weaponLower[64];
    strcopy(weaponLower, sizeof(weaponLower), weapon);
    StringToLowerCase(weaponLower);

    if (g_smWeaponMap.GetString(weaponLower, buffer, maxlen)) {
        return;
    }

    if (strcmp(weaponLower, "weapon_melee") == 0 || strcmp(weaponLower, "melee") == 0) {
        int targetEnt = weaponEnt;
        if (targetEnt <= 0 && client > 0 && IsClientInGame(client)) {
            targetEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        }
        if (targetEnt > 0 && IsValidEntity(targetEnt)) {
            char cls[64];
            GetEntityClassname(targetEnt, cls, sizeof(cls));
            StringToLowerCase(cls);
            if (strcmp(cls, "weapon_melee") == 0 && HasEntProp(targetEnt, Prop_Data, "m_strMapSetScriptName")) {
                char scriptName[64];
                GetEntPropString(targetEnt, Prop_Data, "m_strMapSetScriptName", scriptName, sizeof(scriptName));
                StringToLowerCase(scriptName);
                
                if (scriptName[0] != '\0' && g_smWeaponMap.GetString(scriptName, buffer, maxlen)) {
                    return;
                }
            }
        }
        strcopy(buffer, maxlen, "melee");
        return;
    }

    if (strncmp(weaponLower, "weapon_", 7) == 0) {
        strcopy(buffer, maxlen, weaponLower[7]);
    } else {
        strcopy(buffer, maxlen, weaponLower);
    }
}

bool IsGun(const char[] w) {
    if (w[0] == '\0') return false;
    bool dummy;
    return g_smGuns.GetValue(w, dummy);
}

bool IsMelee(const char[] w) {
    if (w[0] == '\0') return false;
    bool dummy;
    return g_smMelees.GetValue(w, dummy);
}

bool IsCarryableObject(const char[] w) {
    if (w[0] == '\0') return false;
    bool dummy;
    return g_smCarryables.GetValue(w, dummy);
}

void GetPrettyWeaponName(const char[] classname, char[] buffer, int maxlen) {
    if (StrEqual(classname, "pistol")) strcopy(buffer, maxlen, "Pistols");
    else if (StrEqual(classname, "pistol_magnum")) strcopy(buffer, maxlen, "Magnum");
    
    else if (StrEqual(classname, "smg")) strcopy(buffer, maxlen, "Uzi SMG");
    else if (StrEqual(classname, "smg_silenced")) strcopy(buffer, maxlen, "Silenced SMG");
    else if (StrEqual(classname, "smg_mp5")) strcopy(buffer, maxlen, "MP5");
    
    else if (StrEqual(classname, "m16_rifle") || StrEqual(classname, "rifle")) strcopy(buffer, maxlen, "M16 Rifle");
    else if (StrEqual(classname, "rifle_ak47")) strcopy(buffer, maxlen, "AK-47");
    else if (StrEqual(classname, "rifle_desert")) strcopy(buffer, maxlen, "SCAR-L");
    else if (StrEqual(classname, "rifle_sg552")) strcopy(buffer, maxlen, "SG-552");
    else if (StrEqual(classname, "m60")) strcopy(buffer, maxlen, "M60 Machine Gun");
    
    else if (StrEqual(classname, "pumpshotgun")) strcopy(buffer, maxlen, "Pump Shotgun");
    else if (StrEqual(classname, "shotgun_chrome")) strcopy(buffer, maxlen, "Chrome Shotgun");
    else if (StrEqual(classname, "autoshotgun")) strcopy(buffer, maxlen, "Tactical Shotgun");
    else if (StrEqual(classname, "shotgun_spas")) strcopy(buffer, maxlen, "Combat Shotgun");
    
    else if (StrEqual(classname, "hunting_rifle")) strcopy(buffer, maxlen, "Hunting Rifle");
    else if (StrEqual(classname, "sniper_military")) strcopy(buffer, maxlen, "Military Sniper");
    else if (StrEqual(classname, "sniper_scout")) strcopy(buffer, maxlen, "Scout");
    else if (StrEqual(classname, "sniper_awp")) strcopy(buffer, maxlen, "AWP");
    
    else if (StrEqual(classname, "grenade_launcher")) strcopy(buffer, maxlen, "Grenade Launcher");
    else if (StrEqual(classname, "chainsaw")) strcopy(buffer, maxlen, "Chainsaw");
    
    else if (StrEqual(classname, "guitar")) strcopy(buffer, maxlen, "Electric Guitar");
    else if (StrEqual(classname, "fireaxe")) strcopy(buffer, maxlen, "Fireaxe");
    else if (StrEqual(classname, "katana")) strcopy(buffer, maxlen, "Katana");
    else if (StrEqual(classname, "machete")) strcopy(buffer, maxlen, "Machete");
    else if (StrEqual(classname, "baseball_bat")) strcopy(buffer, maxlen, "Baseball Bat");
    else if (StrEqual(classname, "crowbar")) strcopy(buffer, maxlen, "Crowbar");
    else if (StrEqual(classname, "cricket_bat")) strcopy(buffer, maxlen, "Cricket Bat");
    else if (StrEqual(classname, "tonfa")) strcopy(buffer, maxlen, "Nightstick (Tonfa)");
    else if (StrEqual(classname, "frying_pan")) strcopy(buffer, maxlen, "Frying Pan");
    else if (StrEqual(classname, "golfclub")) strcopy(buffer, maxlen, "Golf Club");
    else if (StrEqual(classname, "knife")) strcopy(buffer, maxlen, "Combat Knife");
    else if (StrEqual(classname, "pitchfork")) strcopy(buffer, maxlen, "Pitchfork");
    else if (StrEqual(classname, "shovel")) strcopy(buffer, maxlen, "Shovel");
    else if (StrEqual(classname, "riot_shield")) strcopy(buffer, maxlen, "Riot Shield");
	
	else if (StrEqual(classname, "fire")) strcopy(buffer, maxlen, "Fire");

    else {
        strcopy(buffer, maxlen, classname);
        if (buffer[0] != '\0') buffer[0] = CharToUpper(buffer[0]);
        for (int i = 0; i < maxlen; i++) {
            if (buffer[i] == '\0') break;
            if (buffer[i] == '_') buffer[i] = ' ';
        }
    }
}

int GetWeaponTier(const char[] weapon) {
    if (StrEqual(weapon, "smg") || StrEqual(weapon, "smg_silenced") || StrEqual(weapon, "smg_mp5") || 
        StrEqual(weapon, "pumpshotgun") || StrEqual(weapon, "shotgun_chrome")) return 1;
        
    if (StrEqual(weapon, "m16_rifle") || StrEqual(weapon, "rifle_ak47") || StrEqual(weapon, "rifle_desert") || 
        StrEqual(weapon, "rifle_sg552") || StrEqual(weapon, "autoshotgun") || StrEqual(weapon, "shotgun_spas") || 
        StrEqual(weapon, "hunting_rifle") || StrEqual(weapon, "sniper_military")) return 2;
        
    if (StrEqual(weapon, "grenade_launcher") || StrEqual(weapon, "m60") || StrEqual(weapon, "chainsaw")) return 3;
    
    return 4; 
}

void UpdateClientCache(int client) {
    if (client <= 0 || !IsClientInGame(client)) return;
    g_bIsBot[client] = IsFakeClient(client);
    g_iClientChar[client] = GetSurvivorCharacterInternal(client);

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon > 0 && IsValidEntity(weapon)) {
        OnWeaponSwitchPost(client, weapon);
    } else {
        g_iClientActiveWeaponID[client] = -1;
    }
}

int GetPinnedVictim(int infected)
{
    float currentTime = GetGameTime();
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
        {
            if (!g_bPinResolutionLogged[i])
            {
                if (g_iPinnedBy[i] == infected || (g_iLastPinnedBy[i] == infected && (currentTime - g_fPinEndTime[i]) < 1.0))
                {
                    g_iLastPinnedBy[i] = 0;
                    return i;
                }
            }
        }
    }
    return -1;
}

void GetPinEventPlayers(Event event, const char[] name, int &victim, int &attacker, int &rescuer)
{
    victim = 0;
    attacker = 0;
    rescuer = 0;

    if (StrEqual(name, "tongue_release"))
    {
        attacker = GetClientOfUserId(event.GetInt("userid"));
        victim = GetClientOfUserId(event.GetInt("victim"));
    }
    else if (StrEqual(name, "tongue_pull_stopped"))
    {
        victim = GetClientOfUserId(event.GetInt("victim"));
        attacker = GetClientOfUserId(event.GetInt("smoker"));
        rescuer = GetClientOfUserId(event.GetInt("userid"));
    }
	else if (StrEqual(name, "choke_stopped"))
    {
        victim = GetClientOfUserId(event.GetInt("victim"));
        attacker = GetClientOfUserId(event.GetInt("smoker"));
        rescuer = GetClientOfUserId(event.GetInt("userid"));
    }
    else if (StrEqual(name, "pounce_stopped"))
    {
        victim = GetClientOfUserId(event.GetInt("victim"));
        rescuer = GetClientOfUserId(event.GetInt("userid"));
    }
    else if (StrEqual(name, "jockey_ride_end"))
    {
        attacker = GetClientOfUserId(event.GetInt("userid"));
        victim = GetClientOfUserId(event.GetInt("victim"));
        rescuer = GetClientOfUserId(event.GetInt("rescuer"));
    }
    else if (StrEqual(name, "charger_pummel_end"))
    {
        attacker = GetClientOfUserId(event.GetInt("userid"));
        victim = GetClientOfUserId(event.GetInt("victim"));
        rescuer = GetClientOfUserId(event.GetInt("rescuer"));
    }
	else if (StrEqual(name, "charger_carry_end"))
    {
        attacker = GetClientOfUserId(event.GetInt("userid"));
        victim = GetClientOfUserId(event.GetInt("victim"));
    }
}

void UpdateDamageReceivedStat(int client, const char[] source, int damage) {
    if (!g_cvEnable.BoolValue || damage <= 0) return;
    
    int sourceID = GetDamageSourceID(source);
    
    if (client > 0 && client <= MaxClients && IsClientInGame(client)) {
        if (!g_bIsBot[client]) {
            if (g_bStatsLoaded[client]) {
                g_iDamageLifetimeCache[client][sourceID] += damage;
                g_iDamageCampaignCache[client][sourceID] += damage;
            }
        } else {
            int charID = g_iClientChar[client];
            if (charID >= 0 && charID < MAX_BOT_CHARS) {
                g_iDamageBotCampaignCache[charID][sourceID] += damage;
            }
        }
    }
}

void LogTankDamageBreakdown(int tank) {
	char logBuf[512];
	logBuf[0] = '\0';
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR) {
			int dmg = g_iDamageToTank[tank][i];
			if (dmg > 0) {
				char sName[32];
				GetPlayerNameSafe(i, sName, sizeof(sName));
				if (logBuf[0] == '\0') {
					Format(logBuf, sizeof(logBuf), "%s: %d HP", sName, dmg);
				} else {
					Format(logBuf, sizeof(logBuf), "%s | %s: %d HP", logBuf, sName, dmg);
				}
			}
		}
	}
	
	if (logBuf[0] != '\0') {
		LogActivity("Tank Damage Breakdown -> %s", logBuf);
	}
	
	for (int i = 1; i <= MaxClients; i++) {
		g_iDamageToTank[tank][i] = 0;
	}
}

void LogWitchDamageBreakdown(int witch) {
    if (witch <= 0 || witch >= MAX_ENTITIES_TRACKED) return;

    char logBuf[512];
    logBuf[0] = '\0';
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR) {
            int dmg = g_iDamageToWitch[witch][i];
            if (dmg > 0) {
                char sName[32];
                GetPlayerNameSafe(i, sName, sizeof(sName));
                if (logBuf[0] == '\0') {
                    Format(logBuf, sizeof(logBuf), "%s: %d HP", sName, dmg);
                } else {
                    Format(logBuf, sizeof(logBuf), "%s | %s: %d HP", logBuf, sName, dmg);
                }
            }
        }
    }
    
    if (logBuf[0] != '\0') {
        LogActivity("Witch Damage Breakdown -> %s", logBuf);
    }

    for (int i = 1; i <= MaxClients; i++) {
        g_iDamageToWitch[witch][i] = 0;
    }
}

void GetPrettySourceName(const char[] source, char[] buffer, int maxlen) {
    if (StrEqual(source, "infected")) strcopy(buffer, maxlen, "Common Infected");
    else if (StrEqual(source, "witch_claw") || StrEqual(source, "witch")) strcopy(buffer, maxlen, "Witch Claws");
    else if (StrEqual(source, "tank_punch")) strcopy(buffer, maxlen, "Tank Punch");
    else if (StrEqual(source, "tank_rock")) strcopy(buffer, maxlen, "Tank Rock");
    else if (StrEqual(source, "hunter")) strcopy(buffer, maxlen, "Hunter");
    else if (StrEqual(source, "smoker")) strcopy(buffer, maxlen, "Smoker");
    else if (StrEqual(source, "jockey")) strcopy(buffer, maxlen, "Jockey");
    else if (StrEqual(source, "charger")) strcopy(buffer, maxlen, "Charger");
    else if (StrEqual(source, "spitter")) strcopy(buffer, maxlen, "Spitter");
    else if (StrEqual(source, "boomer")) strcopy(buffer, maxlen, "Boomer");
    else if (StrEqual(source, "friendly_fire")) strcopy(buffer, maxlen, "Friendly Fire");
    else if (StrEqual(source, "fall_damage")) strcopy(buffer, maxlen, "Fall Damage");
    else if (StrEqual(source, "env_fire")) strcopy(buffer, maxlen, "Environmental Fire");
    else if (StrEqual(source, "map_hazard")) strcopy(buffer, maxlen, "Map Hazards (trigger_hurt)");
    else if (StrEqual(source, "self_damage")) strcopy(buffer, maxlen, "Self Inflicted Damage");
	else if (StrEqual(source, "incap_decay")) strcopy(buffer, maxlen, "Incapacitation / Bleed-out");
    else if (StrEqual(source, "world_damage")) strcopy(buffer, maxlen, "World / Physics Impact");
    else {
        strcopy(buffer, maxlen, source);
        if (buffer[0] != '\0') buffer[0] = CharToUpper(buffer[0]);
        for (int i = 0; i < maxlen; i++) {
            if (buffer[i] == '\0') break;
            if (buffer[i] == '_') buffer[i] = ' ';
        }
    }
}

void UpdateClientCacheDelayed(int client) {
    if (client <= 0 || !IsClientInGame(client)) return;
    CreateTimer(0.3, Timer_DelayUpdateCache, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelayUpdateCache(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client)) {
        UpdateClientCache(client);
    }
    return Plugin_Stop;
}

int GetTotalDamageReceived(const int dmgArray[MAX_DMG_SOURCES]) {
    int total = 0;
    for (int i = 0; i < MAX_DMG_SOURCES; i++) {
        total += dmgArray[i];
    }
    return total;
}

void SanitizeFileName(char[] name, int maxlen)
{
	ReplaceString(name, maxlen, "/", "_");
	ReplaceString(name, maxlen, "\\", "_");
	ReplaceString(name, maxlen, ":", "_");
	ReplaceString(name, maxlen, "*", "_");
	ReplaceString(name, maxlen, "?", "_");
	ReplaceString(name, maxlen, "\"", "_");
	ReplaceString(name, maxlen, "<", "_");
	ReplaceString(name, maxlen, ">", "_");
	ReplaceString(name, maxlen, "|", "_");
	ReplaceString(name, maxlen, " ", "_");
}

void StringToLowerCase(char[] str) {
    for (int i = 0; str[i] != '\0'; i++) {
        str[i] = CharToLower(str[i]);
    }
}

int GetSurvivorCharacterInternal(int client) {
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR) return -1;
    
    char model[128];
    GetClientModel(client, model, sizeof(model));

    if (StrContains(model, "gambler", false) != -1) return 0;
    if (StrContains(model, "producer", false) != -1) return 1;
    if (StrContains(model, "coach", false) != -1) return 2;
    if (StrContains(model, "mechanic", false) != -1) return 3;
    if (StrContains(model, "namvet", false) != -1) return 4;
    if (StrContains(model, "teenangst", false) != -1) return 5;
    if (StrContains(model, "biker", false) != -1) return 6;
    if (StrContains(model, "manager", false) != -1) return 7;

    int charID = GetEntProp(client, Prop_Send, "m_survivorCharacter");
    if (charID >= 0 && charID < MAX_BOT_CHARS) return charID;
    
    return -1;
}


void GetBotPrettyName(int character, char[] buffer, int maxlen, int client = 0)
{
    if (character < 0 || character >= MAX_BOT_CHARS)
    {
        strcopy(buffer, maxlen, "Unknown Bot");
        return;
    }

    if (character >= 0 && character < 8)
    {
        if (g_sCachedBotNames[character][0] != '\0')
        {
            strcopy(buffer, maxlen, g_sCachedBotNames[character]);
            return;
        }
    }

    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        GetClientName(client, buffer, maxlen);
        if (buffer[0] != '\0') return;
    }

    if (character >= 0 && character < MAX_BOT_CHARS)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (i != client && IsClientInGame(i) && IsFakeClient(i) && GetSurvivorCharacterInternal(i) == character)
            {
                GetClientName(i, buffer, maxlen);
                if (buffer[0] != '\0') return;
            }
        }
    }

    if (character >= 0 && character < 8)
    {
        static const char defaultNames[][] = { "Nick", "Rochelle", "Coach", "Ellis", "Bill", "Zoey", "Francis", "Louis" };
        strcopy(buffer, maxlen, defaultNames[character]);
    }
    else
    {
        Format(buffer, maxlen, "Extra Bot (%d)", character);
    }
}

bool IsValidClient(int client) { return (client >= 1 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client)); }
bool IsValidSurvivor(int client) { return (client >= 1 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && !IsFakeClient(client)); }
bool IsSurvivor(int client) {
	return (client >= 1 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR);
}

public void OnConfigsExecuted()
{
    UpdateBotNamesCache();
}

public void OnBotNameCVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UpdateBotNamesCache();
}

void UpdateBotNamesCache()
{
    for (int i = 0; i < 8; i++) {
        if (g_cvBotNames[i] == null) {
            char cvarName[64];
            switch (i) {
                case 0: strcopy(cvarName, sizeof(cvarName), "l4d2_custom_bot_name_nick");
                case 1: strcopy(cvarName, sizeof(cvarName), "l4d2_custom_bot_name_rochelle");
                case 2: strcopy(cvarName, sizeof(cvarName), "l4d2_custom_bot_name_coach");
                case 3: strcopy(cvarName, sizeof(cvarName), "l4d2_custom_bot_name_ellis");
                case 4: strcopy(cvarName, sizeof(cvarName), "l4d2_custom_bot_name_bill");
                case 5: strcopy(cvarName, sizeof(cvarName), "l4d2_custom_bot_name_zoey");
                case 6: strcopy(cvarName, sizeof(cvarName), "l4d2_custom_bot_name_francis");
                case 7: strcopy(cvarName, sizeof(cvarName), "l4d2_custom_bot_name_louis");
            }
            g_cvBotNames[i] = FindConVar(cvarName);
            if (g_cvBotNames[i] != null) {
                g_cvBotNames[i].AddChangeHook(OnBotNameCVarChanged);
            }
        }

        if (g_cvBotNames[i] != null) {
            g_cvBotNames[i].GetString(g_sCachedBotNames[i], sizeof(g_sCachedBotNames[]));
        } else {
            g_sCachedBotNames[i][0] = '\0';
        }
    }
}

bool IsReallyPinnedBy(int survivor, int infected)
{
    if (GetEntPropEnt(survivor, Prop_Send, "m_tongueOwner") == infected) return true;
    if (GetEntPropEnt(infected, Prop_Send, "m_tongueVictim") == survivor) return true;
    if (GetEntPropEnt(survivor, Prop_Send, "m_pounceAttacker") == infected) return true;
    if (GetEntPropEnt(survivor, Prop_Send, "m_jockeyAttacker") == infected) return true;
    if (GetEntPropEnt(survivor, Prop_Send, "m_pummelAttacker") == infected) return true;
    if (GetEntPropEnt(survivor, Prop_Send, "m_carryAttacker") == infected) return true;

    if (infected > 0 && IsClientInGame(infected) && IsPlayerAlive(infected))
    {
        if (GetGameTime() - g_fCarryEndTime[survivor] < 1.5)
        {
            return true;
        }
    }
    return false;
}

// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action CmdShowHistory(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    if (!g_bStatsLoaded[client]) {
        PrintToChat(client, "\x04[Stats] \x01Your stats are still loading. Please wait.");
        return Plugin_Handled;
    }

    FlushKillsCache(client);
	
	if (g_Lifetime[client].campaignsPlayed < g_Lifetime[client].campaignsWon) {
        g_Lifetime[client].campaignsPlayed = g_Lifetime[client].campaignsWon;
    }

    int totalKills = 0, gunKills = 0, meleeKills = 0, bulletKills = 0, shellKills = 0;
    int favT1 = 0, favT2 = 0, favT3 = 0, favSec = 0;
    char sFavT1[64], sFavT2[64], sFavT3[64], sFavSec[64];
	
    for (int i = 0; i < g_iCleanWeaponCount; i++) {
        WeaponStats wS;
		wS = g_WeaponLifetimeCache[client][i];
        char key[64];
        strcopy(key, sizeof(key), g_sCleanWeaponNames[i]);
		
        if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
		
        totalKills += wS.kills;

        if (IsGun(key) || StrEqual(key, "chainsaw")) gunKills += wS.kills;
        else if (IsMelee(key)) meleeKills += wS.kills;

        if (StrContains(key, "shotgun") != -1) shellKills += wS.kills;
        else if (IsGun(key)) bulletKills += wS.kills;

        int tier = GetWeaponTier(key);
        if (tier == 1 && wS.kills > favT1) { favT1 = wS.kills; strcopy(sFavT1, sizeof(sFavT1), key); }
        else if (tier == 2 && wS.kills > favT2) { favT2 = wS.kills; strcopy(sFavT2, sizeof(sFavT2), key); }
        else if (tier == 3 && wS.kills > favT3) { favT3 = wS.kills; strcopy(sFavT3, sizeof(sFavT3), key); }
        else if (tier == 4 && wS.kills > favSec) { favSec = wS.kills; strcopy(sFavSec, sizeof(sFavSec), key); }
    }
	
    totalKills += g_Lifetime[client].molotovKills;
    totalKills += g_Lifetime[client].pipeKills;

    int totalS = g_Lifetime[client].totalSeconds;
    int h = totalS / 3600, m = (totalS % 3600) / 60;
    float winRate = (g_Lifetime[client].campaignsPlayed > 0) ? (float(g_Lifetime[client].campaignsWon) / float(g_Lifetime[client].campaignsPlayed)) * 100.0 : 0.0;
    int cp = (g_Lifetime[client].campaignsPlayed > 0) ? g_Lifetime[client].campaignsPlayed : 1;
    float cp_f = float(cp);

    PrintToConsole(client, " \n=========================================================\n             LIFETIME STATISTICS HISTORY                 \n=========================================================");
    PrintToConsole(client, " [ LIFETIME GAMEPLAY STATS ]");
    PrintToConsole(client, " Playtime:           %d hours, %d minutes", h, m);
    PrintToConsole(client, " Campaigns:          %d Played / %d Won (%.1f%% Win Rate) / %d Restarts", g_Lifetime[client].campaignsPlayed, g_Lifetime[client].campaignsWon, winRate, g_Lifetime[client].totalRestarts);
	PrintToConsole(client, " Incapacitations:    %d (Avg: %.1f)  / Deaths (Permanent): %d (Avg: %.1f)", g_Lifetime[client].incaps, float(g_Lifetime[client].incaps) / cp_f, g_Lifetime[client].deaths, float(g_Lifetime[client].deaths) / cp_f);
	
    if (totalS < 3600) {
        PrintToConsole(client, " Infected Killed:    %d", totalKills);
    } else {
        float kph = (float(totalKills) / float(totalS)) * 3600.0;
        PrintToConsole(client, " Infected Killed:    %d  (Avg: %.1f / Hour)", totalKills, kph);
    }
	
    PrintToConsole(client, " Medkits:            %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Lifetime[client].medkitsUsed, float(g_Lifetime[client].medkitsUsed) / cp_f, g_Lifetime[client].medkitsShared, float(g_Lifetime[client].medkitsShared) / cp_f);
    PrintToConsole(client, " Pills:              %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Lifetime[client].pillsUsed, float(g_Lifetime[client].pillsUsed) / cp_f, g_Lifetime[client].pillsShared, float(g_Lifetime[client].pillsShared) / cp_f);
    PrintToConsole(client, " Adrenaline:         %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Lifetime[client].adrenalineUsed, float(g_Lifetime[client].adrenalineUsed) / cp_f, g_Lifetime[client].adrenalineShared, float(g_Lifetime[client].adrenalineShared) / cp_f);
    PrintToConsole(client, " Defibrillators:     %d  (Avg: %.1f / Match)\n", g_Lifetime[client].defibsUsed, float(g_Lifetime[client].defibsUsed) / cp_f);

    PrintToConsole(client, " [ TEAMPLAY STATS ]");
    PrintToConsole(client, " Healed by Ally:     %d  (Avg: %.1f)", g_Lifetime[client].healedByTeammate, float(g_Lifetime[client].healedByTeammate) / cp_f);
    PrintToConsole(client, " Defibbed by Ally:   %d  (Avg: %.1f)", g_Lifetime[client].defibbedByTeammate, float(g_Lifetime[client].defibbedByTeammate) / cp_f);	
    PrintToConsole(client, " Revives Done:       %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].revivesTotal, g_Lifetime[client].revivesRecord, float(g_Lifetime[client].revivesTotal) / cp_f);
    PrintToConsole(client, " Revived by Ally:    %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].revivedByTeammate, g_Lifetime[client].revivedByTeammateRecord, float(g_Lifetime[client].revivedByTeammate) / cp_f);	
    PrintToConsole(client, " Protections Done:   %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].protectionsTotal, g_Lifetime[client].protectionsRecord, float(g_Lifetime[client].protectionsTotal) / cp_f);
    PrintToConsole(client, " Protected by Ally:  %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].protectedByTeammate, g_Lifetime[client].protectedByTeammateRecord, float(g_Lifetime[client].protectedByTeammate) / cp_f);
	PrintToConsole(client, " Ledge Grabs:        %d  (Avg: %.1f)  / Ledge Rescues: %d (Avg: %.1f)", g_Lifetime[client].ledgeGrabs, float(g_Lifetime[client].ledgeGrabs) / cp_f, g_Lifetime[client].ledgeRescues, float(g_Lifetime[client].ledgeRescues) / cp_f);
    PrintToConsole(client, " FF Damage Dealt:    %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].ffDamageTotal, g_Lifetime[client].ffDamageRecord, float(g_Lifetime[client].ffDamageTotal) / cp_f);
    PrintToConsole(client, " FF Damage Received: %d  (Record: %d) (Avg: %.1f)\n", g_Lifetime[client].ffReceivedTotal, g_Lifetime[client].ffReceivedRecord, float(g_Lifetime[client].ffReceivedTotal) / cp_f);

    PrintToConsole(client, " [ THROWABLES ]");
    PrintToConsole(client, " Molotovs:           %d Thrown (Avg: %.1f) / %d Kills (Avg: %.1f)", g_Lifetime[client].molotovsThrown, float(g_Lifetime[client].molotovsThrown) / cp_f, g_Lifetime[client].molotovKills, float(g_Lifetime[client].molotovKills) / cp_f);
    PrintToConsole(client, " Pipe-Bombs:         %d Thrown (Avg: %.1f) / %d Kills (Avg: %.1f)", g_Lifetime[client].pipesThrown, float(g_Lifetime[client].pipesThrown) / cp_f, g_Lifetime[client].pipeKills, float(g_Lifetime[client].pipeKills) / cp_f);
    PrintToConsole(client, " Bile Jars:          %d Thrown (Avg: %.1f) / %d Direct Hits (Avg: %.1f)\n", g_Lifetime[client].bilesThrown, float(g_Lifetime[client].bilesThrown) / cp_f, g_Lifetime[client].bileHits, float(g_Lifetime[client].bileHits) / cp_f);

    PrintToConsole(client, " [ INFECTED KILLED ]");
	int totalSI = g_Lifetime[client].killsSmoker + g_Lifetime[client].killsHunter + g_Lifetime[client].killsBoomer + g_Lifetime[client].killsCharger + g_Lifetime[client].killsJockey + g_Lifetime[client].killsSpitter + g_Lifetime[client].killsTank + g_Lifetime[client].killsWitch;
    PrintToConsole(client, " Common Infected:    %d  (Avg: %.1f)", g_Lifetime[client].killsCommon, float(g_Lifetime[client].killsCommon) / cp_f);
	PrintToConsole(client, " Special Infected:   %d  (Avg: %.1f)", totalSI, float(totalSI) / cp_f);
    PrintToConsole(client, " Tanks:              %d  (Avg: %.1f)  / Damage Dealt: %d (Avg: %.1f)", g_Lifetime[client].killsTank, float(g_Lifetime[client].killsTank) / cp_f, g_Lifetime[client].tankDamage, float(g_Lifetime[client].tankDamage) / cp_f);
    PrintToConsole(client, " Witches:            %d  (Avg: %.1f)  / Damage Dealt: %d (Avg: %.1f)", g_Lifetime[client].killsWitch, float(g_Lifetime[client].killsWitch) / cp_f, g_Lifetime[client].witchDamage, float(g_Lifetime[client].witchDamage) / cp_f);
    PrintToConsole(client, " Smokers:            %d  (Avg: %.1f)  / Hunters: %d (Avg: %.1f)", g_Lifetime[client].killsSmoker, float(g_Lifetime[client].killsSmoker) / cp_f, g_Lifetime[client].killsHunter, float(g_Lifetime[client].killsHunter) / cp_f);
    PrintToConsole(client, " Boomers:            %d  (Avg: %.1f)  / Chargers: %d (Avg: %.1f)", g_Lifetime[client].killsBoomer, float(g_Lifetime[client].killsBoomer) / cp_f, g_Lifetime[client].killsCharger, float(g_Lifetime[client].killsCharger) / cp_f);
    PrintToConsole(client, " Jockeys:            %d  (Avg: %.1f)  / Spitters: %d (Avg: %.1f)\n", g_Lifetime[client].killsJockey, float(g_Lifetime[client].killsJockey) / cp_f, g_Lifetime[client].killsSpitter, float(g_Lifetime[client].killsSpitter) / cp_f);
	
    PrintToConsole(client, " [ SPECIAL COMBAT FEATS ]");
    PrintToConsole(client, " Hunter Skeets:      %-8d /  Hunter Deadstops:    %d", g_Lifetime[client].hunterSkeets, g_Lifetime[client].hunterDeadstops);
    PrintToConsole(client, " Tongue Cuts:        %-8d /  Self-Rescues:        %d", g_Lifetime[client].tongueCuts, g_Lifetime[client].selfRescues);
    PrintToConsole(client, " Jockey Deadstops:   %-8d /  Charger Levels:      %d", g_Lifetime[client].jockeyDeadstops, g_Lifetime[client].chargerLevels);
    PrintToConsole(client, " Witch Crowns:       %-8d /  Witches Startled:    %d", g_Lifetime[client].witchCrowns, g_Lifetime[client].witchesStartled);
    PrintToConsole(client, " Tank Rock Skeets:   %-8d /  Spitters Pre-Spat:   %d", g_Lifetime[client].rockSkeets, g_Lifetime[client].spitterKilledPreSpat);
    PrintToConsole(client, " Times Boomed On:    %-8d /  Car Alarms Triggered:%d\n", g_Lifetime[client].timesBoomed, g_Lifetime[client].carAlarmsTriggered);

	if (g_cvPrintWeaponStats.BoolValue)
	{
		PrintToConsole(client, " [ WEAPON SUMMARY ]");
		float gunPct = (totalKills > 0) ? (float(gunKills) / float(totalKills)) * 100.0 : 0.0;
		float meleePct = (totalKills > 0) ? (float(meleeKills) / float(totalKills)) * 100.0 : 0.0;
		int totalGuns = bulletKills + shellKills;
		float bulletPct = (totalGuns > 0) ? (float(bulletKills) / float(totalGuns)) * 100.0 : 0.0;
		float shellPct = (totalGuns > 0) ? (float(shellKills) / float(totalGuns)) * 100.0 : 0.0;
		
		PrintToConsole(client, " Firearms:           %.1f%%", gunPct);
		PrintToConsole(client, " Melee:              %.1f%%", meleePct);
		PrintToConsole(client, " Bullets vs Shells:  %.1f%% Bullets / %.1f%% Shells\n", bulletPct, shellPct);
	
		char buf[64];
		PrintToConsole(client, " [ FAVORITE WEAPONS ]");
		if (favT1 > 0) { GetPrettyWeaponName(sFavT1, buf, sizeof(buf)); PrintToConsole(client, " Tier 1:             %s (%d Kills)", buf, favT1); }
		if (favT2 > 0) { GetPrettyWeaponName(sFavT2, buf, sizeof(buf)); PrintToConsole(client, " Tier 2:             %s (%d Kills)", buf, favT2); }
		if (favT3 > 0) { GetPrettyWeaponName(sFavT3, buf, sizeof(buf)); PrintToConsole(client, " Tier 3 / Special:   %s (%d Kills)", buf, favT3); }
		if (favSec > 0) { GetPrettyWeaponName(sFavSec, buf, sizeof(buf)); PrintToConsole(client, " Secondary / Melee:  %s (%d Kills)\n", buf, favSec); }
	
		PrintToConsole(client, " [ ALL WEAPONS ]\n %-20s %-8s %-8s %-8s %-8s\n ---------------------------------------------------------", "Weapon", "Kills", "Acc%", "HS%", "Fired");
		for (int i = 0; i < g_iCleanWeaponCount; i++) {
			WeaponStats wS;
			wS = g_WeaponLifetimeCache[client][i];
			char key[64];
			strcopy(key, sizeof(key), g_sCleanWeaponNames[i]);
			if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
			if (wS.fired == 0 && wS.kills == 0) continue;
			GetPrettyWeaponName(key, buf, sizeof(buf));
			float acc = (wS.fired > 0) ? (float(wS.hits) / float(wS.fired)) * 100.0 : 0.0;
			float hs  = (wS.hits > 0)  ? (float(wS.headshots) / float(wS.hits)) * 100.0 : 0.0;
			PrintToConsole(client, " %-20s %-8d %-8.1f%% %-8.1f%% %-8d", buf, wS.kills, (acc > 100.0 ? 100.0 : acc), (hs > 100.0 ? 100.0 : hs), wS.fired);
			
			if (wS.killsCommon > 0 || wS.killsSmoker > 0 || wS.killsBoomer > 0 || wS.killsHunter > 0 || wS.killsSpitter > 0 || wS.killsJockey > 0 || wS.killsCharger > 0 || wS.killsTank > 0 || wS.killsWitch > 0 || wS.tankDamage > 0 || wS.witchDamage > 0) {
				int wSI = wS.killsSmoker + wS.killsBoomer + wS.killsHunter + wS.killsSpitter + wS.killsJockey + wS.killsCharger + wS.killsTank;
				PrintToConsole(client, "   -> Common: %d | Total SI: %d (Sm:%d Bo:%d Hu:%d Sp:%d Jo:%d Ch:%d Tk:%d Wt:%d) | Tank Dmg: %d | Witch Dmg: %d", 
					wS.killsCommon, wSI, wS.killsSmoker, wS.killsBoomer, wS.killsHunter, wS.killsSpitter, wS.killsJockey, wS.killsCharger, wS.killsTank, wS.killsWitch, wS.tankDamage, wS.witchDamage);
			}
	
			if (wS.hunterSkeets > 0 || wS.witchCrowns > 0 || wS.tongueCuts > 0 || wS.chargerLevels > 0 || wS.rockSkeets > 0 || wS.spitterKilledPreSpat > 0) {
				PrintToConsole(client, "   -> Feats: Skeets:%d | Witch Crowns:%d | Tongue Cuts:%d | Charger Levels:%d | Rock Skeets:%d | Spitters Pre-Spat:%d",
					wS.hunterSkeets, wS.witchCrowns, wS.tongueCuts, wS.chargerLevels, wS.rockSkeets, wS.spitterKilledPreSpat);
			}
		}
	}
	
    if (g_cvPrintDamageReceived.BoolValue) {
        int totalDmg = GetTotalDamageReceived(g_iDamageLifetimeCache[client]);
        PrintToConsole(client, "\n [ DAMAGE RECEIVED BY SOURCE ] (Total Taken: %d HP)", totalDmg);
        for (int i = 0; i < MAX_DMG_SOURCES; i++) {
            int dmgVal = g_iDamageLifetimeCache[client][i];
			if (dmgVal == 0) continue;
            char prettyName[64];
            GetPrettySourceName(g_sDamageSourceKeys[i], prettyName, sizeof(prettyName));
            PrintToConsole(client, " %-30s %d HP", prettyName, dmgVal);
        }
        PrintToConsole(client, "\n");
    }
	
    PrintToConsole(client, "=========================================================\n ");
    PrintToChat(client, "\x04[Stats] \x01Lifetime history printed to \x05Console\x01!");
    return Plugin_Handled;
}

public Action CmdShowCampaignHistory(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    if (!g_bStatsLoaded[client]) {
        PrintToChat(client, "\x04[Stats] \x01Your stats are still loading. Please wait.");
        return Plugin_Handled;
    }
	
    FlushKillsCache(client);
	
	if (g_Campaign[client].campaignsPlayed < g_Campaign[client].campaignsWon) {
        g_Campaign[client].campaignsPlayed = g_Campaign[client].campaignsWon;
    }

    int totalKills = 0, gunKills = 0, meleeKills = 0, bulletKills = 0, shellKills = 0;
    int favT1 = 0, favT2 = 0, favT3 = 0, favSec = 0;
    char sFavT1[64], sFavT2[64], sFavT3[64], sFavSec[64];
	
    for (int i = 0; i < g_iCleanWeaponCount; i++) {
        WeaponStats wS;
		wS = g_WeaponCampaignCache[client][i];
        char key[64];
        strcopy(key, sizeof(key), g_sCleanWeaponNames[i]);
		
        if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
		
        totalKills += wS.kills;

        if (IsGun(key) || StrEqual(key, "chainsaw")) gunKills += wS.kills;
        else if (IsMelee(key)) meleeKills += wS.kills;

        if (StrContains(key, "shotgun") != -1) shellKills += wS.kills;
        else if (IsGun(key)) bulletKills += wS.kills;

        int tier = GetWeaponTier(key);
        if (tier == 1 && wS.kills > favT1) { favT1 = wS.kills; strcopy(sFavT1, sizeof(sFavT1), key); }
        else if (tier == 2 && wS.kills > favT2) { favT2 = wS.kills; strcopy(sFavT2, sizeof(sFavT2), key); }
        else if (tier == 3 && wS.kills > favT3) { favT3 = wS.kills; strcopy(sFavT3, sizeof(sFavT3), key); }
        else if (tier == 4 && wS.kills > favSec) { favSec = wS.kills; strcopy(sFavSec, sizeof(sFavSec), key); }
    }
	
    totalKills += g_Campaign[client].molotovKills;
    totalKills += g_Campaign[client].pipeKills;

    int totalS = g_Campaign[client].totalSeconds;
    int h = totalS / 3600, m = (totalS % 3600) / 60;
    float winRate = (g_Campaign[client].campaignsPlayed > 0) ? (float(g_Campaign[client].campaignsWon) / float(g_Campaign[client].campaignsPlayed)) * 100.0 : 0.0;
    int cp = (g_Campaign[client].campaignsPlayed > 0) ? g_Campaign[client].campaignsPlayed : 1;
    float cp_f = float(cp);

    PrintToConsole(client, " \n=========================================================\n             CURRENT CAMPAIGN STATS HISTORY              \n=========================================================");
    PrintToConsole(client, " [ CAMPAIGN GAMEPLAY STATS ]");
    PrintToConsole(client, " Playtime:           %d hours, %d minutes", h, m);
    PrintToConsole(client, " Campaigns:          %d Played / %d Won (%.1f%% Win Rate) / %d Restarts", g_Campaign[client].campaignsPlayed, g_Campaign[client].campaignsWon, winRate, g_Campaign[client].totalRestarts);
	PrintToConsole(client, " Incapacitations:    %d (Avg: %.1f)  / Deaths (Permanent): %d (Avg: %.1f)", g_Campaign[client].incaps, float(g_Campaign[client].incaps) / cp_f, g_Campaign[client].deaths, float(g_Campaign[client].deaths) / cp_f);
	
    if (totalS < 3600) {
        PrintToConsole(client, " Infected Killed:    %d", totalKills);
    } else {
        float kph = (float(totalKills) / float(totalS)) * 3600.0;
        PrintToConsole(client, " Infected Killed:    %d  (Avg: %.1f / Hour)", totalKills, kph);
    }
	
    PrintToConsole(client, " Medkits:            %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Campaign[client].medkitsUsed, float(g_Campaign[client].medkitsUsed) / cp_f, g_Campaign[client].medkitsShared, float(g_Campaign[client].medkitsShared) / cp_f);
    PrintToConsole(client, " Pills:              %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Campaign[client].pillsUsed, float(g_Campaign[client].pillsUsed) / cp_f, g_Campaign[client].pillsShared, float(g_Campaign[client].pillsShared) / cp_f);
    PrintToConsole(client, " Adrenaline:         %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Campaign[client].adrenalineUsed, float(g_Campaign[client].adrenalineUsed) / cp_f, g_Campaign[client].adrenalineShared, float(g_Campaign[client].adrenalineShared) / cp_f);
    PrintToConsole(client, " Defibrillators:     %d  (Avg: %.1f / Match)\n", g_Campaign[client].defibsUsed, float(g_Campaign[client].defibsUsed) / cp_f);

    PrintToConsole(client, " [ TEAMPLAY STATS ]");
    PrintToConsole(client, " Healed by Ally:     %d  (Avg: %.1f)", g_Campaign[client].healedByTeammate, float(g_Campaign[client].healedByTeammate) / cp_f);
    PrintToConsole(client, " Defibbed by Ally:   %d  (Avg: %.1f)", g_Campaign[client].defibbedByTeammate, float(g_Campaign[client].defibbedByTeammate) / cp_f);	
    PrintToConsole(client, " Revives Done:       %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].revivesTotal, g_Campaign[client].revivesRecord, float(g_Campaign[client].revivesTotal) / cp_f);
    PrintToConsole(client, " Revived by Ally:    %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].revivedByTeammate, g_Campaign[client].revivedByTeammateRecord, float(g_Campaign[client].revivedByTeammate) / cp_f);	
    PrintToConsole(client, " Protections Done:   %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].protectionsTotal, g_Campaign[client].protectionsRecord, float(g_Campaign[client].protectionsTotal) / cp_f);
    PrintToConsole(client, " Protected by Ally:  %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].protectedByTeammate, g_Campaign[client].protectedByTeammateRecord, float(g_Campaign[client].protectedByTeammate) / cp_f);
	PrintToConsole(client, " Ledge Grabs:        %d  (Avg: %.1f)  / Ledge Rescues: %d (Avg: %.1f)", g_Campaign[client].ledgeGrabs, float(g_Campaign[client].ledgeGrabs) / cp_f, g_Campaign[client].ledgeRescues, float(g_Campaign[client].ledgeRescues) / cp_f);
    PrintToConsole(client, " FF Damage Dealt:    %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].ffDamageTotal, g_Campaign[client].ffDamageRecord, float(g_Campaign[client].ffDamageTotal) / cp_f);
    PrintToConsole(client, " FF Damage Received: %d  (Record: %d) (Avg: %.1f)\n", g_Campaign[client].ffReceivedTotal, g_Campaign[client].ffReceivedRecord, float(g_Campaign[client].ffReceivedTotal) / cp_f);

    PrintToConsole(client, " [ THROWABLES ]");
    PrintToConsole(client, " Molotovs:           %d Thrown (Avg: %.1f) / %d Kills (Avg: %.1f)", g_Campaign[client].molotovsThrown, float(g_Campaign[client].molotovsThrown) / cp_f, g_Campaign[client].molotovKills, float(g_Campaign[client].molotovKills) / cp_f);
    PrintToConsole(client, " Pipe-Bombs:         %d Thrown (Avg: %.1f) / %d Kills (Avg: %.1f)", g_Campaign[client].pipesThrown, float(g_Campaign[client].pipesThrown) / cp_f, g_Campaign[client].pipeKills, float(g_Campaign[client].pipeKills) / cp_f);
    PrintToConsole(client, " Bile Jars:          %d Thrown (Avg: %.1f) / %d Direct Hits (Avg: %.1f)\n", g_Campaign[client].bilesThrown, float(g_Campaign[client].bilesThrown) / cp_f, g_Campaign[client].bileHits, float(g_Campaign[client].bileHits) / cp_f);

    PrintToConsole(client, " [ INFECTED KILLED ]");
	int totalSI = g_Campaign[client].killsSmoker + g_Campaign[client].killsHunter + g_Campaign[client].killsBoomer + g_Campaign[client].killsCharger + g_Campaign[client].killsJockey + g_Campaign[client].killsSpitter + g_Campaign[client].killsTank + g_Campaign[client].killsWitch;
	PrintToConsole(client, " Common Infected:    %d  (Avg: %.1f)", g_Campaign[client].killsCommon, float(g_Campaign[client].killsCommon) / cp_f);
    PrintToConsole(client, " Special Infected:   %d  (Avg: %.1f)", totalSI, float(totalSI) / cp_f);    
    PrintToConsole(client, " Tanks:              %d  (Avg: %.1f)  / Damage Dealt: %d (Avg: %.1f)", g_Campaign[client].killsTank, float(g_Campaign[client].killsTank) / cp_f, g_Campaign[client].tankDamage, float(g_Campaign[client].tankDamage) / cp_f);
    PrintToConsole(client, " Witches:            %d  (Avg: %.1f)  / Damage Dealt: %d (Avg: %.1f)", g_Campaign[client].killsWitch, float(g_Campaign[client].killsWitch) / cp_f, g_Campaign[client].witchDamage, float(g_Campaign[client].witchDamage) / cp_f);
    PrintToConsole(client, " Smokers:            %d  (Avg: %.1f)  / Hunters: %d (Avg: %.1f)", g_Campaign[client].killsSmoker, float(g_Campaign[client].killsSmoker) / cp_f, g_Campaign[client].killsHunter, float(g_Campaign[client].killsHunter) / cp_f);
    PrintToConsole(client, " Boomers:            %d  (Avg: %.1f)  / Chargers: %d (Avg: %.1f)", g_Campaign[client].killsBoomer, float(g_Campaign[client].killsBoomer) / cp_f, g_Campaign[client].killsCharger, float(g_Campaign[client].killsCharger) / cp_f);
    PrintToConsole(client, " Jockeys:            %d  (Avg: %.1f)  / Spitters: %d (Avg: %.1f)\n", g_Campaign[client].killsJockey, float(g_Campaign[client].killsJockey) / cp_f, g_Campaign[client].killsSpitter, float(g_Campaign[client].killsSpitter) / cp_f);
	
    PrintToConsole(client, " [ SPECIAL COMBAT FEATS ]");
    PrintToConsole(client, " Hunter Skeets:      %-8d /  Hunter Deadstops:    %d", g_Campaign[client].hunterSkeets, g_Campaign[client].hunterDeadstops);
    PrintToConsole(client, " Tongue Cuts:        %-8d /  Self-Rescues:        %d", g_Campaign[client].tongueCuts, g_Campaign[client].selfRescues);
    PrintToConsole(client, " Jockey Deadstops:   %-8d /  Charger Levels:      %d", g_Campaign[client].jockeyDeadstops, g_Campaign[client].chargerLevels);
    PrintToConsole(client, " Witch Crowns:       %-8d /  Witches Startled:    %d", g_Campaign[client].witchCrowns, g_Campaign[client].witchesStartled);
    PrintToConsole(client, " Tank Rock Skeets:   %-8d /  Spitters Pre-Spat:   %d", g_Campaign[client].rockSkeets, g_Campaign[client].spitterKilledPreSpat);
    PrintToConsole(client, " Times Boomed On:    %-8d /  Car Alarms Triggered:%d\n", g_Campaign[client].timesBoomed, g_Campaign[client].carAlarmsTriggered);

	if (g_cvPrintWeaponStats.BoolValue)
	{
		PrintToConsole(client, " [ WEAPON SUMMARY ]");
		float gunPct = (totalKills > 0) ? (float(gunKills) / float(totalKills)) * 100.0 : 0.0;
		float meleePct = (totalKills > 0) ? (float(meleeKills) / float(totalKills)) * 100.0 : 0.0;
		int totalGuns = bulletKills + shellKills;
		float bulletPct = (totalGuns > 0) ? (float(bulletKills) / float(totalGuns)) * 100.0 : 0.0;
		float shellPct = (totalGuns > 0) ? (float(shellKills) / float(totalGuns)) * 100.0 : 0.0;
		
		PrintToConsole(client, " Firearms:           %.1f%%", gunPct);
		PrintToConsole(client, " Melee:              %.1f%%", meleePct);
		PrintToConsole(client, " Bullets vs Shells:  %.1f%% Bullets / %.1f%% Shells\n", bulletPct, shellPct);
	
		char buf[64];
		PrintToConsole(client, " [ FAVORITE WEAPONS ]");
		if (favT1 > 0) { GetPrettyWeaponName(sFavT1, buf, sizeof(buf)); PrintToConsole(client, " Tier 1:             %s (%d Kills)", buf, favT1); }
		if (favT2 > 0) { GetPrettyWeaponName(sFavT2, buf, sizeof(buf)); PrintToConsole(client, " Tier 2:             %s (%d Kills)", buf, favT2); }
		if (favT3 > 0) { GetPrettyWeaponName(sFavT3, buf, sizeof(buf)); PrintToConsole(client, " Tier 3 / Special:   %s (%d Kills)", buf, favT3); }
		if (favSec > 0) { GetPrettyWeaponName(sFavSec, buf, sizeof(buf)); PrintToConsole(client, " Secondary / Melee:  %s (%d Kills)\n", buf, favSec); }
	
		PrintToConsole(client, " [ ALL WEAPONS ]\n %-20s %-8s %-8s %-8s %-8s\n ---------------------------------------------------------", "Weapon", "Kills", "Acc%", "HS%", "Fired");
		for (int i = 0; i < g_iCleanWeaponCount; i++) {
			WeaponStats wS;
			wS = g_WeaponCampaignCache[client][i];
			char key[64];
			strcopy(key, sizeof(key), g_sCleanWeaponNames[i]);
			if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
			if (wS.fired == 0 && wS.kills == 0) continue;
			GetPrettyWeaponName(key, buf, sizeof(buf));
			float acc = (wS.fired > 0) ? (float(wS.hits) / float(wS.fired)) * 100.0 : 0.0;
			float hs  = (wS.hits > 0)  ? (float(wS.headshots) / float(wS.hits)) * 100.0 : 0.0;
			PrintToConsole(client, " %-20s %-8d %-8.1f%% %-8.1f%% %-8d", buf, wS.kills, (acc > 100.0 ? 100.0 : acc), (hs > 100.0 ? 100.0 : hs), wS.fired);
			
			if (wS.killsCommon > 0 || wS.killsSmoker > 0 || wS.killsBoomer > 0 || wS.killsHunter > 0 || wS.killsSpitter > 0 || wS.killsJockey > 0 || wS.killsCharger > 0 || wS.killsTank > 0 || wS.killsWitch > 0 || wS.tankDamage > 0 || wS.witchDamage > 0) {
				int wSI = wS.killsSmoker + wS.killsBoomer + wS.killsHunter + wS.killsSpitter + wS.killsJockey + wS.killsCharger + wS.killsTank;
				PrintToConsole(client, "   -> Common: %d | Total SI: %d (Sm:%d Bo:%d Hu:%d Sp:%d Jo:%d Ch:%d Tk:%d Wt:%d) | Tank Dmg: %d | Witch Dmg: %d", 
					wS.killsCommon, wSI, wS.killsSmoker, wS.killsBoomer, wS.killsHunter, wS.killsSpitter, wS.killsJockey, wS.killsCharger, wS.killsTank, wS.killsWitch, wS.tankDamage, wS.witchDamage);
			}
	
			if (wS.hunterSkeets > 0 || wS.witchCrowns > 0 || wS.tongueCuts > 0 || wS.chargerLevels > 0 || wS.rockSkeets > 0 || wS.spitterKilledPreSpat > 0) {
				PrintToConsole(client, "   -> Feats: Skeets:%d | Witch Crowns:%d | Tongue Cuts:%d | Charger Levels:%d | Rock Skeets:%d | Spitters Pre-Spat:%d",
					wS.hunterSkeets, wS.witchCrowns, wS.tongueCuts, wS.chargerLevels, wS.rockSkeets, wS.spitterKilledPreSpat);
			}
		}
	}
	
    if (g_cvPrintDamageReceived.BoolValue) {
        int totalDmg = GetTotalDamageReceived(g_iDamageCampaignCache[client]);
        PrintToConsole(client, "\n [ DAMAGE RECEIVED BY SOURCE ] (Total Taken: %d HP)", totalDmg);
        for (int i = 0; i < MAX_DMG_SOURCES; i++) {
            int dmgVal = g_iDamageCampaignCache[client][i];
			if (dmgVal == 0) continue;
            char prettyName[64];
            GetPrettySourceName(g_sDamageSourceKeys[i], prettyName, sizeof(prettyName));
            PrintToConsole(client, " %-30s %d HP", prettyName, dmgVal);
        }
        PrintToConsole(client, "\n");
    }
	
    PrintToConsole(client, "=========================================================\n ");
    PrintToChat(client, "\x04[Stats] \x01Current campaign history printed to \x05Console\x01!");
    return Plugin_Handled;
}

public Action CmdExportHistory(int client, int args)
{
    if (!IsValidClient(client) || !g_bStatsLoaded[client]) return Plugin_Handled;

    char sSaveLabel[64];
    if (args >= 1) {
        GetCmdArg(1, sSaveLabel, sizeof(sSaveLabel));
    } else {
        FormatTime(sSaveLabel, sizeof(sSaveLabel), "%Y%m%d_%H%M%S");
    }

    if (ExportPlayerStatsToFile(client, sSaveLabel)) {
        PrintToChat(client, "\x04[Stats] \x01Savestate exported with label: \x05%s", sSaveLabel);
    } else {
        PrintToChat(client, "\x04[Stats] \x01Failed to export your stats history.");
    }
    return Plugin_Handled;
}

public Action CmdImportHistory(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
	
	if (!g_bStatsLoaded[client]) {
		PrintToChat(client, "\x04[Stats] \x01Your stats are still loading. Please wait.");
		return Plugin_Handled;
	}

    if (args < 1) {
        PrintToChat(client, "\x04[Stats] \x01Usage: \x05!importstatshistory <profile_name>");
        return Plugin_Handled;
    }

    char sInputName[PLATFORM_MAX_PATH];
    GetCmdArg(1, sInputName, sizeof(sInputName));
    SanitizeFileName(sInputName, sizeof(sInputName));

    char auth[64];
    GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
    char safeAuth[64]; strcopy(safeAuth, sizeof(safeAuth), auth); ReplaceString(safeAuth, sizeof(safeAuth), ":", "_");

    char sPath[PLATFORM_MAX_PATH];
    
    BuildPath(Path_SM, sPath, sizeof(sPath), "logs/stats_history/Export_%s_%s.cfg", safeAuth, sInputName);
    if (!FileExists(sPath)) {
        BuildPath(Path_SM, sPath, sizeof(sPath), "logs/stats_history/%s", sInputName);
        if (!FileExists(sPath) && StrContains(sInputName, ".cfg") == -1) {
            BuildPath(Path_SM, sPath, sizeof(sPath), "logs/stats_history/%s.cfg", sInputName);
        }
    }

    if (!FileExists(sPath)) {
        PrintToChat(client, "\x04[Stats] \x01Save profile not found: \x05%s", sInputName);
        return Plugin_Handled;
    }

    KeyValues kv = new KeyValues("StatsHistory");
    if (!kv.ImportFromFile(sPath)) {
        PrintToChat(client, "\x04[Stats] \x01Failed to parse file: \x05%s", sInputName);
        delete kv;
        return Plugin_Handled;
    }

    kv.Rewind();
    if (!kv.JumpToKey(auth, false)) {
        PrintToChat(client, "\x04[Stats] \x01Error: This export file does not match your SteamID.");
        delete kv;
        return Plugin_Handled;
    }

    g_Lifetime[client].totalSeconds     = kv.GetNum("seconds_played");
    g_Lifetime[client].campaignsPlayed  = kv.GetNum("campaigns_played");
    g_Lifetime[client].campaignsWon     = kv.GetNum("campaigns_won");
    g_Lifetime[client].totalRestarts    = kv.GetNum("restarts");
	g_Lifetime[client].incaps           = kv.GetNum("incaps");
    g_Lifetime[client].deaths           = kv.GetNum("deaths");
    g_Lifetime[client].medkitsUsed      = kv.GetNum("medkits_used");
    g_Lifetime[client].medkitsShared    = kv.GetNum("medkits_shared");
    g_Lifetime[client].healedByTeammate   = kv.GetNum("healed_by_teammate");
    g_Lifetime[client].pillsUsed        = kv.GetNum("pills_used");
    g_Lifetime[client].pillsShared      = kv.GetNum("pills_shared");
    g_Lifetime[client].adrenalineUsed   = kv.GetNum("adrenaline_used");
    g_Lifetime[client].adrenalineShared = kv.GetNum("adrenaline_shared");
    g_Lifetime[client].defibsUsed       = kv.GetNum("defibs_used");
    g_Lifetime[client].defibbedByTeammate = kv.GetNum("defibbed_by_teammate");
    g_Lifetime[client].revivesTotal      = kv.GetNum("revives_total");
    g_Lifetime[client].revivesRecord     = kv.GetNum("revives_record");
    g_Lifetime[client].revivedByTeammate = kv.GetNum("revived_by_teammate");
    g_Lifetime[client].revivedByTeammateRecord = kv.GetNum("revived_by_teammate_record");
    g_Lifetime[client].protectionsTotal  = kv.GetNum("protections_total");
    g_Lifetime[client].protectionsRecord = kv.GetNum("protections_record");
    g_Lifetime[client].protectedByTeammate = kv.GetNum("protected_by_teammate");
    g_Lifetime[client].protectedByTeammateRecord = kv.GetNum("protected_by_teammate_record");
	g_Lifetime[client].ledgeGrabs        = kv.GetNum("ledge_grabs");
    g_Lifetime[client].ledgeRescues      = kv.GetNum("ledge_rescues");
    g_Lifetime[client].ffDamageTotal     = kv.GetNum("ff_damage_total");
    g_Lifetime[client].ffDamageRecord    = kv.GetNum("ff_damage_record");
    g_Lifetime[client].ffReceivedTotal   = kv.GetNum("ff_received_total");
    g_Lifetime[client].ffReceivedRecord  = kv.GetNum("ff_received_record");
    g_Lifetime[client].molotovsThrown    = kv.GetNum("molotovs_thrown");
    g_Lifetime[client].molotovKills      = kv.GetNum("molotov_kills");
    g_Lifetime[client].pipesThrown       = kv.GetNum("pipes_thrown");
    g_Lifetime[client].pipeKills         = kv.GetNum("pipe_kills");
    g_Lifetime[client].bilesThrown       = kv.GetNum("biles_thrown");
    g_Lifetime[client].bileHits          = kv.GetNum("bile_hits");
    g_Lifetime[client].killsCommon       = kv.GetNum("kills_common");
    g_Lifetime[client].killsTank         = kv.GetNum("kills_tank");
    g_Lifetime[client].killsWitch        = kv.GetNum("kills_witch");
    g_Lifetime[client].killsSmoker       = kv.GetNum("kills_smoker");
    g_Lifetime[client].killsHunter       = kv.GetNum("kills_hunter");
    g_Lifetime[client].killsBoomer       = kv.GetNum("kills_boomer");
    g_Lifetime[client].killsCharger      = kv.GetNum("kills_charger");
    g_Lifetime[client].killsJockey       = kv.GetNum("kills_jockey");
    g_Lifetime[client].killsSpitter      = kv.GetNum("kills_spitter");
    g_Lifetime[client].tankDamage        = kv.GetNum("tank_damage");
    g_Lifetime[client].witchDamage       = kv.GetNum("witch_damage");
    g_Lifetime[client].hunterSkeets      = kv.GetNum("hunter_skeets");
    g_Lifetime[client].witchCrowns       = kv.GetNum("witch_crowns");
    g_Lifetime[client].tongueCuts        = kv.GetNum("tongue_cuts");
	g_Lifetime[client].selfRescues       = kv.GetNum("self_rescues");
    g_Lifetime[client].chargerLevels     = kv.GetNum("charger_levels");
    g_Lifetime[client].rockSkeets        = kv.GetNum("rock_skeets");
    g_Lifetime[client].spitterKilledPreSpat = kv.GetNum("spitter_killed_pre_spat");
    g_Lifetime[client].jockeyDeadstops   = kv.GetNum("jockey_deadstops");
    g_Lifetime[client].hunterDeadstops   = kv.GetNum("hunter_deadstops");
	g_Lifetime[client].witchesStartled   = kv.GetNum("witches_startled");
    g_Lifetime[client].timesBoomed       = kv.GetNum("times_boomed");
	g_Lifetime[client].carAlarmsTriggered = kv.GetNum("car_alarms_triggered");

     WeaponStats zeroW;
    for (int i = 0; i < 128; i++) {
        g_WeaponLifetimeCache[client][i] = zeroW;
    }

    kv.Rewind();
    if (kv.JumpToKey(auth, false) && kv.JumpToKey("Weapons", false)) {
        if (kv.GotoFirstSubKey(false)) {
            do {
                char wName[64];
                kv.GetSectionName(wName, sizeof(wName));
                StringToLowerCase(wName);

                int id;
                if (g_smCleanToID.GetValue(wName, id)) {
                    g_WeaponLifetimeCache[client][id].fired        = kv.GetNum("fired");
                    g_WeaponLifetimeCache[client][id].hits         = kv.GetNum("hits");
                    g_WeaponLifetimeCache[client][id].kills        = kv.GetNum("kills");
                    g_WeaponLifetimeCache[client][id].headshots    = kv.GetNum("headshots");
                    g_WeaponLifetimeCache[client][id].killsCommon  = kv.GetNum("kills_common");
                    g_WeaponLifetimeCache[client][id].killsSmoker  = kv.GetNum("kills_smoker");
                    g_WeaponLifetimeCache[client][id].killsBoomer  = kv.GetNum("kills_boomer");
                    g_WeaponLifetimeCache[client][id].killsHunter  = kv.GetNum("kills_hunter");
                    g_WeaponLifetimeCache[client][id].killsSpitter = kv.GetNum("kills_spitter");
                    g_WeaponLifetimeCache[client][id].killsJockey  = kv.GetNum("kills_jockey");
                    g_WeaponLifetimeCache[client][id].killsCharger = kv.GetNum("kills_charger");
                    g_WeaponLifetimeCache[client][id].killsTank    = kv.GetNum("kills_tank");
                    g_WeaponLifetimeCache[client][id].killsWitch   = kv.GetNum("kills_witch");
                    g_WeaponLifetimeCache[client][id].tankDamage   = kv.GetNum("tank_damage");
                    g_WeaponLifetimeCache[client][id].witchDamage  = kv.GetNum("witch_damage");
                    g_WeaponLifetimeCache[client][id].hunterSkeets      = kv.GetNum("hunter_skeets");
                    g_WeaponLifetimeCache[client][id].witchCrowns       = kv.GetNum("witch_crowns");
                    g_WeaponLifetimeCache[client][id].tongueCuts        = kv.GetNum("tongue_cuts");
                    g_WeaponLifetimeCache[client][id].chargerLevels     = kv.GetNum("charger_levels");
                    g_WeaponLifetimeCache[client][id].rockSkeets        = kv.GetNum("rock_skeets");
                    g_WeaponLifetimeCache[client][id].spitterKilledPreSpat = kv.GetNum("spitter_killed_pre_spat");
                }
            } while (kv.GotoNextKey(false));
        }
    }

    for (int i = 0; i < MAX_DMG_SOURCES; i++) {
        g_iDamageLifetimeCache[client][i] = 0;
    }

    kv.Rewind();
    if (kv.JumpToKey(auth, false) && kv.JumpToKey("DamageReceived", false)) {
        if (kv.GotoFirstSubKey(false)) {
            do {
                char sName[64];
                kv.GetSectionName(sName, sizeof(sName));
                int dmgVal = kv.GetNum("damage");
                int sourceID = GetDamageSourceID(sName);
                g_iDamageLifetimeCache[client][sourceID] = dmgVal;
            } while (kv.GotoNextKey(false));
        }
    }
    delete kv;

    if (g_hDatabase != null) {
        Transaction hTr = new Transaction();
        
        char sPurge[256];
        g_hDatabase.Format(sPurge, sizeof(sPurge), "DELETE FROM weapon_stats WHERE steamid = '%s';", auth);
        hTr.AddQuery(sPurge);
        g_hDatabase.Format(sPurge, sizeof(sPurge), "DELETE FROM damage_received_stats WHERE steamid = '%s';", auth);
        hTr.AddQuery(sPurge);

        AddPlayerToTransaction(client, hTr);

        SQL_ExecuteTransaction(g_hDatabase, hTr, SQL_Transaction_Success, SQL_Transaction_Failure, GetClientUserId(client), DBPrio_High);
    }

    PrintToChat(client, "\x04[Stats] \x01Successfully imported profile: \x05%s", sInputName);
    return Plugin_Handled;
}

public Action CmdPrintHistory(int client, int args)
{
	if (!IsValidClient(client) || !g_bStatsLoaded[client]) return Plugin_Handled;
	GeneratePrintFile(client, false);
	PrintToChat(client, "\x04[Stats] \x01Full stats document printed to \x05logs/stats_history/");
	return Plugin_Handled;
}

public Action CmdPrintCampaignHistory(int client, int args)
{
	if (!IsValidClient(client) || !g_bStatsLoaded[client]) return Plugin_Handled;
	
	GenerateCampaignPrintFile(client);
	PrintToChat(client, "\x04[Stats] \x01Current campaign stats printed to \x05logs/stats_history/");
	return Plugin_Handled;
}

void GeneratePrintFile(int client, bool isAuto)
{
    if (!g_bStatsLoaded[client]) return;
    
    FlushAllCaches();

    char sPath[PLATFORM_MAX_PATH], sTime[32], auth64[64], auth2[64];
    GetClientAuthId(client, AuthId_SteamID64, auth64, sizeof(auth64));
    GetClientAuthId(client, AuthId_Steam2, auth2, sizeof(auth2));
    
    FormatTime(sTime, sizeof(sTime), "%Y-%m-%d_%H-%M-%S");

    if (isAuto) BuildPath(Path_SM, sPath, sizeof(sPath), "logs/stats_history/AutoPrint_%s_%s.txt", auth64, sTime);
    else BuildPath(Path_SM, sPath, sizeof(sPath), "logs/stats_history/Print_%s_%s.txt", auth64, sTime);

    File hFile = OpenFile(sPath, "w");
    if (hFile == null) return;

    int totalKills = 0, gunKills = 0, meleeKills = 0, bulletKills = 0, shellKills = 0;
    int favT1 = 0, favT2 = 0, favT3 = 0, favSec = 0;
    char sFavT1[64], sFavT2[64], sFavT3[64], sFavSec[64];
    
    for (int i = 0; i < g_iCleanWeaponCount; i++) {
        WeaponStats wS;
		wS = g_WeaponLifetimeCache[client][i];
        char key[64];
        strcopy(key, sizeof(key), g_sCleanWeaponNames[i]);
        
        if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
         
        totalKills += wS.kills;

        if (IsGun(key) || StrEqual(key, "chainsaw")) gunKills += wS.kills;
        else if (IsMelee(key)) meleeKills += wS.kills;
        if (StrContains(key, "shotgun") != -1) shellKills += wS.kills;
        else if (IsGun(key)) bulletKills += wS.kills;

        int tier = GetWeaponTier(key);
        if (tier == 1 && wS.kills > favT1) { favT1 = wS.kills; strcopy(sFavT1, sizeof(sFavT1), key); }
        else if (tier == 2 && wS.kills > favT2) { favT2 = wS.kills; strcopy(sFavT2, sizeof(sFavT2), key); }
        else if (tier == 3 && wS.kills > favT3) { favT3 = wS.kills; strcopy(sFavT3, sizeof(sFavT3), key); }
        else if (tier == 4 && wS.kills > favSec) { favSec = wS.kills; strcopy(sFavSec, sizeof(sFavSec), key); }
    }
    
    totalKills += g_Lifetime[client].molotovKills;
    totalKills += g_Lifetime[client].pipeKills;

    int totalS = g_Lifetime[client].totalSeconds;
    int h = totalS / 3600, m = (totalS % 3600) / 60;
    float winRate = (g_Lifetime[client].campaignsPlayed > 0) ? (float(g_Lifetime[client].campaignsWon) / float(g_Lifetime[client].campaignsPlayed)) * 100.0 : 0.0;
    int cp = (g_Lifetime[client].campaignsPlayed > 0) ? g_Lifetime[client].campaignsPlayed : 1;
    float cp_f = float(cp);

    char lineBuffer[256];

    hFile.WriteLine("=========================================================");
    hFile.WriteLine("             LIFETIME STATISTICS HISTORY                 ");
    hFile.WriteLine("=========================================================");
    
    Format(lineBuffer, sizeof(lineBuffer), "SteamID: %s", auth2);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Generated: %s\n", sTime);
    hFile.WriteLine(lineBuffer);
    
    hFile.WriteLine("[ LIFETIME GAMEPLAY STATS ]");
    
    Format(lineBuffer, sizeof(lineBuffer), "Playtime:           %d hours, %d minutes", h, m);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Campaigns:          %d Played / %d Won (%.1f%% Win Rate) / %d Restarts", g_Lifetime[client].campaignsPlayed, g_Lifetime[client].campaignsWon, winRate, g_Lifetime[client].totalRestarts);
    hFile.WriteLine(lineBuffer);
	
	Format(lineBuffer, sizeof(lineBuffer), "Incapacitations:    %d (Avg: %.1f)  / Deaths (Permanent): %d (Avg: %.1f)", g_Lifetime[client].incaps, float(g_Lifetime[client].incaps) / cp_f, g_Lifetime[client].deaths, float(g_Lifetime[client].deaths) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    if (totalS < 3600) {
        Format(lineBuffer, sizeof(lineBuffer), "Infected Killed:    %d", totalKills);
        hFile.WriteLine(lineBuffer);
    } else {
        float kph = (float(totalKills) / float(totalS)) * 3600.0;
        Format(lineBuffer, sizeof(lineBuffer), "Infected Killed:    %d  (Avg: %.1f / Hour)", totalKills, kph);
        hFile.WriteLine(lineBuffer);
    }
    
    Format(lineBuffer, sizeof(lineBuffer), "Medkits:            %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Lifetime[client].medkitsUsed, float(g_Lifetime[client].medkitsUsed) / cp_f, g_Lifetime[client].medkitsShared, float(g_Lifetime[client].medkitsShared) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Pills:              %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Lifetime[client].pillsUsed, float(g_Lifetime[client].pillsUsed) / cp_f, g_Lifetime[client].pillsShared, float(g_Lifetime[client].pillsShared) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Adrenaline:         %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Lifetime[client].adrenalineUsed, float(g_Lifetime[client].adrenalineUsed) / cp_f, g_Lifetime[client].adrenalineShared, float(g_Lifetime[client].adrenalineShared) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Defibrillators:     %d  (Avg: %.1f / Match)\n", g_Lifetime[client].defibsUsed, float(g_Lifetime[client].defibsUsed) / cp_f);
    hFile.WriteLine(lineBuffer);

    hFile.WriteLine("[ TEAMPLAY STATS ]");
    
    Format(lineBuffer, sizeof(lineBuffer), "Healed by Ally:     %d  (Avg: %.1f)", g_Lifetime[client].healedByTeammate, float(g_Lifetime[client].healedByTeammate) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Defibbed by Ally:   %d  (Avg: %.1f)", g_Lifetime[client].defibbedByTeammate, float(g_Lifetime[client].defibbedByTeammate) / cp_f);
    hFile.WriteLine(lineBuffer);	
    
    Format(lineBuffer, sizeof(lineBuffer), "Revives Done:       %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].revivesTotal, g_Lifetime[client].revivesRecord, float(g_Lifetime[client].revivesTotal) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Revived by Ally:    %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].revivedByTeammate, g_Lifetime[client].revivedByTeammateRecord, float(g_Lifetime[client].revivedByTeammate) / cp_f);
    hFile.WriteLine(lineBuffer);	
    
    Format(lineBuffer, sizeof(lineBuffer), "Protections Done:   %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].protectionsTotal, g_Lifetime[client].protectionsRecord, float(g_Lifetime[client].protectionsTotal) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Protected by Ally:  %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].protectedByTeammate, g_Lifetime[client].protectedByTeammateRecord, float(g_Lifetime[client].protectedByTeammate) / cp_f);
    hFile.WriteLine(lineBuffer);
	
	Format(lineBuffer, sizeof(lineBuffer), "Ledge Grabs:        %d  (Avg: %.1f)  / Ledge Rescues: %d (Avg: %.1f)", g_Lifetime[client].ledgeGrabs, float(g_Lifetime[client].ledgeGrabs) / cp_f, g_Lifetime[client].ledgeRescues, float(g_Lifetime[client].ledgeRescues) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "FF Damage Dealt:    %d  (Record: %d) (Avg: %.1f)", g_Lifetime[client].ffDamageTotal, g_Lifetime[client].ffDamageRecord, float(g_Lifetime[client].ffDamageTotal) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "FF Damage Received: %d  (Record: %d) (Avg: %.1f)\n", g_Lifetime[client].ffReceivedTotal, g_Lifetime[client].ffReceivedRecord, float(g_Lifetime[client].ffReceivedTotal) / cp_f);
    hFile.WriteLine(lineBuffer);

    hFile.WriteLine("[ THROWABLES ]");
    
    Format(lineBuffer, sizeof(lineBuffer), "Molotovs:           %d Thrown (Avg: %.1f) / %d Kills (Avg: %.1f)", g_Lifetime[client].molotovsThrown, float(g_Lifetime[client].molotovsThrown) / cp_f, g_Lifetime[client].molotovKills, float(g_Lifetime[client].molotovKills) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Pipe-Bombs:         %d Thrown (Avg: %.1f) / %d Kills (Avg: %.1f)", g_Lifetime[client].pipesThrown, float(g_Lifetime[client].pipesThrown) / cp_f, g_Lifetime[client].pipeKills, float(g_Lifetime[client].pipeKills) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Bile Jars:          %d Thrown (Avg: %.1f) / %d Direct Hits (Avg: %.1f)\n", g_Lifetime[client].bilesThrown, float(g_Lifetime[client].bilesThrown) / cp_f, g_Lifetime[client].bileHits, float(g_Lifetime[client].bileHits) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    hFile.WriteLine("[ INFECTED KILLED ]");
    
    int totalSI = g_Lifetime[client].killsSmoker + g_Lifetime[client].killsHunter + g_Lifetime[client].killsBoomer + g_Lifetime[client].killsCharger + g_Lifetime[client].killsJockey + g_Lifetime[client].killsSpitter + g_Lifetime[client].killsTank + g_Lifetime[client].killsWitch;
    
    Format(lineBuffer, sizeof(lineBuffer), "Common Infected:    %d  (Avg: %.1f)", g_Lifetime[client].killsCommon, float(g_Lifetime[client].killsCommon) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Special Infected:   %d  (Avg: %.1f)", totalSI, float(totalSI) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Witches:            %d  (Avg: %.1f)  / Damage Dealt: %d (Avg: %.1f)", g_Lifetime[client].killsWitch, float(g_Lifetime[client].killsWitch) / cp_f, g_Lifetime[client].witchDamage, float(g_Lifetime[client].witchDamage) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Smokers:            %d  (Avg: %.1f)  / Hunters: %d (Avg: %.1f)", g_Lifetime[client].killsSmoker, float(g_Lifetime[client].killsSmoker) / cp_f, g_Lifetime[client].killsHunter, float(g_Lifetime[client].killsHunter) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Boomers:            %d  (Avg: %.1f)  / Chargers: %d (Avg: %.1f)", g_Lifetime[client].killsBoomer, float(g_Lifetime[client].killsBoomer) / cp_f, g_Lifetime[client].killsCharger, float(g_Lifetime[client].killsCharger) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    Format(lineBuffer, sizeof(lineBuffer), "Jockeys:            %d  (Avg: %.1f)  / Spitters: %d (Avg: %.1f)\n", g_Lifetime[client].killsJockey, float(g_Lifetime[client].killsJockey) / cp_f, g_Lifetime[client].killsSpitter, float(g_Lifetime[client].killsSpitter) / cp_f);
    hFile.WriteLine(lineBuffer);
    
    hFile.WriteLine("[ SPECIAL COMBAT FEATS ]");
    Format(lineBuffer, sizeof(lineBuffer), "Hunter Skeets:      %-8d /  Hunter Deadstops:    %d", g_Lifetime[client].hunterSkeets, g_Lifetime[client].hunterDeadstops);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), "Tongue Cuts:        %-8d /  Self-Rescues:        %d", g_Lifetime[client].tongueCuts, g_Lifetime[client].selfRescues);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), "Jockey Deadstops:   %-8d /  Charger Levels:      %d", g_Lifetime[client].jockeyDeadstops, g_Lifetime[client].chargerLevels);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), "Witch Crowns:       %-8d /  Witches Startled:    %d", g_Lifetime[client].witchCrowns, g_Lifetime[client].witchesStartled);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), "Tank Rock Skeets:   %-8d /  Spitters Pre-Spat:   %d", g_Lifetime[client].rockSkeets, g_Lifetime[client].spitterKilledPreSpat);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), " Times Boomed On:    %-8d /  Car Alarms Triggered:%d\n", g_Lifetime[client].timesBoomed, g_Lifetime[client].carAlarmsTriggered);
    hFile.WriteLine(lineBuffer);

	if (g_cvPrintWeaponStats.BoolValue)
	{
		float gunPct = (totalKills > 0) ? (float(gunKills) / float(totalKills)) * 100.0 : 0.0;
		float meleePct = (totalKills > 0) ? (float(meleeKills) / float(totalKills)) * 100.0 : 0.0;
		int totalGuns = bulletKills + shellKills;
		float bulletPct = (totalGuns > 0) ? (float(bulletKills) / float(totalGuns)) * 100.0 : 0.0;
		float shellPct = (totalGuns > 0) ? (float(shellKills) / float(totalGuns)) * 100.0 : 0.0;
	
		hFile.WriteLine("[ WEAPON SUMMARY ]");
		
		Format(lineBuffer, sizeof(lineBuffer), "Firearms:           %.1f%%", gunPct);
		hFile.WriteLine(lineBuffer);
		
		Format(lineBuffer, sizeof(lineBuffer), "Melee:              %.1f%%", meleePct);
		hFile.WriteLine(lineBuffer);
		
		Format(lineBuffer, sizeof(lineBuffer), "Bullets vs Shells:  %.1f%% Bullets / %.1f%% Shells\n", bulletPct, shellPct);
		hFile.WriteLine(lineBuffer);
	
		char buf[64];
		hFile.WriteLine("[ FAVORITE WEAPONS ]");
		if (favT1 > 0) { 
			GetPrettyWeaponName(sFavT1, buf, sizeof(buf)); 
			Format(lineBuffer, sizeof(lineBuffer), "Tier 1:             %s (%d Kills)", buf, favT1); 
			hFile.WriteLine(lineBuffer); 
		}
		if (favT2 > 0) { 
			GetPrettyWeaponName(sFavT2, buf, sizeof(buf)); 
			Format(lineBuffer, sizeof(lineBuffer), "Tier 2:             %s (%d Kills)", buf, favT2); 
			hFile.WriteLine(lineBuffer); 
		}
		if (favT3 > 0) { 
			GetPrettyWeaponName(sFavT3, buf, sizeof(buf)); 
			Format(lineBuffer, sizeof(lineBuffer), "Tier 3 / Special:   %s (%d Kills)", buf, favT3); 
			hFile.WriteLine(lineBuffer); 
		}
		if (favSec > 0) { 
			GetPrettyWeaponName(sFavSec, buf, sizeof(buf)); 
			Format(lineBuffer, sizeof(lineBuffer), "Secondary / Melee:  %s (%d Kills)\n", buf, favSec); 
			hFile.WriteLine(lineBuffer); 
		}
	
		hFile.WriteLine("[ ALL WEAPONS ]");
		hFile.WriteLine("%-20s %-8s %-8s %-8s %-8s", "Weapon", "Kills", "Acc%", "HS%", "Fired");
		hFile.WriteLine("---------------------------------------------------------");
	
		for (int i = 0; i < g_iCleanWeaponCount; i++) {
			WeaponStats wS;
			wS = g_WeaponLifetimeCache[client][i];
			char key[64];
			strcopy(key, sizeof(key), g_sCleanWeaponNames[i]);
			if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
			if (wS.fired == 0 && wS.kills == 0) continue;
			GetPrettyWeaponName(key, buf, sizeof(buf));
			float acc = (wS.fired > 0) ? (float(wS.hits) / float(wS.fired)) * 100.0 : 0.0;
			float hs  = (wS.hits > 0)  ? (float(wS.headshots) / float(wS.hits)) * 100.0 : 0.0;
			
			Format(lineBuffer, sizeof(lineBuffer), "%-20s %-8d %-8.1f%% %-8.1f%% %-8d", buf, wS.kills, (acc > 100.0 ? 100.0 : acc), (hs > 100.0 ? 100.0 : hs), wS.fired);
			hFile.WriteLine(lineBuffer);
			
			if (wS.killsCommon > 0 || wS.killsSmoker > 0 || wS.killsBoomer > 0 || wS.killsHunter > 0 || wS.killsSpitter > 0 || wS.killsJockey > 0 || wS.killsCharger > 0 || wS.killsTank > 0 || wS.killsWitch > 0 || wS.tankDamage > 0 || wS.witchDamage > 0) {
				int wSI = wS.killsSmoker + wS.killsBoomer + wS.killsHunter + wS.killsSpitter + wS.killsJockey + wS.killsCharger + wS.killsTank;
				Format(lineBuffer, sizeof(lineBuffer), "   -> Common: %d | Total SI: %d (Sm:%d Bo:%d Hu:%d Sp:%d Jo:%d Ch:%d Tk:%d Wt:%d) | Tank Dmg: %d | Witch Dmg: %d", 
					wS.killsCommon, wSI, wS.killsSmoker, wS.killsBoomer, wS.killsHunter, wS.killsSpitter, wS.killsJockey, wS.killsCharger, wS.killsTank, wS.killsWitch, wS.tankDamage, wS.witchDamage);
				hFile.WriteLine(lineBuffer);
			}
	
			if (wS.hunterSkeets > 0 || wS.witchCrowns > 0 || wS.tongueCuts > 0 || wS.chargerLevels > 0 || wS.rockSkeets > 0 || wS.spitterKilledPreSpat > 0) {
				Format(lineBuffer, sizeof(lineBuffer), "   -> Feats: Skeets:%d | Witch Crowns:%d | Tongue Cuts:%d | Charger Levels:%d | Rock Skeets:%d | Spitters Pre-Spat:%d",
					wS.hunterSkeets, wS.witchCrowns, wS.tongueCuts, wS.chargerLevels, wS.rockSkeets, wS.spitterKilledPreSpat);
				hFile.WriteLine(lineBuffer);
			}
		}
	}
    
    if (g_cvPrintDamageReceived.BoolValue) {
        int totalDmg = GetTotalDamageReceived(g_iDamageLifetimeCache[client]);
        Format(lineBuffer, sizeof(lineBuffer), "\n[ DAMAGE RECEIVED BY SOURCE ] (Total Taken: %d HP)", totalDmg);
        hFile.WriteLine(lineBuffer);
        for (int i = 0; i < MAX_DMG_SOURCES; i++) {
            int dmgVal = g_iDamageLifetimeCache[client][i];
			if (dmgVal == 0) continue;
            char prettyName[64];
            GetPrettySourceName(g_sDamageSourceKeys[i], prettyName, sizeof(prettyName));
            Format(lineBuffer, sizeof(lineBuffer), "%-30s %d HP", prettyName, dmgVal);
            hFile.WriteLine(lineBuffer);
        }
        hFile.WriteLine("");
    }
    
    hFile.WriteLine("=========================================================");

    delete hFile;
}

void GenerateCampaignPrintFile(int client)
{
    if (!g_bStatsLoaded[client]) return;
	
    FlushAllCaches();

    char sPath[PLATFORM_MAX_PATH], sTime[32], auth64[64], auth2[64];
    GetClientAuthId(client, AuthId_SteamID64, auth64, sizeof(auth64));
    GetClientAuthId(client, AuthId_Steam2, auth2, sizeof(auth2));
	
    FormatTime(sTime, sizeof(sTime), "%Y-%m-%d_%H-%M-%S");
	
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));

    char safeMapName[64];
    strcopy(safeMapName, sizeof(safeMapName), mapName);
    SanitizeFileName(safeMapName, sizeof(safeMapName));

    BuildPath(Path_SM, sPath, sizeof(sPath), "logs/stats_history/%s_Campaign_%s_%s.txt", safeMapName, auth64, sTime);

    File hFile = OpenFile(sPath, "w");
    if (hFile == null) return;

    int totalKills = 0, gunKills = 0, meleeKills = 0, bulletKills = 0, shellKills = 0;
    int favT1 = 0, favT2 = 0, favT3 = 0, favSec = 0;
    char sFavT1[64], sFavT2[64], sFavT3[64], sFavSec[64];
	
    for (int i = 0; i < g_iCleanWeaponCount; i++) {
        WeaponStats wS;
		wS = g_WeaponCampaignCache[client][i];
        char key[64];
        strcopy(key, sizeof(key), g_sCleanWeaponNames[i]);
		
        if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
		 
        totalKills += wS.kills;

        if (IsGun(key) || StrEqual(key, "chainsaw")) gunKills += wS.kills;
        else if (IsMelee(key)) meleeKills += wS.kills;
        if (StrContains(key, "shotgun") != -1) shellKills += wS.kills;
        else if (IsGun(key)) bulletKills += wS.kills;

        int tier = GetWeaponTier(key);
        if (tier == 1 && wS.kills > favT1) { favT1 = wS.kills; strcopy(sFavT1, sizeof(sFavT1), key); }
        else if (tier == 2 && wS.kills > favT2) { favT2 = wS.kills; strcopy(sFavT2, sizeof(sFavT2), key); }
        else if (tier == 3 && wS.kills > favT3) { favT3 = wS.kills; strcopy(sFavT3, sizeof(sFavT3), key); }
        else if (tier == 4 && wS.kills > favSec) { favSec = wS.kills; strcopy(sFavSec, sizeof(sFavSec), key); }
    }
	
    totalKills += g_Campaign[client].molotovKills;
    totalKills += g_Campaign[client].pipeKills;

    int totalS = g_Campaign[client].totalSeconds;
    int h = totalS / 3600, m = (totalS % 3600) / 60;
    float winRate = (g_Campaign[client].campaignsPlayed > 0) ? (float(g_Campaign[client].campaignsWon) / float(g_Campaign[client].campaignsPlayed)) * 100.0 : 0.0;
    int cp = (g_Campaign[client].campaignsPlayed > 0) ? g_Campaign[client].campaignsPlayed : 1;
    float cp_f = float(cp);

    char lineBuffer[256];

    hFile.WriteLine("=========================================================");
    hFile.WriteLine("                CURRENT CAMPAIGN STATS                   ");
    hFile.WriteLine("=========================================================");
	
    Format(lineBuffer, sizeof(lineBuffer), "SteamID: %s", auth2);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Map:     %s", mapName); 
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Generated: %s\n", sTime);
    hFile.WriteLine(lineBuffer);
	
    hFile.WriteLine("[ CAMPAIGN GAMEPLAY STATS ]");
	
    Format(lineBuffer, sizeof(lineBuffer), "Playtime:           %d hours, %d minutes", h, m);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Campaigns:          %d Played / %d Won (%.1f%% Win Rate) / %d Restarts", g_Campaign[client].campaignsPlayed, g_Campaign[client].campaignsWon, winRate, g_Campaign[client].totalRestarts);
    hFile.WriteLine(lineBuffer);
	
	Format(lineBuffer, sizeof(lineBuffer), "Incapacitations:    %d (Avg: %.1f)  / Deaths (Permanent): %d (Avg: %.1f)", g_Campaign[client].incaps, float(g_Campaign[client].incaps) / cp_f, g_Campaign[client].deaths, float(g_Campaign[client].deaths) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    if (totalS < 3600) {
        Format(lineBuffer, sizeof(lineBuffer), "Infected Killed:    %d", totalKills);
        hFile.WriteLine(lineBuffer);
    } else {
        float kph = (float(totalKills) / float(totalS)) * 3600.0;
        Format(lineBuffer, sizeof(lineBuffer), "Infected Killed:    %d  (Avg: %.1f / Hour)", totalKills, kph);
        hFile.WriteLine(lineBuffer);
    }
	
    Format(lineBuffer, sizeof(lineBuffer), "Medkits:            %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Campaign[client].medkitsUsed, float(g_Campaign[client].medkitsUsed) / cp_f, g_Campaign[client].medkitsShared, float(g_Campaign[client].medkitsShared) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Pills:              %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Campaign[client].pillsUsed, float(g_Campaign[client].pillsUsed) / cp_f, g_Campaign[client].pillsShared, float(g_Campaign[client].pillsShared) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Adrenaline:         %d (Avg: %.1f)  / Shared: %d (Avg: %.1f)", g_Campaign[client].adrenalineUsed, float(g_Campaign[client].adrenalineUsed) / cp_f, g_Campaign[client].adrenalineShared, float(g_Campaign[client].adrenalineShared) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Defibrillators:     %d  (Avg: %.1f / Match)\n", g_Campaign[client].defibsUsed, float(g_Campaign[client].defibsUsed) / cp_f);
    hFile.WriteLine(lineBuffer);

    hFile.WriteLine("[ TEAMPLAY STATS ]");
	
    Format(lineBuffer, sizeof(lineBuffer), "Healed by Ally:     %d  (Avg: %.1f)", g_Campaign[client].healedByTeammate, float(g_Campaign[client].healedByTeammate) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Defibbed by Ally:   %d  (Avg: %.1f)", g_Campaign[client].defibbedByTeammate, float(g_Campaign[client].defibbedByTeammate) / cp_f);
    hFile.WriteLine(lineBuffer);	
	
    Format(lineBuffer, sizeof(lineBuffer), "Revives Done:       %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].revivesTotal, g_Campaign[client].revivesRecord, float(g_Campaign[client].revivesTotal) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Revived by Ally:    %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].revivedByTeammate, g_Campaign[client].revivedByTeammateRecord, float(g_Campaign[client].revivedByTeammate) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Protections Done:   %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].protectionsTotal, g_Campaign[client].protectionsRecord, float(g_Campaign[client].protectionsTotal) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Protected by Ally:  %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].protectedByTeammate, g_Campaign[client].protectedByTeammateRecord, float(g_Campaign[client].protectedByTeammate) / cp_f);
    hFile.WriteLine(lineBuffer);
	
	Format(lineBuffer, sizeof(lineBuffer), "Ledge Grabs:        %d  (Avg: %.1f)  / Ledge Rescues: %d (Avg: %.1f)", g_Campaign[client].ledgeGrabs, float(g_Campaign[client].ledgeGrabs) / cp_f, g_Campaign[client].ledgeRescues, float(g_Campaign[client].ledgeRescues) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "FF Damage Dealt:    %d  (Record: %d) (Avg: %.1f)", g_Campaign[client].ffDamageTotal, g_Campaign[client].ffDamageRecord, float(g_Campaign[client].ffDamageTotal) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "FF Damage Received: %d  (Record: %d) (Avg: %.1f)\n", g_Campaign[client].ffReceivedTotal, g_Campaign[client].ffReceivedRecord, float(g_Campaign[client].ffReceivedTotal) / cp_f);
    hFile.WriteLine(lineBuffer);

    hFile.WriteLine("[ THROWABLES ]");
	
    Format(lineBuffer, sizeof(lineBuffer), "Molotovs:           %d Thrown (Avg: %.1f) / %d Kills (Avg: %.1f)", g_Campaign[client].molotovsThrown, float(g_Campaign[client].molotovsThrown) / cp_f, g_Campaign[client].molotovKills, float(g_Campaign[client].molotovKills) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Pipe-Bombs:         %d Thrown (Avg: %.1f) / %d Kills (Avg: %.1f)", g_Campaign[client].pipesThrown, float(g_Campaign[client].pipesThrown) / cp_f, g_Campaign[client].pipeKills, float(g_Campaign[client].pipeKills) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Bile Jars:          %d Thrown (Avg: %.1f) / %d Direct Hits (Avg: %.1f)\n", g_Campaign[client].bilesThrown, float(g_Campaign[client].bilesThrown) / cp_f, g_Campaign[client].bileHits, float(g_Campaign[client].bileHits) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    hFile.WriteLine("[ INFECTED KILLED ]");
	
    int totalSI = g_Campaign[client].killsSmoker + g_Campaign[client].killsHunter + g_Campaign[client].killsBoomer + g_Campaign[client].killsCharger + g_Campaign[client].killsJockey + g_Campaign[client].killsSpitter + g_Campaign[client].killsTank + g_Campaign[client].killsWitch;
    
    Format(lineBuffer, sizeof(lineBuffer), "Common Infected:    %d  (Avg: %.1f)", g_Campaign[client].killsCommon, float(g_Campaign[client].killsCommon) / cp_f);
    hFile.WriteLine(lineBuffer);
	
	Format(lineBuffer, sizeof(lineBuffer), "Special Infected:   %d  (Avg: %.1f)", totalSI, float(totalSI) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Tanks:              %d  (Avg: %.1f)  / Damage Dealt: %d (Avg: %.1f)", g_Campaign[client].killsTank, float(g_Campaign[client].killsTank) / cp_f, g_Campaign[client].tankDamage, float(g_Campaign[client].tankDamage) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Witches:            %d  (Avg: %.1f)  / Damage Dealt: %d (Avg: %.1f)", g_Campaign[client].killsWitch, float(g_Campaign[client].killsWitch) / cp_f, g_Campaign[client].witchDamage, float(g_Campaign[client].witchDamage) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Smokers:            %d  (Avg: %.1f)  / Hunters: %d (Avg: %.1f)", g_Campaign[client].killsSmoker, float(g_Campaign[client].killsSmoker) / cp_f, g_Campaign[client].killsHunter, float(g_Campaign[client].killsHunter) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Boomers:            %d  (Avg: %.1f)  / Chargers: %d (Avg: %.1f)", g_Campaign[client].killsBoomer, float(g_Campaign[client].killsBoomer) / cp_f, g_Campaign[client].killsCharger, float(g_Campaign[client].killsCharger) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    Format(lineBuffer, sizeof(lineBuffer), "Jockeys:            %d  (Avg: %.1f)  / Spitters: %d (Avg: %.1f)\n", g_Campaign[client].killsJockey, float(g_Campaign[client].killsJockey) / cp_f, g_Campaign[client].killsSpitter, float(g_Campaign[client].killsSpitter) / cp_f);
    hFile.WriteLine(lineBuffer);
	
    hFile.WriteLine("[ SPECIAL COMBAT FEATS ]");
    Format(lineBuffer, sizeof(lineBuffer), "Hunter Skeets:      %-8d /  Hunter Deadstops:    %d", g_Campaign[client].hunterSkeets, g_Campaign[client].hunterDeadstops);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), "Tongue Cuts:        %-8d /  Self-Rescues:        %d", g_Campaign[client].tongueCuts, g_Campaign[client].selfRescues);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), "Jockey Deadstops:   %-8d /  Charger Levels:      %d", g_Campaign[client].jockeyDeadstops, g_Campaign[client].chargerLevels);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), "Witch Crowns:       %-8d /  Witches Startled:    %d", g_Campaign[client].witchCrowns, g_Campaign[client].witchesStartled);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), "Tank Rock Skeets:   %-8d /  Spitters Pre-Spat:   %d", g_Campaign[client].rockSkeets, g_Campaign[client].spitterKilledPreSpat);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), " Times Boomed On:    %-8d /  Car Alarms Triggered:%d\n", g_Campaign[client].timesBoomed, g_Campaign[client].carAlarmsTriggered);
    hFile.WriteLine(lineBuffer);

	if (g_cvPrintWeaponStats.BoolValue)
	{
		float gunPct = (totalKills > 0) ? (float(gunKills) / float(totalKills)) * 100.0 : 0.0;
		float meleePct = (totalKills > 0) ? (float(meleeKills) / float(totalKills)) * 100.0 : 0.0;
		int totalGuns = bulletKills + shellKills;
		float bulletPct = (totalGuns > 0) ? (float(bulletKills) / float(totalGuns)) * 100.0 : 0.0;
		float shellPct = (totalGuns > 0) ? (float(shellKills) / float(totalGuns)) * 100.0 : 0.0;
	
		hFile.WriteLine("[ WEAPON SUMMARY ]");
		
		Format(lineBuffer, sizeof(lineBuffer), "Firearms:           %.1f%%", gunPct);
		hFile.WriteLine(lineBuffer);
		
		Format(lineBuffer, sizeof(lineBuffer), "Melee:              %.1f%%", meleePct);
		hFile.WriteLine(lineBuffer);
		
		Format(lineBuffer, sizeof(lineBuffer), "Bullets vs Shells:  %.1f%% Bullets / %.1f%% Shells\n", bulletPct, shellPct);
		hFile.WriteLine(lineBuffer);
	
		char buf[64];
		hFile.WriteLine("[ FAVORITE WEAPONS ]");
		if (favT1 > 0) { 
			GetPrettyWeaponName(sFavT1, buf, sizeof(buf)); 
			Format(lineBuffer, sizeof(lineBuffer), "Tier 1:             %s (%d Kills)", buf, favT1); 
			hFile.WriteLine(lineBuffer); 
		}
		if (favT2 > 0) { 
			GetPrettyWeaponName(sFavT2, buf, sizeof(buf)); 
			Format(lineBuffer, sizeof(lineBuffer), "Tier 2:             %s (%d Kills)", buf, favT2); 
			hFile.WriteLine(lineBuffer); 
		}
		if (favT3 > 0) { 
			GetPrettyWeaponName(sFavT3, buf, sizeof(buf)); 
			Format(lineBuffer, sizeof(lineBuffer), "Tier 3 / Special:   %s (%d Kills)", buf, favT3); 
			hFile.WriteLine(lineBuffer); 
		}
		if (favSec > 0) { 
			GetPrettyWeaponName(sFavSec, buf, sizeof(buf)); 
			Format(lineBuffer, sizeof(lineBuffer), "Secondary / Melee:  %s (%d Kills)\n", buf, favSec); 
			hFile.WriteLine(lineBuffer); 
		}
	
		hFile.WriteLine("[ ALL WEAPONS ]");
		hFile.WriteLine("%-20s %-8s %-8s %-8s %-8s", "Weapon", "Kills", "Acc%", "HS%", "Fired");
		hFile.WriteLine("---------------------------------------------------------");
	
		for (int i = 0; i < g_iCleanWeaponCount; i++) {
			WeaponStats wS;
			wS = g_WeaponCampaignCache[client][i];
			char key[64];
			strcopy(key, sizeof(key), g_sCleanWeaponNames[i]);
			if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
			if (wS.fired == 0 && wS.kills == 0) continue;
			GetPrettyWeaponName(key, buf, sizeof(buf));
			float acc = (wS.fired > 0) ? (float(wS.hits) / float(wS.fired)) * 100.0 : 0.0;
			float hs  = (wS.hits > 0)  ? (float(wS.headshots) / float(wS.hits)) * 100.0 : 0.0;
			
			Format(lineBuffer, sizeof(lineBuffer), "%-20s %-8d %-8.1f%% %-8.1f%% %-8d", buf, wS.kills, (acc > 100.0 ? 100.0 : acc), (hs > 100.0 ? 100.0 : hs), wS.fired);
			hFile.WriteLine(lineBuffer);
			
			if (wS.killsCommon > 0 || wS.killsSmoker > 0 || wS.killsBoomer > 0 || wS.killsHunter > 0 || wS.killsSpitter > 0 || wS.killsJockey > 0 || wS.killsCharger > 0 || wS.killsTank > 0 || wS.killsWitch > 0 || wS.tankDamage > 0 || wS.witchDamage > 0) {
				int wSI = wS.killsSmoker + wS.killsBoomer + wS.killsHunter + wS.killsSpitter + wS.killsJockey + wS.killsCharger + wS.killsTank;
				Format(lineBuffer, sizeof(lineBuffer), "   -> Common: %d | Total SI: %d (Sm:%d Bo:%d Hu:%d Sp:%d Jo:%d Ch:%d Tk:%d Wt:%d) | Tank Dmg: %d | Witch Dmg: %d", 
					wS.killsCommon, wSI, wS.killsSmoker, wS.killsBoomer, wS.killsHunter, wS.killsSpitter, wS.killsJockey, wS.killsCharger, wS.killsTank, wS.killsWitch, wS.tankDamage, wS.witchDamage);
				hFile.WriteLine(lineBuffer);
			}
	
			if (wS.hunterSkeets > 0 || wS.witchCrowns > 0 || wS.tongueCuts > 0 || wS.chargerLevels > 0 || wS.rockSkeets > 0 || wS.spitterKilledPreSpat > 0) {
				Format(lineBuffer, sizeof(lineBuffer), "   -> Feats: Skeets:%d | Witch Crowns:%d | Tongue Cuts:%d | Charger Levels:%d | Rock Skeets:%d | Spitters Pre-Spat:%d",
					wS.hunterSkeets, wS.witchCrowns, wS.tongueCuts, wS.chargerLevels, wS.rockSkeets, wS.spitterKilledPreSpat);
				hFile.WriteLine(lineBuffer);
			}
		}
	}
	
    if (g_cvPrintDamageReceived.BoolValue) {
        int totalDmg = GetTotalDamageReceived(g_iDamageCampaignCache[client]);
        Format(lineBuffer, sizeof(lineBuffer), "\n[ DAMAGE RECEIVED BY SOURCE ] (Total Taken: %d HP)", totalDmg);
        hFile.WriteLine(lineBuffer);
        for (int i = 0; i < MAX_DMG_SOURCES; i++) {
            int dmgVal = g_iDamageCampaignCache[client][i];
			if (dmgVal == 0) continue;
            char prettyName[64];
            GetPrettySourceName(g_sDamageSourceKeys[i], prettyName, sizeof(prettyName));
            Format(lineBuffer, sizeof(lineBuffer), "%-30s %d HP", prettyName, dmgVal);
            hFile.WriteLine(lineBuffer);
        }
        hFile.WriteLine("");
    }
	
    hFile.WriteLine("[ BOT CAMPAIGN STATISTICS ]");
	
    int activeBotsCount = 0;
    char botName[64];
	
    for (int i = 0; i < MAX_BOT_CHARS; i++) {
        if (g_BotCampaign[i].totalSeconds > 0) {
            activeBotsCount++;
            GetBotPrettyName(i, botName, sizeof(botName));
			
            int botSeconds = g_BotCampaign[i].totalSeconds;
            int hS = botSeconds / 3600, mS = (botSeconds % 3600) / 60;
			
            int botTotalKills = g_BotCampaign[i].molotovKills + g_BotCampaign[i].pipeKills;
            for (int w = 0; w < g_iCleanWeaponCount; w++) {
                WeaponStats wS;
                wS = g_WeaponBotCampaignCache[i][w];
                char key[64];
                strcopy(key, sizeof(key), g_sCleanWeaponNames[w]);
                if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
                botTotalKills += wS.kills;
            }
			
            int botSI = g_BotCampaign[i].killsSmoker + g_BotCampaign[i].killsHunter + g_BotCampaign[i].killsBoomer + g_BotCampaign[i].killsCharger + g_BotCampaign[i].killsJockey + g_BotCampaign[i].killsSpitter + g_BotCampaign[i].killsTank + g_BotCampaign[i].killsWitch;
			
            Format(lineBuffer, sizeof(lineBuffer), " [ %s (BOT) ]", botName);
            hFile.WriteLine(lineBuffer);
			
            Format(lineBuffer, sizeof(lineBuffer), "  Playtime:        %d hours, %d minutes | Kills: %d | Incaps: %d / Deaths: %d / Restarts: %d", hS, mS, botTotalKills, g_BotCampaign[i].incaps, g_BotCampaign[i].deaths, g_BotCampaign[i].totalRestarts);
            hFile.WriteLine(lineBuffer);
			
            Format(lineBuffer, sizeof(lineBuffer), "  Infected Slain:  CI: %-5d /  Total SI: %-5d (Tanks: %-3d / Witches: %-3d)", g_BotCampaign[i].killsCommon, botSI, g_BotCampaign[i].killsTank, g_BotCampaign[i].killsWitch);
            hFile.WriteLine(lineBuffer);
			
            Format(lineBuffer, sizeof(lineBuffer), "  SI Breakdown:    Sm:%-3d /  Hu:%-3d /  Bo:%-3d /  Ch:%-3d /  Jo:%-3d /  Sp:%-3d", g_BotCampaign[i].killsSmoker, g_BotCampaign[i].killsHunter, g_BotCampaign[i].killsBoomer, g_BotCampaign[i].killsCharger, g_BotCampaign[i].killsJockey, g_BotCampaign[i].killsSpitter);
            hFile.WriteLine(lineBuffer);
			
            Format(lineBuffer, sizeof(lineBuffer), "  Teamplay Feats:  Revives:%-3d /  Heals:%-3d /  Defibs:%-3d /  Protections:%-3d /  Ledge Grabs:%-3d /  Ledge Rescues:%-3d", g_BotCampaign[i].revivesTotal, g_BotCampaign[i].medkitsUsed + g_BotCampaign[i].medkitsShared, g_BotCampaign[i].defibsUsed, g_BotCampaign[i].protectionsTotal, g_BotCampaign[i].ledgeGrabs, g_BotCampaign[i].ledgeRescues);
            hFile.WriteLine(lineBuffer);

            Format(lineBuffer, sizeof(lineBuffer), "  Throwables:      Moly Thrown: %-2d (%-3d Kills) | Pipe Thrown: %-2d (%-3d Kills) | Bile Thrown: %-2d", g_BotCampaign[i].molotovsThrown, g_BotCampaign[i].molotovKills, g_BotCampaign[i].pipesThrown, g_BotCampaign[i].pipeKills, g_BotCampaign[i].bilesThrown);
            hFile.WriteLine(lineBuffer);
			
            Format(lineBuffer, sizeof(lineBuffer), "  Dmg Dealt:       Tank:%-6d /  Witch:%-6d", g_BotCampaign[i].tankDamage, g_BotCampaign[i].witchDamage);
            hFile.WriteLine(lineBuffer);
			
            Format(lineBuffer, sizeof(lineBuffer), "  Dmg Received:    Total:%-5d HP", GetTotalDamageReceived(g_iDamageBotCampaignCache[i]));
            hFile.WriteLine(lineBuffer);
			
            if (g_BotCampaign[i].hunterSkeets > 0 || g_BotCampaign[i].witchCrowns > 0 || g_BotCampaign[i].tongueCuts > 0 || g_BotCampaign[i].selfRescues > 0 || g_BotCampaign[i].chargerLevels > 0 || g_BotCampaign[i].rockSkeets > 0 || g_BotCampaign[i].spitterKilledPreSpat > 0 || g_BotCampaign[i].witchesStartled > 0 || g_BotCampaign[i].timesBoomed > 0 || g_BotCampaign[i].jockeyDeadstops > 0 || g_BotCampaign[i].hunterDeadstops > 0 || g_BotCampaign[i].carAlarmsTriggered > 0) {
                Format(lineBuffer, sizeof(lineBuffer), "  Special Feats:   Skeets:%-3d | Crowns:%-3d | Cuts:%-3d | Self-Rescues:%-3d | Levels:%-3d | Rocks:%-3d | Pre-Spat:%-3d | Startled:%-3d | Boomed:%-3d",
                    g_BotCampaign[i].hunterSkeets, g_BotCampaign[i].witchCrowns, g_BotCampaign[i].tongueCuts, g_BotCampaign[i].selfRescues, g_BotCampaign[i].chargerLevels, g_BotCampaign[i].rockSkeets, g_BotCampaign[i].spitterKilledPreSpat, g_BotCampaign[i].witchesStartled, g_BotCampaign[i].timesBoomed);
                hFile.WriteLine(lineBuffer);
                Format(lineBuffer, sizeof(lineBuffer), "                   Jockey Deadstops: %-3d | Hunter Deadstops: %-3d | Car Alarms Triggered: %-3d", g_BotCampaign[i].jockeyDeadstops, g_BotCampaign[i].hunterDeadstops, g_BotCampaign[i].carAlarmsTriggered);
                hFile.WriteLine(lineBuffer);
            }
			
            hFile.WriteLine("  Weapon Log:");
            for (int w = 0; w < g_iCleanWeaponCount; w++) {
                WeaponStats wS;
                wS = g_WeaponBotCampaignCache[i][w];
                char key[64], prettyWPN[64];
                strcopy(key, sizeof(key), g_sCleanWeaponNames[w]);
                if (wS.kills == 0 && wS.fired == 0) continue;
                if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
                GetPrettyWeaponName(key, prettyWPN, sizeof(prettyWPN));

                float acc = (wS.fired > 0) ? (float(wS.hits) / float(wS.fired)) * 100.0 : 0.0;
                if (acc > 100.0) acc = 100.0;

                Format(lineBuffer, sizeof(lineBuffer), "    -> %-20s: %d Kills (Fired: %-5d | Hits: %-5d | Acc: %-5.1f%% | HS: %-5d)", 
                    prettyWPN, wS.kills, wS.fired, wS.hits, acc, wS.headshots);
                hFile.WriteLine(lineBuffer);
            }

            if (g_cvPrintDamageReceived.BoolValue) {
                hFile.WriteLine("  Damage Taken Log:");
                for (int d = 0; d < MAX_DMG_SOURCES; d++) {
                    int dmgVal = g_iDamageBotCampaignCache[i][d];
                    if (dmgVal == 0) continue;
                    char sName[64], prettyName[64];
                    strcopy(sName, sizeof(sName), g_sDamageSourceKeys[d]);
                    GetPrettySourceName(sName, prettyName, sizeof(prettyName));
                    Format(lineBuffer, sizeof(lineBuffer), "    -> %-25s: %d HP", prettyName, dmgVal);
                    hFile.WriteLine(lineBuffer);
                }
            }
            hFile.WriteLine("");
        }
    }
	
    if (activeBotsCount == 0) {
        hFile.WriteLine("  (No active bot companion statistics recorded for this campaign run yet.)");
    }
	
    hFile.WriteLine("=========================================================");

    delete hFile;
}

public Action CmdResetHistory(int client, int args)
{
    if (g_hDatabase == null) {
        PrintToChat(client, "\x04[Stats] \x01Database is not connected.");
        return Plugin_Handled;
    }

    if (g_cvResetBackup.BoolValue) {
        char sBackupLabel[64], sTime[32];
        FormatTime(sTime, sizeof(sTime), "%Y%m%d_%H%M%S");
        Format(sBackupLabel, sizeof(sBackupLabel), "AutoResetBackup_%s", sTime);
        
        for (int i = 1; i <= MaxClients; i++) {
            if (IsValidClient(i) && g_bStatsLoaded[i]) {
                ExportPlayerStatsToFile(i, sBackupLabel);
            }
        }
        ReplyToCommand(client, "\x04[Stats] \x01Optional pre-reset backups saved with label: \x05%s", sBackupLabel);
    }

    g_hDatabase.Query(SQL_Callback_Reset, "DELETE FROM player_stats;");
    g_hDatabase.Query(SQL_Callback_Reset, "DELETE FROM weapon_stats;");
    g_hDatabase.Query(SQL_Callback_Reset, "DELETE FROM damage_received_stats;");

    WeaponStats zeroWeapon;

    for (int i = 1; i <= MaxClients; i++) {
        g_Lifetime[i].Reset();
        g_Campaign[i].Reset();

        for (int w = 0; w < 128; w++) {
            g_WeaponLifetimeCache[i][w] = zeroWeapon;
            g_WeaponCampaignCache[i][w] = zeroWeapon;
        }

        for (int d = 0; d < MAX_DMG_SOURCES; d++) {
            g_iDamageLifetimeCache[i][d] = 0;
            g_iDamageCampaignCache[i][d] = 0;
        }
    }

    for (int b = 0; b < MAX_BOT_CHARS; b++) {
        g_BotCampaign[b].Reset();

        for (int w = 0; w < 128; w++) {
            g_WeaponBotCampaignCache[b][w] = zeroWeapon;
        }

        for (int d = 0; d < MAX_DMG_SOURCES; d++) {
            g_iDamageBotCampaignCache[b][d] = 0;
        }
    }

    PrintToChat(client, "\x04[Stats] \x01All stats history database records have been deleted and reset.");
    return Plugin_Handled;
}

public void SQL_Callback_Reset(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null) {
		LogError("[Stats SQLite] Error resetting table data: %s", error);
	}
}

public void SQL_Callback_GenericError(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null) LogError("[Stats History] Query Failed: %s", error);
}

public Action CmdResetStatsForMe(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;

    if (g_hDatabase == null) {
        PrintToChat(client, "\x04[Stats] \x01Database is not initialized. Cannot reset stats.");
        return Plugin_Handled;
    }

    char auth[64];
    if (!GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth))) {
        PrintToChat(client, "\x04[Stats] \x01Failed to retrieve your SteamID. Cannot reset stats.");
        return Plugin_Handled;
    }

    if (g_cvResetBackup.BoolValue) {
        char sTime[32], sBackupLabel[64];
        FormatTime(sTime, sizeof(sTime), "%Y%m%d_%H%M%S");
        Format(sBackupLabel, sizeof(sBackupLabel), "BackupBeforeReset_%s", sTime);

        if (ExportPlayerStatsToFile(client, sBackupLabel)) {
            PrintToChat(client, "\x04[Stats] \x01An automatic backup has been created: \x05%s", sBackupLabel);
            PrintToChat(client, "\x04[Stats] \x01To restore these stats later, type: \x03!importstatshistory %s", sBackupLabel);
        }
		else {
			PrintToChat(client, "\x04[Stats] \x01Warning: Failed to create a safety backup before resetting.");
		}		
    }
	

    char sQuery[256];
    g_hDatabase.Format(sQuery, sizeof(sQuery), "DELETE FROM player_stats WHERE steamid = '%s';", auth);
    SQL_TQuery(g_hDatabase, SQL_Callback_GenericError, sQuery);

    g_hDatabase.Format(sQuery, sizeof(sQuery), "DELETE FROM weapon_stats WHERE steamid = '%s';", auth);
    SQL_TQuery(g_hDatabase, SQL_Callback_GenericError, sQuery);
    
    g_hDatabase.Format(sQuery, sizeof(sQuery), "DELETE FROM damage_received_stats WHERE steamid = '%s';", auth);
    SQL_TQuery(g_hDatabase, SQL_Callback_GenericError, sQuery);

    g_Lifetime[client].Reset();
    g_Campaign[client].Reset();

    WeaponStats zeroWeapon;
    for (int w = 0; w < 128; w++) {
        g_WeaponLifetimeCache[client][w] = zeroWeapon;
        g_WeaponCampaignCache[client][w] = zeroWeapon;
    }

    for (int d = 0; d < MAX_DMG_SOURCES; d++) {
        g_iDamageLifetimeCache[client][d] = 0;
        g_iDamageCampaignCache[client][d] = 0;
    }

    PrintToChat(client, "\x04[Stats] \x01Successfully reset all of your statistics.");
    return Plugin_Handled;
}

public Action CmdShowBotsCampaignHistory(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    
    FlushAllCaches();

    PrintToConsole(client, " \n=========================================================\n             SURVIVOR BOTS CAMPAIGN STATISTICS           \n=========================================================");
	
    int activeBotsCount = 0;
    char botName[64], lineBuffer[256];

    for (int i = 0; i < MAX_BOT_CHARS; i++) {
        if (g_BotCampaign[i].totalSeconds > 0) {
            activeBotsCount++;
            GetBotPrettyName(i, botName, sizeof(botName));

            int totalS = g_BotCampaign[i].totalSeconds;
            int h = totalS / 3600, m = (totalS % 3600) / 60;
			
            int totalKills = g_BotCampaign[i].molotovKills + g_BotCampaign[i].pipeKills;
            for (int w = 0; w < g_iCleanWeaponCount; w++) {
                WeaponStats wS;
                wS = g_WeaponBotCampaignCache[i][w];
                char key[64];
                strcopy(key, sizeof(key), g_sCleanWeaponNames[w]);
                if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
                totalKills += wS.kills;
            }

            int botSI = g_BotCampaign[i].killsSmoker + g_BotCampaign[i].killsHunter + g_BotCampaign[i].killsBoomer + g_BotCampaign[i].killsCharger + g_BotCampaign[i].killsJockey + g_BotCampaign[i].killsSpitter + g_BotCampaign[i].killsTank + g_BotCampaign[i].killsWitch;
			
            PrintToConsole(client, " \n [ %s (BOT) ]", botName);
            PrintToConsole(client, "  Playtime:        %d hours, %d minutes | Kills: %d | Incaps: %d / Deaths: %d / Restarts: %d", h, m, totalKills, g_BotCampaign[i].incaps, g_BotCampaign[i].deaths, g_BotCampaign[i].totalRestarts);
            PrintToConsole(client, "  Infected Slain:  CI: %-5d /  Total SI: %-5d (Tanks: %-3d / Witches: %-3d)", g_BotCampaign[i].killsCommon, botSI, g_BotCampaign[i].killsTank, g_BotCampaign[i].killsWitch);
            PrintToConsole(client, "  SI Breakdown:    Sm:%-3d /  Hu:%-3d /  Bo:%-3d /  Ch:%-3d /  Jo:%-3d /  Sp:%-3d", g_BotCampaign[i].killsSmoker, g_BotCampaign[i].killsHunter, g_BotCampaign[i].killsBoomer, g_BotCampaign[i].killsCharger, g_BotCampaign[i].killsJockey, g_BotCampaign[i].killsSpitter);
            PrintToConsole(client, "  Teamplay Feats:  Revives:%-3d /  Heals:%-3d /  Defibs:%-3d /  Protections:%-3d /  Ledge Grabs:%-3d /  Ledge Rescues:%-3d", g_BotCampaign[i].revivesTotal, g_BotCampaign[i].medkitsUsed + g_BotCampaign[i].medkitsShared, g_BotCampaign[i].defibsUsed, g_BotCampaign[i].protectionsTotal, g_BotCampaign[i].ledgeGrabs, g_BotCampaign[i].ledgeRescues);
            PrintToConsole(client, "  Throwables:      Moly Thrown: %-2d (%-3d Kills) | Pipe Thrown: %-2d (%-3d Kills) | Bile Thrown: %-2d", g_BotCampaign[i].molotovsThrown, g_BotCampaign[i].molotovKills, g_BotCampaign[i].pipesThrown, g_BotCampaign[i].pipeKills, g_BotCampaign[i].bilesThrown);
            PrintToConsole(client, "  Dmg Dealt:       Tank:%-6d /  Witch:%-6d", g_BotCampaign[i].tankDamage, g_BotCampaign[i].witchDamage);
            PrintToConsole(client, "  Dmg Received:    Total:%-5d HP", GetTotalDamageReceived(g_iDamageBotCampaignCache[i]));
			
            if (g_BotCampaign[i].hunterSkeets > 0 || g_BotCampaign[i].witchCrowns > 0 || g_BotCampaign[i].tongueCuts > 0 || g_BotCampaign[i].selfRescues > 0 || g_BotCampaign[i].chargerLevels > 0 || g_BotCampaign[i].rockSkeets > 0 || g_BotCampaign[i].spitterKilledPreSpat > 0 || g_BotCampaign[i].witchesStartled > 0 || g_BotCampaign[i].timesBoomed > 0 || g_BotCampaign[i].jockeyDeadstops > 0 || g_BotCampaign[i].hunterDeadstops > 0 || g_BotCampaign[i].carAlarmsTriggered > 0) {
                PrintToConsole(client, "  Special Feats:   Skeets:%-3d | Crowns:%-3d | Cuts:%-3d | Self-Rescues:%-3d | Levels:%-3d | Rocks:%-3d | Pre-Spat:%-3d | Startled:%-3d | Boomed:%-3d",
                    g_BotCampaign[i].hunterSkeets, g_BotCampaign[i].witchCrowns, g_BotCampaign[i].tongueCuts, g_BotCampaign[i].selfRescues, g_BotCampaign[i].chargerLevels, g_BotCampaign[i].rockSkeets, g_BotCampaign[i].spitterKilledPreSpat, g_BotCampaign[i].witchesStartled, g_BotCampaign[i].timesBoomed);
                PrintToConsole(client, "                   Jockey Deadstops: %-3d | Hunter Deadstops: %-3d | Car Alarms Triggered: %-3d", g_BotCampaign[i].jockeyDeadstops, g_BotCampaign[i].hunterDeadstops, g_BotCampaign[i].carAlarmsTriggered);
            }

            PrintToConsole(client, "  Weapon Log:");
            for (int w = 0; w < g_iCleanWeaponCount; w++) {
                WeaponStats wS;
                wS = g_WeaponBotCampaignCache[i][w];
                char key[64], prettyWPN[64];
                strcopy(key, sizeof(key), g_sCleanWeaponNames[w]);
                if (wS.kills == 0 && wS.fired == 0) continue;
                if (StrEqual(key, "pipe_bomb") || StrEqual(key, "vomitjar") || StrEqual(key, "molotov") || IsCarryableObject(key)) continue;
                GetPrettyWeaponName(key, prettyWPN, sizeof(prettyWPN));

                float acc = (wS.fired > 0) ? (float(wS.hits) / float(wS.fired)) * 100.0 : 0.0;
                if (acc > 100.0) acc = 100.0;

                PrintToConsole(client, "    -> %-20s: %d Kills (Fired: %-5d | Hits: %-5d | Acc: %-5.1f%% | HS: %-5d)", 
                    prettyWPN, wS.kills, wS.fired, wS.hits, acc, wS.headshots);
            }

            if (g_cvPrintDamageReceived.BoolValue) {
                PrintToConsole(client, "  Damage Taken Log:");
                for (int d = 0; d < MAX_DMG_SOURCES; d++) {
                    int dmgVal = g_iDamageBotCampaignCache[i][d];
                    if (dmgVal == 0) continue;
                    char prettyName[64];
                    GetPrettySourceName(g_sDamageSourceKeys[d], prettyName, sizeof(prettyName));
                    Format(lineBuffer, sizeof(lineBuffer), "    -> %-25s: %d HP", prettyName, dmgVal);
                    PrintToConsole(client, lineBuffer);
                }
            }
        }
    }

    if (activeBotsCount == 0) {
        PrintToConsole(client, " \n  (No active bot companion statistics recorded for this campaign run yet.)");
    }

    PrintToConsole(client, "=========================================================\n ");
    PrintToChat(client, "\x04[Stats] \x01Survivor bots campaign history printed to \x05Console\x01!");
    return Plugin_Handled;
}

// ====================================================================================================
//					MANUAL SAVE COMMANDS
// ====================================================================================================
public Action CmdSaveHistory(int client, int args)
{
    if (g_hDatabase == null)
    {
        ReplyToCommand(client, "[Stats] Database not initialized. Cannot save.");
        return Plugin_Handled;
    }

    if (g_bIsDatabaseSaving)
    {
        ReplyToCommand(client, "[Stats] A save transaction is already in progress. Please wait.");
        return Plugin_Handled;
    }

    SaveAndWriteAllStats();
    ReplyToCommand(client, "\x04[Stats] \x01Global save triggered for all active players.");
    return Plugin_Handled;
}

public Action CmdSaveForMe(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;

    if (g_hDatabase == null)
    {
        PrintToChat(client, "\x04[Stats] \x01Database error. Statistics cannot be saved at this time.");
        return Plugin_Handled;
    }

    if (!g_bStatsLoaded[client])
    {
        PrintToChat(client, "\x04[Stats] \x01Your stats haven't finished loading yet.");
        return Plugin_Handled;
    }

    Transaction hTr = new Transaction();
    AddPlayerToTransaction(client, hTr);
    
    SQL_ExecuteTransaction(g_hDatabase, hTr, SQL_ManualSaveSuccess, SQL_ManualSaveFailure, GetClientUserId(client), DBPrio_High);

    PrintToChat(client, "\x04[Stats] \x01Manually syncing your stats to the database...");
    return Plugin_Handled;
}

public void SQL_ManualSaveSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    int client = GetClientOfUserId(data);
    if (client > 0 && IsClientInGame(client))
    {
        PrintToChat(client, "\x04[Stats] \x03Personal stats successfully saved!");
    }
}

public void SQL_ManualSaveFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    int client = GetClientOfUserId(data);
    if (client > 0 && IsClientInGame(client))
    {
        PrintToChat(client, "\x04[Stats] \x02Save failed. \x01Check server logs for details.");
    }
    LogError("[Stats History] Manual save transaction failed for player: %s", error);
}

void CacheCampaignStats(int client, const char[] auth)
{
    if (g_kvCampaignCache == null) return;

    g_kvCampaignCache.Rewind();
    if (g_kvCampaignCache.JumpToKey(auth, true))
    {
        g_kvCampaignCache.SetNum("seconds_played", g_Campaign[client].totalSeconds);
        g_kvCampaignCache.SetNum("campaigns_played", g_Campaign[client].campaignsPlayed);
        g_kvCampaignCache.SetNum("campaigns_won", g_Campaign[client].campaignsWon);
        g_kvCampaignCache.SetNum("restarts", g_Campaign[client].totalRestarts);
		g_kvCampaignCache.SetNum("incaps", g_Campaign[client].incaps);
        g_kvCampaignCache.SetNum("deaths", g_Campaign[client].deaths);
        g_kvCampaignCache.SetNum("medkits_used", g_Campaign[client].medkitsUsed);
        g_kvCampaignCache.SetNum("medkits_shared", g_Campaign[client].medkitsShared);
        g_kvCampaignCache.SetNum("healed_by_teammate", g_Campaign[client].healedByTeammate);
        g_kvCampaignCache.SetNum("pills_used", g_Campaign[client].pillsUsed);
        g_kvCampaignCache.SetNum("pills_shared", g_Campaign[client].pillsShared);
        g_kvCampaignCache.SetNum("adrenaline_used", g_Campaign[client].adrenalineUsed);
        g_kvCampaignCache.SetNum("adrenaline_shared", g_Campaign[client].adrenalineShared);
        g_kvCampaignCache.SetNum("defibs_used", g_Campaign[client].defibsUsed);
        g_kvCampaignCache.SetNum("defibbed_by_teammate", g_Campaign[client].defibbedByTeammate);
        g_kvCampaignCache.SetNum("revives_total", g_Campaign[client].revivesTotal);
        g_kvCampaignCache.SetNum("revives_record", g_Campaign[client].revivesRecord);
        g_kvCampaignCache.SetNum("revived_by_teammate", g_Campaign[client].revivedByTeammate);
        g_kvCampaignCache.SetNum("revived_by_teammate_record", g_Campaign[client].revivedByTeammateRecord);
        g_kvCampaignCache.SetNum("protections_total", g_Campaign[client].protectionsTotal);
        g_kvCampaignCache.SetNum("protections_record", g_Campaign[client].protectionsRecord);
        g_kvCampaignCache.SetNum("protected_by_teammate", g_Campaign[client].protectedByTeammate);
        g_kvCampaignCache.SetNum("protected_by_teammate_record", g_Campaign[client].protectedByTeammateRecord);
		g_kvCampaignCache.SetNum("ledge_grabs", g_Campaign[client].ledgeGrabs);
        g_kvCampaignCache.SetNum("ledge_rescues", g_Campaign[client].ledgeRescues);
        g_kvCampaignCache.SetNum("ff_damage_total", g_Campaign[client].ffDamageTotal);
        g_kvCampaignCache.SetNum("ff_damage_record", g_Campaign[client].ffDamageRecord);
        g_kvCampaignCache.SetNum("ff_received_total", g_Campaign[client].ffReceivedTotal);
        g_kvCampaignCache.SetNum("ff_received_record", g_Campaign[client].ffReceivedRecord);
        g_kvCampaignCache.SetNum("molotovs_thrown", g_Campaign[client].molotovsThrown);
        g_kvCampaignCache.SetNum("molotov_kills", g_Campaign[client].molotovKills);
        g_kvCampaignCache.SetNum("pipes_thrown", g_Campaign[client].pipesThrown);
        g_kvCampaignCache.SetNum("pipe_kills", g_Campaign[client].pipeKills);
        g_kvCampaignCache.SetNum("biles_thrown", g_Campaign[client].bilesThrown);
        g_kvCampaignCache.SetNum("bile_hits", g_Campaign[client].bileHits);
        g_kvCampaignCache.SetNum("kills_common", g_Campaign[client].killsCommon);
        g_kvCampaignCache.SetNum("kills_tank", g_Campaign[client].killsTank);
        g_kvCampaignCache.SetNum("kills_witch", g_Campaign[client].killsWitch);
        g_kvCampaignCache.SetNum("kills_smoker", g_Campaign[client].killsSmoker);
        g_kvCampaignCache.SetNum("kills_hunter", g_Campaign[client].killsHunter);
        g_kvCampaignCache.SetNum("kills_boomer", g_Campaign[client].killsBoomer);
        g_kvCampaignCache.SetNum("kills_charger", g_Campaign[client].killsCharger);
        g_kvCampaignCache.SetNum("kills_jockey", g_Campaign[client].killsJockey);
        g_kvCampaignCache.SetNum("kills_spitter", g_Campaign[client].killsSpitter);
        g_kvCampaignCache.SetNum("tank_damage", g_Campaign[client].tankDamage);
        g_kvCampaignCache.SetNum("witch_damage", g_Campaign[client].witchDamage);
        g_kvCampaignCache.SetNum("hunter_skeets", g_Campaign[client].hunterSkeets);
        g_kvCampaignCache.SetNum("witch_crowns", g_Campaign[client].witchCrowns);
        g_kvCampaignCache.SetNum("tongue_cuts", g_Campaign[client].tongueCuts);
		g_kvCampaignCache.SetNum("self_rescues", g_Campaign[client].selfRescues);
        g_kvCampaignCache.SetNum("charger_levels", g_Campaign[client].chargerLevels);
        g_kvCampaignCache.SetNum("rock_skeets", g_Campaign[client].rockSkeets);
        g_kvCampaignCache.SetNum("spitter_killed_pre_spat", g_Campaign[client].spitterKilledPreSpat);
        g_kvCampaignCache.SetNum("jockey_deadstops", g_Campaign[client].jockeyDeadstops);
        g_kvCampaignCache.SetNum("hunter_deadstops", g_Campaign[client].hunterDeadstops);
		g_kvCampaignCache.SetNum("witches_startled", g_Campaign[client].witchesStartled);
        g_kvCampaignCache.SetNum("times_boomed", g_Campaign[client].timesBoomed);
		g_kvCampaignCache.SetNum("car_alarms_triggered", g_Campaign[client].carAlarmsTriggered);

        if (g_kvCampaignCache.JumpToKey("Weapons", true)) {
            for (int i = 0; i < g_iCleanWeaponCount; i++) {
                char wName[64];
                strcopy(wName, sizeof(wName), g_sCleanWeaponNames[i]);
                WeaponStats wS;
                wS = g_WeaponCampaignCache[client][i];
                if (wS.fired == 0 && wS.kills == 0) continue;
                if (g_kvCampaignCache.JumpToKey(wName, true)) {
                    g_kvCampaignCache.SetNum("fired", wS.fired);
                    g_kvCampaignCache.SetNum("hits", wS.hits);
                    g_kvCampaignCache.SetNum("kills", wS.kills);
                    g_kvCampaignCache.SetNum("headshots", wS.headshots);
                    g_kvCampaignCache.SetNum("kills_common", wS.killsCommon);
                    g_kvCampaignCache.SetNum("kills_smoker", wS.killsSmoker);
                    g_kvCampaignCache.SetNum("kills_boomer", wS.killsBoomer);
                    g_kvCampaignCache.SetNum("kills_hunter", wS.killsHunter);
                    g_kvCampaignCache.SetNum("kills_spitter", wS.killsSpitter);
                    g_kvCampaignCache.SetNum("kills_jockey", wS.killsJockey);
                    g_kvCampaignCache.SetNum("kills_charger", wS.killsCharger);
                    g_kvCampaignCache.SetNum("kills_tank", wS.killsTank);
                    g_kvCampaignCache.SetNum("kills_witch", wS.killsWitch);
                    g_kvCampaignCache.SetNum("tank_damage", wS.tankDamage);
                    g_kvCampaignCache.SetNum("witch_damage", wS.witchDamage);
                    g_kvCampaignCache.SetNum("hunter_skeets", wS.hunterSkeets);
                    g_kvCampaignCache.SetNum("witch_crowns", wS.witchCrowns);
                    g_kvCampaignCache.SetNum("tongue_cuts", wS.tongueCuts);
                    g_kvCampaignCache.SetNum("charger_levels", wS.chargerLevels);
                    g_kvCampaignCache.SetNum("rock_skeets", wS.rockSkeets);
                    g_kvCampaignCache.SetNum("spitter_killed_pre_spat", wS.spitterKilledPreSpat);
                    g_kvCampaignCache.GoBack();
                }
            }
            g_kvCampaignCache.GoBack();
        }

        if (g_kvCampaignCache.JumpToKey("DamageReceived", true)) {
            for (int i = 0; i < MAX_DMG_SOURCES; i++) {
                int dmgVal = g_iDamageCampaignCache[client][i];
                if (dmgVal == 0) continue;
                if (g_kvCampaignCache.JumpToKey(g_sDamageSourceKeys[i], true)) {
                    g_kvCampaignCache.SetNum("damage", dmgVal);
                    g_kvCampaignCache.GoBack();
                }
            }
            g_kvCampaignCache.GoBack();
        }
    }
}

void RestoreCampaignStats(int client, const char[] auth)
{
    if (g_kvCampaignCache == null) return;

    g_kvCampaignCache.Rewind();
    if (g_kvCampaignCache.JumpToKey(auth, false))
    {
        g_Campaign[client].totalSeconds     = g_kvCampaignCache.GetNum("seconds_played");
        g_Campaign[client].campaignsPlayed  = g_kvCampaignCache.GetNum("campaigns_played");
        g_Campaign[client].campaignsWon     = g_kvCampaignCache.GetNum("campaigns_won");
        g_Campaign[client].totalRestarts    = g_kvCampaignCache.GetNum("restarts");
		g_Campaign[client].incaps           = g_kvCampaignCache.GetNum("incaps");
        g_Campaign[client].deaths           = g_kvCampaignCache.GetNum("deaths");
        g_Campaign[client].medkitsUsed      = g_kvCampaignCache.GetNum("medkits_used");
        g_Campaign[client].medkitsShared    = g_kvCampaignCache.GetNum("medkits_shared");
        g_Campaign[client].healedByTeammate   = g_kvCampaignCache.GetNum("healed_by_teammate");
        g_Campaign[client].pillsUsed        = g_kvCampaignCache.GetNum("pills_used");
        g_Campaign[client].pillsShared      = g_kvCampaignCache.GetNum("pills_shared");
        g_Campaign[client].adrenalineUsed   = g_kvCampaignCache.GetNum("adrenaline_used");
        g_Campaign[client].adrenalineShared = g_kvCampaignCache.GetNum("adrenaline_shared");
        g_Campaign[client].defibsUsed       = g_kvCampaignCache.GetNum("defibs_used");
        g_Campaign[client].defibbedByTeammate = g_kvCampaignCache.GetNum("defibbed_by_teammate");
        g_Campaign[client].revivesTotal      = g_kvCampaignCache.GetNum("revives_total");
        g_Campaign[client].revivesRecord     = g_kvCampaignCache.GetNum("revives_record");
        g_Campaign[client].revivedByTeammate = g_kvCampaignCache.GetNum("revived_by_teammate");
        g_Campaign[client].revivedByTeammateRecord = g_kvCampaignCache.GetNum("revived_by_teammate_record");
        g_Campaign[client].protectionsTotal  = g_kvCampaignCache.GetNum("protections_total");
        g_Campaign[client].protectionsRecord = g_kvCampaignCache.GetNum("protections_record");
        g_Campaign[client].protectedByTeammate = g_kvCampaignCache.GetNum("protected_by_teammate");
        g_Campaign[client].protectedByTeammateRecord = g_kvCampaignCache.GetNum("protected_by_teammate_record");
		g_Campaign[client].ledgeGrabs        = g_kvCampaignCache.GetNum("ledge_grabs");
        g_Campaign[client].ledgeRescues      = g_kvCampaignCache.GetNum("ledge_rescues");
        g_Campaign[client].ffDamageTotal     = g_kvCampaignCache.GetNum("ff_damage_total");
        g_Campaign[client].ffDamageRecord    = g_kvCampaignCache.GetNum("ff_damage_record");
        g_Campaign[client].ffReceivedTotal   = g_kvCampaignCache.GetNum("ff_received_total");
        g_Campaign[client].ffReceivedRecord  = g_kvCampaignCache.GetNum("ff_received_record");
        g_Campaign[client].molotovsThrown    = g_kvCampaignCache.GetNum("molotovs_thrown");
        g_Campaign[client].molotovKills      = g_kvCampaignCache.GetNum("molotov_kills");
        g_Campaign[client].pipesThrown       = g_kvCampaignCache.GetNum("pipes_thrown");
        g_Campaign[client].pipeKills         = g_kvCampaignCache.GetNum("pipe_kills");
        g_Campaign[client].bilesThrown       = g_kvCampaignCache.GetNum("biles_thrown");
        g_Campaign[client].bileHits          = g_kvCampaignCache.GetNum("bile_hits");
        g_Campaign[client].killsCommon       = g_kvCampaignCache.GetNum("kills_common");
        g_Campaign[client].killsTank         = g_kvCampaignCache.GetNum("kills_tank");
        g_Campaign[client].killsWitch        = g_kvCampaignCache.GetNum("kills_witch");
        g_Campaign[client].killsSmoker       = g_kvCampaignCache.GetNum("kills_smoker");
        g_Campaign[client].killsHunter       = g_kvCampaignCache.GetNum("kills_hunter");
        g_Campaign[client].killsBoomer       = g_kvCampaignCache.GetNum("kills_boomer");
        g_Campaign[client].killsCharger      = g_kvCampaignCache.GetNum("kills_charger");
        g_Campaign[client].killsJockey       = g_kvCampaignCache.GetNum("kills_jockey");
        g_Campaign[client].killsSpitter      = g_kvCampaignCache.GetNum("kills_spitter");
        g_Campaign[client].tankDamage        = g_kvCampaignCache.GetNum("tank_damage");
        g_Campaign[client].witchDamage       = g_kvCampaignCache.GetNum("witch_damage");
        g_Campaign[client].hunterSkeets      = g_kvCampaignCache.GetNum("hunter_skeets");
        g_Campaign[client].witchCrowns       = g_kvCampaignCache.GetNum("witch_crowns");
        g_Campaign[client].tongueCuts        = g_kvCampaignCache.GetNum("tongue_cuts");
		g_Campaign[client].selfRescues       = g_kvCampaignCache.GetNum("self_rescues");
        g_Campaign[client].chargerLevels     = g_kvCampaignCache.GetNum("charger_levels");
        g_Campaign[client].rockSkeets        = g_kvCampaignCache.GetNum("rock_skeets");
        g_Campaign[client].spitterKilledPreSpat = g_kvCampaignCache.GetNum("spitter_killed_pre_spat");
        g_Campaign[client].jockeyDeadstops   = g_kvCampaignCache.GetNum("jockey_deadstops");
        g_Campaign[client].hunterDeadstops   = g_kvCampaignCache.GetNum("hunter_deadstops");
		g_Campaign[client].witchesStartled   = g_kvCampaignCache.GetNum("witches_startled");
        g_Campaign[client].timesBoomed       = g_kvCampaignCache.GetNum("times_boomed");
		g_Campaign[client].carAlarmsTriggered = g_kvCampaignCache.GetNum("car_alarms_triggered");
		
		if (g_Campaign[client].campaignsPlayed < g_Campaign[client].campaignsWon) {
            g_Campaign[client].campaignsPlayed = g_Campaign[client].campaignsWon;
        }
    }

    WeaponStats zeroW;
    for (int i = 0; i < 128; i++) {
        g_WeaponCampaignCache[client][i] = zeroW;
    }

    g_kvCampaignCache.Rewind();
    if (g_kvCampaignCache.JumpToKey(auth, false) && g_kvCampaignCache.JumpToKey("Weapons", false)) {
        if (g_kvCampaignCache.GotoFirstSubKey(false)) {
            do {
                char wName[64]; g_kvCampaignCache.GetSectionName(wName, sizeof(wName));
                StringToLowerCase(wName);

                int id;
                if (g_smCleanToID.GetValue(wName, id)) {
                    g_WeaponCampaignCache[client][id].fired        = g_kvCampaignCache.GetNum("fired");
                    g_WeaponCampaignCache[client][id].hits         = g_kvCampaignCache.GetNum("hits");
                    g_WeaponCampaignCache[client][id].kills        = g_kvCampaignCache.GetNum("kills");
                    g_WeaponCampaignCache[client][id].headshots    = g_kvCampaignCache.GetNum("headshots");
                    g_WeaponCampaignCache[client][id].killsCommon  = g_kvCampaignCache.GetNum("kills_common");
                    g_WeaponCampaignCache[client][id].killsSmoker  = g_kvCampaignCache.GetNum("kills_smoker");
                    g_WeaponCampaignCache[client][id].killsBoomer  = g_kvCampaignCache.GetNum("kills_boomer");
                    g_WeaponCampaignCache[client][id].killsHunter  = g_kvCampaignCache.GetNum("kills_hunter");
                    g_WeaponCampaignCache[client][id].killsSpitter = g_kvCampaignCache.GetNum("kills_spitter");
                    g_WeaponCampaignCache[client][id].killsJockey  = g_kvCampaignCache.GetNum("kills_jockey");
                    g_WeaponCampaignCache[client][id].killsCharger = g_kvCampaignCache.GetNum("kills_charger");
                    g_WeaponCampaignCache[client][id].killsTank    = g_kvCampaignCache.GetNum("kills_tank");
                    g_WeaponCampaignCache[client][id].killsWitch   = g_kvCampaignCache.GetNum("kills_witch");
                    g_WeaponCampaignCache[client][id].tankDamage   = g_kvCampaignCache.GetNum("tank_damage");
                    g_WeaponCampaignCache[client][id].witchDamage  = g_kvCampaignCache.GetNum("witch_damage");
                    g_WeaponCampaignCache[client][id].hunterSkeets      = g_kvCampaignCache.GetNum("hunter_skeets");
                    g_WeaponCampaignCache[client][id].witchCrowns       = g_kvCampaignCache.GetNum("witch_crowns");
                    g_WeaponCampaignCache[client][id].tongueCuts        = g_kvCampaignCache.GetNum("tongue_cuts");
                    g_WeaponCampaignCache[client][id].chargerLevels     = g_kvCampaignCache.GetNum("charger_levels");
                    g_WeaponCampaignCache[client][id].rockSkeets        = g_kvCampaignCache.GetNum("rock_skeets");
                    g_WeaponCampaignCache[client][id].spitterKilledPreSpat = g_kvCampaignCache.GetNum("spitter_killed_pre_spat");
                }
            } while (g_kvCampaignCache.GotoNextKey(false));
        }
    }

    for (int i = 0; i < MAX_DMG_SOURCES; i++) {
        g_iDamageCampaignCache[client][i] = 0;
    }

    g_kvCampaignCache.Rewind();
    if (g_kvCampaignCache.JumpToKey(auth, false) && g_kvCampaignCache.JumpToKey("DamageReceived", false)) {
        if (g_kvCampaignCache.GotoFirstSubKey(false)) {
            do {
                char sName[64]; g_kvCampaignCache.GetSectionName(sName, sizeof(sName));
                int dmgVal = g_kvCampaignCache.GetNum("damage");
                int sourceID = GetDamageSourceID(sName);
                g_iDamageCampaignCache[client][sourceID] = dmgVal;
            } while (g_kvCampaignCache.GotoNextKey(false));
        }
    }

    g_kvCampaignCache.Rewind();
    g_kvCampaignCache.DeleteKey(auth);
}

bool ExportPlayerStatsToFile(int client, const char[] label)
{
    if (!IsValidClient(client) || !g_bStatsLoaded[client]) return false;

    FlushKillsCache(client);

    char sPath[PLATFORM_MAX_PATH], auth[64];
    GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
    
    char safeAuth[64]; 
    strcopy(safeAuth, sizeof(safeAuth), auth); 
    ReplaceString(safeAuth, sizeof(safeAuth), ":", "_");

    char sanitizedLabel[64];
    strcopy(sanitizedLabel, sizeof(sanitizedLabel), label);
    SanitizeFileName(sanitizedLabel, sizeof(sanitizedLabel));

    BuildPath(Path_SM, sPath, sizeof(sPath), "logs/stats_history/Export_%s_%s.cfg", safeAuth, sanitizedLabel);
	
	if (g_Lifetime[client].campaignsPlayed < g_Lifetime[client].campaignsWon) {
        g_Lifetime[client].campaignsPlayed = g_Lifetime[client].campaignsWon;
    }
	
    KeyValues exportKV = new KeyValues("StatsHistory");
    exportKV.JumpToKey(auth, true);

    exportKV.SetNum("seconds_played", g_Lifetime[client].totalSeconds);
    exportKV.SetNum("campaigns_played", g_Lifetime[client].campaignsPlayed);
    exportKV.SetNum("campaigns_won", g_Lifetime[client].campaignsWon);
    exportKV.SetNum("restarts", g_Lifetime[client].totalRestarts);
    exportKV.SetNum("incaps", g_Lifetime[client].incaps);
    exportKV.SetNum("deaths", g_Lifetime[client].deaths);
    exportKV.SetNum("medkits_used", g_Lifetime[client].medkitsUsed);
    exportKV.SetNum("medkits_shared", g_Lifetime[client].medkitsShared);
    exportKV.SetNum("healed_by_teammate", g_Lifetime[client].healedByTeammate);
    exportKV.SetNum("pills_used", g_Lifetime[client].pillsUsed);
    exportKV.SetNum("pills_shared", g_Lifetime[client].pillsShared);
    exportKV.SetNum("adrenaline_used", g_Lifetime[client].adrenalineUsed);
    exportKV.SetNum("adrenaline_shared", g_Lifetime[client].adrenalineShared);
    exportKV.SetNum("defibs_used", g_Lifetime[client].defibsUsed);
    exportKV.SetNum("defibbed_by_teammate", g_Lifetime[client].defibbedByTeammate);
    exportKV.SetNum("revives_total", g_Lifetime[client].revivesTotal);
    exportKV.SetNum("revives_record", g_Lifetime[client].revivesRecord);
    exportKV.SetNum("revived_by_teammate", g_Lifetime[client].revivedByTeammate);
    exportKV.SetNum("revived_by_teammate_record", g_Lifetime[client].revivedByTeammateRecord);
    exportKV.SetNum("protections_total", g_Lifetime[client].protectionsTotal);
    exportKV.SetNum("protections_record", g_Lifetime[client].protectionsRecord);
    exportKV.SetNum("protected_by_teammate", g_Lifetime[client].protectedByTeammate);
    exportKV.SetNum("protected_by_teammate_record", g_Lifetime[client].protectedByTeammateRecord);
    exportKV.SetNum("ledge_grabs", g_Lifetime[client].ledgeGrabs);
    exportKV.SetNum("ledge_rescues", g_Lifetime[client].ledgeRescues);
    exportKV.SetNum("ff_damage_total", g_Lifetime[client].ffDamageTotal);
    exportKV.SetNum("ff_damage_record", g_Lifetime[client].ffDamageRecord);
    exportKV.SetNum("ff_received_total", g_Lifetime[client].ffReceivedTotal);
    exportKV.SetNum("ff_received_record", g_Lifetime[client].ffReceivedRecord);
    exportKV.SetNum("molotovs_thrown", g_Lifetime[client].molotovsThrown);
    exportKV.SetNum("molotov_kills", g_Lifetime[client].molotovKills);
    exportKV.SetNum("pipes_thrown", g_Lifetime[client].pipesThrown);
    exportKV.SetNum("pipe_kills", g_Lifetime[client].pipeKills);
    exportKV.SetNum("biles_thrown", g_Lifetime[client].bilesThrown);
    exportKV.SetNum("bile_hits", g_Lifetime[client].bileHits);
    exportKV.SetNum("kills_common", g_Lifetime[client].killsCommon);
    exportKV.SetNum("kills_tank", g_Lifetime[client].killsTank);
    exportKV.SetNum("kills_witch", g_Lifetime[client].killsWitch);
    exportKV.SetNum("kills_smoker", g_Lifetime[client].killsSmoker);
    exportKV.SetNum("kills_hunter", g_Lifetime[client].killsHunter);
    exportKV.SetNum("kills_boomer", g_Lifetime[client].killsBoomer);
    exportKV.SetNum("kills_charger", g_Lifetime[client].killsCharger);
    exportKV.SetNum("kills_jockey", g_Lifetime[client].killsJockey);
    exportKV.SetNum("kills_spitter", g_Lifetime[client].killsSpitter);
    exportKV.SetNum("tank_damage", g_Lifetime[client].tankDamage);
    exportKV.SetNum("witch_damage", g_Lifetime[client].witchDamage);
    exportKV.SetNum("hunter_skeets", g_Lifetime[client].hunterSkeets);
    exportKV.SetNum("witch_crowns", g_Lifetime[client].witchCrowns);
    exportKV.SetNum("tongue_cuts", g_Lifetime[client].tongueCuts);
    exportKV.SetNum("self_rescues", g_Lifetime[client].selfRescues);    
    exportKV.SetNum("charger_levels", g_Lifetime[client].chargerLevels);
    exportKV.SetNum("rock_skeets", g_Lifetime[client].rockSkeets);
    exportKV.SetNum("spitter_killed_pre_spat", g_Lifetime[client].spitterKilledPreSpat);
    exportKV.SetNum("jockey_deadstops", g_Lifetime[client].jockeyDeadstops);
    exportKV.SetNum("hunter_deadstops", g_Lifetime[client].hunterDeadstops);
    exportKV.SetNum("witches_startled", g_Lifetime[client].witchesStartled);
    exportKV.SetNum("times_boomed", g_Lifetime[client].timesBoomed);
	exportKV.SetNum("car_alarms_triggered", g_Lifetime[client].carAlarmsTriggered);

    if (exportKV.JumpToKey("Weapons", true)) {
        for (int i = 0; i < g_iCleanWeaponCount; i++) {
            char wName[64];
            strcopy(wName, sizeof(wName), g_sCleanWeaponNames[i]);

            WeaponStats wS;
            wS = g_WeaponLifetimeCache[client][i];
            if (wS.fired == 0 && wS.kills == 0) continue;

            if (exportKV.JumpToKey(wName, true)) {
                exportKV.SetNum("fired", wS.fired);
                exportKV.SetNum("hits", wS.hits);
                exportKV.SetNum("kills", wS.kills);
                exportKV.SetNum("headshots", wS.headshots);
                exportKV.SetNum("kills_common", wS.killsCommon);
                exportKV.SetNum("kills_smoker", wS.killsSmoker);
                exportKV.SetNum("kills_boomer", wS.killsBoomer);
                exportKV.SetNum("kills_hunter", wS.killsHunter);
                exportKV.SetNum("kills_spitter", wS.killsSpitter);
                exportKV.SetNum("kills_jockey", wS.killsJockey);
                exportKV.SetNum("kills_charger", wS.killsCharger);
                exportKV.SetNum("kills_tank", wS.killsTank);
                exportKV.SetNum("kills_witch", wS.killsWitch);
                exportKV.SetNum("tank_damage", wS.tankDamage);
                exportKV.SetNum("witch_damage", wS.witchDamage);
                exportKV.SetNum("hunter_skeets", wS.hunterSkeets);
                exportKV.SetNum("witch_crowns", wS.witchCrowns);
                exportKV.SetNum("tongue_cuts", wS.tongueCuts);
                exportKV.SetNum("charger_levels", wS.chargerLevels);
                exportKV.SetNum("rock_skeets", wS.rockSkeets);
                exportKV.SetNum("spitter_killed_pre_spat", wS.spitterKilledPreSpat);
                exportKV.GoBack();
            }
        }
        exportKV.GoBack();
    }

    if (exportKV.JumpToKey("DamageReceived", true)) {
        for (int i = 0; i < MAX_DMG_SOURCES; i++) {
            int dmgVal = g_iDamageLifetimeCache[client][i];
            if (dmgVal == 0) continue;
            
            if (exportKV.JumpToKey(g_sDamageSourceKeys[i], true)) {
                exportKV.SetNum("damage", dmgVal);
                exportKV.GoBack();
            }
        }
        exportKV.GoBack();
    }

    exportKV.Rewind(); 
    bool bSuccess = exportKV.ExportToFile(sPath); 
    delete exportKV;

    return bSuccess;
}

// ====================================================================================================
//					CACHE HELPER FUNCTIONS
// ====================================================================================================
void CacheCommonKill(int client, const char[] clean)
{
    if (client <= 0 || client > MaxClients) return;
    
    int id;
    if (g_smCleanToID.GetValue(clean, id)) {
        g_iCachedCommonKills[client][id]++;
        g_iCachedTotalKills[client][id]++;
    }
}

void FlushKillsCache(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client)) return;

    for (int i = 0; i < g_iCleanWeaponCount; i++) {
        int commonKills = g_iCachedCommonKills[client][i];
        int totalKills = g_iCachedTotalKills[client][i];

        if (commonKills > 0 || totalKills > 0) {
            if (!g_bIsBot[client]) {
                if (g_bStatsLoaded[client]) {
                    g_WeaponLifetimeCache[client][i].kills += totalKills;
                    g_WeaponLifetimeCache[client][i].killsCommon += commonKills;

                    g_WeaponCampaignCache[client][i].kills += totalKills;
                    g_WeaponCampaignCache[client][i].killsCommon += commonKills;
                }
            } else {
                int charID = g_iClientChar[client];
                if (charID >= 0 && charID < MAX_BOT_CHARS) {
                    g_WeaponBotCampaignCache[charID][i].kills += totalKills;
                    g_WeaponBotCampaignCache[charID][i].killsCommon += commonKills;
                }
            }

            g_iCachedCommonKills[client][i] = 0;
            g_iCachedTotalKills[client][i] = 0;
        }
    }
}

void FlushAllCaches()
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            FlushKillsCache(i);
        }
    }
}

// ====================================================================================================
//					MATCH ACTIVITY LOG FUNCTIONS
// ====================================================================================================
void LogActivity(const char[] format, any...)
{
    if (!g_cvEnable.BoolValue || !g_cvActivityLogsEnable.BoolValue) return;

    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 2);

    int h = g_iCampaignTime / 3600;
    int m = (g_iCampaignTime % 3600) / 60;
    int s = g_iCampaignTime % 60;

    char timestampedLine[512];
    Format(timestampedLine, sizeof(timestampedLine), "[%02d:%02d:%02d] %s", h, m, s, buffer);

    g_hActivityLog.PushString(timestampedLine);

    if (g_cvActivityChatEnable.BoolValue)
    {
        PrintToChatAll("\x04[Activity] \x01%s", buffer);
    }
}

void WriteActivityLog()
{
    if (!g_cvActivityLogsEnable.BoolValue || g_hActivityLog.Length == 0) return;

    char sMap[64], sDate[32], sDifficulty[32];
    GetCurrentMap(sMap, sizeof(sMap));
    FormatTime(sDate, sizeof(sDate), "%Y%m%d_%H%M%S");
    g_cvDifficulty.GetString(sDifficulty, sizeof(sDifficulty));

    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "logs/match_activity/Activity_%s_%s_%s.log", sMap, sDifficulty, sDate);

    File hFile = OpenFile(sPath, "w");
    if (hFile == null) return;

    hFile.WriteLine("=========================================================");
    hFile.WriteLine("                   MATCH ACTIVITY LOG                    ");
    hFile.WriteLine("=========================================================");
    
    char lineBuffer[256];
    Format(lineBuffer, sizeof(lineBuffer), " Map:        %s", sMap);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), " Difficulty: %s", sDifficulty);
    hFile.WriteLine(lineBuffer);
    Format(lineBuffer, sizeof(lineBuffer), " Date/Time:  %s", sDate);
    hFile.WriteLine(lineBuffer);
    
    hFile.WriteLine("=========================================================\n");

    char line[512];
    for (int i = 0; i < g_hActivityLog.Length; i++)
    {
        g_hActivityLog.GetString(i, line, sizeof(line));
        hFile.WriteLine(line);
    }

    hFile.WriteLine("\n=========================================================");
    hFile.WriteLine("                   END OF ACTIVITY LOG                   ");
    hFile.WriteLine("=========================================================");

    delete hFile;
}

public Action CmdShowMatchActivity(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client)) return Plugin_Handled;

    int len = g_hActivityLog.Length;
    if (len == 0)
    {
        PrintToChat(client, "\x04[Stats] \x01No activity has been logged yet for this campaign.");
        return Plugin_Handled;
    }

    PrintToConsole(client, " \n=========================================================");
    PrintToConsole(client, "             CURRENT MATCH ACTIVITY LOG                  ");
    PrintToConsole(client, "=========================================================");

    char line[512];
    for (int i = 0; i < len; i++)
    {
        g_hActivityLog.GetString(i, line, sizeof(line));
        PrintToConsole(client, "%s", line);
    }

    PrintToConsole(client, "=========================================================\n ");
    PrintToChat(client, "\x04[Stats] \x01Current match activity printed to \x05Console\x01!");

    return Plugin_Handled;
}

public Action CmdPrintMatchActivity(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client)) return Plugin_Handled;

    int len = g_hActivityLog.Length;
    if (len == 0)
    {
        PrintToChat(client, "\x04[Stats] \x01No activity has been logged yet to print.");
        return Plugin_Handled;
    }

    WriteActivityLog();
    PrintToChat(client, "\x04[Stats] \x01Current match activity successfully printed to file!");

    return Plugin_Handled;
}

void GetPlayerNameSafe(int client, char[] buffer, int maxlen)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
    {
        strcopy(buffer, maxlen, "Unknown");
        return;
    }

    if (IsFakeClient(client))
    {
        if (GetClientTeam(client) == TEAM_SURVIVOR)
        {
            int character = g_iClientChar[client];
            if (character == -1) {
                character = GetSurvivorCharacterInternal(client);
            }
            GetBotPrettyName(character, buffer, maxlen, client);
        }
        else
        {
            GetClientName(client, buffer, maxlen);
        }
    }
    else
    {
        GetClientName(client, buffer, maxlen);
    }
}

// ====================================================================================================
//                  INTERACTION LOGGING CALLBACKS
// ====================================================================================================

public void Event_GasCanPourCompleted(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || !IsClientInGame(client)) return;

    char sPlayerName[32];
    GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));

    int goal = GameRules_GetProp("m_nScavengeItemsGoal");
    g_iCansPoured++;

    if (goal > 0)
    {
        int left = goal - g_iCansPoured;
        if (left < 0) left = 0;

        LogActivity("%s poured a gas can. [Progress: %d/%d poured, %d left]", sPlayerName, g_iCansPoured, goal, left);
    }
    else
    {
        LogActivity("%s poured a gas can.", sPlayerName);
    }
}

public void Event_GasCanPourInterrupted(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || !IsClientInGame(client)) return;

    char sPlayerName[32];
    GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));

    LogActivity("%s's gas can pouring was interrupted.", sPlayerName);
}

public void Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    char item[64];
    event.GetString("item", item, sizeof(item));

    if (StrContains(item, "cola_bottles", false) != -1)
    {
        int client = GetClientOfUserId(event.GetInt("userid"));
        if (client > 0 && IsClientInGame(client))
        {
            char sPlayerName[32];
            GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));
            LogActivity("%s picked up the Cola Bottles.", sPlayerName);
        }
    }
}

public void Event_WeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    char item[64];
    event.GetString("item", item, sizeof(item));
    if (StrContains(item, "cola_bottles", false) != -1)
    {
        int client = GetClientOfUserId(event.GetInt("userid"));
        if (client > 0 && IsClientInGame(client))
        {
            char sPlayerName[32];
            GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));
            LogActivity("%s dropped the Cola Bottles.", sPlayerName);
        }
    }
}

public void Output_OnButtonInstant(const char[] output, int caller, int activator, float delay)
{
    if (activator <= 0 || activator > MaxClients || !IsClientInGame(activator)) return;

    if (caller > 0 && caller < MAX_ENTITIES_TRACKED)
    {
        float curTime = GetGameTime();
        if (curTime - g_fLastButtonPressTime[caller] < 1.0)
        {
            return;
        }
        g_fLastButtonPressTime[caller] = curTime;
    }

    char sPlayerName[32], sBtnName[64];
    GetPlayerNameSafe(activator, sPlayerName, sizeof(sPlayerName));
    GetEntPropString(caller, Prop_Data, "m_iName", sBtnName, sizeof(sBtnName));

    if (sBtnName[0] == '\0') strcopy(sBtnName, sizeof(sBtnName), "Unnamed Button");

    if (StrContains(sBtnName, "radio", false) != -1)
    {
        LogActivity("%s initiated the rescue radio dialogue!", sPlayerName);
    }
    else
    {
        LogActivity("%s pressed button [%s].", sPlayerName, sBtnName);
    }
}

public void Output_OnButtonStartHold(const char[] output, int caller, int activator, float delay)
{
    if (activator <= 0 || activator > MaxClients || !IsClientInGame(activator)) return;

    float curTime = GetGameTime();
    if (caller > 0 && caller < MAX_ENTITIES_TRACKED)
    {
        if (curTime - g_fLastButtonPressTime[caller] < 1.0) return;
        g_fLastButtonPressTime[caller] = curTime;
    }

    g_bIsPressingButton[activator] = true;

    char sPlayerName[32], sBtnName[64];
    GetPlayerNameSafe(activator, sPlayerName, sizeof(sPlayerName));
    GetEntPropString(caller, Prop_Data, "m_iName", sBtnName, sizeof(sBtnName));

    if (sBtnName[0] == '\0') strcopy(sBtnName, sizeof(sBtnName), "Unnamed Timed Button");

    LogActivity("%s started pressing button [%s]...", sPlayerName, sBtnName);
}

public void Output_OnButtonCompleteHold(const char[] output, int caller, int activator, float delay)
{
    int player = activator;

    if (player <= 0 || player > MaxClients || !IsClientInGame(player))
    {
        for (int i = 1; i <= MaxClients; i++) {
            if (g_bIsPressingButton[i]) { player = i; break; }
        }
    }
    if (player <= 0 || player > MaxClients || !IsClientInGame(player)) return;

    float curTime = GetGameTime();
    if (caller > 0 && caller < MAX_ENTITIES_TRACKED)
    {
        if (curTime - g_fLastButtonCompleteTime[caller] < 1.0) return;
        g_fLastButtonCompleteTime[caller] = curTime;
    }

    g_bIsPressingButton[player] = false;

    char sPlayerName[32], sBtnName[64];
    GetPlayerNameSafe(player, sPlayerName, sizeof(sPlayerName));
    GetEntPropString(caller, Prop_Data, "m_iName", sBtnName, sizeof(sBtnName));

    if (sBtnName[0] == '\0') strcopy(sBtnName, sizeof(sBtnName), "Unnamed Timed Button");

    LogActivity("%s completed pressing button [%s]!", sPlayerName, sBtnName);
}

public void Output_OnButtonCancelHold(const char[] output, int caller, int activator, float delay)
{
    int player = activator;

    if (player <= 0 || player > MaxClients || !IsClientInGame(player))
    {
        for (int i = 1; i <= MaxClients; i++) {
            if (g_bIsPressingButton[i]) { player = i; break; }
        }
    }
    if (player <= 0 || player > MaxClients || !IsClientInGame(player)) return;

    float curTime = GetGameTime();
    if (caller > 0 && caller < MAX_ENTITIES_TRACKED)
    {
        if (curTime - g_fLastButtonCancelTime[caller] < 1.0) return;
        g_fLastButtonCancelTime[caller] = curTime;
    }

    g_bIsPressingButton[player] = false;

    char sPlayerName[32], sBtnName[64];
    GetPlayerNameSafe(player, sPlayerName, sizeof(sPlayerName));
    GetEntPropString(caller, Prop_Data, "m_iName", sBtnName, sizeof(sBtnName));

    if (sBtnName[0] == '\0') strcopy(sBtnName, sizeof(sBtnName), "Unnamed Timed Button");

    LogActivity("%s stopped pressing button [%s] (unfinished).", sPlayerName, sBtnName);
}

public void Output_OnFinaleTriggered(const char[] output, int caller, int activator, float delay)
{
    int player = activator;

    if (player <= 0 || player > MaxClients || !IsClientInGame(player))
    {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsValidSurvivor(i)) { player = i; break; }
        }
    }
    if (player <= 0 || player > MaxClients || !IsClientInGame(player)) return;

    float curTime = GetGameTime();
    if (curTime - g_fLastFinaleTriggerTime < 2.0) return;
    g_fLastFinaleTriggerTime = curTime;

    char sPlayerName[32];
    GetPlayerNameSafe(player, sPlayerName, sizeof(sPlayerName));

    LogActivity("%s activated the finale trigger!", sPlayerName);
}

public void Output_OnUseFinished(const char[] output, int caller, int activator, float delay)
{
    if (activator <= 0 || activator > MaxClients || !IsClientInGame(activator)) return;

    char sName[64];
    GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));

    if (StrContains(sName, "nozzle", false) != -1)
    {
        return;
    }

    float curTime = GetGameTime();
    if (caller > 0 && caller < MAX_ENTITIES_TRACKED)
    {
        if (curTime - g_fLastButtonCompleteTime[caller] < 1.0) return;
        g_fLastButtonCompleteTime[caller] = curTime;
    }

    char sPlayerName[32];
    GetPlayerNameSafe(activator, sPlayerName, sizeof(sPlayerName));

    if (sName[0] == '\0') strcopy(sName, sizeof(sName), "Unnamed Use Target");

    LogActivity("%s completed interaction with [%s]!", sPlayerName, sName);
}

public void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    float curTime = GetGameTime();
    if (curTime - g_fLastFinaleTriggerTime < 2.0) return;
    g_fLastFinaleTriggerTime = curTime;

    int initiator = GetClosestSurvivorToFinale();
    if (initiator <= 0) return;

    char sPlayerName[32];
    GetPlayerNameSafe(initiator, sPlayerName, sizeof(sPlayerName));

    LogActivity("%s started the finale!", sPlayerName);
}

public void Event_GauntletFinaleStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    float curTime = GetGameTime();
    if (curTime - g_fLastFinaleTriggerTime < 2.0) return;
    g_fLastFinaleTriggerTime = curTime;

    int initiator = GetClosestSurvivorToFinale();
    if (initiator <= 0) return;

    char sPlayerName[32];
    GetPlayerNameSafe(initiator, sPlayerName, sizeof(sPlayerName));

    LogActivity("%s started the gauntlet finale!", sPlayerName);
}

public void Event_FinaleBridgeLowering(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnable.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || !IsClientInGame(client)) return;

    char sPlayerName[32];
    GetPlayerNameSafe(client, sPlayerName, sizeof(sPlayerName));

    LogActivity("%s triggered the bridge lowering mechanism!", sPlayerName);
}

int GetClosestSurvivorToFinale()
{
    int targetEnt = -1;
    while ((targetEnt = FindEntityByClassname(targetEnt, "trigger_finale")) != -1)
    {
        float targetPos[3];
        GetEntPropVector(targetEnt, Prop_Send, "m_vecOrigin", targetPos);

        int closestPlayer = -1;
        float minDistance = 999999.0;

        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidSurvivor(i) && IsPlayerAlive(i))
            {
                float playerPos[3];
                GetClientAbsOrigin(i, playerPos);
                float dist = GetVectorDistance(playerPos, targetPos);
                if (dist < minDistance)
                {
                    minDistance = dist;
                    closestPlayer = i;
                }
            }
        }
        return closestPlayer;
    }
    return -1;
}

// ====================================================================================================
//                  C1M2 STREETS - COLA SPECIFIC FUNCTIONS
// ====================================================================================================

void HookColaBuyerEntity()
{
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    if (StrContains(mapName, "c1m2", false) == -1) return;

    int maxEntities = GetMaxEntities();
    for (int entity = 1; entity < maxEntities; entity++)
    {
        if (IsValidEntity(entity))
        {
            char classname[64];
            GetEntityClassname(entity, classname, sizeof(classname));

            if (StrEqual(classname, "point_prop_use_target", false) || StrEqual(classname, "point_script_use_target", false))
            {
                HookSingleEntityOutput(entity, "OnUseFinished", Output_ColaBuyerFinished);
                //LogActivity("[Debug] Successfully hooked Whitaker's cola delivery slot (Entity index: %d, Class: %s)!", entity, classname);
                break;
            }
        }
    }
}

public void Output_ColaBuyerFinished(const char[] output, int caller, int activator, float delay)
{
    int player = activator;

    if (player <= 0 || player > MaxClients || !IsClientInGame(player))
    {
        player = GetEntPropEnt(caller, Prop_Send, "m_useActionOwner");
    }
    
    if (player <= 0 || player > MaxClients || !IsClientInGame(player))
    {
        float targetPos[3];
        GetEntPropVector(caller, Prop_Send, "m_vecOrigin", targetPos);
        float minDistance = 999999.0;
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidSurvivor(i) && IsPlayerAlive(i))
            {
                float plyPos[3];
                GetClientAbsOrigin(i, plyPos);
                float dist = GetVectorDistance(plyPos, targetPos);
                if (dist < minDistance)
                    player = i;
            }
        }
    }

    if (player > 0 && IsClientInGame(player))
    {
        char sPlayerName[32];
        GetPlayerNameSafe(player, sPlayerName, sizeof(sPlayerName));
        LogActivity("%s successfully delivered the cola to Whitaker!", sPlayerName);
    }
    else
    {
        LogActivity("The Cola Bottles were successfully delivered to Whitaker!");
    }
}
