if CLIENT then

local Scoreboard
local LegendaryScoreboardOpen = false

BadgeData = BadgeData or {
    list = {},
    owned = {},
    equipped = { nil, nil, nil }
}

-- roleBadges[steamid64] = badgeID
local roleBadges = roleBadges or {}

--------------------------------------------------------------------
-- (Optionnel) désactiver d’autres scoreboards connus
--------------------------------------------------------------------
hook.Remove("ScoreboardShow", "DarkRP_ScoreboardShow")
hook.Remove("ScoreboardHide", "DarkRP_ScoreboardHide")
hook.Remove("ScoreboardShow", "ULXScoreboardShow")
hook.Remove("ScoreboardHide", "ULXScoreboardHide")

--------------------------------------------------------------------
-- RÉCEPTION DES DONNÉES BADGES (3 slots joueurs)
--------------------------------------------------------------------

net.Receive("LegendaryBadges_SendDataV2", function()
    BadgeData.list = {}
    local count = net.ReadUInt(16)

    for i = 1, count do
        local id    = net.ReadString()
        local name  = net.ReadString()
        local color = net.ReadColor()
        local icon  = net.ReadString()

        BadgeData.list[id] = {
            id    = id,
            name  = name,
            color = color,
            icon  = icon
        }
    end

    BadgeData.owned = {}
    local ownedCount = net.ReadUInt(16)

    for i = 1, ownedCount do
        table.insert(BadgeData.owned, net.ReadString())
    end

    BadgeData.equipped = {}
    for i = 1, 3 do
        local has = net.ReadBool()
        if has then
            BadgeData.equipped[i] = net.ReadString()
        else
            BadgeData.equipped[i] = nil
        end
    end

    local lp = LocalPlayer()
    if IsValid(lp) then
        lp.LegendaryBadgesClientEquipped = table.Copy(BadgeData.equipped)
    end
end)

--------------------------------------------------------------------
-- RÉCEPTION DES BADGES DE RÔLE POUR TOUS LES JOUEURS
--------------------------------------------------------------------

net.Receive("LegendaryBadges_SendRoles", function()
    roleBadges = {}

    local count = net.ReadUInt(8)
    print("[Badges][CL] Receive roles, count =", count)

    for i = 1, count do
        local sid = net.ReadString()
        local has = net.ReadBool()

        if has then
            local id = net.ReadString()
            roleBadges[sid] = id
            print(" ->", sid, "roleID", id)
        else
            print(" ->", sid, "no role")
        end
    end
end)

--------------------------------------------------------------------
-- RÉFRESH DES LIGNES DU SCOREBOARD
--------------------------------------------------------------------

