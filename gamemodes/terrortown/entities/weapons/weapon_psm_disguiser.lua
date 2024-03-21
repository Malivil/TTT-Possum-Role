if CLIENT then
    SWEP.PrintName          = "psm_disguiser"
    SWEP.Slot               = 7

    SWEP.ViewModelFOV       = 60
end

SWEP.ViewModel              = "models/weapons/v_slam.mdl"
SWEP.WorldModel             = "models/weapons/w_slam.mdl"
SWEP.Weight                 = 2

SWEP.Base                   = "weapon_tttbase"
SWEP.Category               = WEAPON_CATEGORY_ROLE

SWEP.Spawnable              = true
SWEP.AutoSpawnable          = false
SWEP.HoldType               = "slam"
SWEP.Kind                   = WEAPON_ROLE

SWEP.DeploySpeed            = 4
SWEP.AllowDrop              = false
SWEP.NoSights               = true
SWEP.UseHands               = true
SWEP.LimitedStock           = true
SWEP.AmmoEnt                = nil

SWEP.Primary.Delay          = 0.25
SWEP.Primary.Automatic      = false
SWEP.Primary.Cone           = 0
SWEP.Primary.Ammo           = nil
SWEP.Primary.ClipSize       = 100
SWEP.Primary.ClipMax        = 100
SWEP.Primary.DefaultClip    = 100
SWEP.Primary.Sound          = ""

if SERVER then
    SWEP.UseCount = 0

    CreateConVar("ttt_possum_disguiser_drain", "0.32", FCVAR_NONE, "The drain delay", 0.01, 1)
    CreateConVar("ttt_possum_disguiser_recharge", "0.16", FCVAR_NONE, "The recharge delay", 0.01, 1)
    CreateConVar("ttt_possum_disguiser_uses", "0", FCVAR_NONE, "How many times the disguiser can be used. 0 = Infinite", 0, 1)
end

-- If this disguiser has limited uses, remove it when they've met or exceeded that amount
local function CheckUseCount(disguiser)
    local uses = GetConVar("ttt_possum_disguiser_uses"):GetInt()
    disguiser.UseCount = disguiser.UseCount + 1

    -- 0 = Infinite
    if uses == 0 then return end

    if disguiser.UseCount >= uses then
        disguiser:Remove()
    end
end

function SWEP:Initialize()
    self.lastTickSecond = 0
    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)

    if CLIENT then
        self:AddHUDHelp("psm_disguiser_help_pri", "psm_disguiser_help_sec", true)
    end
    return self.BaseClass.Initialize(self)
end

function SWEP:Equip()
end

-- If we're switching from a TFA weapon to the disguiser while it's running, JUST DO IT!
-- The holster animation causes a delay where the client is not allowed to switch weapons
-- This means if we tell the user to select a weapon and then block the user from switching weapons immediately after,
-- the holster animation delay will cause the player to not select the weapon we told them to
hook.Add("TFA_PreHolster", "PossumTFAPreHolster", function(wep, target)
    if not IsValid(wep) or not IsValid(target) then return end

    local owner = wep:GetOwner()
    if not IsPlayer(owner) or not owner:IsPossum() then return end

    local weapon = WEPS.GetClass(target)
    local running = owner:GetNWBool("PossumDisguiseRunning", false)
    if running and weapon == "weapon_psm_disguiser" then
        return true
    end
end)

function SWEP:Holster()
    return not self:GetOwner():GetNWBool("PossumDisguiseRunning", false)
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
    return true
end

function SWEP:SetDisguiserState(active)
    if CLIENT then return end

    local owner = self:GetOwner()
    owner:SetNWBool("PossumDisguiseActive", active)

    local message = "Your disguiser has been "
    if not active then
        message = message .. "de-"
    end
    message = message .. "activated."
    owner:QueueMessage(MSG_PRINTBOTH, message)
end

function SWEP:PrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if owner:GetNWBool("PossumDisguiseRunning", false) then return end

    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)

    if SERVER then
        -- Toggle state
        local active = not owner:GetNWBool("PossumDisguiseActive", false)
        self:SetDisguiserState(active)
    end
end

function SWEP:SecondaryAttack()
    if CLIENT then return end

    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if owner:GetNWBool("PossumDisguiseRunning", false) then
        owner:PossumRevive()
        CheckUseCount(self)
    end
end

function SWEP:Think()
    if CLIENT then return end

    local owner = self:GetOwner()
    local running = owner:GetNWBool("PossumDisguiseRunning", false)
    local rate = running and GetConVar("ttt_possum_disguiser_drain"):GetFloat() or GetConVar("ttt_possum_disguiser_recharge"):GetFloat()

    if CurTime() - self.lastTickSecond > rate then
        local clip = self:Clip1()
        -- If they run out of charge, disable the disguiser
        if running and clip == 0 then
            owner:PossumRevive()
            CheckUseCount(self)
        else
            if running then
                clip = clip - 1
            else
                clip = clip + 1
            end

            if clip < 0 or clip > self:GetMaxClip1() then return end

            self:SetClip1(clip)
            self.lastTickSecond = CurTime()
        end
    end
end

function SWEP:OnDrop()
    self:Remove()
end

function SWEP:OnRemove()
    if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive() then
        RunConsoleCommand("lastinv")
    end
end

if SERVER then
    hook.Add("TTTPlayerHandcuffed", "Possum_TTTPlayerHandcuffed", function(owner, target, time)
        if not IsValid(target) then return end
        if not target:IsPossum() then return end

        local disguiser = target:GetWeapon("weapon_psm_disguiser")
        if not IsValid(disguiser) then return end

        disguiser:SetDisguiserState(false)
        if target:GetNWBool("PossumDisguiseRunning", false) then
            target:PossumRevive()
            CheckUseCount(disguiser)
        end
    end)
end