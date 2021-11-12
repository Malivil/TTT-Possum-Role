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

SWEP.AllowDrop              = false
SWEP.NoSights               = true
SWEP.UseHands               = true
SWEP.LimitedStock           = true
SWEP.AmmoEnt                = nil

SWEP.Primary.Delay          = 1
SWEP.Primary.Automatic      = false
SWEP.Primary.Cone           = 0
SWEP.Primary.Ammo           = nil
SWEP.Primary.ClipSize       = 100
SWEP.Primary.ClipMax        = 100
SWEP.Primary.DefaultClip    = 100
SWEP.Primary.Sound          = ""

if SERVER then
    CreateConVar("ttt_possum_disguiser_drain", "0.32", FCVAR_NONE, "The drain delay", 0.01, 1)
    CreateConVar("ttt_possum_disguiser_recharge", "0.16", FCVAR_NONE, "The recharge delay", 0.01, 1)
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

function SWEP:Holster()
    return not self:GetOwner():GetNWBool("PossumDisguiseRunning", false)
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
    return true
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if owner:GetNWBool("PossumDisguiseRunning", false) then return end

    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)

    -- Toggle state
    owner:SetNWBool("PossumDisguiseActive", not owner:GetNWBool("PossumDisguiseActive", false))
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
            owner:SetNWBool("PossumDisguiseRunning", false)
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