--[[
This is the fission monitoring script

Its split into constants, helpers, models, views, tests, and then execution code.

]]--


--[[CONSTANTS]]--

local REACTOR_STATES = {
	OFFLINE = "white",
	ONLINE = "green",
	WARNING = "yellow",
	DANGER = "red",
}

local TURBINE_STATES = {GOOD = "green",	BAD = "red",}

--[[HELPERS]]--

-- class.lua
-- Compatible with Lua 5.1 (not 5.0).
-- Stolen from http://lua-users.org/wiki/SimpleLuaClasses
function class(base_cls, init_fn)
   local cls = {}    -- a new class instance
   if not init_fn and type(base_cls) == 'function' then
      init_fn = base_cls
      base_cls = nil
   elseif type(base_cls) == 'table' then
      for key,value in pairs(base_cls) do
         cls[key] = value
      end
      cls._base = base_cls
   end
   cls.__index = cls

   local metatable = {}
   metatable.__call = function(class_tbl, ...)
	   local obj = {}
	   setmetatable(obj,c)
	   if class_tbl.init then
	      class_tbl.init(obj,...)
	   else 
	      if base_cls and base_cls.init then
	      	base_cls.init(obj, ...)
	      end
	   end
	   return obj
   end
   cls.init = init_fn
   setmetatable(cls, metatable)
   return cls
end

--[[MODELS]]--

--[[Mekanism Peripheral Model
Base class which exposes shared methods such as getPeripheral
]]--

MekPeripheral = class()

function MekPeripheral:init(dingus, cfg)
	self.limits = cfg.limits
	self.tolerances = cfg.tolerances
	self.peripheral = dingus
	self.update()
	return self
end

function MekPeripheral:update()
	error("update not implemented")
end

function MekPeripheral:status_message()
	error("status_message not implemented")
end

function MekPeripheral:breach_limit(metric, high_is_bad)
	high_is_bad = high_is_bad or true
	return (self.metrics[metric] < self.limits[metric]) * high_is_bad
end

function MekPeripheral:approach_limit(metric)
	return math.abs(self.limits[metric] - self.metrics[metric]) < self.tolerances[metric]
end


--[[Reactor Model

This is the model class for working with the reactor as a peripheral, it provides a start-stop api and exposes functions to
monitor the health and feed back the monitor state.
]]--

Reactor = class(MekPeripheral)

function Reactor:update()
	-- Sets the reactor specific data available from the Reactor api
		self.status = peripheral.getStatus()
		self.max_burn_rate = peripheral.getBurnRate()
		self.metrics = {
			"burn_rate"=self.peripheral.get_BurnRate(),
			"temp"=self.peripheral.getTemperature(),
			"damage"=self.peripheral.getDamagePercent(),
			"coolant"=self.peripheral.getCoolantFilledPercentage(),
			"waste"=self.peripheral.getWasteFilledPercentage()
		}
end

function Reactor:status_message()
	-- Delivers a one line formatted json message string
	local status_msg = ""
	if self.status then status_msg = "on" else status_msg = "off" end
	local msg_text = string.format(
		"Reactor %s burn:%f/%f mb/t temp:%fk dmg:%f%% coolant:%f%% waste:%f%%", 
		status_msg, 
		self.metrics["burn_rate"], 
		self.max_burn_rate, 
		self.metrics["temperature"], 
		self.metrics["damage"], 
		self.metrics["coolant"], 
		self.metrics["waste"]
		)
	local message = {
		{text=msg_text, color=self.health()}
	}
	return textutils.serialiseJSON(message)
end

function Reactor:health()
	--[[This function returns a health enum based on reactor health]]--
	if self.status == false then return REACTOR_STATES.OFFLINE end
	local health_metrics = {
		"temperature"=true,
		"coolant"=false,
		"damage"=true,
		"waste"=true,
	}
	local poor_health = false
	for metric, high_is_bad in pairs(health_metrics) do
		if self.breach_limit(metric, high_is_bad) then return REACTOR_STATES.CRITICAL end
		poor_health = poor_health or self.approach_limit(metric)
	end
	if poor_health return REACTOR_STATES.BAD else return REACTOR_STATES.GOOD end
end

function Reactor:shutdown()
	self.peripheral.scram()
end

function Reactor:start()
	self.peripheral.activate()
end


--[[TURBINE MODEL]]--

local Turbine = class(MekPeripheral)

function Turbine:update()
end

function Turbine:health()
	--[[This function returns a health enum based on turbine state.]]--
	if self.breach_limit("stored_power_percentage") then 
		return TURBINE_STATES.BAD 
	else
		return TURBINE_STATES.GOOD
	end
end

function Turbine:status_message()
	local msg_text = string.format(
		"Turbine: %f%% internal power storage used.", self.metrics["stored_power_percentage"])
	local message = {{text=msg_text, color=self.health()}}
	return textutils.serialiseJSON(message)
end

--[[VIEWS]]--

--[[TESTS]]--

