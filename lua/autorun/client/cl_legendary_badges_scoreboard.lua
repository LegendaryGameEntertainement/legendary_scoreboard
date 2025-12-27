if CLIENT then

    local Scoreboard

    BadgeData = BadgeData or {
        list = {},
        owned = {},
        equipped = { nil, nil, nil }
    }

    --------------------------------------------------------------------
    -- RÉCEPTION DES DONNÉES BADGES (même net que le menu)
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

        hook.Add("Think", "LegendaryBadges_ScoreboardThink", function()
            if not IsValid(Scoreboard) or not Scoreboard:IsVisible() then return end

            scroll:Clear()

            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) then continue end

                local line = scroll:Add("DPanel")
                line:Dock(TOP)
                line:DockMargin(0, 0, 0, 2)
                line:SetTall(32)

                function line:Paint(w, h)
                    surface.SetDrawColor(40, 40, 40, 220)
                    surface.DrawRect(0, 0, w, h)

                    -- Pseudo
                    draw.SimpleText(ply:Nick(), "DermaDefault", 8, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    -- Ping
                    draw.SimpleText(ply:Ping() .. " ms", "DermaDefault", w - 10, h / 2, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end

                -- Panneau des badges, positionné manuellement
                local badgePanel = vgui.Create("DPanel", line)
                badgePanel:SetSize(3 * 24 + 3 * 4, 32)
                badgePanel:SetPos(200, 0) -- décale ici pour être à côté du pseudo
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
                        eq = {} -- plus tard : synchro des autres joueurs
                    end

                    local x = 0
                    for i = 1, 3 do
                        local id = eq[i]
                        if id and BadgeData.list[id] then
                            local data = BadgeData.list[id]

                            surface.SetDrawColor(data.color or color_white)
                            surface.DrawRect(x, 4, 24, 24)

                            surface.SetDrawColor(255, 255, 255)
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
                end
            end
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
        gui.EnableScreenClicker(true)
        return true
    end)

    hook.Add("ScoreboardHide", "LegendaryBadges_ScoreboardHide", function()
        if IsValid(Scoreboard) then
            Scoreboard:Hide()
        end
        gui.EnableScreenClicker(false)
        return true
    end)

end