local function RefreshScoreboardLines(scroll)
    if not IsValid(scroll) then return end

    scroll:Clear()

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        --------------------------------------------------------
        -- Ligne joueur = DButton (clic gauche -> debug / SteamID)
        --------------------------------------------------------
        local line = vgui.Create("DButton", scroll)
        line:Dock(TOP)
        line:DockMargin(0, 0, 0, 2)
        line:SetTall(32)
        line:SetText("")
        line:SetMouseInputEnabled(true)
        line:SetKeyboardInputEnabled(false)

        function line:Paint(w, h)
            surface.SetDrawColor(40, 40, 40, 220)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText(ply:Nick(), "DermaDefault", 8, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(ply:Ping() .. " ms", "DermaDefault", w - 10, h / 2, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        function line:DoClick()
            local sid = ply:SteamID() or ""
            if sid == "" then return end

            SetClipboardText(sid)
            chat.AddText(
                Color(0, 200, 0), "[Scoreboard] ",
                color_white, "SteamID de ",
                Color(200, 200, 255), ply:Nick(),
                color_white, " copié : ",
                Color(200, 255, 200), sid
            )
        end


        --------------------------------------------------------
        -- Panneau des badges (3 slots + rôle)
        --------------------------------------------------------
        local badgePanel = vgui.Create("DPanel", line)
        badgePanel:SetSize(4 * 24 + 4 * 4 + 8, 32)
        badgePanel:SetPos(200, 0)
        badgePanel:SetMouseInputEnabled(true)

        local tooltip = ""

        function badgePanel:OnCursorEntered()
            if tooltip ~= "" then
                self:SetTooltip(tooltip)
            end
        end

        function badgePanel:Paint(w, h)
            surface.SetDrawColor(0, 0, 0, 0)
            surface.DrawRect(0, 0, w, h)

            tooltip = ""

            local eq
            if ply == LocalPlayer() then
                eq = ply.LegendaryBadgesClientEquipped or {}
            else
                eq = {}
            end

            local x = 0

            -- 3 slots configurables
            for i = 1, 3 do
                local id = eq[i]

                if id and BadgeData.list[id] then
                    local data = BadgeData.list[id]
                    local col  = data.color or color_white

                    if col.a > 0 then
                        surface.SetDrawColor(col.r, col.g, col.b, col.a)
                        surface.DrawRect(x, 4, 24, 24)
                    end

                    surface.SetDrawColor(255, 255, 255, 255)
                    if data.icon ~= "" then
                        local mat = Material(data.icon, "smooth")
                        surface.SetMaterial(mat)
                        surface.DrawTexturedRect(x + 4, 8, 16, 16)
                    end

                    if tooltip ~= "" then
                        tooltip = tooltip .. " / "
                    end
                    tooltip = tooltip .. (data.name or id)
                end

                x = x + 28
            end

            -- 4e slot : badge de rôle
            local roleID = roleBadges[ply:SteamID64() or "0"]

            if roleID and BadgeData.list[roleID] then
                x = x + 4

                local data = BadgeData.list[roleID]
                local col  = data.color or color_white

                if col.a > 0 then
                    surface.SetDrawColor(col.r, col.g, col.b, col.a)
                    surface.DrawRect(x, 4, 24, 24)
                end

                surface.SetDrawColor(255, 255, 255, 255)
                if data.icon ~= "" then
                    local mat = Material(data.icon, "smooth")
                    surface.SetMaterial(mat)
                    surface.DrawTexturedRect(x + 4, 8, 16, 16)
                end

                if tooltip ~= "" then
                    tooltip = tooltip .. " / "
                end
                tooltip = tooltip .. (data.name or roleID)
            end
        end
    end
end

--------------------------------------------------------------------
-- CRÉATION SCOREBOARD
--------------------------------------------------------------------

local function CreateScoreboard()
    if IsValid(Scoreboard) then Scoreboard:Remove() end

    Scoreboard = vgui.Create("DFrame")
    Scoreboard:SetSize(ScrW() * 0.6, ScrH() * 0.7)
    Scoreboard:Center()
    Scoreboard:SetTitle("Legendary Scoreboard")
    Scoreboard:SetDraggable(false)
    Scoreboard:ShowCloseButton(false)

    local scroll = vgui.Create("DScrollPanel", Scoreboard)
    scroll:Dock(FILL)

    -- premier remplissage
    RefreshScoreboardLines(scroll)

    -- mise à jour toutes les 0.5 s quand le scoreboard est visible
    timer.Create("LegendaryBadges_ScoreboardRefresh", 0.5, 0, function()
        if not IsValid(Scoreboard) or not Scoreboard:IsVisible() then return end
        RefreshScoreboardLines(scroll)
    end)
end

--------------------------------------------------------------------
-- SÉCURITÉ : TABLE ÉQUIPÉE POUR TOUS LES JOUEURS
--------------------------------------------------------------------

hook.Add("Think", "LegendaryBadges_SyncEquipped", function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        ply.LegendaryBadgesClientEquipped = ply.LegendaryBadgesClientEquipped or { nil, nil, nil }
    end
end)

--------------------------------------------------------------------
-- HOOKS SCOREBOARD
--------------------------------------------------------------------

hook.Add("ScoreboardShow", "LegendaryBadges_ScoreboardShow", function()
    if not IsValid(Scoreboard) then
        CreateScoreboard()
    end

    Scoreboard:Show()
    Scoreboard:MakePopup()
    Scoreboard:SetKeyboardInputEnabled(false)

    timer.Simple(0, function()
        if IsValid(Scoreboard) then
            gui.EnableScreenClicker(true)
        end
    end)

    LegendaryScoreboardOpen = true
    return true
end)

hook.Add("ScoreboardHide", "LegendaryBadges_ScoreboardHide", function()
    if IsValid(Scoreboard) then
        Scoreboard:Hide()
    end

    gui.EnableScreenClicker(false)
    LegendaryScoreboardOpen = false
    return true
end)

--------------------------------------------------------------------
-- BLOQUER LES INPUTS QUAND LE TAB EST OUVERT
--------------------------------------------------------------------

hook.Add("CreateMove", "LegendaryBadges_BlockInputsWhenOpen_Unique", function(cmd)
    if not LegendaryScoreboardOpen then return end

    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
    cmd:RemoveKey(IN_RELOAD)

    cmd:ClearMovement()
    cmd:SetForwardMove(0)
    cmd:SetSideMove(0)
    cmd:SetUpMove(0)
end)

--------------------------------------------------------------------
-- COMMANDE DE TEST SANS TAB
--------------------------------------------------------------------

concommand.Add("legendary_scoreboard_test", function()
    if not IsValid(Scoreboard) then
        CreateScoreboard()
    end

    Scoreboard:Show()
    Scoreboard:MakePopup()
    Scoreboard:SetKeyboardInputEnabled(false)

    timer.Simple(0, function()
        if IsValid(Scoreboard) then
            gui.EnableScreenClicker(true)
        end
    end)

    LegendaryScoreboardOpen = true -- important pour bloquer les tirs
end)

end
