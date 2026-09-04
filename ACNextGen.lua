---@diagnostic disable: undefined-global
--============================================================
-- ACNextGen.lua
-- ACNextGen V2.0 Modular Architecture
-- Host / Orchestrator
--============================================================

local APP_NAME = "ACNextGen"
local VERSION  = "V2.0.0 Modular JSON Architecture"

-- Core
local utils = require("Core.utils")
local bus = require("Core.result_bus")
local loader = require("Engine.loader")

-- Engines
local tireEngine = require("Engine.tire")
local suspensionEngine = require("Engine.suspension")
local chassisEngine = require("Engine.chassis")
local drivetrainEngine = require("Engine.drivetrain")
local brakeEngine = require("Engine.brake")
local thermalEngine = require("Engine.thermal")
local loadTransferEngine = require("Engine.load_transfer")
local steeringEngine = require("Engine.steering")
local damageEngine = require("Engine.damage")
local yawMomentEngine = require("Engine.yaw_moment")

-- Car Engine
local carEngine = require("Car_Engine.engine")

-- Output / Observation
local sendPhysics = require("Send.physics")
local observer = require("Observer.observer")

--============================================================
-- Execution Order (preserved from legacy dependency analysis)
--============================================================
local executionOrder = {
    { name = "car_engine",      module = carEngine,      hz = 60 },
    { name = "load_transfer",   module = loadTransferEngine, hz = 60 },
    { name = "suspension",      module = suspensionEngine,   hz = 60 },
    { name = "tire",            module = tireEngine,         hz = 60 },
    { name = "brake",           module = brakeEngine,        hz = 60 },
    { name = "drivetrain",      module = drivetrainEngine,    hz = 60 },
    { name = "chassis",         module = chassisEngine,       hz = 30 },
    { name = "thermal",         module = thermalEngine,       hz = 10 },
    { name = "steering",        module = steeringEngine,      hz = 30 },
    { name = "damage",          module = damageEngine,        hz = 10 },
    { name = "yaw_moment",      module = yawMomentEngine,     hz = 60 },
}

--============================================================
-- Runtime state
--============================================================
local runtime = {
    frame = 0,
    time = 0.0,
    initialized = false,
    carOK = false,
    wheelsOK = false,
    activeErrorCount = 0,
    totalErrorCount = 0,
    lastError = "",
    moduleStatus = {},
    moduleErrors = {},
}

local timers = {}
for _, e in ipairs(executionOrder) do
    timers[e.name] = {
        accumulator = 0.0,
        interval = 1.0 / e.hz,
        error = "",
        lastStatus = "INIT",
        updateCount = 0,
    }
end

local profile = {
    worstEverName = "none",
    worstEverMs = 0.0,
    maxMs = {},
    lastMs = {},
    avgMs = {},
    count = {},
}

--============================================================
-- Helpers
--============================================================
local function num(v, fallback)
    local n = tonumber(v)
    if n == nil or n ~= n then return fallback or 0.0 end
    return n
end

local function safeClock()
    if os and os.clock then
        local ok, value = pcall(os.clock)
        if ok and value then return value end
    end
    return 0.0
end

local function safeGetCar()
    if not ac or not ac.getCar then return nil end
    local ok, car = pcall(ac.getCar, 0)
    if ok then return car end
    return nil
end

local function hasWheels(car)
    if not car then return false end
    local ok, wheels = pcall(function() return car.wheels end)
    return ok and wheels ~= nil
end

local function log(msg)
    if ac and ac.log then pcall(ac.log, "[" .. APP_NAME .. "] " .. tostring(msg)) end
end

local function shortError(value)
    local s = tostring(value or "")
    s = s:gsub("\\", "/")
    local fileLine = s:match("([^/]+%.lua:%d+.*)$")
    if fileLine then return fileLine end
    if #s > 160 then return s:sub(1, 157) .. "..." end
    return s
end

