#pragma newdecls required

#include ccprocessor

public Plugin myinfo = 
{
	name = "[CCP] FakeUsername",
	author = "nullent?",
	description = "Ability to set a fake username in chat msgs",
	version = "1.5.0",
	url = "discord.gg/ChTyPUG"
};

#define SZ(%0)	%0, sizeof(%0)
#define _CVAR_INIT_CHANGE(%0,%1) %0(FindConVar(%1), NULL_STRING, NULL_STRING)
#define _CVAR_ON_CHANGE(%0) public void %0(ConVar cvar, const char[] szOldVal, const char[] szNewVal)

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1

char fakename[MPL][NAME_LENGTH];

int AccessFlag, ROOT;
int ClientFlags[MPL];

int nLevel;

public void OnPluginStart()
{    
    ROOT = ReadFlagString("z");

    RegConsoleCmd("sm_fakename", OnCmdUse);

    CreateConVar("ccp_fakename_accessflag", "a", "Access flag or empty, other than the 'z' flag").AddChangeHook(OnAccessChanged);
    CreateConVar("ccp_fakename_priority", "9", "The priority level to change the username", _, true, 0.0).AddChangeHook(OnChangePName);

    AutoExecConfig(true, "ccp_fakename", "ccprocessor");
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());
    
    _CVAR_INIT_CHANGE(OnAccessChanged, "ccp_fakename_accessflag");
    _CVAR_INIT_CHANGE(OnChangePName, "ccp_fakename_priority");
}

_CVAR_ON_CHANGE(OnAccessChanged)
{
    if(!cvar)
        return;
    
    char szFlag[4];
    cvar.GetString(SZ(szFlag));

    AccessFlag = ReadFlagString(szFlag);
}

_CVAR_ON_CHANGE(OnChangePName)
{
    if(cvar)
        nLevel = cvar.IntValue;
}

public Action OnCmdUse(int iClient, int args)
{
    if(args == 1 && iClient && IsClientInGame(iClient) && IsValidClient(iClient))
        GetCmdArg(1, fakename[iClient], sizeof(fakename[]));

    return Plugin_Handled;
}

public void OnClientPutInServer(int iClient)
{
    fakename[iClient][0] = 0;
    ClientFlags[iClient] = 0;
}

public void OnClientPostAdminCheck(int iClient)
{
    ClientFlags[iClient] = GetUserFlagBits(iClient);
}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size)
{
    if(mType <= eMsg_ALL && part == BIND_NAME && fakename[sender][0] && pLevel < nLevel)
    {
        pLevel = nLevel;
        FormatEx(buffer, size, fakename[sender]);
    }  
}

bool IsValidClient(int iClient)
{    
    return ((ClientFlags[iClient] && (ClientFlags[iClient] & ROOT)) || (AccessFlag && (ClientFlags[iClient] & AccessFlag)));
}
