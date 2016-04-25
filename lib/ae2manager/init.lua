local colors = require("colors")
local component = require("component")
local log = require("log")
local os = require("os")
local sides = require("sides")

local ae2manager = {}
local ae2actions = {}

function ae2manager.new(meInterface)
  local obj = newObject(ae2manager)
  obj.ae2 = (meInterface or component.me_interface or component.me_controller)
  obj.canceled = false
  obj.actions = ae2actions.new()
  obj.itemProcessDelay = 0.05
  obj.craftingJobs = {}
  obj.maxCraftingJobs = 1
  obj.config = {}
  obj.logger = log.new()
  return obj
end

-- Sometimes AE2 goes offline, or the computer loses its connection and can't
-- communicate with the network. This function checks to see if AE2 is
-- available.
function ae2manager:ae2Available()
  return (self.ae2.getMaxStoredPower() > 0)
end

function ae2manager:cleanup()
  for _, itemConfig in pairs(self.config.items) do
    if itemConfig.action == "redstone" then
      self:redstone(itemConfig, 0)
    end
  end
  self:cancel()
end

function ae2manager:cancel()
  self.canceled = true
end

function ae2manager:craft(craftable, quantity)
  local itemStack = craftable.getItemStack()
  if self:isCrafting(itemStack) or
     self:numCraftingJobs() >= self.maxCraftingJobs then
    return nil
  end
  local job = craftable.request(quantity)
  self:addCraftingJob(itemStack, job)
  return job
end

function ae2manager:redstone(itemConfig, signalStrength)
  local redstone = component.redstone
  if itemConfig.address then
    redstone = component.proxy(address)
  end
  local side = sides[itemConfig.side]
  local color = colors[itemConfig.color]
  redstone.setBundledOutput(side, color, signalStrength)
end

function ae2manager:run()
  self.canceled = false
  while not self.canceled do
    self:processItems()
  end
end

function ae2manager:hasItems(itemConfigs)
  for idx, config in pairs(itemConfigs) do
    local itemStack = self:getItemStack(config)
    if itemStack.size < config.minimum then
      return false
    end
  end
  return true
end

function ae2manager:processItems()
  for idx, itemConfig in pairs(self.config.items) do
    self:processItem(itemConfig)
    os.sleep(self.itemProcessDelay)
  end
end

function ae2manager:processItem(itemConfig)
  local itemStack = self:getItemStack(itemConfig)
  self.actions[itemConfig.action](self, itemStack, itemConfig)
end

function ae2manager:getItemStack(filter)
  local result = self.ae2.getItemsInNetwork(filter)
  if result["n"] == 0 then
    -- TODO: Copy filter into this returned value
    return {size = 0}
  end
  return result[1]
end

function ae2manager:getCraftable(filter)
  local result = self.ae2.getCraftables(filter)
  return result[1]
end

function ae2manager:setConfiguration(config)
  self.config = config
  if not self.config.items then
    self.config.items = {}
  end
  if tonumber(self.config.maxCraftingJobs) then
    self:setMaxCraftingJobs(config.maxCraftingJobs)
  end
end

function ae2manager:setMaxCraftingJobs(count)
  self.maxCraftingJobs = count
end

function ae2manager:addCraftingJob(item, job)
  self.craftingJobs[self.itemId(item)] = job
end

function ae2manager:isCrafting(item)
  local id = self.itemId(item)
  local job = self.craftingJobs[id]
  if job and not self.craftingJobDone(job) then
    return true
  else
    return false
  end
end

function ae2manager:numCraftingJobs()
  local numJobs = 0
  for idx, job in pairs(self.craftingJobs) do
    if self.craftingJobDone(job) then
      self.craftingJobs[idx] = nil
    else
      numJobs = numJobs + 1
    end
  end
  return numJobs
end

function ae2manager.itemDisplayName(itemStack)
  return (itemStack.label or itemStack.name or "?")
end

function ae2manager.itemId(itemStack)
  return (itemStack.name .. "/" .. itemStack.label)
end

function ae2manager.craftingJobDone(job)
  return (job.isDone() or job.isCanceled())
end

function ae2actions.new()
  return newObject(ae2actions)
end

function ae2actions.doProduceItems(ae2, itemStack, itemConfig)
  local needItems = itemConfig.minimum > itemStack.size
  local prereqMet = (itemConfig.ifHasItems == nil) or ae2:hasItems(itemConfig.ifHasItems)
  return (needItems and prereqMet)
end

function ae2actions.craft(ae2, itemStack, itemConfig)
  if not ae2actions.doProduceItems(ae2, itemStack, itemConfig) then
    return nil
  end
  local craftable = ae2:getCraftable(itemConfig)
  if not craftable then
    if ae2:ae2Available() then
      local itemDisplayName = ae2.itemDisplayName(itemConfig)
      ae2.logger:warn("Can't get craftable for " .. itemDisplayName)
    end
    return nil
  end
  local neededQuantity = itemConfig.minimum - itemStack.size
  local defaultQuantity = 64
  if neededQuantity < defaultQuantity then
    defaultQuantity = neededQuantity
  end
  local quantity = itemConfig.quantity or defaultQuantity
  ae2:craft(craftable, quantity)
end

function ae2actions.redstone(ae2, itemStack, itemConfig)
  local signalStrength = 0
  if itemStack.size < itemConfig.minimum then
    signalStrength = 255
  end
  ae2:redstone(itemConfig, signalStrength)
end

function newObject(template)
  local obj = {}
  for k, v in pairs(template) do
    if k ~= "new" then
      obj[k] = v
    end
  end
  return obj
end

return ae2manager
-- vim: shiftwidth=2 softtabstop=2 ft=lua
