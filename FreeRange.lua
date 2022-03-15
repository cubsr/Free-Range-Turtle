local whitelist = {"minecraft:iron_ore", "minecraft:gold_ore", "minecraft:coal", "minecraft:redstone", "minecraft:obsidian", "minecraft:flint", "minecraft:emerald", "minecraft:diamond", "appliedenergistics2:material", "computercraft:turtle_advanced"}
local modemPosition = "right" --basic version of peripherals update to modem position
local storage = {} --holds position of items
local storedCount = {} --hold count of items in
local openSlot = 4 --the first slot that can use items lowest value is 4
local depositChestSlot = 3 --slot that holds the chest to dump ores in
local fuelChestSlot = 2 --chest to get fuel out of
local currentlySearching = false --this is true if the turtle is checking the area for more ore
local operatingLevel = 12 --the level the turtle should operate at in case the turtle needs to move down
local homeArea = {327, operatingLevel, 1708} --the spot a turtle tries not to go to far from
local rebootCheck = false --checks if the turtle just restared
if arg[1] then
	if tostring(arg[1]) == "reboot" then
		rebootCheck = true
	end
end
	
local ErrorHandler
local Deposit
local FullDeposit
local TakeFullInventory
local PlaceChest
local SearchPattern
local CheckImmediate
local Dig
local Forward
local Direction
local CardinalDirection
local ReturnHome
local MoveHome
local SetDirection

--checks if the input item is whitelisted returns true/false
local function CheckWhiteList(itemName)
	local found = false
	for i = 1, #whitelist do
		if itemName == whitelist[i] then
			found = true
			return found
		end
	end
	return found
end

--handles moving items in inventory input is what item it is moving
local function TransferItem(itemName)
	local temp = turtle.getSelectedSlot()
	turtle.select(1)
	if not storage[itemName] then --enters if the item is not known in its inventory
		if openSlot >= 17 then --all slots are full
			FullDeposit(depositChestSlot)
		else
			storage[itemName] = openSlot 
			if not turtle.transferTo(openSlot) then
				ErrorHandler("TransferItem", itemName)
			else
				openSlot = openSlot + 1
			end
		end
	elseif not turtle.transferTo(storage[itemName]) then --for some reason the transfer didn't work
		if openSlot >= 17 then
			FullDeposit(depositChestSlot)
		else
			storage[itemName] = openSlot
			openSlot = openSlot + 1
			if not turtle.transferTo(storage[itemName]) then
				ErrorHandler("TransferItem", itemName)
			end
		end
	else --I think this is extra but I don't want to break anything right now
		local data = turtle.getItemDetail(1)
		if data then
			if openSlot >= 17 then
				FullDeposit(depositChestSlot)
			else
				storage[itemName] = openSlot
				openSlot = openSlot + 1
				if not turtle.transferTo(storage[itemName]) then
					ErrorHandler("TransferItem", itemName)
				end
			end
		end
	end
end

--places chest of currently slected slot
PlaceChest = function()
	if not turtle.placeDown() then
		turtle.down()
		if turtle.detectDown() then
			turtle.digDown()
			local data = turtle.getItemDetail(1)
			if data then
				local temp = turtle.getSelectedSlot()
				turtle.select(1)
				if CheckWhiteList(data.name) then
					TransferItem(data.name)
				else
					turtle.drop()
				end
				turtle.select(temp)				
			end
		end	
		PlaceChest()
	end
end

--moves up once space
local function Up()
	if not turtle.up() then
		local gravelTest = false
		repeat
			if turtle.detectUp() then
				turtle.digUp()
				local data = turtle.getItemDetail(1)
				if data then
					local temp = turtle.getSelectedSlot()
					turtle.select(1)
					if CheckWhiteList(data.name) then
						TransferItem(data.name)
					else
						turtle.drop()
					end
				end
				turtle.select(temp)				
			else
				turtle.up()
				gravelTest = true
			end
		until gravelTest == true
	end
end

