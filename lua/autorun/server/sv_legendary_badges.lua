if SERVER then

util.AddNetworkString("LegendaryBadges_SendDataV2")
util.AddNetworkString("LegendaryBadges_UpdateEquipped")
util.AddNetworkString("LegendaryBadges_AdminCreateBadge")
util.AddNetworkString("LegendaryBadges_AdminCreateResult")
util.AddNetworkString("LegendaryBadges_AdminDeleteBadge")
util.AddNetworkString("LegendaryBadges_SendRoles")

LegendaryBadges = LegendaryBadges or {}

LegendaryBadges.List = LegendaryBadges.List or {}
LegendaryBadges.PlayerData = LegendaryBadges.PlayerData or {}

local DATA_DIR         = "legendary_badges"
local DATA_FILE        = DATA_DIR .. "/badges.json"
local PLAYER_DATA_FILE = DATA_DIR .. "/players.json"

--------------------------------------------------------------------
-- SAUVEGARDE / CHARGEMENT JSON BADGES
--------------------------------------------------------------------

local function SaveBadgesToFile()
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end

    local toSave = {}

    for id, data in pairs(LegendaryBadges.List or {}) do
        toSave[id] = {
            id   = data.id,
            name = data.name,
            icon = data.icon,
            r    = data.color and data.color.r or 255,
            g    = data.color and data.color.g or 255,
            b    = data.color and data.color.b or 255,
            a    = data.color and data.color.a or 255
        }
    end

    local json = util.TableToJSON(toSave, true)
    file.Write(DATA_FILE, json)
end

local function LoadBadgesFromFile()
    if not file.Exists(DATA_FILE, "DATA") then return end

    local json = file.Read(DATA_FILE, "DATA")
    if not json or json == "" then return end

    local tbl = util.JSONToTable(json)
    if not istable(tbl) then return end

    LegendaryBadges.List = {}

    for key, data in pairs(tbl) do
        local id = tostring(data.id or key)

        LegendaryBadges.List[id] = {
            id    = id,
            name  = data.name or id,
            icon  = data.icon or "",
            color = Color(
                data.r or 255,
                data.g or 255,
                data.b or 255,
                data.a or 255
            )
        }
    end
end

--------------------------------------------------------------------
-- SAUVEGARDE / CHARGEMENT JSON JOUEURS
--------------------------------------------------------------------

local function SavePlayersToFile()
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end

    local json = util.TableToJSON(LegendaryBadges.PlayerData or {}, true)
    file.Write(PLAYER_DATA_FILE, json)
end

local function LoadPlayersFromFile()
    if not file.Exists(PLAYER_DATA_FILE, "DATA") then return end

    local json = file.Read(PLAYER_DATA_FILE, "DATA")
    if not json or json == "" then return end

    local tbl = util.JSONToTable(json)
    if not istable(tbl) then return end

    LegendaryBadges.PlayerData = tbl
end

local function ComputeNextID()
    local maxID = 0

    for id, _ in pairs(LegendaryBadges.List) do
        local num = tonumber(id)
        if num and num > maxID then
            maxID = num
        end
    end

    LegendaryBadges.NextID = maxID + 1
end

--------------------------------------------------------------------
-- INIT LISTE BADGES + DONNÉES JOUEURS
--------------------------------------------------------------------

LoadBadgesFromFile()
LoadPlayersFromFile()

if table.Count(LegendaryBadges.List) == 0 then
    LegendaryBadges.List = {
        ["1"] = {
            id    = "1",
            name  = "Vétéran",
            color = Color(255, 215, 0),
            icon  = "icon16/star.png"
        },
        ["2"] = {
            id    = "2",
            name  = "Builder",
            color = Color(0, 200, 255),
            icon  = "icon16/wrench.png"
        },
        ["3"] = {
            id    = "3",
            name  = "Staff",
            color = Color(255, 80, 80),
            icon  = "icon16/shield.png"
        }
    }

    SaveBadgesToFile()
end

ComputeNextID()

--------------------------------------------------------------------
-- CONFIG RÔLES (via LegendaryBadgesConfig)
--------------------------------------------------------------------

