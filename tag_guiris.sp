/*  SM Tag Guiris
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <geoip>
//#include <cssclantags>

//#define VERSION "v3.1 by Franc1sco steam: franug (Made in Spain)"

// de-privatize and reedited version for released to the public in beta version
// 
#define VERSION "1.3"

new bool:g_Guiri[MAXPLAYERS+1] = {false, ...};

new Handle:PaisPropio;
new Handle:ElTagGuiri;

// maximum SteamIDs the plugin can handle; increase value as needed
#define WHITELIST_MAX 255

new Handle:cf_mode;
new Handle:Unknown_guiri;


new String:whitelist[WHITELIST_MAX][64];
new listlen;

public Plugin:myinfo =
{
	name = "SM Tag Guiris",
	author = "Franc1sco Steam: franug",
	description = "Anti guiris Freekillers",
	version = VERSION,
	url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	CreateConVar("sm_TagGuiris_version", VERSION, "Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

        PaisPropio = CreateConVar("tag_local", "ES", "List of the countries");

        ElTagGuiri = CreateConVar("sm_guiri_tag", "GUIRI|", "Tag for people who do not speak your language");

	cf_mode = CreateConVar("sm_guiris_mode", "1", "", FCVAR_PLUGIN);

	Unknown_guiri = CreateConVar("sm_guiris_Unknown", "0", "People with Unknown country will be disallow. 0 = allow, 1 = disallow");

	RegAdminCmd("sm_guiris_reload", CommandReload, ADMFLAG_GENERIC, "Reloads server whitelist");
	RegAdminCmd("sm_guiris_list", CommandList, ADMFLAG_GENERIC, "List all SteamIDs in whitelist");
	RegAdminCmd("sm_guiris_add", CommandAdd, ADMFLAG_GENERIC, "Adds a player to the whitelist");

	HookEvent("player_spawn", OnSpawn);

	LoadList();
	
	for(new i = 1; i <=MaxClients; ++i)
	{
		if (!IsClientInGame(i))
			continue;
			
		OnClientPostAdminCheck(i);
	}

}

public Action:CommandAdd(client, args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "[SM_GUIRIS] Use: sm_guiris_add <#userid|name>");
		return Plugin_Handled;
	}
	//new String:steamid[64];
	//GetCmdArg(1, steamid, sizeof(steamid));
	//TrimString(steamid);

        decl String:arg[30];
        GetCmdArg(1, arg, sizeof(arg));

        new target;

        if((target = FindTarget(client, arg)) == -1)
        {
           PrintToChat(client, "\x01Target not found");
           return Plugin_Handled; // Target not found...
        }

        new String:steamid[64];
        GetClientAuthString(target, steamid, sizeof(steamid));
	
	new String:path[PLATFORM_MAX_PATH];
	BuildPath(PathType:Path_SM, path, sizeof(path), "configs/franug_noguiris.txt");
	
	new Handle:file = OpenFile(path, "a");
	if(file != INVALID_HANDLE)
	{
		WriteFileLine(file, steamid);
		whitelist[listlen] = steamid;
		listlen++;
		
		ReplyToCommand(client, "[SM_GUIRIS] %N [%s] has been added to the list of noguiri", target,steamid);
	}
	else
	{
		ReplyToCommand(client, "[SM_GUIRIS] Failed to open %s for writing", path);
	}
	CloseHandle(file);
	
	return Plugin_Handled;
}

public OnClientPostAdminCheck(client)
{
        if (IsFakeClient(client))
            return;

	new String:ip[16];
	new String:code2[3];

	GetClientIP(client, ip, sizeof(ip));
	GeoipCode2(ip, code2);

        //g_Guiri[client] = false;

	//PrintToChatAll("pasado1");
	
	if (Reject(code2))
	{
	    //PrintToChatAll("pasado2");
            if(GetUserAdmin(client) == INVALID_ADMIN_ID)
            {
		new String:auth[64];
		GetClientAuthString(client, auth, sizeof(auth));
		new bool:allow = false;
		for(new i; i < listlen; i++)
		{
			if(strcmp(auth, whitelist[i]) == 0)
			{
				allow = true;
				break;
			}
		}

		if(!allow)
		{
                      g_Guiri[client] = true;

                      CreateTimer(5.0, Tag_G, client);

		      //PrintToChatAll("pasado3");

                      return;
                }
            }
	}

        g_Guiri[client] = false;
}

public OnClientSettingsChanged(client)
{
  if (g_Guiri[client])
  {
    if (IsClientInGame(client) && !IsFakeClient(client))
    {
        CreateTimer(1.0, Tag_G, client);
    }
  }
}   

public Action:Tag_G(Handle:timer, any:client)
{
 if (IsClientInGame(client) && !IsFakeClient(client) && g_Guiri[client])
 {

    decl String:tagguiri[32];
    GetConVarString(ElTagGuiri, tagguiri, sizeof(tagguiri));


    CS_SetClientClanTag(client, tagguiri);

 }
} 

public LoadList()
{
	new String:path[PLATFORM_MAX_PATH];
	BuildPath(PathType:Path_SM, path, sizeof(path), "configs/franug_noguiris.txt");
	
	new Handle:file = OpenFile(path, "r");
	if(file == INVALID_HANDLE)
	{
		SetFailState("[SM_GUIRIS] Unable to read file %s", path);
	}
	
	listlen = 0;
	new String:steamid[64];
	while(!IsEndOfFile(file) && ReadFileLine(file, steamid, sizeof(steamid)))
	{
		if (steamid[0] == ';' || !IsCharAlpha(steamid[0]))
		{
			continue;
		}
		new len = strlen(steamid);
		for (new i; i < len; i++)
		{
			if (IsCharSpace(steamid[i]) || steamid[i] == ';')
			{
				steamid[i] = '\0';
				break;
			}
		}
		whitelist[listlen] = steamid;
		listlen++;
	}
	
	CloseHandle(file);
}

public Action:CommandReload(client, args)
{
	LoadList();
	ReplyToCommand(client, "[SM_GUIRIS] %d SteamIDs loadeds form the list noguiri", listlen);
	return Plugin_Handled;
}

public Action:CommandList(client, args)
{
	PrintToConsole(client, "[SM_GUIRIS] Listing current list (%d items):", listlen);
	for(new i; i < listlen; i++)
	{
		PrintToConsole(client, "%s", whitelist[i]);
	}
	return Plugin_Handled;
}

public OnSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

        if(!g_Guiri[client] || IsFakeClient(client))
            return;

        if (GetClientTeam(client) == 3)  
        {
               ChangeClientTeam(client, 2);
	       PrintToChat(client, "[SM_GUIRIS] You not allowed to be CT");
               //CS_RespawnPlayer(client);
        }  
        CreateTimer(0.0, Tag_G, client);
}

// code from country filter
public bool:Reject(const String:code2[])
{
	if(StrEqual("", code2))
	{
		if(GetConVarInt(Unknown_guiri) == 1)
			return true;
		else
			return false;
	}
		
	new String:str[255];
	new String:arr[100][3];
	
	GetConVarString(PaisPropio, str, 255);
	
	new total = ExplodeString(str, " ", arr, 100, 3);
	if(total == 0) strcopy(arr[total++], 3, str);
	
	if(GetConVarInt(cf_mode) == 2)
	{
		for(new i = 0; i < total; i++)
		{
			if(StrEqual(arr[i], code2))
				return true;
		}
	}
	else
	{
		new bool:reject = true;
		
		for(new i = 0; i < total; i++)
		{
			if(StrEqual(arr[i], code2))
				reject = false;
		}
		
		return reject;
	}

	return false;
}
//