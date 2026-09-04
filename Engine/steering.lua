---@diagnostic disable: undefined-global
local M = {}

local utils = require("Core.utils")
local bus = require("Core.result_bus")

function M.init() end

function M.update(dt, car)
    local steer = bus.get("steer", 0)
    local speed = bus.get("speedKmh", 0)
    local yawRate = bus.get("yawRate", 0)

    local steerDamping = utils.clamp(1.0 - speed * 0.003, 0.2, 1.0)
    local steerWeight = steer * (1.0 + bus.get("body_steer", 0))
    local yawDemand = steer * speed * 0.01

    bus.set("steer_damping", steerDamping)
    bus.set("steer_weight", steerWeight)
    bus.set("yaw_steer_demand", yawDemand)
    bus.set("steering_status", "RUNNING")
end

return M