local function GetRoleBadgeForPlayer(ply)
    print("[Badges][SV] GetRoleBadgeForPlayer", ply:Nick(), ply:GetUserGroup(),
        "cfg=", (LegendaryBadgesConfig and "OK" or "NIL"))

    if not LegendaryBadgesConfig or not LegendaryBadgesConfig.RoleBadges then return nil end

    local group = string.lower(ply:GetUserGroup() or "")
    local id = LegendaryBadgesConfig.RoleBadges[group]

    print(" group key:", group, "-> id:", id or "nil")

    if id and LegendaryBadges.List[id] then
        return id
    end

    return nil
end

local function BroadcastRoleBadges()
    net.Start("LegendaryBadges_SendRoles")
    net.WriteUInt(#player.GetAll(), 8)

    for _, pl in ipairs(player.GetAll()) do
        if IsValid(pl) then
            net.WriteString(pl:SteamID64() or "0")

            local roleID = GetRoleBadgeForPlayer(pl)
            net.WriteBool(roleID ~= nil)

            if roleID then
                net.WriteString(roleID)
            end
        end
    end

    net.Broadcast()

    print("[Badges][SV] BroadcastRoleBadges")

    for _, pl in ipairs(player.GetAll()) do
        if IsValid(pl) then
            local roleID = GetRoleBadgeForPlayer(pl)
            print(" ->", pl:Nick(), pl:GetUserGroup(), "roleID =", roleID or "nil")
        end
    end
end

--------------------------------------------------------------------
-- GESTION DONNÉES JOUEUR (par SteamID)
--------------------------------------------------------------------

local function InitPlayerData(ply)
    if not IsValid(ply) then return end

    local sid = ply:SteamID()
    LegendaryBadges.PlayerData[sid] = LegendaryBadges.PlayerData[sid] or {}

    ply.LegendaryBadges = LegendaryBadges.PlayerData[sid]

    if not ply.LegendaryBadges.owned then
        ply.LegendaryBadges.owned = {}

        local group = string.lower(ply:GetUserGroup() or "")

        -- Rangs qui possèdent automatiquement tous les badges
        if LegendaryBadgesConfig
        and LegendaryBadgesConfig.AllBadgesRanks
        and LegendaryBadgesConfig.AllBadgesRanks[group] then

            for id, _ in pairs(LegendaryBadges.List) do
                table.insert(ply.LegendaryBadges.owned, id)
            end
        end
        -- Les autres : aucun badge par défaut
    end

    ply.LegendaryBadges.equipped = ply.LegendaryBadges.equipped or {
        nil, nil, nil
    }
end

--------------------------------------------------------------------
-- ENVOI AU CLIENT (avec 4e slot rôle)
--------------------------------------------------------------------

local function SendBadgeData(ply)
    if not IsValid(ply) then return end

    print("[Badges][SV] SendBadgeData ->", ply:Nick(), "count:", table.Count(LegendaryBadges.List or {}))

    net.Start("LegendaryBadges_SendDataV2")

    net.WriteUInt(table.Count(LegendaryBadges.List), 16)

    for id, data in pairs(LegendaryBadges.List) do
        net.WriteString(id)
        net.WriteString(data.name or id)
        net.WriteColor(data.color or Color(255, 255, 255))
        net.WriteString(data.icon or "")
    end

    local owned = ply.LegendaryBadges.owned or {}
    net.WriteUInt(#owned, 16)

    for _, bid in ipairs(owned) do
        net.WriteString(bid)
    end

    local eq = ply.LegendaryBadges.equipped or {}

    for i = 1, 3 do
        net.WriteBool(eq[i] ~= nil)
        if eq[i] then
            net.WriteString(eq[i])
        end
    end

    -- 4e slot non éditable : badge lié au rank (pour ce joueur)
    local roleID = GetRoleBadgeForPlayer(ply)
    net.WriteBool(roleID ~= nil)

    if roleID then
        net.WriteString(roleID)
    end

    net.Send(ply)
end

local function BroadcastBadgeList()
    for _, pl in ipairs(player.GetAll()) do
        InitPlayerData(pl)
        SendBadgeData(pl)
    end
end

--------------------------------------------------------------------
-- GESTION DES BADGES PAR STEAMID (shop / commandes)
--------------------------------------------------------------------

local function LegendaryBadges_AddBadgeToSteamID(steamid, badgeID)
    if not LegendaryBadges.List[badgeID] then
        print("[Badges] legendary_addbadge: badgeID inexistant:", badgeID)
        return
    end

    LegendaryBadges.PlayerData[steamid] = LegendaryBadges.PlayerData[steamid] or {
        owned    = {},
        equipped = { nil, nil, nil }
    }

    local data = LegendaryBadges.PlayerData[steamid]
    data.owned = data.owned or {}

    for _, id in ipairs(data.owned) do
        if id == badgeID then
            print("[Badges] legendary_addbadge: le joueur", steamid, "possède déjà le badge", badgeID)
            return -- déjà possédé
        end
    end

    table.insert(data.owned, badgeID)
    print("[Badges] Badge", badgeID, "ajouté au joueur", steamid)

    -- Si le joueur est connecté, resync immédiat
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:SteamID() == steamid then
            InitPlayerData(ply)
            SendBadgeData(ply)
            print("[Badges] Synchronisation envoyée à", ply:Nick(), "pour l'ajout du badge", badgeID)
            break
        end
    end

    SavePlayersToFile()
end

local function LegendaryBadges_RemoveBadgeFromSteamID(steamid, badgeID)
    local data = LegendaryBadges.PlayerData[steamid]

    if not data or not data.owned then
        print("[Badges] legendary_delbadge: aucun data pour", steamid, "ou pas de owned")
        return
    end

    local hadBadge = false

    -- Retirer de la liste owned
    for k, id in ipairs(data.owned) do
        if id == badgeID then
            table.remove(data.owned, k)
            hadBadge = true
            break
        end
    end

    if not hadBadge then
        print("[Badges] legendary_delbadge: le joueur", steamid, "ne possède pas le badge", badgeID)
    else
        print("[Badges] Badge", badgeID, "retiré du joueur", steamid)
    end

    -- Retirer des slots équipés
    data.equipped = data.equipped or { nil, nil, nil }
    local unequipped = false

    for i = 1, 3 do
        if data.equipped[i] == badgeID then
            data.equipped[i] = nil
            unequipped = true
        end
    end

    if unequipped then
        print("[Badges] Badge", badgeID, "déséquipé des slots du joueur", steamid)
    end

    -- Si le joueur est connecté, resync immédiat
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:SteamID() == steamid then
            InitPlayerData(ply)
            SendBadgeData(ply)
            print("[Badges] Synchronisation envoyée à", ply:Nick(), "pour la suppression du badge", badgeID)
            break
        end
    end

    SavePlayersToFile()
end

--------------------------------------------------------------------
-- COMMANDES CONSOLE / SHOP
--------------------------------------------------------------------

-- Ajoute l'accès à un badge : legendary_addbadge
concommand.Add("legendary_addbadge", function(ply, cmd, args)
    -- Si appelé par un joueur, limiter aux superadmins
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    if #args < 2 then
        print("Usage: legendary_addbadge <steamid> <badgeID>")
        return
    end

    -- Reconstruire le SteamID même s'il est découpé
    local badgeID = args[#args]
    table.remove(args, #args)
    local steamid = table.concat(args, " ")

    print("[Badges] Commande legendary_addbadge par",
        IsValid(ply) and (ply:Nick() .. " (" .. ply:SteamID() .. ")") or "console",
        "-> steamid:", steamid, "badgeID:", badgeID)

    LegendaryBadges_AddBadgeToSteamID(steamid, badgeID)
end)

-- Retire l'accès à un badge : legendary_delbadge
concommand.Add("legendary_delbadge", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    if #args < 2 then
        print("Usage: legendary_delbadge <steamid> <badgeID>")
        return
    end

    local badgeID = args[#args]
    table.remove(args, #args)
    local steamid = table.concat(args, " ")

    print("[Badges] Commande legendary_delbadge par",
        IsValid(ply) and (ply:Nick() .. " (" .. ply:SteamID() .. ")") or "console",
        "-> steamid:", steamid, "badgeID:", badgeID)

    LegendaryBadges_RemoveBadgeFromSteamID(steamid, badgeID)
end)

--------------------------------------------------------------------
-- HOOKS
--------------------------------------------------------------------

hook.Add("PlayerInitialSpawn", "LegendaryBadges_InitData", function(ply)
    print("[Badges][SV] PlayerInitialSpawn", ply:Nick())

    InitPlayerData(ply)

    timer.Simple(2, function()
        if not IsValid(ply) then return end

        print("[Badges][SV] Timer 2s, envoi badges à", ply:Nick())

        SendBadgeData(ply)
        BroadcastRoleBadges()
    end)
end)

net.Receive("LegendaryBadges_UpdateEquipped", function(len, ply)
    InitPlayerData(ply)

    local newEquipped = {}

    for i = 1, 3 do
        local has = net.ReadBool()
        if has then
            local id = net.ReadString()
            newEquipped[i] = id
        else
            newEquipped[i] = nil
        end
    end

    local ownedSet = {}

    for _, bid in ipairs(ply.LegendaryBadges.owned or {}) do
        ownedSet[bid] = true
    end

    for i = 1, 3 do
        local id = newEquipped[i]
        if id and not ownedSet[id] then
            newEquipped[i] = nil
        end
    end

    ply.LegendaryBadges.equipped = newEquipped

    SavePlayersToFile()
end)

net.Receive("LegendaryBadges_AdminCreateBadge", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local name  = net.ReadString()
    local icon  = net.ReadString()
    local color = net.ReadColor()

    if name == "" then
        net.Start("LegendaryBadges_AdminCreateResult")
        net.WriteBool(false)
        net.WriteString("Nom invalide.")
        net.Send(ply)
        return
    end

    local id = tostring(LegendaryBadges.NextID or 1)
    LegendaryBadges.NextID = (LegendaryBadges.NextID or 1) + 1

    LegendaryBadges.List[id] = {
        id    = id,
        name  = name,
        icon  = icon,
        color = color
    }

    print("[Badges] Badge admin créé par", ply:Nick(), "ID:", id, "Nom:", name)

    -- Donner ce nouveau badge à tous les joueurs dont le rang est dans AllBadgesRanks
    if LegendaryBadgesConfig and LegendaryBadgesConfig.AllBadgesRanks then
        for _, pl in ipairs(player.GetAll()) do
            if IsValid(pl) then
                local group = string.lower(pl:GetUserGroup() or "")
                if LegendaryBadgesConfig.AllBadgesRanks[group] then
                    local sid = pl:SteamID()
                    LegendaryBadges.PlayerData[sid] = LegendaryBadges.PlayerData[sid] or {
                        owned    = {},
                        equipped = { nil, nil, nil }
                    }

                    local pdata = LegendaryBadges.PlayerData[sid]
                    pdata.owned = pdata.owned or {}

                    local already = false
                    for _, bid in ipairs(pdata.owned) do
                        if bid == id then
                            already = true
                            break
                        end
                    end

                    if not already then
                        table.insert(pdata.owned, id)
                    end

                    InitPlayerData(pl)
                    SendBadgeData(pl)
                end
            end
        end

        SavePlayersToFile()
    end

    SaveBadgesToFile()
    BroadcastBadgeList()
    BroadcastRoleBadges()

    net.Start("LegendaryBadges_AdminCreateResult")
    net.WriteBool(true)
    net.WriteString("Badge créé avec l'ID " .. id .. ".")
    net.Send(ply)
end)

net.Receive("LegendaryBadges_AdminDeleteBadge", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local id = net.ReadString()
    if id == "" or not LegendaryBadges.List[id] then return end

    print("[Badges] Suppression du badge ID", id, "par", ply:Nick())

    for _, pl in ipairs(player.GetAll()) do
        if not IsValid(pl) then continue end

        if pl.LegendaryBadges and pl.LegendaryBadges.owned then
            for k, v in ipairs(pl.LegendaryBadges.owned) do
                if v == id then
                    table.remove(pl.LegendaryBadges.owned, k)
                    break
                end
            end
        end

        if pl.LegendaryBadges and pl.LegendaryBadges.equipped then
            for i = 1, 3 do
                if pl.LegendaryBadges.equipped[i] == id then
                    pl.LegendaryBadges.equipped[i] = nil
                end
            end
        end
    end

    LegendaryBadges.List[id] = nil

    SaveBadgesToFile()
    SavePlayersToFile()
    BroadcastBadgeList()
    BroadcastRoleBadges()
end)

end
