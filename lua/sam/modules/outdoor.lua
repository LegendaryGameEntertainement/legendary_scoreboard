if not sam then
    print("[OUTDOOR] SAM not loaded")
    return
end

print("[OUTDOOR] Outdoor module loaded")

sam.command.set_category("outdoor", "Outdoor")

-- !badges : ouvre le menu pour soi-même
sam.command.new("badges")
    :SetPermission("badges", "user")
    :SetCategory("outdoor")
    :Help("Ouvrir le menu de badges.")
    :OnExecute(function(ply)
        if IsValid(ply) then
            ply:ConCommand("legendary_badges\n")
        end
    end)
:End()

-- !badgesadmin : ouvre le menu admin pour soi-même
sam.command.new("badgesadmin")
    :SetPermission("badgesadmin", "admin")
    :SetCategory("outdoor")
    :Help("Ouvrir le menu admin des badges.")
    :OnExecute(function(ply)
        if IsValid(ply) then
            ply:ConCommand("legendary_badges_admin\n")
        end
    end)
:End()

sam.command.new("addbadges")
    :SetPermission("badges_add", "superadmin")
    :SetCategory("outdoor")
    :Help("Ajouter un badge à un joueur (ID numérique du badge).")

    :AddArg("player", {single_target = true})
    :AddArg("number", {hint = "badge ID", min = 1, round = true})

    :OnExecute(function(ply, targets, badgeID)
        local target = targets[1]
        if not IsValid(target) then return end

        local sid = target:SteamID()
        LegendaryBadges.AddBadgeToSteamID(sid, tostring(badgeID))

        sam.player.send_message(nil, "Badges ajoutés", {
            A = ply,
            T = targets,
            V = badgeID
        })
    end)
:End()


sam.command.new("delbadges")
    :SetPermission("badges_del", "superadmin")
    :SetCategory("outdoor")
    :Help("Retirer un badge à un joueur (ID numérique du badge).")

    :AddArg("player", {single_target = true})
    :AddArg("number", {hint = "badge ID", min = 1, round = true})

    :OnExecute(function(ply, targets, badgeID)
        local target = targets[1]
        if not IsValid(target) then return end

        local sid = target:SteamID()
        LegendaryBadges.RemoveBadgeFromSteamID(sid, tostring(badgeID))

        sam.player.send_message(nil, "Badges supprimés", {
            A = ply,
            T = targets,
            V = badgeID
        })
    end)
:End()