--checks how many slots are used not counting input slot and chest slots
local function CheckSlotsUsed()
	local amount = 0
	for i = 4, 16 do
		local data = turtle.getItemDetail(i)
		if data then
			amount = amount + 1
		end
	end
	return amount
end

--sends a message needs to be updated to not an open broadcast
local function SendMessage(message)
	rednet.open(modemPosition)
	rednet.broadcast(message)
	rednet.close(modemPosition)
end

--shifts inventory down one I think this causes inventory errors
local function ShiftInventory(itemSlot)
	local temp = turtle.getSelectedSlot()
	local done = false
	local slot
	repeat
		if itemSlot + 1 < 17 then			
			if not turtle.getItemDetail(itemSlot) and turtle.getItemDetail(itemSlot + 1) then
				turtle.select(itemSlot + 1)
				turtle.transferTo(itemSlot)
				itemSlot = itemSlot + 1
			else
				done = true
			end
		else
			done = true
		end
	until done
	turtle.select(temp)
	print("Inventory Shifted")
	TakeFullInventory()
end

--checks what is happening in the inventory I decided to liberally call the error handler this could be more robust 
TakeFullInventory = function()
	local temp = turtle.getSelectedSlot()
	print("Taking Inventory")
	for i = 4, 16 do
		turtle.select(i)
		local data = turtle.getItemDetail(i)
		if data then
			if storage[data.name] then
				storedCount[data.name] =  turtle.getItemCount(i)
			elseif CheckWhiteList(data.name) then
				if i > openSlot or storage[data.name] < i then 
					ErrorHandler("TakeFullInventory", data.name)
				end
			else
				turtle.drop()
				ShiftInventory(i)
				openSlot = CheckSlotsUsed() + 4
			end
				
		end
	end
	turtle.select(temp)
end

--this was built to handle errors withou depositing but that resulted in many errorhandler calls so I decided to just deposit everything and report the problem
ErrorHandler = function(errorFunction, item)
	local message = "Inventory error encountered from " .. errorFunction .. " holding " .. item .. "\n"
	local expectedOpenSlot = CheckSlotsUsed() + 4
	if expectedOpenSlot > openSlot then
		message = message .. "More slots used than expected"
		FullDeposit(depositChestSlot)
	elseif expectedOpenSlot < openSlot then
		message = message .. "Less slots used than expected"
		FullDeposit(depositChestSlot)
	else
		message = message .. "Error called but expected amount of slots are used"
		FullDeposit(depositChestSlot)
	end	
	SendMessage(message)	
end

--put everything the turtle has into the deposit chest
FullDeposit = function(depositSlot)
	local temp = turtle.getSelectedSlot()
	turtle.select(depositSlot)
	PlaceChest()
	turtle.select(1)
	turtle.dropDown()
	for i = 4, 16 do
		turtle.select(i)
		turtle.dropDown()
	end
	turtle.select(depositSlot)
	turtle.digDown()
	turtle.select(temp)
	openSlot = 4
	storage = {}
	local x, y, z = gps.locate()
	if y < operatingLevel then
		for i = y, operatingLevel do
			Up()
		end
	end
	SendMessage("Full deposit done")
end

--casual deposit that inputs known slots
Deposit = function(depositSlot)
	local temp = turtle.getSelectedSlot()
	turtle.select(depositSlot)
	PlaceChest()
	if openSlot > 5 then
		PlaceChest()
		for i = 4, openSlot - 1 do
			turtle.select(i)
			turtle.dropDown()
		end
		openSlot = 4
	end
	turtle.select(depositSlot)
	turtle.digDown()
	turtle.select(temp)
	storage = {}
	local x, y, z = gps.locate()
	if y < operatingLevel then
		for i = y, operatingLevel do
			Up()
		end
	end
	SendMessage("Deposit done")
end

--digs up, down, and in front of it
CheckImmediate = function()
	Dig()
	DigDown()
	DigUp()
end

