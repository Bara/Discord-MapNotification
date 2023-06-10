#pragma semicolon 1

#include <sourcemod>
#include <regex>
#include <autoexecconfig>
#include <discordWebhookAPI>

#pragma newdecls required

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))
#define FILE_LASTMAP "addons/sourcemod/configs/DMN_LastMap.ini"

ConVar g_cWebhook = null;
ConVar g_cAvatar = null;
ConVar g_cUsername = null;
ConVar g_cColor = null;
ConVar g_cLangCode = null;
ConVar g_cGame = null;
ConVar g_cLogo = null;
ConVar g_cTimestamp = null;

public Plugin myinfo =
{
    name        = "[Discord] Map Notifications",
    description = "",
    version     = "1.0.1",
    author      = "Bara",
    url         = "https://github.com/Bara"
};

public void OnPluginStart()
{
    LoadTranslations("discord_mapnotification.phrases");

    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("discord.mapnotifications");
    g_cWebhook = AutoExecConfig_CreateConVar("discord_map_notification_webhook", "MapNotification", "Discord webhook name for this plugin (addons/sourcemod/configs/DMN_Discord.cfg)");
    g_cAvatar = AutoExecConfig_CreateConVar("discord_map_notification_avatar", "https://csgottt.com/map_notification.png", "URL to Avatar image");
    g_cUsername = AutoExecConfig_CreateConVar("discord_map_notification_username", "Map Notifications", "Discord username");
    g_cColor = AutoExecConfig_CreateConVar("discord_map_notification_colors", "16738740", "Decimal color code\nHex to Decimal - https://www.rapidtables.com/convert/number/hex-to-decimal.html");
    g_cLangCode = AutoExecConfig_CreateConVar("discord_map_notification_language_code", "en", "Which language (as 2 or 3 digit code) for discord messages?\nHere's a list of some/all languages codes:\nhttps://en.wikipedia.org/wiki/List_of_ISO_639-1_codes");
    g_cGame = AutoExecConfig_CreateConVar("discord_map_notification_game", "csgo", "Which game directory for images? (Default: csgo)");
    g_cLogo = AutoExecConfig_CreateConVar("discord_custom_logo_url", "", "If you want to set a custom logo for the embedded discord message, fill this with your logo url out.\nIf you use custom logo, map picture (from gametracker) will be ignored.");
    g_cTimestamp = AutoExecConfig_CreateConVar("discord_map_notification_timestamp", "1", "Show timestamp/date in footer? (0 - Disabled, 1 - Enabled)", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    RegAdminCmd("dmn_test", Command_Test, ADMFLAG_ROOT);
}

public void OnMapStart()
{
    LogMessage("OnMapStart");
    CreateTimer(15.0, Timer_PrepareMessage, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_Test(int client, int args)
{
    PrepareAndSendMessage(true);

    return Plugin_Stop;
}

public Action Timer_PrepareMessage(Handle timer)
{
    PrepareAndSendMessage(false);

    return Plugin_Stop;
}

void PrepareAndSendMessage(bool test)
{
    char sHostname[512];
    ConVar cvar = FindConVar("hostname");
    cvar.GetString(sHostname, sizeof(sHostname));

    /* Get map */
    char sMap[64], sLastMap[32];
    GetCurrentMap(sMap, sizeof(sMap));
    GetLastMap(sLastMap, sizeof(sLastMap));

    /* Get max player information */
    int iMax = GetMaxHumanPlayers();

    /* Get player/bot informations */
    int iPlayers = 0;

    LoopValidClients(i)
    {
        iPlayers++;
    }

    if (!test && StrContains(sLastMap, sMap, false) != -1 && iPlayers < 2)
    {
        return;
    }

    char sPlayers[24];
    Format(sPlayers, sizeof(sPlayers), "%d/%d", iPlayers, iMax);

    /* Get server ip + port for connection link */
    char sIP[18];
    int ips[4];
    int iIP = GetConVarInt(FindConVar("hostip"));
    ips[0] = (iIP >> 24) & 0x000000FF;
    ips[1] = (iIP >> 16) & 0x000000FF;
    ips[2] = (iIP >> 8) & 0x000000FF;
    ips[3] = iIP & 0x000000FF;
    Format(sIP, sizeof(sIP), "%d.%d.%d.%d", ips[0], ips[1], ips[2], ips[3]);

    cvar = FindConVar("hostport");
    int iPort = cvar.IntValue;

    char sConnect[256];
    Format(sConnect, sizeof(sConnect), "steam://connect/%s:%d", sIP, iPort);

    char sGame[18];
    g_cGame.GetString(sGame, sizeof(sGame));

    char sSplit[3][32];
    if (ExplodeString(sMap, "/", sSplit, sizeof(sSplit), sizeof(sSplit[])) > 1)
    {
        strcopy(sMap, sizeof(sMap), sSplit[2]);
    }

    /* Set bot avatar */
    char sThumb[256];
    g_cLogo.GetString(sThumb, sizeof(sThumb));

    if (strlen(sThumb) < 2)
    {
        Format(sThumb, sizeof(sThumb), "https://image.gametracker.com/images/maps/160x120/%s/%s.jpg", sGame, sMap);
    }

    /* Start and Send discord notification */
    char sWeb[256], sHook[256];
    g_cWebhook.GetString(sWeb, sizeof(sWeb));
    
    if (!GetDiscordWebhook(sWeb, sHook, sizeof(sHook)))
    {
        SetFailState("[Map Notification] (Timer_SendMessage) Can't find webhook");
        return;
    }

    Webhook wWebhook = new Webhook();

    char sName[128];
    g_cUsername.GetString(sName, sizeof(sName));
    wWebhook.SetUsername(sName);

    char sAvatar[256];
    g_cAvatar.GetString(sAvatar, sizeof(sAvatar));
    wWebhook.SetAvatarURL(sAvatar);

    char sCode[4];
    g_cLangCode.GetString(sCode, sizeof(sCode));

    int iLang = GetLanguageByCode(sCode);

    Embed eEmbed = new Embed();
    eEmbed.SetColor(g_cColor.IntValue);
    eEmbed.SetTitle(sHostname);

    if (g_cTimestamp.BoolValue)
    {
        eEmbed.SetTimeStampNow();
    }

    EmbedThumbnail eThumbnail = new EmbedThumbnail(sThumb);
    eEmbed.SetThumbnail(eThumbnail);
    delete eThumbnail;

    char sNow[64];
    Format(sNow, sizeof(sNow), "%T", "Now playing", iLang);
    EmbedField eMap = new EmbedField(sNow, sMap, true);
    eEmbed.AddField(eMap);

    char sOnline[64];
    Format(sOnline, sizeof(sOnline), "%T", "Players Online", iLang);
    EmbedField ePlayers = new EmbedField(sOnline, sPlayers, true);
    eEmbed.AddField(ePlayers);

    char sJoin[128];
    Format(sJoin, sizeof(sJoin), "%T", "Quick Join", iLang);
    EmbedField eConnect = new EmbedField(sJoin, sConnect, true);
    eEmbed.AddField(eConnect);

    wWebhook.AddEmbed(eEmbed);
    wWebhook.Execute(sHook, OnWebHookExecuted);
    delete wWebhook;

    UpdateLastMap(sMap);

    return;
}

public void OnWebHookExecuted(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_NoContent && response.Status != HTTPStatus_OK)
    {
        LogError("[Discord.OnWebHookExecuted] An error has occured while sending the webhook. Status Code: %d", response.Status);
    }
}

void GetLastMap(char[] sMap, int iLength)
{
    File fFile = OpenFile(FILE_LASTMAP, "r");

    char sBuffer[32];

    if (fFile != null)
    {
        while (!fFile.EndOfFile() && fFile.ReadLine(sBuffer, sizeof(sBuffer)))
        {
            if (strlen(sBuffer) > 1)
            {
                strcopy(sMap, iLength, sBuffer);
            }
        }
    }
    else
    {
        SetFailState("[Map Notification] (GetLastMap) Cannot open file %s", FILE_LASTMAP);
        return;
    }
    delete fFile;
}

void UpdateLastMap(const char[] sMap)
{
    File fFile = OpenFile(FILE_LASTMAP, "w+");

    if (fFile != null)
    {
        fFile.Flush();
        bool success = WriteFileLine(fFile, sMap);
        if (!success)
        {
            delete fFile;
            SetFailState("[Map Notification] (UpdateLastMap) Cannot write file %s", FILE_LASTMAP);
            return;
        }
    }
    else
    {
        delete fFile; // Just to be sure
        SetFailState("[Map Notification] (UpdateLastMap) Cannot open file %s", FILE_LASTMAP);
        return;
    }
    delete fFile;
}

bool IsClientValid(int client)
{
    if (client > 0 && client <= MaxClients)
    {
        if(IsClientConnected(client) && !IsClientSourceTV(client))
        {
            return true;
        }
    }

    return false;
}

bool GetDiscordWebhook(const char[] sWebhook, char[] sUrl, int iLength)
{
    KeyValues kvWebhook = new KeyValues("Discord");

    char sFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/DMN_Discord.cfg");

    if (!FileExists(sFile))
    {
        SetFailState("[Map Notification] (GetDiscordWebhook) \"%s\" not found!", sFile);
        delete kvWebhook;
        return false;
    }

    if (!kvWebhook.ImportFromFile(sFile))
    {
        SetFailState("[Map Notification] (GetDiscordWebhook) Can't read: \"%s\"!", sFile);
        delete kvWebhook;
        return false;
    }

    kvWebhook.GetString(sWebhook, sUrl, iLength, "default");

    if (strlen(sUrl) > 2)
    {
        delete kvWebhook;
        return true;
    }

    delete kvWebhook;
    return false;
}
