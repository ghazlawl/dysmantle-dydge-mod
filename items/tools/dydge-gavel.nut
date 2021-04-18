/**
 * The # of milliseconds (?) since the last shot was fired. Used to control
 * how quickly a weapon fires.
 */
time_since_last_shot <- 0;

/**
 * The # of bullets in a full clip.
 */
CLIP_SIZE <- 100;

local info = {
    name = "Dydge Gavel"
    description = "Description goes here."
    icon = "items/tools/dydge-gavel.png"
    prop = "actors/tools/dydge-gavel.xml"
    prop_bone = "tool"
    prop_handle_bone = "handle"
    type = "ranged_weapon"
    unique = true
    destroy_after_owner_death = true
    stance = "gun"
    damage_increase_per_upgrade_level = 15
    number_of_uses = 4
    additional_uses_per_upgrade_level = 1
    prop_mount_scale = "1.5"
    prop_mount_angle_x = "-90" // roll
    prop_mount_angle_y = "40" // pitch
    prop_mount_angle_z = "190" // yaw
    prop_mount_offset_x = "-9" // down/up
    prop_mount_offset_y = "7" // left/right
    prop_mount_offset_z = "3" // forward/back
    /*
    // Last known good values:
    prop_mount_angle_x = "-90" // roll
    prop_mount_angle_y = "40" // pitch
    prop_mount_angle_z = "190" // yaw
    prop_mount_offset_x = "-9" // down/up
    prop_mount_offset_y = "7" // left/right
    prop_mount_offset_z = "3" // forward/back
    */
};

local projectile_plasma = {
    fire_rate = 0.2
    muzzle_effect = "effects/muzzle-plasma.xml"
    projectile = "actors/projectiles/gavel-plasma.xml"
    sound = "sfx/weapons/plasma-rifle-fire"
    velocity = 2000
}

local projectile_lead = {
    fire_rate = 0.1
    muzzle_effect = "effects/muzzle-conventional.xml"
    projectile = "actors/projectiles/gavel-lead.xml"
    sound = "sfx/weapons/smg_fire"
    velocity = 4000
}

// Get the projectile data.
local projectile_data = projectile_lead;

// ============================== //
// Required Functions
// ============================== //

function OnMetadataRead() {
    return info;
}

local owner_handle = 0;
local item_id = null;
local elapsed_time = 0;
local trigger_up_time = 0;
local is_trigger_up = true;
local is_aiming = false;
local clip = CLIP_SIZE;

function OnInitialize(so_handle_owner, id) {
    owner_handle = so_handle_owner;
    item_id = id;
    return true;
}

function OnTriggerDown() {
    is_trigger_up = false;

    if (clip <= 0) {
        return;
    }

    if (Game_IsPlayingAnimationByAction(owner_handle, "reload")) {
        return;
    }

    if (!Game_IsPlayingAnimationByAction(owner_handle, "aim")) {
        is_aiming = true;
        elapsed_time = 0;
        trigger_up_time = 0;
        Game_StartAiming(owner_handle, "weapon", 80, 1000, 0);
    }
}

function OnTriggerUp() {
    is_trigger_up = true;
    trigger_up_time = elapsed_time;

    Stage_SendStageObjectCommandWord(owner_handle, "aiming_end");
    is_aiming = false;

    elapsed_time = 0;
}

function OnTriggerCancel() {
    OnTriggerUp();
}

function OnUpdate(tdelta) {
    // Update the delta vars.
    time_since_last_shot += tdelta;
    elapsed_time += tdelta;

    if (is_aiming && elapsed_time > 0.3 && !is_trigger_up && time_since_last_shot > projectile_data.fire_rate) {
        // Fire a projectile.
        FireProjectile(owner_handle);

        // Reset the delta var.
        time_since_last_shot = 0;
    }
}

function OnCommandWord(id, kvs) {
    if (id == "weapon_fired") {
        if (!Game_CanItemBeTriggered(owner_handle, item_id)) {
            OnTriggerUp();
        } else {
            clip--;
        }
    }
}

function OnEquipped() {
    // Get the projectile data.
    projectile_data = GetProjectileData();
}

// ============================== //
// Custom Functions
// ============================== //

/**
 * Gets the projectile data. This value is affected by any equipped trinkets.
 */
function GetProjectileData() {
    if (Game_IsItemEquipped(owner_handle, "items/trinkets/baseball-card.nut")) {
        Game_AddActorNotification(owner_handle, "Plasma projectile activated.");
        return projectile_plasma;
    }

    Game_AddActorNotification(owner_handle, "Lead projectile activated.");
    return projectile_lead;
}

/**
 * Fires a projectile.
 */
function FireProjectile(so_player) {
    // Get the player position and angle.
    local pos = StageObject_GetPosition(so_player);
    local angle = StageObject_GetAngle(so_player);

    // Calculate the x and y offset of the projectile to move it closer to
    // the barrel of the gun.
    local x = cos(angle * PI / 180) * 45;
    local y = sin(angle * PI / 180) * 45;

    // Create the projectile, set the owner, set the angle.
    local so_projectile = Stage_CreateActor(projectile_data.projectile, pos[0] + x, pos[1] + y, pos[2] - 78);
    StageObject_SetAngle(so_projectile, angle - 8);
    Actor_SetOwner(so_projectile, so_player);

    // Spawn the muzzle effect.
    Stage_SpawnEffect(projectile_data.muzzle_effect, pos[0] + x, pos[1] + y, pos[2] - 78, angle - 8);

    // Calculate the velocity angle in radians. We subtract 8 degrees to
    // compensate for the difference between the barrel of the gun and the
    // ranged weapon indicator.
    local angle_radians = (angle - 8) * PI / 180;

    // Set the projectile velocity.
    Actor_SetLinearVelocity(so_projectile, projectile_data.velocity * cos(-angle_radians), -projectile_data.velocity * sin(-angle_radians), 0);

    // Play the sound.
    NX_PlaySound(projectile_data.sound, 0.8, 0.0, 1.0);
}