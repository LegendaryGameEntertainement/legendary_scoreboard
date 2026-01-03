if CLIENT then

BadgeData = {
    list = {},
    owned = {},
    equipped = { nil, nil, nil }
}

-- Références panel admin / joueur pour refresh
local AdminFrame
local AdminList
BadgesPlayerFrame = BadgesPlayerFrame or nil

--------------------------------------------------------------------
-- RÉCEPTION DES DONNÉES BADGES
--------------------------------------------------------------------

net.Receive("LegendaryBadges_SendDataV2", function()
    print("[Badges] net LegendaryBadges_SendDataV2 reçu")

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

    if IsValid(AdminList) then
        AdminList:Clear()
        for id, data in pairs(BadgeData.list) do
            local line = AdminList:AddLine(id, data.name or id)
            line.id = id
        end
    end

    -- si le menu joueur est ouvert, on le ferme pour qu'il soit rouvert proprement
    if IsValid(BadgesPlayerFrame) then
        BadgesPlayerFrame:Close()
        BadgesPlayerFrame = nil
    end
end)

--------------------------------------------------------------------
-- FEEDBACK ADMIN (CRÉATION)
--------------------------------------------------------------------

net.Receive("LegendaryBadges_AdminCreateResult", function()
    local ok  = net.ReadBool()
    local msg = net.ReadString() or ""
    local col = ok and Color(0, 200, 0) or Color(200, 0, 0)

    chat.AddText(col, "[Badges Admin] ", color_white, msg)
end)

--------------------------------------------------------------------
-- MENU JOUEUR
--------------------------------------------------------------------

local function OpenPlayerBadgeMenu()
    if table.IsEmpty(BadgeData.list) then
        chat.AddText(Color(255, 255, 0), "[Badges] Aucune donnée pour l'instant, le menu sera vide jusqu'à la réception du serveur.")
    end

    if IsValid(BadgesPlayerFrame) then
        BadgesPlayerFrame:Close()
    end

    local frame = vgui.Create("DFrame")
    BadgesPlayerFrame = frame
    frame:SetSize(500, 300)
    frame:Center()
    frame:SetTitle("Badges")
    frame:MakePopup()

    local list = vgui.Create("DScrollPanel", frame)
    list:Dock(LEFT)
    list:SetWide(250)

    local slotsPanel = vgui.Create("DPanel", frame)
    slotsPanel:Dock(FILL)

    -- récupérer les badges déjà équipés (priorité à la copie locale)
    local lp      = LocalPlayer()
    local initial = BadgeData.equipped

    if IsValid(lp) and istable(lp.LegendaryBadgesClientEquipped) then
        initial = lp.LegendaryBadgesClientEquipped
    end

    local slots = { initial[1], initial[2], initial[3] }

    local function RefreshSlots()
        slotsPanel:Clear()

        for i = 1, 3 do
            local pnl = vgui.Create("DButton", slotsPanel)
            pnl:Dock(TOP)
            pnl:DockMargin(5, 5, 5, 0)
            pnl:SetTall(40)

            local id = slots[i]

            if id and BadgeData.list[id] then
                pnl:SetText("Slot " .. i .. " : " .. (BadgeData.list[id].name or id))
            else
                pnl:SetText("Slot " .. i .. " : (vide)")
            end

            pnl.DoRightClick = function()
                slots[i] = nil
                RefreshSlots()
            end
        end

        local save = vgui.Create("DButton", slotsPanel)
        save:Dock(BOTTOM)
        save:DockMargin(5, 5, 5, 5)
        save:SetTall(32)
        save:SetText("Sauvegarder")

        save.DoClick = function()
            net.Start("LegendaryBadges_UpdateEquipped")
            for i = 1, 3 do
                local id = slots[i]
                net.WriteBool(id ~= nil)
                if id then
                    net.WriteString(id)
                end
            end
            net.SendToServer()

            local lp = LocalPlayer()
            if IsValid(lp) then
                lp.LegendaryBadgesClientEquipped = table.Copy(slots)
                chat.AddText(Color(0, 200, 0), "[Badges] ", color_white, "Configuration sauvegardée.")
                PrintTable(lp.LegendaryBadgesClientEquipped or {})
            end

            frame:Close()
            BadgesPlayerFrame = nil
        end
    end

    RefreshSlots()

    for _, id in ipairs(BadgeData.owned) do
        local data = BadgeData.list[id]
        if not data then continue end

        local pnl = list:Add("DButton")
        pnl:Dock(TOP)
        pnl:DockMargin(5, 5, 5, 0)
        pnl:SetTall(32)
        pnl:SetText(data.name or id)

        pnl.DoClick = function()
            local menu = DermaMenu()
            for i = 1, 3 do
                menu:AddOption("Mettre dans Slot " .. i, function()
                    slots[i] = id
                    RefreshSlots()
                end)
            end
            menu:Open()
        end
    end
