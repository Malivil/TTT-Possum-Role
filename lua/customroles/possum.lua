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
        ["psm_disguiser"] = "Death Disguiser",
        ["psm_disguiser_charge"] = "DISGUISE REMAINING",
        ["psm_disguiser_hud"] = "Death disguiser active",
        ["psm_disguiser_help_pri"] = "Use {primaryfire} to toggle the device on and off",
        ["psm_disguiser_help_sec"] = "While the device is active, taking damage will cause you to play dead"
    }
}

ROLE.convars = {}
table.insert(ROLE.convars, {
    cvar = "ttt_possum_disguiser_drain",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
table.insert(ROLE.convars, {
    cvar = "ttt_possum_disguiser_recharge",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})

RegisterRole(ROLE)

if SERVER then
    AddCSLuaFile()

    hook.Add("EntityTakeDamage", "Possum_EntityTakeDamage", function(ent, dmginfo)
        if not IsPlayer(ent) or not ent:Alive() or ent:IsSpec() or not ent:IsPossum() then return end
        if not ent:GetNWBool("PossumDisguiseActive", false) then return end

        local att = dmginfo:GetAttacker()
        if not IsPlayer(att) or att == ent then return end

        -- Play dead
        ent:SetNWBool("PossumDisguiseRunning", true)
        ent:SelectWeapon("weapon_psm_disguiser")
        -- TODO: Ragdoll, lock view
    end)

    hook.Add("TTTPrepareRound", "Possum_PrepareRound", function()
        for _, v in pairs(player.GetAll()) do
            v:SetNWBool("PossumDisguiseActive", false)
            v:SetNWBool("PossumDisguiseRunning", false)
        end
    end)

    hook.Add("TTTPlayerRoleChanged", "Possum_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        ply:SetNWBool("PossumDisguiseActive", false)
        ply:SetNWBool("PossumDisguiseRunning", false)
    end)
end

if CLIENT then
    surface.CreateFont("PSMTimeLeft", {
        font = "Trebuchet24",
        size = 22,
        weight = 600
    })

    hook.Add("TTTHUDInfoPaint", "Possum_TTTHUDInfoPaint", function(client, label_left, label_top)
        if not IsPlayer(client) or not client:Alive() or client:IsSpec() or not client:IsPossum() then return end
        if not client:GetNWBool("PossumDisguiseActive", false) then return end

        surface.SetFont("TabLarge")
        surface.SetTextColor(255, 255, 255, 230)

        text = LANG.GetTranslation("psm_disguiser_hud")
        local _, h = surface.GetTextSize(text)

        surface.SetTextPos(label_left, ScrH() - label_top - h)
        surface.DrawText(text)

        -- Move the label up for the next one
        label_top = label_top + 20
    end)

    -- Disguise time progress bar
    local margin = 10
    local width, height = 250, 25
    local x = ScrW() / 2 - width / 2
    local y = margin / 2 + height
    local colors = {
        background = Color(30, 60, 100, 222),
        fill = Color(75, 150, 255, 255)
    }
    hook.Add("HUDPaint", "Possum_HUDPaint", function()
        local client = LocalPlayer()
        if not IsPlayer(client) then return end

        local weap = client:GetActiveWeapon()
        if not IsValid(weap) then return end

        if WEPS.GetClass(weap) ~= "weapon_psm_disguiser" then return end

        local max = weap:GetMaxClip1()
        local diff = max - weap:Clip1()
        if diff > 0 then
            HUD:PaintBar(8, x, y, width, height, colors, 1 - (diff / max))
            draw.SimpleText(LANG.GetTranslation("psm_disguiser_charge"), "PSMTimeLeft", ScrW() / 2, y + 1, COLOR_WHITE, TEXT_ALIGN_CENTER)
        end
    end)
end