function init(virtual)
  if not virtual then
    entity.setInteractive(not entity.isInboundNodeConnected(0))

    if storage.tileArea == nil then
      storage.tileArea = {}
    end

    if storage.swapState == nil then
      storage.swapState = false -- false = blocks in foreground, true = blocks in background
    end

    if storage.transitionState == nil then
      storage.transitionState = 0 -- >1 = breaking, 1 = placing, 0 = passive
    end

    if storage.bgData == nil then
      storage.bgData = {}
    end

    if storage.fgData == nil then
      storage.fgData = {}
    end

    self.initialized = false

    updateAnimationState()
  end
end

function initInWorld()
  --world.logInfo(string.format("%s initializing in world", entity.configParameter("objectName")))
  datawire.init()
  self.initialized = true
end

function updateAnimationState()
  if storage.swapState then
    entity.setAnimationState("layerState", "background")
  else
    entity.setAnimationState("layerState", "foreground")
  end
end

function onInboundNodeChange(args) 
  checkNodes()
end

oldOnNodeConnectionChange = onNodeConnectionChange
 
function onNodeConnectionChange()
  if oldOnNodeConnectionChange then
    oldOnNodeConnectionChange()
  end

  checkNodes()
  entity.setInteractive(not entity.isInboundNodeConnected(0))
end

function checkNodes()
  swapLayer(entity.getInboundNodeLevel(0))
end

function validateData(data, dataType, nodeId)
  return dataType == "area"
end

function onValidDataReceived(data, dataType, nodeId)
  if storage.transitionState > 0 then
    storage.pendingAreaData = data
  else
    storage.tileArea = data
  end
end

function onInteraction(args)
  if not entity.isInboundNodeConnected(0) then
    swapLayer(not storage.swapState)
  end
end

function swapLayer(newState)
  if newState ~= storage.swapState then
    --world.logInfo("storage.tileArea")
    --world.logInfo(storage.tileArea)

    storage.swapState = newState
    storage.transitionState = 3

    storage.bgData = scanLayer(storage.tileArea, "background")
    storage.fgData = scanLayer(storage.tileArea, "foreground")

    breakLayer(storage.tileArea, "background", false)
    breakLayer(storage.tileArea, "foreground", false)

    updateAnimationState()
  end
end

function main()
  if not self.initialized then
    initInWorld()
  end

  --timer waits for blocks to finish being destroyed before starting placement
  if storage.transitionState > 0 then
    if storage.transitionState == 1 then
      --place stored blocks
      placeLayer(storage.tileArea, "background", storage.fgData, true)
      placeLayer(storage.tileArea, "foreground", storage.bgData, true)

      if storage.pendingAreaData then
        storage.tileArea = storage.pendingAreaData
        storage.pendingAreaData = false
      end
    end

    storage.transitionState = storage.transitionState - 1
  end
end