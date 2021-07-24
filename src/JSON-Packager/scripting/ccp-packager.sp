#pragma newdecls required

#define INCLUDE_RIPJSON

#if defined INCLUDE_DEBUG
    #define DEBUG "[Packager]"
#endif

#include <ccprocessor>
#include <ccprocessor_pkg>

public Plugin myinfo = 
{
	name = "[CCP] JSON Packager",
	author = "rej.chev",
	description = "...",
	version = "1.1.0",
	url = "discord.gg/ChTyPUG"
};

bool g_bLate;

/*
Pattern :: 
    {
        // client index
        0: {

        },
        
        1: {

        },

        ...
    }
*/
JSONObject packager;

GlobalForward
    fwdPackageUpdated,
    fwdPackageAvailable;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    #if defined DEBUG
    DBUILD()
    #endif

    CreateNative("ccp_GetPackage", Native_GetPackage);
    CreateNative("ccp_SetPackage", Native_SetPackage);
    CreateNative("ccp_HasPackage", Native_HasPackage);
    CreateNative("ccp_IsVerified", Native_IsVerified);
    CreateNative("ccp_SetArtifact", Native_Insert);
    CreateNative("ccp_RemoveArtifact", Native_Remove);
    CreateNative("ccp_GetArtifact", Native_GetArtifact);
    CreateNative("ccp_HasArtifact", Native_HasArtifact);

    // Processing(Handle initiator, int Client,const char[] artifact, Handle value, int repLevel = -1)
    // level = -1 is default replacement level for this plugin.
    // don't change value with this replacement level...
    fwdPackageUpdated = new GlobalForward(
        "ccp_pkg_UpdateRequest", 
        ET_Hook, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_CellByRef
    );

    fwdPackageAvailable = new GlobalForward(
        "ccp_pkg_Available", 
        ET_Ignore, Param_Cell
    );


    RegPluginLibrary("ccprocessor_pkg");

    g_bLate = late;
}

public any Native_GetPackage(Handle h, int a) {
    static char index[4];
    FormatEx(index, sizeof(index), "%d", GetNativeCell(1));

    if(packager.HasKey(index))
        return packager.Get(index);
    
    return 0;
}

public any Native_SetPackage(Handle h, int a) {
    int iClient = GetNativeCell(1);

    static char index[4];
    FormatEx(index, sizeof(index), "%d", iClient);

    Handle value = GetNativeCell(2);

    if(updatePackage(h, iClient, NULL_STRING, value, GetNativeCell(3)) > Proc_Change) {
        return false;
    }

    return (value) ? packager.Set(index, view_as<JSON>(value)) : packager.SetNull(index);
}

public any Native_HasPackage(Handle h, int a) {
    static char index[4];
    FormatEx(index, sizeof(index), "%d", GetNativeCell(1));

    return packager.HasKey(index);
}

public any Native_IsVerified(Handle h, int a) {
    int iClient = GetNativeCell(1);
    bool ver;

    static char index[4];
    FormatEx(index, sizeof(index), "%d", iClient);

    JSONObject obj;
    if((obj = asJSONO(ccp_GetPackage(iClient))) != null && obj.HasKey("auth") && !obj.IsNull("auth")) {
        char auth[64];
        auth = GetClientAuthIdEx(iClient);

        char buffer[64];
        obj.GetString("auth", buffer, sizeof(buffer));

        ver = auth[0] != 0 && strcmp(auth, buffer) == 0;
    }

    delete obj;
    
    return ver;
}

// bool(int iClient, const char[] artifact, Handle value, int repLevel)
public any Native_Insert(Handle h, int a) {
    int iClient = GetNativeCell(1);

    if(!ccp_HasPackage(iClient))
        return ThrowNativeError(-1, "Client package is null");

    static char artifact[64];
    GetNativeString(2, artifact, sizeof(artifact));
    
    Handle value = GetNativeCell(3);

    if(updatePackage(h, iClient, artifact, value, GetNativeCell(4)) > Proc_Change) {
        return false;
    }

    JSONObject client;
    client = asJSONO(ccp_GetPackage(iClient));
    client.Set(artifact, view_as<JSON>(value));

    if(!ccp_SetPackage(iClient, client, -1)) {
        delete client;
        return false;
    }

    delete client;
    return true;
}

