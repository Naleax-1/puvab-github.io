---@diagnostic disable: undefined-global
local M = {}

local utils = require("Core.utils")
local bus = require("Core.result_bus")
local loader = require("Engine.loader")

local P = {
    fadeGain = 0.003,
    fadeDecay = 0.001,
    lockThreshold = 0.85,
    tempAmbient = 25.0,
    tempGain = 0.5,
    tempCool = 0.02,
    minDt = 0.0001,
    maxDt = 0.050,
}

local W = {}
for i=0,3 do W[i] = { temp = 25.0, fade = 0.0, lock = 0.0, rootHeat = 0.0 } end

local state = { status = "INIT", updateCount = 0 }

function M.init()
    local def = loader.getParams("brake")
    if def then for k,v in pairs(def) do if P[k]~=nil and type(v)=="number" then P[k]=v end end end
    state.status = "READY"
end

function M.update(dt, car)
    dt = utils.clamp(utils.num(dt,0.001), P.minDt, P.maxDt)
    state.updateCount = state.updateCount + 1
    local brakeInput = bus.get("brake", 0)
    local speed = bus.get("speedKmh", 0)

    for i=0,3 do
        local w = W[i]
        local slipR = math.abs(bus.getWheel(i, "slipRatio", 0))
        local loadRaw = bus.getWheel(i, "load", 0)

        -- Temperature
        w.temp = w.temp + (brakeInput * P.tempGain * loadRaw * 0.0001 - (w.temp - P.tempAmbient) * P.tempCool) * dt

        -- Fade
        local fadeTarget = utils.clamp((w.temp - 100.0) * 0.01, 0, 0.5)
        w.fade = utils.lowPass(w.fade, fadeTarget, dt, 0.5)

        -- Lock
        local lockTarget = (slipR > P.lockThreshold and brakeInput > 0.1) and 1.0 or 0.0
        w.lock = utils.lowPass(w.lock, lockTarget, dt, 0.03)

        w.rootHeat = w.fade * 0.5 + (w.temp - P.tempAmbient) * 0.01

        bus.setWheel(i, "brake_temp", w.temp)
        bus.setWheel(i, "brake_fade", w.fade)
        bus.setWheel(i, "brake_lock", w.lock)
        bus.setWheel(i, "brake_root_heat", w.rootHeat)
    end

    bus.set("brake_status", "RUNNING")
    bus.set("brake_update_count", state.updateCount)
end

return M
