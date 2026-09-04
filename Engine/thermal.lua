---@diagnostic disable: undefined-global
local M = {}

local utils = require("Core.utils")
local bus = require("Core.result_bus")

function M.init() end

function M.update(dt, car)
    -- Thermal is integrated into tire_thermal_brush and brake thermals.
    -- This engine aggregates global thermal state.
    local avgTemp = 0
    for i=0,3 do avgTemp = avgTemp + bus.getWheel(i, "brake_temp", 25) end
    avgTemp = avgTemp * 0.25
    bus.set("thermal_brake_avg", avgTemp)
    bus.set("thermal_status", "RUNNING")
end

return M
