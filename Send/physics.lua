---@diagnostic disable: undefined-global
--============================================================
-- Send/physics.lua
-- ACNextGen V2.0 Send Layer
-- Result Bus -> AC Store (legacy key compatibility)
-- NO physics calculation. Pure transport.
--============================================================
local M = {}

local utils = require("Core.utils")
local bus = require("Core.result_bus")

local lastStore = {}
local INTERVAL = 0.05

local LEGACY_MAP = {
    -- Global
    { bus = "speedKmh",           key = "ngp_hub_speed" },
    { bus = "rpm_filtered",       key = "ngp_hub_rpm" },
    { bus = "gear",               key = "ngp_hub_gear" },
    { bus = "steer",              key = "ngp_hub_steer" },
    { bus = "gas",                key = "ngp_hub_gas" },
    { bus = "brake",              key = "ngp_hub_brake" },
    { bus = "clutch",             key = "ngp_hub_clutch" },
    { bus = "handbrake",          key = "ngp_hub_handbrake" },
    { bus = "yawRate",            key = "ngp_hub_yaw" },
    { bus = "body_rigidity",      key = "ngp_hub_body_rigidity" },
    { bus = "chassis_energy",     key = "ngp_hub_chassis_energy" },
    { bus = "chassis_flex_energy",key = "ngp_hub_chassis_flex" },
    { bus = "damage_total",       key = "ngp_hub_damage_total" },
    { bus = "condition_total",    key = "ngp_hub_condition_total" },
    { bus = "virtual_yaw",        key = "ngp_hub_virtual_yaw" },
    { bus = "virtual_pitch",      key = "ngp_hub_virtual_pitch" },
    { bus = "virtual_roll",       key = "ngp_hub_virtual_roll" },
    { bus = "drive_torque",       key = "ngp_hub_drive_torque" },
    { bus = "diff_input_torque_nm",key = "ngp_hub_diff_input_torque_nm" },
    { bus = "shaft_twist",        key = "ngp_hub_shaft_twist" },
    { bus = "shaft_velocity",     key = "ngp_hub_shaft_velocity" },
    { bus = "drive_lash",         key = "ngp_hub_drive_lash" },
    { bus = "shift_shock",        key = "ngp_hub_shift_shock" },
    { bus = "windup",             key = "ngp_hub_windup" },
    { bus = "windup_energy",      key = "ngp_hub_windup_energy" },
    { bus = "windup_release",     key = "ngp_hub_windup_release" },
    { bus = "soft_torque",        key = "ngp_hub_soft_torque" },
    { bus = "rear_push",          key = "ngp_hub_rear_push" },
    { bus = "drive_yaw_hint",     key = "ngp_hub_drive_yaw_hint" },
    { bus = "lsd_lock",           key = "ngp_hub_lsd_lock" },
    { bus = "lsd_diff",           key = "ngp_hub_lsd_diff" },
    { bus = "lsd_heat",           key = "ngp_hub_lsd_heat" },
    { bus = "lsd_target",         key = "ngp_hub_lsd_target" },
    { bus = "lsd_input_torque_nm",key = "ngp_hub_lsd_input_torque_nm" },
    { bus = "lsd_lock_torque_nm", key = "ngp_hub_lsd_lock_torque_nm" },
    { bus = "diff_power",         key = "ngp_hub_diff_power" },
    { bus = "diff_coast",         key = "ngp_hub_diff_coast" },
    { bus = "diff_preload",       key = "ngp_hub_diff_preload" },
    { bus = "diff_forceL",        key = "ngp_hub_diff_forceL" },
    { bus = "diff_forceR",        key = "ngp_hub_diff_forceR" },
    { bus = "diff_mode",          key = "ngp_hub_diff_mode" },
    { bus = "load_path_avg_work", key = "ngp_hub_load_path_avg_work" },
    { bus = "load_path_avg_efficiency", key = "ngp_hub_load_path_avg_efficiency" },
    { bus = "load_path_avg_integrity",  key = "ngp_hub_load_path_avg_integrity" },
    { bus = "load_path_avg_loss", key = "ngp_hub_load_path_avg_loss" },
    { bus = "load_path_dominant", key = "ngp_hub_load_path_dominant" },
    { bus = "preserve_avg",       key = "ngp_hub_preserve_avg" },
    { bus = "front_axis_anchor",  key = "ngp_hub_front_axis_anchor" },
    { bus = "front_axis_authority", key = "ngp_hub_front_axis_authority" },
    { bus = "front_axis_yaw_resist",  key = "ngp_hub_front_axis_yaw_resist" },
    { bus = "front_axis_steer_weight",key = "ngp_hub_front_axis_steer_weight" },
    { bus = "front_axis_slip_damp",   key = "ngp_hub_front_axis_slip_damp" },
}

local WHEEL_LEGACY = {
    { bus = "load",              key = "ngp_hub_load_" },
    { bus = "sprung_load",       key = "ngp_hub_wheel_load_" },
    { bus = "dlt_load",          key = "ngp_hub_dlt_" },
    { bus = "load_ratio",        key = "ngp_hub_ratio_" },
    { bus = "slipRatio",         key = "ngp_hub_slipR_" },
    { bus = "slipAngle",         key = "ngp_hub_slipA_" },
    { bus = "omega",             key = "ngp_hub_omega_" },
    { bus = "tire_force_lat",    key = "ngp_hub_force_lat_" },
    { bus = "tire_force_long",   key = "ngp_hub_force_long_" },
    { bus = "tire_force_road",   key = "ngp_hub_force_road_" },
    { bus = "contact_quality",   key = "ngp_hub_contact_quality_" },
    { bus = "contact_trust",     key = "ngp_hub_contact_trust_" },
    { bus = "contact_loss",      key = "ngp_hub_contact_loss_" },
    { bus = "susp_force",        key = "ngp_hub_susp_force_" },
    { bus = "susp_scale",        key = "ngp_hub_susp_scale_" },
    { bus = "damper_force",      key = "ngp_hub_damper_force_" },
    { bus = "damper_velocity",   key = "ngp_hub_damper_velocity_" },
    { bus = "brake_lock",        key = "ngp_hub_brake_lock_" },
    { bus = "brake_temp",        key = "ngp_hub_brake_temp_" },
    { bus = "load_path_work",    key = "ngp_hub_load_path_work_" },
    { bus = "load_path_efficiency", key = "ngp_hub_load_path_efficiency_" },
    { bus = "load_path_loss",    key = "ngp_hub_load_path_loss_" },
}

function M.init()
    lastStore = {}
end

function M.update(dt)
    -- Global keys
    for _, map in ipairs(LEGACY_MAP) do
        local v = bus.get(map.bus, nil)
        if v ~= nil then
            utils.storeInterval(lastStore, map.key, v, INTERVAL)
        end
    end

    -- Wheel keys
    for i = 0, 3 do
        for _, map in ipairs(WHEEL_LEGACY) do
            local v = bus.getWheel(i, map.bus, nil)
            if v ~= nil then
                utils.storeInterval(lastStore, map.key .. i, v, INTERVAL)
            end
        end
    end

    -- Status keys
    utils.storeInterval(lastStore, "ngp_hub_status", "RUNNING", INTERVAL)
    utils.storeInterval(lastStore, "ngp_hub_alive", 1, INTERVAL)
end

return M
