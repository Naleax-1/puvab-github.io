---@diagnostic disable: undefined-global
--============================================================
-- Car_Engine/engine.lua
-- ACNextGen V2.0 Car Engine Host
-- Integrates: combustion, torque, rpm, gearbox, clutch
--============================================================
local M = {}

local utils = require("Core.utils")
local bus = require("Core.result_bus")
local loader = require("Engine.loader")

local combustion = require("Car_Engine.combustion")
local torque = require("Car_Engine.torque")
local rpm = require("Car_Engine.rpm")
local gearbox = require("Car_Engine.gearbox")
local clutch = require("Car_Engine.clutch")

local P = {
    rpmTau = 0.080,
    gearInertia = 0.120,
    clutchTau = 0.150,
    engineBrakeTorqueNm = 70.0,
    maxEngineTorqueNm = 1400.0,
    fallbackPeakTorqueNm = 360.0,
    fallbackRedlineRpm = 7200.0,
    normalizedTorqueReferenceNm = 1200.0,
    minDt = 0.0001,
    maxDt = 0.050,
}

local state = {
    status = "INIT",
    updateCount = 0,
    rawRPM = 0.0,
    filteredRPM = 0.0,
    gas = 0.0,
    brake = 0.0,
    clutchInput = 1.0,
    clutch = 1.0,
    gear = 0,
    engineTorqueNm = 0.0,
    engineBrakeTorqueNm = 0.0,
    clutchTorqueNm = 0.0,
    gearboxOutputTorqueNm = 0.0,
    normalizedTorque = 0.0,
}

function M.init()
    local def = loader.getParams("car_engine")
    if def then for k,v in pairs(def) do if P[k]~=nil and type(v)=="number" then P[k]=v end end end
    combustion.init()
    torque.init()
    rpm.init()
    gearbox.init()
    clutch.init()
    state.status = "READY"
end

function M.update(dt, car)
    dt = utils.clamp(utils.num(dt,0.001), P.minDt, P.maxDt)
    state.updateCount = state.updateCount + 1
    state.status = "RUNNING"

    if not car then
        state.filteredRPM = utils.lowPass(state.filteredRPM, 0, dt, 0.2)
        bus.set("engine_torque_nm", 0)
        bus.set("gearbox_output_torque_nm", 0)
        return
    end

    local input = {
        rpm = utils.carValue(car, "rpm", 0),
        gas = utils.clamp(utils.carValue(car, "gas", 0), 0, 1),
        brake = utils.clamp(utils.carValue(car, "brake", 0), 0, 1),
        clutch = utils.clamp(utils.carValue(car, "clutch", 1), 0, 1),
        gear = math.floor(utils.carValue(car, "gear", 0)),
    }

    state.rawRPM = input.rpm
    state.gas = input.gas
    state.brake = input.brake
    state.clutchInput = input.clutch
    state.gear = input.gear

    -- RPM filtering
    state.filteredRPM = utils.lowPass(state.filteredRPM, input.rpm, dt, P.rpmTau)

    -- Gearbox
    local gearRatio = gearbox.getRatio(input.gear)
    local finalRatio = gearbox.getFinalRatio()

    -- Combustion / Torque
    local baseTorque = torque.calculate(input.gas, state.filteredRPM, gearRatio)
    local engineBrake = 0.0
    if math.abs(input.gear) > 0 then
        local rpmRatio = utils.clamp(state.filteredRPM / math.max(P.fallbackRedlineRpm, 1000), 0, 1.2)
        engineBrake = P.engineBrakeTorqueNm * (0.35 + 0.65 * rpmRatio) * (1.0 - input.gas)
    end
    state.engineBrakeTorqueNm = engineBrake
    state.engineTorqueNm = utils.clamp(baseTorque - engineBrake, -P.maxEngineTorqueNm, P.maxEngineTorqueNm)

    -- Clutch
    state.clutch = utils.clamp(utils.lowPass(state.clutch, input.clutch, dt, P.clutchTau), 0, 1)
    local clutchCapacity = 520.0
    local clutchSlipLoss = utils.clamp(math.max(math.abs(state.engineTorqueNm) - clutchCapacity, 0) / clutchCapacity * 0.18, 0, 0.45)
    state.clutchTorqueNm = state.engineTorqueNm * state.clutch * (1.0 - clutchSlipLoss)

    -- Gearbox output
    state.gearboxOutputTorqueNm = state.clutchTorqueNm * gearRatio * finalRatio * P.drivelineEfficiency
    state.normalizedTorque = utils.clamp(state.gearboxOutputTorqueNm / math.max(P.normalizedTorqueReferenceNm, 1), -1, 1)

    -- Publish
    bus.set("rpm_raw", state.rawRPM)
    bus.set("rpm_filtered", state.filteredRPM)
    bus.set("gas", state.gas)
    bus.set("brake", state.brake)
    bus.set("clutch_input", state.clutchInput)
    bus.set("clutch", state.clutch)
    bus.set("gear", state.gear)
    bus.set("engine_torque_nm", state.engineTorqueNm)
    bus.set("engine_brake_torque_nm", state.engineBrakeTorqueNm)
    bus.set("clutch_torque_nm", state.clutchTorqueNm)
    bus.set("gearbox_output_torque_nm", state.gearboxOutputTorqueNm)
    bus.set("normalized_torque", state.normalizedTorque)
    bus.set("gear_ratio", gearRatio)
    bus.set("final_ratio", finalRatio)
    bus.set("car_engine_status", state.status)
    bus.set("car_engine_update_count", state.updateCount)
end

function M.getState()
    return state
end

return M
