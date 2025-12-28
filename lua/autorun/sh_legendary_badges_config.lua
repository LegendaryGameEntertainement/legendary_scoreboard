LegendaryBadgesConfig = LegendaryBadgesConfig or {}

-- Rangs qui peuvent ouvrir le menu admin (commande legendary_badges_admin)
LegendaryBadgesConfig.EditorRanks = {
    superadmin = true,
    admin      = true
}

-- Badge “rôle” forcé par rang (ID de badge existant dans LegendaryBadges.List)
LegendaryBadgesConfig.RoleBadges = {
    superadmin = "3",
    admin      = "3",
    moderator  = "3",
    vip        = "4",
}
