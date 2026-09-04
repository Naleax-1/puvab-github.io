---@diagnostic disable: undefined-global
local M = {}

local utils = require("Core.utils")
local bus = require("Core.result_bus")
local loader = require("Engine.loader")

local P = {
    wheelLoadRef = 3500.0,
    loadRatioMin = 0.30,
    loadRatioMax = 2.70,
    transferGain = 0.8,
    pitchGain = 0.5,
    rollGain = 0.4,
}

local W = {}
for i=0,3 do W[i] = { load = 3500, dlt = 0, ratio = 1.0, sprungLoad = 3500 } end

function M.init()
    local def = loader.getParams("load_transfer")
    if def then for k,v in pairs(def) do if P[k]~=nil and type(v)=="number" then P[k]=v end end end
end

function M.update(dt, car)
    local gas = bus.get("gas", 0)
    local brake = bus.get("brake", 0)
    local steer = bus.get("steer", 0)
    local speed = bus.get("speedKmh", 0)

    for i=0,3 do
        local base = bus.getWheel(i, "load", P.wheelLoadRef)
        local isFront = (i < 2) and 1 or 0
        local isLeft = (i % 2 == 0) and 1 or 0

        local pitch = (gas * P.pitchGain - brake * P.pitchGain * 1.2) * (isFront == 1 and -1 or 1)
        local roll = math.abs(steer) * P.rollGain * speed * 0.01 * (isLeft == 1 and -1 or 1)
        local dlt = pitch * P.wheelLoadRef * 0.1 + roll * P.wheelLoadRef * 0.05

        W[i].dlt = utils.lowPass(W[i].dlt, dlt, dt, 0.06)
        W[i].sprungLoad = utils.clamp(base + W[i].dlt, 100, 12000)
        W[i].ratio = utils.clamp(W[i].sprungLoad / math.max(base, 1), P.loadRatioMin, P.loadRatioMax)

        bus.setWheel(i, "dlt_load", W[i].dlt)
        bus.setWheel(i, "sprung_load", W[i].sprungLoad)
        bus.setWheel(i, "load_ratio", W[i].ratio)
    end

    bus.set("load_transfer_status", "RUNNING")
end

return M
