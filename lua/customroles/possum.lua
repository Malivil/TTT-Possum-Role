local ROLE = {}

ROLE.nameraw = "possum"
ROLE.name = "Possum"
ROLE.nameplural = "Possums"
ROLE.nameext = "a Possum"
ROLE.nameshort = "psm"

ROLE.desc = [[You are {role}!

Protect yourself from your enemies by
using your device to play dead when attacked.]]

ROLE.team = ROLE_TEAM_INNOCENT

ROLE.startinghealth = 125
ROLE.maxhealth = 125

ROLE.loadout = {"weapon_psm_disguiser"}

ROLE.translations = {
    ["english"] = {
        ["psm_disguiser"] = "Death Disguiser"
    }
}

ROLE.convars = {}

RegisterRole(ROLE)

if SERVER then
    AddCSLuaFile()
end