end

concommand.Add("legendary_badges", OpenPlayerBadgeMenu)

--------------------------------------------------------------------
-- MENU ADMIN
--------------------------------------------------------------------

local function OpenAdminBadgeMenu()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:IsSuperAdmin() then return end

    AdminFrame = vgui.Create("DFrame")
    AdminFrame:SetSize(600, 400)
    AdminFrame:Center()
    AdminFrame:SetTitle("Legendary Badges - Admin")
    AdminFrame:MakePopup()

    AdminList = vgui.Create("DListView", AdminFrame)
    AdminList:Dock(LEFT)
    AdminList:SetWide(250)
    AdminList:AddColumn("ID")
    AdminList:AddColumn("Nom")

    local editor = vgui.Create("DPanel", AdminFrame)
    editor:Dock(FILL)

    local selectedID
    local nameEntry, iconEntry, colorMixer, noBackgroundCheck

    local function LoadBadge(id)
        selectedID = id
        local data = BadgeData.list[id]
        if not data then return end

        nameEntry:SetValue(data.name or id)
        iconEntry:SetValue(data.icon or "")
        colorMixer:SetColor(data.color or Color(255, 255, 255))

        if data.color and data.color.a == 0 then
            noBackgroundCheck:SetValue(1)
        else
            noBackgroundCheck:SetValue(0)
        end
    end

    nameEntry = vgui.Create("DTextEntry", editor)
    nameEntry:Dock(TOP)
    nameEntry:DockMargin(5, 5, 5, 0)
    nameEntry:SetPlaceholderText("Nom affiché")

    iconEntry = vgui.Create("DTextEntry", editor)
    iconEntry:Dock(TOP)
    iconEntry:DockMargin(5, 5, 5, 0)
    iconEntry:SetPlaceholderText("Chemin icône (ex: icon16/star.png)")

    colorMixer = vgui.Create("DColorMixer", editor)
    colorMixer:Dock(TOP)
    colorMixer:DockMargin(5, 5, 5, 0)
    colorMixer:SetTall(150)
    colorMixer:SetPalette(true)
    colorMixer:SetAlphaBar(true)
    colorMixer:SetWangs(true)

    noBackgroundCheck = vgui.Create("DCheckBoxLabel", editor)
    noBackgroundCheck:Dock(TOP)
    noBackgroundCheck:DockMargin(5, 5, 5, 0)
    noBackgroundCheck:SetText("Pas de couleur de fond (transparent)")
    noBackgroundCheck:SetValue(0)
    noBackgroundCheck:SizeToContents()

    local deleteBtn = vgui.Create("DButton", editor)
    deleteBtn:Dock(BOTTOM)
    deleteBtn:DockMargin(5, 5, 5, 0)
    deleteBtn:SetTall(28)
    deleteBtn:SetText("Supprimer le badge sélectionné")

    deleteBtn.DoClick = function()
        if not selectedID or not BadgeData.list[selectedID] then
            chat.AddText(Color(255, 0, 0), "[Badges Admin] Aucun badge sélectionné.")
            return
        end

        Derma_Query(
            "Supprimer le badge \"" .. (BadgeData.list[selectedID].name or selectedID) .. "\" ?",
            "Confirmation",
            "Oui", function()
                net.Start("LegendaryBadges_AdminDeleteBadge")
                net.WriteString(selectedID)
                net.SendToServer()
            end,
            "Non"
        )
    end

    local createBtn = vgui.Create("DButton", editor)
    createBtn:Dock(BOTTOM)
    createBtn:DockMargin(5, 5, 5, 5)
    createBtn:SetTall(32)
    createBtn:SetText("Créer un nouveau badge")

    createBtn.DoClick = function()
        local name = nameEntry:GetValue() or ""
        local icon = iconEntry:GetValue() or ""
        local col  = colorMixer:GetColor()

        if name == "" then
            chat.AddText(Color(255, 0, 0), "[Badges Admin] Nom vide.")
            return
        end

        if noBackgroundCheck:GetChecked() then
            col.a = 0
        end

        net.Start("LegendaryBadges_AdminCreateBadge")
            net.WriteString(name)
            net.WriteString(icon)
            net.WriteColor(col)
        net.SendToServer()

        nameEntry:SetValue("")
        iconEntry:SetValue("")
        noBackgroundCheck:SetValue(0)
    end

    local function RefreshList()
        if not IsValid(AdminList) then return end

        AdminList:Clear()
        for id, data in pairs(BadgeData.list) do
            local line = AdminList:AddLine(id, data.name or id)
            line.id = id
        end
    end

    AdminList.OnRowSelected = function(_, _, line)
        if not line or not line.id then return end
        LoadBadge(line.id)
    end

    RefreshList()
end

concommand.Add("legendary_badges_admin", OpenAdminBadgeMenu)

end
