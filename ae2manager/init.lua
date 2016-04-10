local colors = require("colors")
local component = require("component")
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
  return obj
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
  if self:isCrafting(itemStack) or
     self:numCraftingJobs() >= self.maxCraftingJobs then
    return nil
  end
  job = craftable.request(quantity)
  self:addCraftingJob(craftable.getItemStack(), job)
  return job
end

function ae2manager:redstone(itemConfig, signalStrength)
  redstone = component.redstone
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

function ae2manager:processItems()
  for idx, itemConfig in pairs(self.config.items) do
    self:processItem(itemConfig)
    os.sleep(self.itemProcessDelay)
  end
end

function ae2manager:processItem(itemConfig)
  itemStack = (self:getItemStack(itemConfig) or {size = 0})
  self.actions[itemConfig.action](self, itemStack, itemConfig)
end

function ae2manager:getItemStack(filter)
  result = self.ae2.getItemsInNetwork(filter)
  return result[1]
end

function ae2manager:getCraftable(filter)
  result = self.ae2.getCraftables(filter)
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
  id = self.itemId(item)
  job = self.craftingJobs[id]
  if job and not self.craftingJobDone(job) then
    return true
  else
    return false
  end
end

function ae2manager:numCraftingJobs()
  numJobs = 0
  for idx, job in pairs(self.craftingJobs) do
    if self.craftingJobDone(job) then
      self.craftingJobs[idx] = nil
    else
      numJobs = numJobs + 1
    end
  end
  return numJobs
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

function ae2actions.craft(ae2manager, itemStack, itemConfig)
  if itemStack.size > itemConfig.minimum then
    return nil
  end
  craftable = ae2manager:getCraftable(itemConfig)
  neededQuantity = itemConfig.minimum - itemStack.size
  defaultQuantity = 64
  if neededQuantity < defaultQuantity then
    defaultQuantity = neededQuantity
  end
  quantity = itemConfig.quantity or defaultQuantity
  ae2manager:craft(craftable, quantity)
end

function ae2actions.redstone(ae2manager, itemStack, itemConfig)
  local signalStrength = 0
  if itemStack.size < itemConfig.minimum then
    signalStrength = 255
  end
  ae2manager:redstone(itemConfig, signalStrength)
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