--check 3x3 area around where a whitelisted item is found
SearchPattern = function()
	currentlySearching = true
	turtle.turnLeft()
	CheckImmediate()
	Forward()
	for i = 1, 3 do
		turtle.turnRight()
		CheckImmediate()
		Forward()
		CheckImmediate()
		Forward()
	end
	turtle.turnRight()
	CheckImmediate()
	Forward()
	turtle.turnRight()
	Forward()
	CheckImmediate()
	Forward()
	currentlySearching = false
end
	
--checks fuel and fuels the turtle
local function Fueling(fuelSlot)
	if turtle.getFuelLevel() < 200 then
		local temp = turtle.getSelectedSlot()
		turtle.select(fuelSlot)
		PlaceChest()
		turtle.suckDown(1)
		turtle.refuel(1)
		turtle.dropDown(1)
		turtle.digDown()
		turtle.select(temp)
		local x, y, z = gps.locate()
		if y < operatingLevel then
			for i = y, operatingLevel do
				Up()
			end
		end
	end	
end

--checks if the turtle has everything it needs to start
local function Prepare()
	local greenlight = false
	local data1 = turtle.getItemDetail(fuelChestSlot)
	if data1 then
		if data1.name == "enderstorage:ender_storage" then
			greenlight = true
		else
			print("Fuel Chest not found in slot ", tostring(fuelChestSlot))			
		end
	else
		local exists, block = turtle.inspectDown()
		if exists then
			if block.name == "enderstorage:ender_storage" then
				local temp = turtle.getSelectedSlot()
				turtle.select(fuelChestSlot)
				turtle.digDown()
				local datatemp = turtle.getItemDetail(fuelChestSlot)
				if datatemp.name == "enderstorage:ender_storage" then
					greenlight = true
				end
				turtle.select(temp)
			else
				print("Fuel Chest not found in slot ", tostring(fuelChestSlot))
			end
		else
			print("Fuel Chest not found in slot ", tostring(fuelChestSlot))
		end
	end
	local data2 = turtle.getItemDetail(depositChestSlot)
	if data2 then
		if data2.name ~= "enderstorage:ender_storage" then
			print("Deposit Chest not found in slot ", tostring(fuelChestSlot))
			greenlight = false
		end
	else
		local exists, block = turtle.inspectDown()
		if exists then
			if block.name == "enderstorage:ender_storage" then
				local temp = turtle.getSelectedSlot()
				turtle.select(depositChestSlot)
				turtle.digDown()
				local datatemp = turtle.getItemDetail(depositChestSlot)
				if datatemp.name ~= "enderstorage:ender_storage" then
					greenlight = false
					print("Deposit Chest not found in slot ", tostring(depositChestSlot))
				end
				turtle.select(temp)
			else
				greenlight = false
				print("Deposit Chest not found in slot ", tostring(depositChestSlot))
			end
		else
			greenlight = false
			print("Deposit Chest not found in slot ", tostring(depositChestSlot))
		end
	end
	if greenlight then
		Fueling(fuelChestSlot)
		TakeFullInventory()
	end
	return greenlight
end

--dig forward one block and handle the item it mined
Dig = function()
	if turtle.detect() then
		turtle.dig()
		local data = turtle.getItemDetail(1)
		if data then
			if CheckWhiteList(data.name) then
				TransferItem(data.name)
				if not currentlySearching then
					SearchPattern()
				end
			else
				turtle.drop()
			end
		end
    end	
end

--dig down one block and handle the item it mined
DigDown = function()
	if turtle.detectDown() then
		turtle.digDown()
		local data = turtle.getItemDetail(1)
		if data then
			if CheckWhiteList(data.name) then
				TransferItem(data.name)
			else
				turtle.drop()
			end
		end
    end	
end

--dig down one block and handle the item it mined
DigUp = function()
	if turtle.detectUp() then
		turtle.digUp()
		local data = turtle.getItemDetail(1)
		if data then
			if CheckWhiteList(data.name) then
				TransferItem(data.name)
			else
				turtle.drop()
			end
		end
    end	
end

