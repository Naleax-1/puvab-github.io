---@diagnostic disable: undefined-global
local M = {}

local utils = require("Core.utils")
local loader = require("Engine.loader")

local P = {
    defaultFinalRatio = 4.10,
    defaultGearRatio1 = 3.20,
    defaultGearRatio2 = 2.10,
    defaultGearRatio3 = 1.50,
    defaultGearRatio4 = 1.15,
    defaultGearRatio5 = 0.90,
    defaultGearRatio6 = 0.75,
    minGearRatioAbs = 0.001,
}

local state = {
    finalRatio = 4.10,
    gearRatios = {},
    drivetrainType = "UNKNOWN",
    configLoaded = false,
}

function M.init()
    local def = loader.getParams("drivetrain")
    if def then for k,v in pairs(def) do if P[k]~=nil and type(v)=="number" then P[k]=v end end end
    state.finalRatio = P.defaultFinalRatio
    for g=1,6 do state.gearRatios[g] = P["defaultGearRatio"..g] end
    state.gearRatios[-1] = -P.defaultGearRatio1
end

function M.getRatio(gear)
    gear = math.floor(utils.num(gear, 0))
    if gear == 0 then return 0.0 end
    local r = state.gearRatios[gear]
    if r and math.abs(r) > P.minGearRatioAbs then return r end
    if gear == 1 then return P.defaultGearRatio1 end
    if gear == 2 then return P.defaultGearRatio2 end
    if gear == 3 then return P.defaultGearRatio3 end
    if gear == 4 then return P.defaultGearRatio4 end
    if gear == 5 then return P.defaultGearRatio5 end
    if gear == 6 then return P.defaultGearRatio6 end
    if gear < 0 then return -P.defaultGearRatio1 end
    return 0.0
end

function M.getFinalRatio()
    return state.finalRatio
end

return M
