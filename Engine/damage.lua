---@diagnostic disable: undefined-global
local M = {}

local utils = require("Core.utils")
local bus = require("Core.result_bus")

function M.init() end

function M.update(dt, car)
    local total = 0
    for i=0,3 do
        local hop = bus.getWheel(i, "hop_shock", 0)
        total = total + hop
    end
    local damage = utils.clamp(total * 0.1, 0, 1)
    local condition = 1.0 - damage

    bus.set("damage_total", damage)
    bus.set("condition_total", condition)
    bus.set("damage_status", "RUNNING")
end

return M
