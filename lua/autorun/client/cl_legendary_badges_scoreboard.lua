if CLIENT then

local Scoreboard
local LegendaryScoreboardOpen = false

BadgeData = BadgeData or {
    list     = {},
    owned    = {},
    equipped = { nil, nil, nil }
}

local roleBadges = roleBadges or {}

hook.Remove("ScoreboardShow", "DarkRP_ScoreboardShow")
hook.Remove("ScoreboardHide", "DarkRP_ScoreboardHide")
hook.Remove("ScoreboardShow", "ULXScoreboardShow")
hook.Remove("ScoreboardHide", "ULXScoreboardHide")

-- icône custom pour le socreboard
local matFriend = Material("icon16/heart.png", "smooth")
local matServerLogo = Material("materials/logo/logo.png", "smooth")
print("[Scoreboard] matServerLogo IsError =", matServerLogo:IsError())

--------------------------------------------------------------------
-- BLUR UTILS
--------------------------------------------------------------------
local blurMat = Material("pp/blurscreen")
local function DrawBlur(panel, layers, density, alpha)
    local x, y = panel:LocalToScreen(0, 0)
    local scrW, scrH = ScrW(), ScrH()

    surface.SetDrawColor(255, 255, 255, alpha)
    surface.SetMaterial(blurMat)

    for i = 1, layers do
        blurMat:SetFloat("$blur", (i / layers) * density)
        blurMat:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, scrW, scrH)
    end
