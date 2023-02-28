--[[
	The Reactor Class
	API for monitoring the fission core and performing a shutdown if necessary
	]]--

os.loadAPI("./class.lua")

local HEALTH = {
	OFFLINE = 0, -- Reactor isn't even running
	GOOD = 1, -- Reactor is running well under tolerance
	BAD = 3, -- Reactor has breached tolerance
	CRITICAL = 4 -- Reactor is beyond limits, SCRAM
}

Reactor = class()

function Reactor:init(cfg)
	
	self.cfg = cfg
	self.peripheral = Reactor.getReactor(cfg)
	self.update()
	return self
end

function Reactor:update()
		self.status = peripheral.getStatus()
		self.burn_rate = peripheral.getBurnRate()
		self.max_burn_rate = peripheral.getBurnRate()
		self.temp = peripheral.getTemperature()
		self.damage = peripheral.getDamagePercent()
		self.coolant = peripheral.getCoolantFilledPercentage()
		self.waste = peripheral.getWasteFilledPercentage()
end

function Reactor:status_message()
	local status_msg = ""
	if self.status then status_msg = "on" else status_msg = "off" end
	local msg_text = string.format(
		"Reactor %s burn:%f/%f temp:%f dmg:%f coolant:%f waste:%f", 
		status_msg, 
		self.burn_rate, 
		self.max_burn_rate, 
		self.temp, 
		self.damage, 
		self.coolant, 
		self.waste
		)
	local color = "white"
	if self.health()==HEALTH.GOOD then 
		color = "green"
	elseif self.health()==HEALTH.OKAY then
		color = "blue"
	elseif self.health()==HEALTH.BAD then
		color = "yellow"
	elseif self.health()==HEALTH.DANGER then
		color = "red"
	local message = {
		{text=msg_text, color=color}
	}
	return textutils.serialiseJSON(message)
end

function Reactor:too_hot()
	return self.temp > self.cfg.max_temp
end

function Reactor:hot()
	return self.temp > (self.cfg.max_temp - self.cfg.temp_tolerance)


function Reactor:coolant_leak()
	return self.coolant < self.cfg.min_coolant
end

function Reactor:coolant_low()
	return self.coolant < (self.cfg.min_coolant + self.cfg.coolant_tolerance)
end

function Reactor:too_damaged()
	return self.damage > self.cfg.max_damage
end

function Reactor:damaged()
	return self.damage > (self.cfg.max_damage - self.cfg.damage_tolerance)
end

function Reactor:too_much_waste()
	return self.waste > self.cfg.max_waste
end

function Reactor:waste_building_up()
	return self.waste > (self.cfg.max_waste - self.cfg.waste_tolerance)
end


function Reactor.health()
	--[[
	This function returns a health enum based on reactor health
	]]--

	self.update()

	if self.status == false then
		return HEALTH.OFFLINE
	end

	--cfg specifies tolerance bands and max values for temp, waste, damage and coolant
	--if all values below tolerance -> Good
	--if one value within tolerance -> Okay
	--if one value within half-tolerance -> Bad
	--if one value beyond max -> Critical

	if self.too_hot() or self.coolant_leak() or self.too_damaged() or self.waste_full() then
		return HEALTH.CRITICAL
	end

	if self.hot() or self.coolant_low() or self.damaged() or self.waste_building_up()
		return HEALTH.BAD
	end

	return HEALTH.GOOD
end

function Reactor.shutdown()
	self.peripheral.scram()
end

function Reactor.start()
	self.peripheral.activate()
end