// bool(int iClient, const char[] artifact, int &repLevel)
public any Native_Remove(Handle h, int a) {
    int iClient = GetNativeCell(1);

    if(!ccp_HasPackage(iClient))
        return ThrowNativeError(-1, "Client package is null");

    static char artifact[64];
    GetNativeString(2, artifact, sizeof(artifact));

    if(updatePackage(h, iClient, artifact, null, GetNativeCell(3)) > Proc_Change) {
        return false;
    }

    JSONObject client;
    client = asJSONO(ccp_GetPackage(iClient));
    client.Remove(artifact);

    if(!ccp_SetPackage(iClient, client, -1)) {
        delete client;
        return false;
    }

    delete client;
    return true;
}

public any Native_GetArtifact(Handle h, int a) {
    int iClient = GetNativeCell(1);

    if(!ccp_HasPackage(iClient))
        return ThrowNativeError(-1, "Client package is null");

    static char artifact[64];
    GetNativeString(2, artifact, sizeof(artifact));

    JSONObject client;
    client = asJSONO(ccp_GetPackage(iClient));
    
    JSON obj;
    if(client.HasKey(artifact) && !client.IsNull(artifact))
        obj = client.Get(artifact);

    delete client;
    return obj;
}

public any Native_HasArtifact(Handle h, int a) {
    int iClient = GetNativeCell(1);

    if(!ccp_HasPackage(iClient))
        return ThrowNativeError(-1, "Client package is null");

    static char artifact[64];
    GetNativeString(2, artifact, sizeof(artifact));

    JSONObject client;
    client = asJSONO(ccp_GetPackage(iClient));
    
    bool has = client.HasKey(artifact) && !client.IsNull(artifact);

    delete client;
    return has;
}

Processing updatePackage(Handle initiator, int iClient, const char[] artifact, Handle value, int repLevel) {
    Processing result = Proc_Continue;

    Call_StartForward(fwdPackageUpdated);

    Call_PushCell(initiator);
    Call_PushCell(iClient);
    Call_PushString(artifact);
    Call_PushCell(value);
    Call_PushCellRef(repLevel);

    Call_Finish(result);

    return result;
}

bool Initialization(int iClient, const char[] auth = "STEAM_ID_SERVER") {
    JSONObject obj;

    if(ccp_HasPackage(iClient))
        ccp_SetPackage(iClient, obj, -1);
    
    obj = new JSONObject();
    obj.SetString("auth", auth);
    obj.SetInt("uid", (iClient) ? GetClientUserId(iClient) : 0);

    bool success = ccp_SetPackage(iClient, obj, -1);

    delete obj;

    return success;
}

public void OnPluginStart() {
    packager = new JSONObject();

    if(g_bLate) {
        g_bLate = false;
        for(int i = 1; i <= MaxClients; i++) {
            if(IsClientConnected(i) && IsClientAuthorized(i)) {
                OnClientAuthorized(i, GetClientAuthIdEx(i));
            }
        }
    }
}

public void OnMapStart() {
    #if defined DEBUG
    DBUILD()
    #endif

    OnClientAuthorized(0, "STEAM_ID_SERVER");
}

public void OnClientAuthorized(int iClient, const char[] auth) {
    if(iClient && (IsFakeClient(iClient) || IsClientSourceTV(iClient)))
        return;

    if(!ccp_SetPackage(iClient, null, -1) || !Initialization(iClient, auth))
        SetFailState("What the fuck are u doing?");

    Call_StartForward(fwdPackageAvailable);
    Call_PushCell(iClient);
    Call_Finish();
}

char[] GetClientAuthIdEx(int iClient) {
    static char auth[64];

    if(!GetClientAuthId(iClient, AuthId_Steam2, auth, sizeof(auth)))
        auth = NULL_STRING;

    return auth;
}