end

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
-- CRÉATION LIGNES SCOREBOARD (style cards)
--------------------------------------------------------------------
local function BuildScoreboardLines(scroll)
    if not IsValid(scroll) then return end
    scroll:Clear()

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local line = vgui.Create("DButton", scroll)
        line:Dock(TOP)
        line:DockMargin(0, 0, 0, 6)
        line:SetTall(40)
        line:SetText("")
        line:SetMouseInputEnabled(true)
        line:SetKeyboardInputEnabled(false)
        line.SubMenu = nil

        -- Avatar Steam du joueur
        local avatar = vgui.Create("AvatarImage", line)
        avatar:SetSize(32, 32)
        avatar:SetPos(4, 4)                -- un peu à gauche dans la card
        avatar:SetPlayer(ply, 32)          -- 32 = taille de l’avatar


        ----------------------------------------------------------------
        -- Rendu de la ligne
        ----------------------------------------------------------------
        function line:Paint(w, h)
            local radius = 5
            draw.RoundedBox(radius, 0, 0, w, h, Color(20, 20, 20, 230))

            -- pseudo
            draw.SimpleText(ply:Nick(), "DermaDefault", 48, h / 2, color_white,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- icône ami + ping
            local lp = LocalPlayer()
            local isFriend = false
            if IsValid(lp) and IsValid(ply) then
                local status = lp:GetFriendStatus(ply)
                isFriend = (status == "friend")
            end

            local pingText = ply:Ping() .. " ms"
            surface.SetFont("DermaDefault")
            local tw, th = surface.GetTextSize(pingText)

            local baseX  = w - 40
            local pingY  = h / 2
            local iconSz = 16

            if isFriend then
                local iconX = baseX - tw - iconSz - 8
                local iconY = pingY - iconSz / 2

                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(matFriend)
                surface.DrawTexturedRect(iconX, iconY, iconSz, iconSz)

                draw.SimpleText(pingText, "DermaDefault",
                    iconX + iconSz + 4, pingY,
                    Color(200, 200, 200),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(pingText, "DermaDefault",
                    baseX, pingY,
                    Color(200, 200, 200),
                    TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        ----------------------------------------------------------------
        -- SOUS-MENU STAFF
        ----------------------------------------------------------------
        local function BuildSubMenu()
            local sub = vgui.Create("DPanel", scroll)
            sub:Dock(TOP)
            sub:SetTall(38)
            sub:DockMargin(40, 2, 40, 6)

            function sub:Paint(w, h)
                surface.SetDrawColor(15, 15, 15, 230)
                surface.DrawRect(0, 0, w, h)
            end

            local function AddBtn(txt, iconMat, onClick)
                local b = vgui.Create("DButton", sub)
                b:Dock(LEFT)
                b:DockMargin(4, 4, 4, 4)
                b:SetWide(110)
                b:SetText("")
                b.OnMousePressed = nil
                b.DoClick = function()
                    if onClick then onClick() end
                end

                function b:Paint(w, h)
                    surface.SetDrawColor(30, 30, 30, 255)
                    surface.DrawRect(0, 0, w, h)
                    if iconMat then
                        surface.SetDrawColor(255, 255, 255)
                        surface.SetMaterial(iconMat)
                        surface.DrawTexturedRect(6, 6, 16, 16)
                    end
                    draw.SimpleText(txt, "DermaDefault", 26, h / 2,
                        Color(230, 230, 230),
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end

            local matSteam  = Material("icon16/world.png")
            local matID     = Material("icon16/key.png")
            local matFreeze = Material("icon16/lock.png")
            local matGoto   = Material("icon16/arrow_right.png")
            local matBring  = Material("icon16/arrow_left.png")
            local matBack   = Material("icon16/arrow_undo.png")
            local matSpec   = Material("icon16/eye.png")

            AddBtn("profil steam", matSteam, function()
                local sid64 = ply:SteamID64()
                if sid64 then
                    gui.OpenURL("https://steamcommunity.com/profiles/" .. sid64)
                end
            end)

            AddBtn("steamid", matID, function()
                local sid = ply:SteamID() or ""
                if sid ~= "" then
                    SetClipboardText(sid)
                    chat.AddText(
                        Color(0, 200, 0), "[Scoreboard] ",
                        color_white, "SteamID de ",
                        Color(200, 200, 255), ply:Nick(),
                        color_white, " copié : ",
                        Color(200, 255, 200), sid
                    )
                end
            end)

            AddBtn("geler", matFreeze, function()
                net.Start("LegendaryBadges_AdminAction")
                net.WriteString("freeze")
                net.WriteEntity(ply)
                net.SendToServer()
            end)

            AddBtn("amener à soi", matBring, function()
                net.Start("LegendaryBadges_AdminAction")
                net.WriteString("bring")
                net.WriteEntity(ply)
                net.SendToServer()
            end)

            AddBtn("renvoyer", matBack, function()
                net.Start("LegendaryBadges_AdminAction")
                net.WriteString("back")
                net.WriteEntity(ply)
                net.SendToServer()
            end)

            AddBtn("observer", matSpec, function()
                net.Start("LegendaryBadges_AdminAction")
                net.WriteString("spectate")
                net.WriteEntity(ply)
                net.SendToServer()
            end)

            AddBtn("goto", matGoto, function()
                net.Start("LegendaryBadges_AdminAction")
                net.WriteString("goto")
                net.WriteEntity(ply)
                net.SendToServer()
            end)

            return sub
        end

        ----------------------------------------------------------------
        -- TOGGLE MENU
        ----------------------------------------------------------------
        function line:DoClick()
            if IsValid(self.SubMenu) then
                self.SubMenu:Remove()
                self.SubMenu = nil
                return
            end

            for _, other in ipairs(scroll:GetChildren()) do
                if IsValid(other.SubMenu) then
                    other.SubMenu:Remove()
                    other.SubMenu = nil
                end
            end

            self.SubMenu = BuildSubMenu()
            self.SubMenu:SetZPos(self:GetZPos() + 1)
        end

        --------------------------------------------------------
        -- Panneau des badges 
        --------------------------------------------------------
        local badgePanel = vgui.Create("DPanel", line)
        badgePanel:SetSize(4 * 24 + 4 * 4 + 8, 32)
        badgePanel:SetPos(200, 4)
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
-- CRÉATION SCOREBOARD (style screenshot)
--------------------------------------------------------------------
local function CreateScoreboard()
    if IsValid(Scoreboard) then Scoreboard:Remove() end

    local sw, sh = ScrW(), ScrH()

    -- Panel racine plein écran, transparent
    Scoreboard = vgui.Create("DPanel")
    Scoreboard:SetSize(sw, sh)
    Scoreboard:Center()
    Scoreboard:SetMouseInputEnabled(true)
    Scoreboard:SetKeyboardInputEnabled(false)

    function Scoreboard:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 0)
        surface.DrawRect(0, 0, w, h)
    end

    -- Panel flou type screenshot
    local blurPanel = vgui.Create("DPanel", Scoreboard)
    blurPanel:SetSize(1920, 957)
    blurPanel:SetPos(6, 62)

    function blurPanel:Paint(w, h)
        DrawBlur(self, 4, 6, 255)
        surface.SetDrawColor(0, 0, 0, 80) -- semi-transparent
        surface.DrawRect(0, 0, w, h)
    end

    -- Logo global du serveur
    local serverLogo = vgui.Create("DImage", blurPanel)
    serverLogo:SetSize(328, 124)                -- arrondi de 123.55
    serverLogo:SetImage("logo/logo.png")        -- adapte le chemin ("logo/logo.png" si materials/logo/logo.vtf)
    -- position relative au blurPanel (tu m'as donné des coords écran)
    serverLogo:SetPos(784 - 6, 109 - 62)        -- on enlève l'offset du blurPanel (6, 62)


    -- barre "X joueurs sur Y"
    local playersBar = vgui.Create("DPanel", blurPanel)
    playersBar:SetSize(300, 24)
    playersBar:SetPos(389 - 6, 267 - 62)

    function playersBar:Paint(w, h)
        local txt = string.format("%d joueurs sur %d", #player.GetAll(), 120)
        draw.SimpleText(txt, "DermaDefault", 0, 0, color_white,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- zone scroll des lignes joueurs
    local scroll = vgui.Create("DScrollPanel", blurPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(378 - 6, 289 - 62, 378 - 6, 80)

    BuildScoreboardLines(scroll)
end

--------------------------------------------------------------------
-- SÉCURITÉ : TABLE ÉQUIPÉE POUR TOUS LES JOUEURS
--------------------------------------------------------------------
hook.Add("Think", "LegendaryBadges_SyncEquipped", function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        ply.LegendaryBadgesClientEquipped =
            ply.LegendaryBadgesClientEquipped or { nil, nil, nil }
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

end
