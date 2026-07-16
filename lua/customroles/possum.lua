local hook = hook
local player = player
local table = table

local AddHook = hook.Add
local PlayerIterator = player.Iterator
local TableInsert = table.insert

local ROLE = {}

ROLE.nameraw = "possum"
ROLE.name = "Possum"
ROLE.nameplural = "Possums"
ROLE.nameext = "a Possum"
ROLE.nameshort = "psm"

ROLE.desc = [[You are {role}!

Protect yourself from your enemies by
using your device to play dead when attacked.]]
ROLE.shortdesc = "Can play dead when attacked by activating their Death Disguiser."

ROLE.team = ROLE_TEAM_INNOCENT

ROLE.startinghealth = 125
ROLE.maxhealth = 125

ROLE.loadout = {"weapon_psm_disguiser"}

ROLE.translations = {
    ["english"] = {
        ["psm_disguiser"] = "Death Disguiser",
        ["psm_disguiser_charge"] = "DISGUISE REMAINING",
        ["psm_disguiser_charge_info"] = "Press {secondaryfire} to stop playing dead early",
        ["psm_disguiser_hud"] = "Death disguiser active",
        ["psm_disguiser_help_pri"] = "Use {primaryfire} to toggle the device on and off",
        ["psm_disguiser_help_sec"] = "While the device is active, taking damage will cause you to play dead"
    }
}

ROLE.convars = {
    {
        cvar = "ttt_possum_disguiser_drain",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 2
    },
    {
        cvar = "ttt_possum_disguiser_recharge",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 2
    },
    {
        cvar = "ttt_possum_damage_resist",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 2
    },
    {
        cvar = "ttt_possum_disguiser_uses",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    }
}


if SERVER then
    AddCSLuaFile()

    local possum_damage_resist = CreateConVar("ttt_possum_damage_resist", 0, FCVAR_NONE, "Playing Dead damage resistance factor", 0, 1)

    local plymeta = FindMetaTable("Player")
    function plymeta:PossumPlayDead()
        if not self:IsPossum() then return end
        if self.in_ragdoll then return end

        self:SetNWBool("PossumDisguiseRunning", true)
        self:SetActiveWeapon(self:GetWeapon("weapon_psm_disguiser"))
        local rag = self:Ragdoll(0, true, true)
        if IsValid(rag) then
            rag.damage_resist = possum_damage_resist:GetFloat()
        end
    end

    function plymeta:PossumRevive()
        if not self:IsPossum() then return end
        if not self.in_ragdoll then return end

        self:SetNWBool("PossumDisguiseRunning", false)
        self:UnRagdoll()
    end

    local function Possum_PostEntityTakeDamage(ent, dmginfo, taken)
        if not taken then return end
        if not IsPlayer(ent) then return end
        if not ent:Alive() or ent:IsSpec() or not ent:IsPossum() then return end
        if not ent:GetNWBool("PossumDisguiseActive", false) then return end

        local att = dmginfo:GetAttacker()
        if not IsPlayer(att) then return end
        if att == ent then return end

        -- Ignore damage from jester-like players
        if att:ShouldActLikeJester() then return end

        -- If the possum is disabled, don't do anything
        if ent:IsRoleAbilityDisabled() then return end

        ent:PossumPlayDead()
    end

    -- Clear possum data when it's no longer relevant
    local function ClearPossumData(ply)
        ply:SetNWBool("PossumDisguiseActive", false)
        ply:SetNWBool("PossumDisguiseRunning", false)
    end

    AddHook("TTTPrepareRound", "Possum_PrepareRound", function()
        for _, v in PlayerIterator() do
            ClearPossumData(v)
        end
    end)

    AddHook("TTTPlayerRoleChanged", "Possum_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        ClearPossumData(ply)
    end)

    local function Possum_KillCheck_PlayerDeath(victim, infl, attacker)
        if not IsPlayer(victim) or not victim:IsPossum() then return end
        ClearPossumData(victim)
    end

    ------------------
    -- REGISTRATION --
    ------------------

    ROLE.registeredhooks = {
        ["PlayerDeath"] = Possum_KillCheck_PlayerDeath,
        ["PostEntityTakeDamage"] = Possum_PostEntityTakeDamage
    }
end

