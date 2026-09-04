---@diagnostic disable: undefined-global
local M = {}

local utils = require("Core.utils")
local bus = require("Core.result_bus")

function M.init() end

function M.update(dt, car)
    local yawRate = bus.get("yawRate", 0)
    local steer = bus.get("steer", 0)
    local speed = bus.get("speedKmh", 0)

    local demand = steer * speed * 0.005
    local response = yawRate * 10.0
    local budget = demand - response
    local understeer = utils.clamp(budget, 0, 1)
    local oversteer = utils.clamp(-budget, 0, 1)
    local spinRisk = oversteer * (1.0 - utils.clamp(speed * 0.01, 0, 1))

    bus.set("yaw_budget", budget)
    bus.set("yaw_balance", response)
    bus.set("yaw_understeer_energy", understeer)
    bus.set("yaw_oversteer_energy", oversteer)
    bus.set("yaw_spin_risk", spinRisk)
    bus.set("yaw_moment_status", "RUNNING")
end

return M
