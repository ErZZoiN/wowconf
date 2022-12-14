AuctionatorIncrementalScanFrameMixin = {}

local INCREMENTAL_SCAN_EVENTS = {
  "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
  "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
  "AUCTION_HOUSE_CLOSED"
}

function AuctionatorIncrementalScanFrameMixin:OnLoad()
  Auctionator.Debug.Message("AuctionatorIncrementalScanFrameMixin:OnLoad")
  Auctionator.EventBus:RegisterSource(self, "AuctionatorIncrementalScanFrameMixin")

  self.doingFullScan = false

  self:RegisterForEvents()
end

function AuctionatorIncrementalScanFrameMixin:RegisterForEvents()
  Auctionator.Debug.Message("AuctionatorIncrementalScanFrameMixin:RegisterForEvents()")

  FrameUtil.RegisterFrameForEvents(self, INCREMENTAL_SCAN_EVENTS)
end

function AuctionatorIncrementalScanFrameMixin:UnregisterForEvents()
  Auctionator.Debug.Message("AuctionatorIncrementalScanFrameMixin:UnregisterForEvents()")

  FrameUtil.UnregisterFrameForEvents(self, INCREMENTAL_SCAN_EVENTS)
end

function AuctionatorIncrementalScanFrameMixin:OnEvent(event, ...)
  if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
    self.info = {} -- New search results so reset info

    self:AddPrices(C_AuctionHouse.GetBrowseResults())
    self:NextStep()
  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
    self:AddPrices(...)
    self:NextStep()

  elseif event == "AUCTION_HOUSE_CLOSED" and self.doingFullScan then
    self.doingFullScan = false
    Auctionator.Utilities.Message(AUCTIONATOR_L_FULL_SCAN_FAILED)
    Auctionator.EventBus:Fire(self, Auctionator.IncrementalScan.Events.ScanFailed)
  end
end

function AuctionatorIncrementalScanFrameMixin:InitiateScan()
  Auctionator.Utilities.Message(AUCTIONATOR_L_STARTING_FULL_SCAN)
  Auctionator.AH.SendBrowseQuery({searchString = "", sorts = {}, filters = {}, itemClassFilters = {}})
  self.previousDatabaseCount = Auctionator.Database.GetItemCount()
  self.doingFullScan = true

  Auctionator.EventBus:Fire(self, Auctionator.IncrementalScan.Events.ScanStart)
  self:FireProgressEvent()
end

function AuctionatorIncrementalScanFrameMixin:FireProgressEvent()
  local infoCount = 0

  if self.info ~= nil then
    for _, _  in pairs(self.info) do
      infoCount = infoCount + 1
    end
  end

  local dbCount = Auctionator.Database.GetItemCount()

  -- 10% complete after making the browse request
  local progress = 0.1

  if dbCount == 0 then
    -- 50% done if we don't have anything in the database
    progress = 0.5
  elseif dbCount > infoCount then
    -- 10%-90% complete when processing browse results
    progress = progress + 0.8 * infoCount / dbCount
  else
    -- 90% if got more browse results than prices already in the database
    progress = 0.9
  end

  Auctionator.EventBus:Fire(self, Auctionator.IncrementalScan.Events.ScanProgress, progress)
end

function AuctionatorIncrementalScanFrameMixin:AddPrices(results)
  Auctionator.Debug.Message("AuctionatorIncrementalScanFrameMixin:AddPrices()", results)

  for _, resultInfo in ipairs(results) do
    local itemKey = Auctionator.Utilities.ItemKeyFromBrowseResult(resultInfo)
    if self.info[itemKey] == nil then
      self.info[itemKey] = {}
    end

    table.insert(self.info[itemKey],
      { price = resultInfo.minPrice, available = resultInfo.totalQuantity }
    )
  end

  if self.doingFullScan then
    self:FireProgressEvent()
  end
end

function AuctionatorIncrementalScanFrameMixin:NextStep()
  if not Auctionator.AH.HasFullBrowseResults() then
    Auctionator.AH.RequestMoreBrowseResults()
  else
    local count = Auctionator.Database.ProcessScan(self.info)

    if self.doingFullScan then
      Auctionator.Utilities.Message(AUCTIONATOR_L_FINISHED_PROCESSING:format(count))
      self.doingFullScan = false

      Auctionator.EventBus:Fire(self, Auctionator.IncrementalScan.Events.ScanComplete)
    end

    self.info = {} --Already processed, so clear
  end
end
