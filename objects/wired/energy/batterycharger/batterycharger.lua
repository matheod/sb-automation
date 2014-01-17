function init(virtual)
  if not virtual then
    energy.init()
    datawire.init()

    --table of batteries in the charger
    self.batteries = {}

    -- will be updated when batteries are checked
    self.batteryUnusedCapacity = 0

    --maximum energy to request for batteries from a single pulse
    self.batteryChargeAmount = 5

    --flag to allow/disallow energy output
    if storage.discharging == nil then
      storage.discharging = false
    end

    --frequency (in seconds) to check for batteries present
    self.batteryCheckFreq = 1
    self.batteryCheckTimer = self.batteryCheckFreq

    --store this so that we don't have to compute it repeatedly
    local pos = entity.position()
    self.batteryCheckArea = {
      {pos[1], pos[2] - 1},
      1.5
    }
  end
end

-- this hook is called by the first datawire.update()
function initAfterLoading()
  checkBatteries()
end

function die()
  energy.die()
end

function battCompare(a, b)
  return a.position[1] < b.position[1]
end

function checkBatteries()
  self.batteries = {}
  self.batteryUnusedCapacity = 0

  local entityIds = world.objectQuery(self.batteryCheckArea[1], self.batteryCheckArea[2], { withoutEntityId = entity.id(), callScript = "isBattery" })
  for i, entityId in ipairs(entityIds) do
    local batteryStatus = world.callScriptedEntity(entityId, "getBatteryStatus")
    self.batteries[#self.batteries + 1] = batteryStatus
    self.batteryUnusedCapacity = self.batteryUnusedCapacity + batteryStatus.unusedCapacity
  end

  --order batteries left -> right
  table.sort(self.batteries, battCompare)

  updateAnimationState()
  self.batteryCheckTimer = self.batteryCheckFreq --reset this here so we don't perform periodic checks right after a pulse

  --world.logInfo("found %d batteries with %f total unused capacity", #entityIds, self.batteryUnusedCapacity)
  --world.logInfo(self.batteries)
end

function updateAnimationState()
  --TODO: display indicators, I guess. some of this may be handled by the battery
end

function onEnergyNeedsCheck()
  return math.min(self.batteryChargeAmount, self.batteryUnusedCapacity)
end

function onEnergyReceived(amount, visited)
  checkBatteries()
  local acceptedEnergy = chargeBatteries(amount)

  return {acceptedEnergy, visited}
end

function chargeBatteries(amount)
  local amountRemaining = amount
  for i, bStatus in ipairs(self.batteries) do
    local amountAccepted = world.callScriptedEntity(bStatus.id, "energy.addEnergy", amountRemaining)
    if amountAccepted then --this check probably isn't necessary, but just in case a battery explodes or somethin
      if amountAccepted > 0 then
        world.callScriptedEntity(bStatus.id, "entity.setParticleEmitterActive", "charging", true)
      else
        world.callScriptedEntity(bStatus.id, "entity.setParticleEmitterActive", "charging", false)
      end
      amountRemaining = amountRemaining - amountAccepted
    end
  end

  return amount - amountRemaining
end

function dischargeBatteries(amount)
  --TODO

  --return energyRemoved
end

function main()
  self.batteryCheckTimer = self.batteryCheckTimer - entity.dt()
  if self.batteryCheckTimer <= 0 then
    checkBatteries()
  end

  datawire.update()
  energy.update()
end