--move forward 1 blocks
Forward = function()
	if not turtle.forward() then
		local gravelTest = false
		repeat
			if turtle.detect() then
				turtle.dig()
				local data = turtle.getItemDetail(1)
				if data then
					if CheckWhiteList(data.name) then
						TransferItem(data.name)
						if not currentlySearching then
							SearchPattern()
						end
					else
						turtle.drop()
					end
				end				
			else
				turtle.forward()
				gravelTest = true
			end
		until gravelTest == true
	end
end

--move forward variable blocks
local function ForwardVariable(length)
	if length > 0 then
		local i = 0
		repeat 				
			Dig()
			Forward()
			i = i + 1
		until i == length
	end
end

--returns its current position
Direction = function()
	currentlySearching = true
	local compass = -1
	local x1, y1, z1 = gps.locate()
	Forward()
	local x2, y2, z2 = gps.locate()
	if x1 == x2 then
		if z1 < z2 then
			compass = 3
		else
			compass = 1
		end
	else
		if x1 < x2 then
			compass = 2
		else
			compass = 4
		end
	end 
	currentlySearching = false
	return compass, x2, y2, z2
end

--changes the direction from current to desired
SetDirection = function(currentDirection, desiredDirection)
	local spins = currentDirection - desiredDirection
	if spins == -3 or spins == 1 then
		turtle.turnLeft()
	elseif  spins == 3 or spins == -1 then
		turtle.turnRight()
	elseif spins ~= 0 then
		turtle.turnLeft()
		turtle.turnLeft()
	end
end

--gives dirction in words
CardinalDirection = function(compass)
	local direction
	if compass == 1 then
		direction = "north"
	elseif compass == 2 then
		direction = "east"
	elseif compass == 3 then
		direction = "south"
	elseif compass == 4 then
		direction = "west"
	else
		direction = "Unknown"
	end
	return direction
end

--check if it is too far from home
ReturnHome = function(x, z)
	local tooFar = false
	if homeArea[1] - x > 200 or homeArea[1] - x < -200 then
		tooFar = true
	elseif homeArea[3] - z > 200 or homeArea[3] - z < -200 then
		tooFar = true
	end
	return tooFar
end

--this actually moves the robot back to new where it's home coordinates are
MoveHome = function(direction, x, z)
	local newStop = math.random(7, 17)
	if x < homeArea[1] then
		SetDirection(direction, 2)
		direction = 2
	else
		SetDirection(direction, 4)
		direction = 4
	end
	Fueling(fuelChestSlot)
	ForwardVariable(math.abs(homeArea[1] - x) + newStop)
	Fueling(fuelChestSlot)
	if z < homeArea[3] then
		SetDirection(direction, 3)
		direction = 3
	else
		SetDirection(direction, 1)
		direction = 1
	end
	ForwardVariable(math.abs(homeArea[3] - z) + newStop)
	Fueling(fuelChestSlot)
end

--main

if Prepare() then
	local direction, x, y, z = Direction()
	if rebootCheck then --since it rebooted need to see how far from home the turtle is and turn back
		if ReturnHome(x, z) then
			SendMessage("Moving home from " .. x .. " " .. y .. " " .. z)
			MoveHome(direction, x, z)
		else
			SendMessage("Starting mission at " .. x .. " " .. y .. " " .. z .. " heading " .. CardinalDirection(direction))
		end
	end
	repeat--this will run forever until the turtle is in an unloaded
		turtle.select(1)
		local movement = math.random(30, 60)
		ForwardVariable(movement)
		local turn = math.random(1, 2)
		if turn == 1 then
			turtle.turnLeft()
		else
			turtle.turnRight()
		end
		direction, x, y, z = Direction() -- find and report position
		SendMessage("Arrived at " .. x .. " " .. y .. " " .. z .. " now heading " .. CardinalDirection(direction))
		Fueling(fuelChestSlot)
	until 1 == 0
else
	local x, y, z = gps.locate()
	SendMessage("Failed prepare at " .. x .. " " .. y .. " " .. z)
end