--============================================================
-- Profile
--============================================================
local function updateProfile(name, elapsedMs)
    profile.lastMs[name] = elapsedMs
    profile.maxMs[name] = math.max(profile.maxMs[name] or 0.0, elapsedMs)
    profile.count[name] = (profile.count[name] or 0) + 1
    local oldAvg = profile.avgMs[name] or elapsedMs
    profile.avgMs[name] = oldAvg + (elapsedMs - oldAvg) * 0.05
end

--============================================================
-- Engine execution
--============================================================
local function safeUpdate(entry, dt, car, profileNow)
    local timer = timers[entry.name]
    if not timer then return end

    timer.accumulator = timer.accumulator + dt
    if timer.accumulator + 0.000001 < timer.interval then
        return
    end

    local updateDt = math.min(timer.accumulator, 0.050)
    timer.accumulator = timer.accumulator - timer.interval
    if timer.accumulator > timer.interval * 2.0 then
        timer.accumulator = timer.interval
    elseif timer.accumulator < 0.0 then
        timer.accumulator = 0.0
    end

    local ok, err
    local elapsedMs = 0.0

    if profileNow then
        local t0 = safeClock()
        ok, err = pcall(entry.module.update, updateDt, car)
        elapsedMs = (safeClock() - t0) * 1000.0
        updateProfile(entry.name, elapsedMs)
    else
        ok, err = pcall(entry.module.update, updateDt, car)
    end

    if ok then
        timer.lastStatus = "OK"
        timer.error = ""
        timer.updateCount = timer.updateCount + 1
        runtime.moduleStatus[entry.name] = "OK"
        runtime.moduleErrors[entry.name] = ""
    else
        timer.lastStatus = "ERROR"
        timer.error = tostring(err)
        runtime.moduleStatus[entry.name] = "ERROR"
        runtime.moduleErrors[entry.name] = tostring(err)
        runtime.totalErrorCount = runtime.totalErrorCount + 1
        runtime.lastError = entry.name .. ": " .. shortError(err)
        log(runtime.lastError)
    end
end

--============================================================
-- Init
--============================================================
local function initAll()
    log(VERSION .. " initializing...")

    bus.clear()

    local loadedDefs = loader.loadAll()
    log("Definitions cached: " .. tostring(loadedDefs))

    for _, e in ipairs(executionOrder) do
        local ok, err = pcall(e.module.init)
        if not ok then
            log("INIT ERROR " .. e.name .. ": " .. shortError(err))
            timers[e.name].lastStatus = "INIT ERROR"
            timers[e.name].error = tostring(err)
        else
            timers[e.name].lastStatus = "READY"
        end
    end

    observer.init()
    sendPhysics.init()

    runtime.initialized = true
    log(VERSION .. " initialized")
end

--============================================================
-- Main update
--============================================================
function update(dt)
    dt = num(dt, 0.0)
    if dt <= 0.0 then dt = 0.001 end

    runtime.frame = runtime.frame + 1
    runtime.time = runtime.time + dt

    local car = safeGetCar()
    runtime.carOK = car ~= nil
    runtime.wheelsOK = hasWheels(car)

    -- Set root car state into Result Bus
    bus.setCarState(car)

    -- Execute engines in order
    local profileNow = (runtime.frame % 30 == 0)  -- sample every 30 frames (~0.5s)

    for _, e in ipairs(executionOrder) do
        safeUpdate(e, dt, car, profileNow)
    end

    -- Publish Result Bus to AC store (throttled)
    sendPhysics.update(dt)

    -- GC step
    if runtime.frame % 60 == 0 and collectgarbage then
        pcall(collectgarbage, "step", 16)
    end
end

--============================================================
-- UI
--============================================================
function windowMain()
    local ok, err = pcall(observer.drawUI, runtime, executionOrder, profile)
    if not ok then
        if ui then
            ui.text("ACNextGen Observer Error")
            ui.text(shortError(err))
        end
    end
end

--============================================================
-- Boot
--============================================================
initAll()