if CLIENT then
    local draw = draw
    local surface = surface

    surface.CreateFont("PSMTimeLeft", {
        font = "Trebuchet24",
        size = 22,
        weight = 600
    })

    -- Show a message when the death disguiser is enabled
    local function Possum_TTTHUDInfoPaint(client, label_left, label_top, active_labels)
        if not IsPlayer(client) or not client:Alive() or client:IsSpec() or not client:IsPossum() then return end
        if not client:GetNWBool("PossumDisguiseActive", false) then return end

        surface.SetFont("TabLarge")
        surface.SetTextColor(255, 255, 255, 230)

        text = LANG.GetTranslation("psm_disguiser_hud")
        local _, h = surface.GetTextSize(text)

        -- Move this up based on how many other labels here are
        if active_labels then
            label_top = label_top + (20 * #active_labels)
        else
            label_top = label_top + 20
        end

        surface.SetTextPos(label_left, ScrH() - label_top - h)
        surface.DrawText(text)

        -- Track that the label was added so others can position accurately
        if active_labels then
            TableInsert(active_labels, "possum")
        end
    end

    -- Disguise time progress bar
    local margin = 10
    local width, height = 250, 25
    local x = ScrW() / 2 - width / 2
    local y = margin / 2 + height
    local colors = {
        background = Color(30, 60, 100, 222),
        fill = Color(75, 150, 255, 255)
    }
    local function Possum_HUDPaint()
        local client = LocalPlayer()
        if not IsPlayer(client) then return end

        local weap = client:GetActiveWeapon()
        if not IsValid(weap) then return end

        if WEPS.GetClass(weap) ~= "weapon_psm_disguiser" then return end

        local max = weap:GetMaxClip1()
        local diff = max - weap:Clip1()
        if diff > 0 then
            CRHUD:PaintBar(8, x, y, width, height, colors, 1 - (diff / max))
            draw.SimpleText(LANG.GetTranslation("psm_disguiser_charge"), "PSMTimeLeft", ScrW() / 2, y + 1, COLOR_WHITE, TEXT_ALIGN_CENTER)
            if client:GetNWBool("PossumDisguiseRunning", false) then
                draw.SimpleText(LANG.GetParamTranslation("psm_disguiser_charge_info", { secondaryfire = Key("+attack2", "MOUSE2")}), "TabLarge", ScrW() / 2, margin, COLOR_WHITE, TEXT_ALIGN_CENTER)
            end
        end
    end

    local function Possum_TTTScoreGroup(ply)
        if not IsPlayer(ply) or not ply:IsPossum() then return end
        if not ply:Alive() or ply:IsSpec() then return end

        -- Only continue if the possum is currently pretending to be dead
        if not ply:GetNWBool("PossumDisguiseRunning", false) then return end

        local client = LocalPlayer()
        if not IsPlayer(client) then return end

        -- If the client is someone who would know that someone has died (via the scoreboard), show the possum as "missing in action" to fully disguise that
        if client:IsSpec() or
                client:IsActiveTraitorTeam() or client:IsActiveMonsterTeam() or
                (client:IsActiveIndependentTeam() and cvars.Bool("ttt_" .. ROLE_STRINGS_RAW[client:GetRole()] .. "_update_scoreboard", false)) or
                ((GAMEMODE.round_state ~= ROUND_ACTIVE) and client:IsTerror()) then
            return GROUP_NOTFOUND
        end
    end

    -- Tutorial
    AddHook("TTTTutorialRoleText", "Possum_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_POSSUM then
            local roleColor = ROLE_COLORS[ROLE_INNOCENT]
            local html = "The " .. ROLE_STRINGS[ROLE_POSSUM] .. " is a member of the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>innocent team</span> whose goal is to protect themselves and help their team win."

            html = html .. "<span style='display: block; margin-top: 10px;'>Use the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>" .. LANG.GetTranslation("psm_disguiser") .. "</span> to prepare yourself to play dead.</span>"
            html = html .. "<span style='display: block; margin-top: 10px;'>Once the " .. LANG.GetTranslation("psm_disguiser") .. " <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>is enabled</span>, you will automatically play dead when you take damage.</span>"
            html = html .. "<span style='display: block; margin-top: 10px;'>You are only able to <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>play dead for a limited time</span>, so be careful!</span>"

            return html
        end
    end)

    ------------------
    -- REGISTRATION --
    ------------------

    ROLE.registeredhooks = {
        ["HUDPaint"] = Possum_HUDPaint,
        ["TTTHUDInfoPaint"] = Possum_TTTHUDInfoPaint,
        ["TTTScoreGroup"] = Possum_TTTScoreGroup
    }
end

RegisterRole(ROLE)