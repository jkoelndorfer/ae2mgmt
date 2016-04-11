local io = require("io")

local log = {}
local l = {}

l.TRACE    = 50
l.DEBUG    = 40
l.INFO     = 30
l.WARN     = 20
l.ERROR    = 10
l.CRITICAL = 0
local STDOUT_FD = 1

function log.new()
  local logger = {}
  logger.files = {}
  for idx, val in pairs(l) do
    logger[idx] = val
  end
  logger:set_level(l.CRITICAL)
  logger:add_file(io.stream(STDOUT_FD))
  return logger
end

function l:set_level(lvl)
  self.current_level = lvl
end

function l:add_file(f)
  table.insert(self.files, f)
end

function l:log(lvl, message)
  if self.current_level >= lvl then
    for _, file in pairs(self.files) do
      file:write(message .. "\n")
      file:flush()
    end
  end
end

function l:trace(message)
  self:log(self.TRACE, message)
end

function l:debug(message)
  self:log(self.DEBUG, message)
end

function l:info(message)
  self:log(self.INFO, message)
end

function l:warn(message)
  self:log(self.WARN, message)
end

function l:error(message)
  self:log(self.ERROR, message)
end

function l:critical(message)
  self:log(self.CRITICAL, message)
end

return log