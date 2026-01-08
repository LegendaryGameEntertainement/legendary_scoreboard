LegendaryBadgesConfig = LegendaryBadgesConfig or {}

-- Rangs qui peuvent ouvrir le menu admin 
LegendaryBadgesConfig.EditorRanks = {
    superadmin = true,
    admin      = true
}

-- Rangs qui peuvent ajouter / supprimer des badges
LegendaryBadgesConfig.ManageBadgeRanks = {
    superadmin = true
}

-- Rangs qui possèdent automatiquement tous les badges
LegendaryBadgesConfig.AllBadgesRanks = {
    superadmin = true
}

-- Badge “rôle” forcé par rang (ID de badge existant dans LegendaryBadges.List)
LegendaryBadgesConfig.RoleBadges = {
    superadmin = "3",
    admin      = "3",
    moderator  = "3",
    vip        = "4",
}
