local player = player

local PlayerIterator = player.Iterator

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
table.insert(ROLE.convars, {
    cvar = "ttt_possum_damage_resist",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
table.insert(ROLE.convars, {
    cvar = "ttt_possum_disguiser_uses",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})

RegisterRole(ROLE)

if SERVER then
    AddCSLuaFile()

    local possum_damage_resist = CreateConVar("ttt_possum_damage_resist", 0, FCVAR_NONE, "Playing Dead damage resistance factor", 0, 1)

    local plymeta = FindMetaTable("Player")
    function plymeta:PossumPlayDead()
        if not self:IsPossum() then return end

        -- TODO: Cleanup after release
        if CRVersion("2.3.2") then
            if self.in_ragdoll then return end
            self:SetNWBool("PossumDisguiseRunning", true)
            self:SetActiveWeapon(self:GetWeapon("weapon_psm_disguiser"))
            local rag = self:Ragdoll(0, true, true)
            if IsValid(rag) then
                rag.damage_resist = possum_damage_resist:GetFloat()
            end
            return
        end

        if IsValid(self.possumRagdoll) then return end

        self:SetNWBool("PossumDisguiseRunning", true)
        self:SetActiveWeapon(self:GetWeapon("weapon_psm_disguiser"))

        -- Create ragdoll and lock their view
        local ragdoll = ents.Create("prop_ragdoll")
        ragdoll.ragdolledPly = self
        ragdoll.playerHealth = self:Health()
        ragdoll.playerColor = self:GetPlayerColor()
        -- Don't let the red matter bomb destroy this ragdoll
        ragdoll.WYOZIBHDontEat = true

        local velocity = self:GetVelocity()
        ragdoll:SetPos(self:GetPos())
        ragdoll:SetModel(self:GetModel())
        ragdoll:SetSkin(self:GetSkin())
        for _, value in pairs(self:GetBodyGroups()) do
            ragdoll:SetBodygroup(value.id, self:GetBodygroup(value.id))
        end
        ragdoll:SetAngles(self:GetAngles())
        ragdoll:SetColor(self:GetColor())
        CORPSE.SetPlayerNick(ragdoll, self)
        ragdoll:Spawn()
        ragdoll:Activate()

        local rag_collide = GetConVar("ttt_ragdoll_collide")
        ragdoll:SetCollisionGroup(rag_collide:GetBool() and COLLISION_GROUP_WEAPON or COLLISION_GROUP_DEBRIS_TRIGGER)

        -- So their player ent will match up (position-wise) with where their ragdoll is.
        self:SetParent(ragdoll)
        -- Set velocity for each piece of the ragdoll
        for i = 1, ragdoll:GetPhysicsObjectCount() do
            local phys_obj = ragdoll:GetPhysicsObjectNum(i)
            if phys_obj then
                phys_obj:SetVelocity(velocity)
            end
        end

        self.possumRagdoll = ragdoll
        self:Spectate(OBS_MODE_CHASE)
        self:SpectateEntity(ragdoll)

        -- The disguiser stays in their hand so hide it from view
        self:DrawViewModel(false)
        self:DrawWorldModel(false)

        -- If there is a barnacle holding this player, tell it to let go
        -- We do this so the player doesn't get stuck in a partial capture state
        -- where they are taking damage from the barnacle even they have revived
        -- and moved away
        for _, b in ipairs(ents.FindByClass("npc_barnacle")) do
            if not IsValid(b) then continue end
            if b:GetEnemy() ~= self then continue end
            b:Fire("LetGo", nil, 0, self, self)
        end
    end

    function plymeta:PossumRevive()
        if not self:IsPossum() then return end

        -- TODO: Cleanup after release
        if CRVersion("2.3.2") then
            if not self.in_ragdoll then return end
            self:SetNWBool("PossumDisguiseRunning", false)
            self:UnRagdoll()
            return
        end

        if not IsValid(self.possumRagdoll) then return end

        self:SetNWBool("PossumDisguiseRunning", false)

        -- Save these things in case something like a Randomat has changed them
        -- We'll restore them later since the `Spawn` call resets these flags to their default
        local jumpPower = self:GetJumpPower()
        local walkSpeed = self:GetWalkSpeed()
        local maxHealth = self:GetMaxHealth()

        -- Unragdoll
        self:SpectateEntity(nil)
        self:UnSpectate()
        self:SetParent()
        self:Spawn()
        self:SetPos(self.possumRagdoll:GetPos())
        self:SetVelocity(self.possumRagdoll:GetVelocity())
        local yaw = self.possumRagdoll:GetAngles().yaw
        self:SetAngles(Angle(0, yaw, 0))
        self:SetModel(self.possumRagdoll:GetModel())
        self:SetPlayerColor(self.possumRagdoll.playerColor)

        -- Let weapons be seen again
        self:DrawViewModel(true)
        self:DrawWorldModel(true)

        local newhealth = self.possumRagdoll.playerHealth
        if newhealth <= 0 then
            newhealth = 1
        end
        self:SetHealth(newhealth)

        -- Restore potentially-changed values
        self:SetWalkSpeed(walkSpeed)
        self:SetJumpPower(jumpPower)
        self:SetMaxHealth(maxHealth)

        SafeRemoveEntity(self.possumRagdoll)
        self.possumRagdoll = nil
    end

    local function TransferRagdollDamage(rag, dmginfo)
        if not IsRagdoll(rag) then return end
        local ply = rag.ragdolledPly
        if not IsPlayer(ply) or not ply:Alive() or ply:IsSpec() then return end

        -- Keep track of how much health they have left
        local damage = dmginfo:GetDamage()
        -- Apply damage resistance, if it's enabled
        local damage_resist = possum_damage_resist:GetFloat()
        if damage_resist > 0 then
            damage = damage - (damage * damage_resist)
        end
        rag.playerHealth = rag.playerHealth - damage

        util.StartBleeding(rag, damage, 5)

        -- Kill the player if they run out of health
        if rag.playerHealth <= 0 then
            ply:PossumRevive()
            -- Disable the disguise so they don't just ragdoll again
            ply:SetNWBool("PossumDisguiseActive", false)

            local att = dmginfo:GetAttacker()
            local inflictor = dmginfo:GetInflictor()
            if not IsValid(inflictor) then
                inflictor = att
            end
            local dmg_type = dmginfo:GetDamageType()

            -- Use TakeDamage instead of Kill so it properly applies karma
            local dmg = DamageInfo()
            dmg:SetDamageType(dmg_type)
            dmg:SetAttacker(att)
            dmg:SetInflictor(inflictor)
            -- Use 10 so damage scaling doesn't mess with it. The worse damage factor (0.1) will still deal 1 damage after scaling a 10 down
            -- Karma ignores excess damage anyway
            dmg:SetDamage(10)
            dmg:SetDamageForce(Vector(0, 0, 1))

            ply:TakeDamageInfo(dmg)
        else
            ply:SetHealth(rag.playerHealth)
        end
    end

    hook.Add("PostEntityTakeDamage", "Possum_PostEntityTakeDamage", function(ent, dmginfo, taken)
        if not taken then return end

        local att = dmginfo:GetAttacker()
        if not IsPlayer(att) then return end

        -- Don't transfer damage from jester-like players
        if att:ShouldActLikeJester() then return end

        -- TODO: Cleanup after release
        local ply, rag
        if IsRagdoll(ent) then
            rag = ent
            ply = ent.ragdolledPly
        elseif IsPlayer(ent) then
            ply = ent
            rag = ent.possumRagdoll
        end

        if not IsPlayer(ply) or not ply:Alive() or ply:IsSpec() or not ply:IsPossum() then return end
        if not ply:GetNWBool("PossumDisguiseActive", false) then return end
        if att == ply then return end

        -- Transfer possum damage from the ragdoll to the real player
        if IsRagdoll(rag) then
            TransferRagdollDamage(rag, dmginfo)
        elseif not ply:IsRoleAbilityDisabled() then
            ply:PossumPlayDead()
        end
    end)

    -- Clear possum data when it's no longer relevant
    local function ClearPossumData(ply)
        ply:SetNWBool("PossumDisguiseActive", false)
        ply:SetNWBool("PossumDisguiseRunning", false)
        SafeRemoveEntity(ply.possumRagdoll)
        ply.possumRagdoll = nil
    end

    hook.Add("TTTPrepareRound", "Possum_PrepareRound", function()
        for _, v in PlayerIterator() do
            ClearPossumData(v)
        end
    end)

    hook.Add("TTTPlayerRoleChanged", "Possum_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        ClearPossumData(ply)
    end)

    hook.Add("PlayerDeath", "Possum_KillCheck_PlayerDeath", function(victim, infl, attacker)
        if not IsPlayer(victim) or not victim:IsPossum() then return end
        ClearPossumData(victim)
    end)
end

if CLIENT then
    surface.CreateFont("PSMTimeLeft", {
        font = "Trebuchet24",
        size = 22,
        weight = 600
    })

    -- Show a message when the death disguiser is enabled
    hook.Add("TTTHUDInfoPaint", "Possum_TTTHUDInfoPaint", function(client, label_left, label_top, active_labels)
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
            table.insert(active_labels, "possum")
        end
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
            CRHUD:PaintBar(8, x, y, width, height, colors, 1 - (diff / max))
            draw.SimpleText(LANG.GetTranslation("psm_disguiser_charge"), "PSMTimeLeft", ScrW() / 2, y + 1, COLOR_WHITE, TEXT_ALIGN_CENTER)
            if client:GetNWBool("PossumDisguiseRunning", false) then
                draw.SimpleText(LANG.GetParamTranslation("psm_disguiser_charge_info", { secondaryfire = Key("+attack2", "MOUSE2")}), "TabLarge", ScrW() / 2, margin, COLOR_WHITE, TEXT_ALIGN_CENTER)
            end
        end
    end)

    hook.Add("TTTScoreGroup", "Possum_TTTScoreGroup", function(ply)
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
    end)

    -- Tutorial
    hook.Add("TTTTutorialRoleText", "Possum_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_POSSUM then
            local roleColor = ROLE_COLORS[ROLE_INNOCENT]
            local html = "The " .. ROLE_STRINGS[ROLE_POSSUM] .. " is a member of the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>innocent team</span> whose goal is to protect themselves and help their team win."

            html = html .. "<span style='display: block; margin-top: 10px;'>Use the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>" .. LANG.GetTranslation("psm_disguiser") .. "</span> to prepare yourself to play dead.</span>"
            html = html .. "<span style='display: block; margin-top: 10px;'>Once the " .. LANG.GetTranslation("psm_disguiser") .. " <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>is enabled</span>, you will automatically play dead when you take damage.</span>"
            html = html .. "<span style='display: block; margin-top: 10px;'>You are only able to <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>play dead for a limited time</span>, so be careful!</span>"

            return html
        end
    end)
end