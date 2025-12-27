if SERVER then
    util.AddNetworkString("LegendaryBadges_SendDataV2")
    util.AddNetworkString("LegendaryBadges_UpdateEquipped")
    util.AddNetworkString("LegendaryBadges_AdminCreateBadge")
    util.AddNetworkString("LegendaryBadges_AdminCreateResult")
    -- Net pour la suppression depuis le menu admin
    util.AddNetworkString("LegendaryBadges_AdminDeleteBadge")

    LegendaryBadges = LegendaryBadges or {}
    LegendaryBadges.List = LegendaryBadges.List or {}

    local DATA_DIR  = "legendary_badges"
    local DATA_FILE = DATA_DIR .. "/badges.json"

    --------------------------------------------------------------------
    -- SAUVEGARDE / CHARGEMENT JSON
    --------------------------------------------------------------------
    local function SaveBadgesToFile()
        if not file.IsDir(DATA_DIR, "DATA") then
            file.CreateDir(DATA_DIR)
        end

        local toSave = {}

        for id, data in pairs(LegendaryBadges.List or {}) do
            toSave[id] = {
                id    = data.id,
                name  = data.name,
                icon  = data.icon,
                r     = data.color and data.color.r or 255,
                g     = data.color and data.color.g or 255,
                b     = data.color and data.color.b or 255,
                a     = data.color and data.color.a or 255
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
    -- INIT LISTE BADGES
    --------------------------------------------------------------------
    LoadBadgesFromFile()

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
    -- GESTION DONNÉES JOUEUR
    --------------------------------------------------------------------
    local function InitPlayerData(ply)
        if not IsValid(ply) then return end
        ply.LegendaryBadges = ply.LegendaryBadges or {}

        if not ply.LegendaryBadges.owned then
            ply.LegendaryBadges.owned = {}
            for id, _ in pairs(LegendaryBadges.List) do
                table.insert(ply.LegendaryBadges.owned, id)
            end
        end

        ply.LegendaryBadges.equipped = ply.LegendaryBadges.equipped or {
            nil, nil, nil
        }
    end

    --------------------------------------------------------------------
    -- ENVOI AU CLIENT (avec debug)
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
        net.Send(ply)
    end

    local function BroadcastBadgeList()
        for _, pl in ipairs(player.GetAll()) do
            InitPlayerData(pl)
            SendBadgeData(pl)
        end
    end

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

        SaveBadgesToFile()
        BroadcastBadgeList()

        net.Start("LegendaryBadges_AdminCreateResult")
            net.WriteBool(true)
            net.WriteString("Badge créé avec l'ID " .. id .. ".")
        net.Send(ply)
    end)

    --------------------------------------------------------------------
    -- SUPPRESSION D'UN BADGE (appelée par le bouton dans le menu admin)
    --------------------------------------------------------------------
    net.Receive("LegendaryBadges_AdminDeleteBadge", function(len, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end

        local id = net.ReadString()
        if id == "" or not LegendaryBadges.List[id] then return end

        -- Retirer le badge de toutes les données joueurs (owned + equipped)
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

        -- Supprimer de la liste globale + sauvegarde
        LegendaryBadges.List[id] = nil
        SaveBadgesToFile()

        -- Re-synchroniser la liste avec tout le monde (menu admin, menu joueur, scoreboard)
        BroadcastBadgeList()
    end)
end
