---@diagnostic disable: undefined-global
local M = {}

local utils = require("Core.utils")
local loader = require("Engine.loader")

local P = {
    fallbackPeakTorqueNm = 360.0,
    fallbackRedlineRpm = 7200.0,
    maxEngineTorqueNm = 1400.0,
}

function M.init()
    local def = loader.getParams("car_engine")
    if def then for k,v in pairs(def) do if P[k]~=nil and type(v)=="number" then P[k]=v end end end
end

function M.calculate(gas, rpm, gearRatio)
    gas = utils.clamp(utils.num(gas, 0), 0, 1)
    rpm = utils.num(rpm, 0)
    local redline = math.max(P.fallbackRedlineRpm, 1000)
    local x = utils.clamp(rpm / redline, 0, 1.25)
    local low = 0.42 + 0.58 * utils.clamp(x / 0.55, 0, 1)
    local highDrop = 1.0 - utils.clamp((x - 0.72) / 0.38, 0, 1) * 0.38
    local base = P.fallbackPeakTorqueNm * utils.clamp(low * highDrop, 0.30, 1.05)
    return utils.clamp(base * gas, 0, P.maxEngineTorqueNm)
end

return M
