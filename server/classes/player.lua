function CreateESXPlayer(userData)
	local self = {}

	self.accounts = userData.accounts
	self.coords = userData.coords
	self.identifier = userData.identifier
	self.inventory = userData.inventory
	self.job = userData.job
	self.loadout = userData.loadout
	self.playerId = userData.playerId
	self.source = userData.playerId -- deprecated, use playerId instead!
	self.variables = {}
	self.weight = userData.weight
	self.maxWeight = Config.MaxWeight

	self.health = userData.health
	self.armour = userData.armour
	self.name = userData.name
	self.skin = userData.skin
	self.status = userData.status
	self.phoneNumber = userData.phoneNumber
	self.groups = userData.groups

	for group,v in pairs(self.groups) do
		ExecuteCommand(('add_principal identifier.%s group.%s'):format(self.identifier, group))
	end

	self.triggerEvent = function(eventName, ...) TriggerClientEvent(eventName, self.playerId, ...) end

	self.setCoords = function(_coords)
		self.updateCoords(_coords)
		self.triggerEvent('esx:teleport', _coords)
	end

	self.updateCoords = function(_coords) self.coords = ESX.Math.FormatCoordsTable(_coords, 'table') end

	self.getCoords = function(vector)
		local playerPed = GetPlayerPed(self.playerId)
		local playerCoords = GetEntityCoords(playerPed)

		if playerCoords then
			if vector then
				return ESX.Math.FormatCoordsTable(playerCoords, 'vector3')
			else
				return ESX.Math.FormatCoordsTable(playerCoords, 'table')
			end
		else
			if vector then
				return vector3(self.coords.x, self.coords.y, self.coords.z)
			else
				return self.coords
			end
		end
	end

	self.kick = function(reason) DropPlayer(self.playerId, reason) end

	self.setMoney = function(money)
		money = math.round(money)
		self.setAccountMoney('money', money)
	end

	self.getMoney = function() return self.getAccount('money').money end

	self.addMoney = function(money, reason)
		money = math.round(money)
		self.addAccountMoney('money', money, reason)
	end

	self.removeMoney = function(money, reason)
		money = math.round(money)
		self.removeAccountMoney('money', money, reason)
	end

	self.setHealth = function(newHealth)
		self.health = newHealth
		self.triggerEvent('esx:setHealth', self.health)
	end

	self.getHealth = function() return self.health end

	self.setArmour = function(newArmour)
		self.armour = newArmour
		self.triggerEvent('esx:setArmour', self.armour)
	end

	self.getArmour = function() return self.armour end

	self.updateHealth = function(_health, _armour)
		self.health = _health
		self.armour = _armour
	end

	self.getAccountBalance = function(accountName)
		local account = self.getAccount(accountName)

		if account then
			return account.money
		else
			return 0
		end
	end

	self.getIdentifier = function(steamDec)
		if steamDec then
			return tonumber(string.sub(self.identifier, 7, -1), 16)
		else
			return self.identifier
		end
	end

	self.addGroup = function(group)
		if self.groups[group] then
			return false
		else
			self.groups[group] = true
			self.triggerEvent('esx:setGroups', self.groups)
			ExecuteCommand(('add_principal identifier.%s group.%s'):format(self.identifier, group))
			return true
		end
	end

	self.removeGroup = function(group)
		if self.groups[group] then
			if group == 'user' then
				return false
			else
				self.groups[group] = nil
				self.triggerEvent('esx:setGroups', self.groups)
				ExecuteCommand(('remove_principal identifier.%s group.%s'):format(self.identifier, group))
				return true
			end
		else
			return false
		end
	end

	self.getGroups = function() return self.groups end
	self.set = function(k, v) self.variables[k] = v end
	self.get = function(k) return self.variables[k] end

	self.getAccounts = function(minimal, keyValue)
		if minimal then
			local minimalAccounts = {}

			for k,v in ipairs(self.accounts) do
				minimalAccounts[v.name] = v.money
			end

			return minimalAccounts
		elseif keyValue then
			local minimalAccounts = {}

			for k,v in ipairs(self.accounts) do
				minimalAccounts[v.name] = v
			end

			return minimalAccounts
		else
			return self.accounts
		end
	end

	self.getAccount = function(account)
		for k,v in ipairs(self.accounts) do
			if v.name == account then
				return v
			end
		end
	end

	self.getInventory = function(minimal, keyValue)
		if minimal then
			local minimalInventory = {}

			for k,v in ipairs(self.inventory) do
				if v.count > 0 then
					minimalInventory[v.name] = v.count
				end
			end

			return minimalInventory
		elseif keyValue then
			local minimalInventory = {}

			for k,v in ipairs(self.inventory) do
				minimalInventory[v.name] = v
			end

			return minimalInventory
		else
			return self.inventory
		end
	end

	self.getJob = function() return self.job end

	self.getLoadout = function(minimal)
		if minimal then
			local minimalLoadout = {}

			for k,v in pairs(self.loadout) do
				minimalLoadout[v.name] = {}
				if v.tintIndex > 0 then minimalLoadout[v.name].tintIndex = v.tintIndex end

				if #v.components > 0 then
					local components = {}

					for k2,component in ipairs(v.components) do
						if component ~= 'clip_default' then
							table.insert(components, component)
						end
					end

					if #components > 0 then
						minimalLoadout[v.name].components = components
					end
				end
			end

			return minimalLoadout
		else
			return self.loadout
		end
	end

	self.setAccountMoney = function(accountName, money, reason)
		if money >= 0 then
			local account = self.getAccount(accountName)

			if account then
				local newMoney = math.round(money)
				account.money = newMoney

				self.triggerEvent('esx:setAccountMoney', account)
			end
		end
	end

	self.addAccountMoney = function(accountName, money, reason)
		if money > 0 then
			local account = self.getAccount(accountName)

			if account then
				local newMoney = account.money + math.round(money)
				account.money = newMoney

				self.triggerEvent('esx:setAccountMoney', account)
			end
		end
	end

	self.removeAccountMoney = function(accountName, money, reason)
		if money > 0 then
			local account = self.getAccount(accountName)

			if account then
				local newMoney = account.money - math.round(money)
				account.money = newMoney

				self.triggerEvent('esx:setAccountMoney', account)
			end
		end
	end

	self.getInventoryItem = function(name)
		for k,v in ipairs(self.inventory) do
			if v.name == name then
				return v
			end
		end

		return
	end

	self.hasItem = function(item) return self.getInventoryItem(item).count >= 1 end

	self.addInventoryItem = function(name, count)
		local item = self.getInventoryItem(name)

		if item then
			count = math.round(count)
			item.count = item.count + count
			self.weight = self.weight + (item.weight * count)

			TriggerEvent('esx:onAddInventoryItem', self.playerId, item.name, item.count)
			self.triggerEvent('esx:addInventoryItem', item.name, item.count)
		end
	end

	self.removeInventoryItem = function(name, count)
		local item = self.getInventoryItem(name)

		if item then
			count = math.round(count)
			local newCount = item.count - count

			if newCount >= 0 then
				item.count = newCount
				self.weight = self.weight - (item.weight * count)

				TriggerEvent('esx:onRemoveInventoryItem', self.playerId, item.name, item.count)
				self.triggerEvent('esx:removeInventoryItem', item.name, item.count)
			end
		end
	end

	self.setInventoryItem = function(name, count)
		local item = self.getInventoryItem(name)

		if item and count >= 0 then
			count = math.round(count)

			if count > item.count then
				self.addInventoryItem(item.name, count - item.count)
			else
				self.removeInventoryItem(item.name, item.count - count)
			end
		end
	end

	self.getWeight = function() return self.weight end
	self.getMaxWeight = function() return self.maxWeight end

	self.canCarryItems = function(data)
		local currentWeight = self.weight
		if data then
			for _,v in pairs(data) do
				currentWeight = currentWeight+(ESX.Items[v.name].weight*v.count)
			end
		end

		return currentWeight <= self.maxWeight
	end

	self.canCarryItem = function(name, count)
		local currentWeight, itemWeight = self.weight, ESX.Items[name].weight
		local newWeight = currentWeight + (itemWeight * count)

		return newWeight <= self.maxWeight
	end

	self.canSwapItems = function(addedItems, removedItems)
		local currentWeight = self.weight
		if addedItems then
			for _, v in pairs(addedItems) do
				currentWeight = currentWeight + (ESX.Items[v.name].weight*v.count)
			end
		end
		if removedItems then
			for _, v in pairs(removedItems) do
				currentWeight = currentWeight - (ESX.Items[v.name].weight*v.count)
			end
		end
		return currentWeight <= self.maxWeight
	end

	self.canSwapItem = function(firstItem, firstItemCount, testItem, testItemCount)
		local firstItemObject = self.getInventoryItem(firstItem)
		local testItemObject = self.getInventoryItem(testItem)

		if firstItemObject.count >= firstItemCount then
			local weightWithoutFirstItem = math.round(self.weight - (firstItemObject.weight * firstItemCount))
			local weightWithTestItem = math.round(weightWithoutFirstItem + (testItemObject.weight * testItemCount))

			return weightWithTestItem <= self.maxWeight
		end

		return false
	end

	self.setMaxWeight = function(newWeight)
		self.maxWeight = newWeight
		self.triggerEvent('esx:setMaxWeight', self.maxWeight)
	end

	self.setJob = function(job, grade)
		grade = tostring(grade)
		local lastJob = json.decode(json.encode(self.job))

		if ESX.DoesJobExist(job, grade) then
			local jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]

			self.job.id    = jobObject.id
			self.job.name  = jobObject.name
			self.job.label = jobObject.label

			self.job.grade        = tonumber(grade)
			self.job.grade_name   = gradeObject.name
			self.job.grade_label  = gradeObject.label
			self.job.grade_salary = gradeObject.salary

			if gradeObject.skin_male then
				self.job.skin_male = json.decode(gradeObject.skin_male)
			else
				self.job.skin_male = {}
			end

			if gradeObject.skin_female then
				self.job.skin_female = json.decode(gradeObject.skin_female)
			else
				self.job.skin_female = {}
			end

			TriggerEvent('esx:setJob', self.playerId, self.job, lastJob)
			self.triggerEvent('esx:setJob', self.job, lastJob)
		else
			print(('[ESX] [^3WARNING^7] Ignoring invalid .setJob() usage for "%s"'):format(self.identifier))
		end
	end

	self.addWeapon = function(weaponName, ammo)
		if not self.hasWeapon(weaponName) then
			local weaponLabel = ESX.GetWeaponLabel(weaponName)

			table.insert(self.loadout, {
				name = weaponName,
				ammo = ammo,
				label = weaponLabel,
				components = {},
				tintIndex = 0
			})

			self.triggerEvent('esx:addWeapon', weaponName, ammo)
			self.showInventoryItemNotification(weaponLabel, true)
		end
	end

	self.addWeaponComponent = function(weaponName, weaponComponent)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			local component = ESX.GetWeaponComponent(weaponName, weaponComponent)

			if component then
				if not self.hasWeaponComponent(weaponName, weaponComponent) then
					table.insert(self.loadout[weaponName].components, weaponComponent)
					self.triggerEvent('esx:addWeaponComponent', weaponName, weaponComponent)
					self.showInventoryItemNotification(component.label, true)
				end
			end
		end
	end

	self.addWeaponAmmo = function(weaponName, ammoCount)
		local loadoutNum, weapon = self.getWeapon(weaponName)

		if weapon then
			weapon.ammo = weapon.ammo + ammoCount
			self.triggerEvent('esx:setWeaponAmmo', weaponName, weapon.ammo)
		end
	end

	self.updateWeaponAmmo = function(weaponName, ammoCount)
		local loadoutNum, weapon = self.getWeapon(weaponName)

		if weapon then
			if ammoCount < weapon.ammo then
				weapon.ammo = ammoCount
			end
		end
	end

	self.setWeaponTint = function(weaponName, weaponTintIndex)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			local weaponObject = ESX.GetWeapon(weaponName)

			if weaponObject.tints and weaponObject.tints[weaponTintIndex] then
				self.loadout[weaponName].tintIndex = weaponTintIndex
				self.triggerEvent('esx:setWeaponTint', weaponName, weaponTintIndex)
				self.showInventoryItemNotification(weaponObject.tints[weaponTintIndex], true)
			end
		end
	end

	self.getWeaponTint = function(weaponName)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			return weapon.tintIndex
		end

		return 0
	end

	self.removeWeapon = function(weaponName)
		local weaponLabel

		if self.loadout[weaponName] ~= nil then
			weaponLabel = self.loadout[weaponName].label

			for k2,v2 in ipairs(self.loadout[weaponName].components) do
				self.removeWeaponComponent(weaponName, v2)
			end

			self.loadout[weaponName] = nil

			self.triggerEvent('esx:removeWeapon', weaponName)
			self.showInventoryItemNotification(weaponLabel, false)
		end
	end

	self.removeWeaponComponent = function(weaponName, weaponComponent)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			local component = ESX.GetWeaponComponent(weaponName, weaponComponent)

			if component then
				if self.hasWeaponComponent(weaponName, weaponComponent) then
					for k,v in ipairs(self.loadout[weaponName].components) do
						if v == weaponComponent then
							table.remove(self.loadout[weaponName].components, k)
							break
						end
					end

					self.triggerEvent('esx:removeWeaponComponent', weaponName, weaponComponent)
					self.showInventoryItemNotification(component.label, false)
				end
			end
		end
	end

	self.hasWeaponComponent = function(weaponName, weaponComponent)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			for k,v in ipairs(weapon.components) do
				if v == weaponComponent then
					return true
				end
			end

			return false
		else
			return false
		end
	end

	self.hasWeapon = function(weaponName)
		if self.loadout[weaponName] then
			return true
		else
			return false
		end
	end

	self.getWeapon = function(weaponName) return self.loadout[weaponName] end
	self.showNotification = function(msg, flash, saveToBrief, hudColorIndex) self.triggerEvent('esx:showNotification', msg, flash, saveToBrief, hudColorIndex) end
	self.showHelpNotification = function(msg, thisFrame, beep, duration) self.triggerEvent('esx:showHelpNotification', msg, thisFrame, beep, duration) end
	self.showAdvancedNotification = function(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex) self.triggerEvent('esx:showAdvancedNotification', sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex) end
	self.showInventoryItemNotification = function(msg, add) self.triggerEvent('esx:showInventoryItemNotification', msg, add) end
	self.save = function(cb) ESX.SavePlayer(self, cb) end
	self.getName = self.name

	self.isAceAllowed = function(object) return IsPlayerAceAllowed(self.playerId, object) end

	self.setName = function(_name)
		self.name = _name
		TriggerEvent('esx:setName', self.playerId, self.name)
	end

	self.setSkin = function(newSkin) self.skin = newSkin end
	self.getSkin = function() return self.skin end
	self.getStatus = function() return self.status end
	self.setStatus = function(newStatus) self.status = newStatus end
	self.getPhoneNumber = function() return self.phoneNumber end

	return self
end
