---@diagnostic disable: undefined-global
--============================================================
-- Observer/observer.lua
-- ACNextGen V2.0 Read-Only Observer
-- Reads from Result Bus ONLY. No physics calculation.
--============================================================
local M = {}

local bus = require("Core.result_bus")

function M.init()
    if ac and ac.log then ac.log("[ACNextGen] Observer v2.0 Ready") end
end

local function textKV(label, value, fmt)
    if fmt then
        ui.text(string.format("%-26s : " .. fmt, tostring(label), value))
    else
        ui.text(string.format("%-26s : %s", tostring(label), tostring(value)))
    end
end

local WHEEL_NAMES = { [0]="FL",[1]="FR",[2]="RL",[3]="RR" }

function M.drawUI(runtime, executionOrder, profile)
    local car = ac.getCar(0)
    if not car then
        ui.text("Vehicle not found")
        return
    end

    ui.text("=== ACNextGen Observer v2.0 ===")
    ui.separator()

    -- Core
    textKV("Speed", bus.get("speedKmh",0), "%.1f km/h")
    textKV("RPM", bus.get("rpm_filtered",0), "%.0f")
    textKV("Gear", bus.get("gear",0), "%d")
    textKV("Steer", bus.get("steer",0), "%.3f")
    textKV("Gas", bus.get("gas",0), "%.3f")
    textKV("Brake", bus.get("brake",0), "%.3f")
    textKV("Clutch", bus.get("clutch",1), "%.3f")

    ui.separator()
    ui.text("=== ENGINE / DRIVETRAIN ===")
    textKV("Engine Torque Nm", bus.get("engine_torque_nm",0), "%.1f")
    textKV("Gearbox Out Nm", bus.get("gearbox_output_torque_nm",0), "%.1f")
    textKV("Drive Torque", bus.get("drive_torque",0), "%.3f")
    textKV("Diff Lock", bus.get("lsd_lock",0), "%.2f")
    textKV("Shaft Twist", bus.get("shaft_twist",0), "%.3f")
    textKV("Shift Shock", bus.get("shift_shock",0), "%.3f")

    ui.separator()
    ui.text("=== CHASSIS ===")
    textKV("Body Rigidity", bus.get("body_rigidity",1), "%.3f")
    textKV("Chassis Energy", bus.get("chassis_energy",0), "%.3f")
    textKV("Flex Energy", bus.get("chassis_flex_energy",0), "%.3f")
    textKV("Roll Angle", bus.get("roll_angle",0), "%.3f")
    textKV("Pitch Angle", bus.get("pitch_angle",0), "%.3f")
    textKV("Virtual Yaw", bus.get("virtual_yaw",0), "%.3f")

    ui.separator()
    ui.text("=== YAW / STEERING ===")
    textKV("Yaw Rate", bus.get("yawRate",0), "%.5f")
    textKV("Yaw Budget", bus.get("yaw_budget",0), "%+.3f")
    textKV("Spin Risk", bus.get("yaw_spin_risk",0), "%.3f")
    textKV("Steer Weight", bus.get("steer_weight",0), "%.3f")

    ui.separator()
    ui.text("=== WHEELS ===")
    for i=0,3 do
        ui.text(string.format(
            "%s Load %.0f / dLT %+.0f / CQ %.2f / SlipR %.3f / SlipA %.3f / Lat %.1f / Long %.1f",
            WHEEL_NAMES[i],
            bus.getWheel(i,"load",0),
            bus.getWheel(i,"dlt_load",0),
            bus.getWheel(i,"contact_quality",1),
            bus.getWheel(i,"slipRatio",0),
            bus.getWheel(i,"slipAngle",0),
            bus.getWheel(i,"tire_force_lat",0),
            bus.getWheel(i,"tire_force_long",0)
        ))
    end

    ui.separator()
    ui.text("=== RUNTIME ===")
    textKV("Frame", runtime.frame or 0, "%d")
    textKV("Errors", runtime.totalErrorCount or 0, "%d")
    if runtime.lastError and runtime.lastError ~= "" then
        ui.text("Last Error: " .. tostring(runtime.lastError))
    end

    ui.separator()
    ui.text("=== PROFILER ===")
    if profile then
        textKV("Worst Ever", profile.worstEverName or "none", "%s")
        textKV("Worst Ever ms", profile.worstEverMs or 0, "%.3f")
    end
end

return M
