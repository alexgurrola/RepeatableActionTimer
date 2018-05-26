--------------------------
-- Initialize Variables --
--------------------------

RepeatableActionTimer = {}
RepeatableActionTimer.name = "RepeatableActionTimer"
RepeatableActionTimer.configVersion = 2
RepeatableActionTimer.controls = {}
RepeatableActionTimer.defaults = {
    shadowySupplier = true,
    stables = true,
    timers = {}
}
RepeatableActionTimer.character = {
    total = GetNumCharacters(),
    id = GetCurrentCharacterId(),
    names = {}
}
RepeatableActionTimer.GUI = {
    listHolder = nil,
    topLevel = nil,
    deadTime = "--",
    rowHeight = "24"
}

---------------------
--  OnAddOnLoaded  --
---------------------

function OnAddOnLoaded(event, addonName)
    if addonName ~= RepeatableActionTimer.name then
        return
    end
    RepeatableActionTimer:Initialize(RepeatableActionTimer)
end

--------------------------
--  Initialize Function --
--------------------------

function RepeatableActionTimer:Initialize(self)
    self.saveData = ZO_SavedVars:NewAccountWide(self.name .. "Data", self.configVersion, nil, self.defaults)
    self:RepairSaveData(self)
    self:CreateSettingsWindow(self)
    self:BuildTimers(self)
    self:UpdateCharacterTimer(self)

    -- Register Key Bind Names
    ZO_CreateStringId("SI_BINDING_NAME_ACTION_TIMER_TOGGLE", "Toggle Window Visibility")

    -- System Hooks
    if (RepeatableActionTimer_GUI ~= nil) then
        SCENE_MANAGER:RegisterTopLevel(RepeatableActionTimer_GUI, false)
        self.GUI.topLevel = RepeatableActionTimer_GUI
        self.GUI.listHolder = RepeatableActionTimer_GUI_ListHolder
        self.GUI.topLevel:ClearAnchors()
        self.GUI.topLevel:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        self.GUI.topLevel:SetHeight(self.GUI.topLevel:GetHeight() + (self.character.total * self.GUI.rowHeight))
        self:CreateListHolder(self)
    else
        d("Unable to initialize Action Timer GUI!")
    end

    -- Event Hooks
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_NEW_MOVEMENT_IN_UI_MODE, function(...)
        return self:OnPlayerMove(self, ...)
    end)
    --[[
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_REMOVED, function(...)
        return self:OnQuestRemoved(self, ...)
    end)
    ]]
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_RETICLE_HIDDEN_UPDATE, function(...)
        return self:OnReticleHidden(self, ...)
    end)

    -- Release Hooks
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
end

---------------
-- Libraries --
---------------

local LAM2 = LibStub("LibAddonMenu-2.0")

--------------------
-- Internal Tools --
--------------------

-- allow debugging based on changes
RepeatableActionTimer.debugLog = {}
function RepeatableActionTimer:Debug(self, key, output)
    if output ~= self.debugLog[key] then
        self.debugLog[key] = output
        d(self.name .. "." .. key .. ":", output)
    end
end

function RepeatableActionTimer:RepairSaveData(self)
    for key, value in pairs(self.defaults) do
        if (self.saveData[key] == nil) then
            self.saveData[key] = value
        end
    end
end

-- Note: This is disabled in favor or ZO_FormatTime for now
--[[
function RepeatableActionTimer:Clock(self, seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "00:00:00"
  else
    days = math.floor(seconds / 86400)
    hours = math.floor(seconds / 3600 - (days * 86400))
    mins = math.floor(seconds / 60 - (days * 86400) - (hours * 60))
    secs = math.floor(seconds - (days * 86400) - (hours * 3600) - (mins * 60))
    return days > 0 and string.format("%02.fd %02.fh %02.fm %02.fs", days, hours, mins, secs) or string.format("%02.fh %02.fm %02.fs", hours, mins, secs)
  end
end
]]

----------
-- Data --
----------

function RepeatableActionTimer:BuildTimers(self)
    for i = 1, self.character.total do
        local name, _, _, _, _, _, characterId = GetCharacterInfo(i)
        -- Register Names while transversing
        if self.character.names[characterId] == nil then
            -- Strip the grammar markup
            self.character.names[characterId] = zo_strformat("<<1>>", name)
        end
        -- Store Timers
        if self.saveData.timers[characterId] == nil then
            self.saveData.timers[characterId] = {
                stables = nil,
                shadowySupplier = nil
            }
        end
    end
end

function RepeatableActionTimer:UpdateCharacterTimer(self)
    self.saveData.timers[self.character.id].stables = GetTimeStamp() + math.floor(GetTimeUntilCanBeTrained() / 1000)
    self.saveData.timers[self.character.id].shadowySupplier = GetTimeStamp() + GetTimeToShadowyConnectionsResetInSeconds()
end

--------------------
-- Menu Functions --
--------------------

function RepeatableActionTimer:CreateSettingsWindow(self)
    local panelData = {
        type = "panel",
        name = "Action Timer",
        displayName = "Repeatable Action Timer",
        author = "Positron",
        version = "0.2",
        website = "https://github.com/alexgurrola/RepeatableActionTimer",
        slashCommand = "/actiontimer",
        registerForDefaults = true,
    }
    -- local panel =
    LAM2:RegisterAddonPanel(self.name .. "Config", panelData)
    local optionsData = {}
    optionsData[#optionsData + 1] = {
        type = "header",
        name = "Actors"
    }
    --[[
    optionsData[#optionsData + 1] = {
        type = "description",
        text = "This addon keeps track of when a repeatable action can be repeated."
    }
    ]]
    optionsData[#optionsData + 1] = {
        type = "description",
        text = "This will house settings for toggling specific timers for each character."
    }
    --[[
    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = "Stables",
        tooltip = "Turn this off if you want to stop tracking Shadowy Supplier interactions.",
        requiresReload = false,
        default = self.defaults.stables,
        getFunc = function()
            return self.saveData.stables
        end,
        setFunc = function(newValue)
            self.saveData.stables = newValue
        end,
    }
    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = "Shadowy Supplier",
        tooltip = "Turn this off if you want to stop tracking Shadowy Supplier interactions.",
        requiresReload = false,
        default = self.defaults.shadowySupplier,
        getFunc = function()
            return self.saveData.shadowySupplier
        end,
        setFunc = function(newValue)
            self.saveData.shadowySupplier = newValue
        end,
    }
    ]]
    -- Other Actions
    optionsData[#optionsData + 1] = {
        type = "header",
        name = "Other Actions"
    }
    -- Donation Button
    optionsData[#optionsData + 1] = {
        type = "button",
        name = "Small Donation",
        tooltip = "This will compose appreciation mail for @PositronXX.  You can either accept the prompt directly or decline the transaction and mail a custom letter in the Outbox.",
        func = function()
            local wallet = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
            local tithe = math.floor(wallet / 10)
            MAIL_SEND:ClearFields()
            MAIL_SEND.to:SetText("@PositronXX")
            MAIL_SEND.subject:SetText("Donation to Action Timer")
            MAIL_SEND.body:SetText("Keep the updates coming!")
            MAIL_SEND:SetSendMoneyMode(true)
            MAIL_SEND:AttachMoney(0, tithe)
            MAIL_SEND:UpdateMoneyAttachment()
            MAIL_SEND:UpdatePostageMoney()
            SCENE_MANAGER:CallWhen("mailSend", SCENE_SHOWN, function()
                ZO_MailSendBodyField:TakeFocus()
            end)
            ZO_MainMenuSceneGroupBar.m_object:SelectDescriptor("mailSend")
            MAIL_SEND:Send()
        end,
    }
    LAM2:RegisterOptionControls(self.name .. "Config", optionsData)
end

-------------------
-- UI/UX Actions --
-------------------

function RepeatableActionTimer:CreateLine(self, i, predecessor, parent)
    local row = CreateControlFromVirtual(self.name .. "_Row_", parent, self.name .. "_SlotTemplate", i)

    row.name = row:GetNamedChild("_Name")
    row.stables = row:GetNamedChild("_TimeStables")
    row.shadowySupplier = row:GetNamedChild("_TimeShadowySupplier")

    row:SetHidden(false)
    row:SetMouseEnabled(true)
    row:SetHeight(self.GUI.rowHeight)

    if i == 1 then
        row:SetAnchor(TOPLEFT, self.GUI.listHolder, TOPLEFT, 0, 0)
        row:SetAnchor(TOPRIGHT, self.GUI.listHolder, TOPRIGHT, 0, 0)
    else
        row:SetAnchor(TOPLEFT, predecessor, BOTTOMLEFT, 0, self.GUI.listHolder.rowHeight)
        row:SetAnchor(TOPRIGHT, predecessor, BOTTOMRIGHT, 0, self.GUI.listHolder.rowHeight)
    end

    row:SetParent(self.GUI.listHolder)

    return row
end

function RepeatableActionTimer:FillLine(self, line, item)
    line.name:SetText(item == nil and "Unknown" or item.name)
    line.stables:SetText(item == nil and self.GUI.deadTime or item.stables)
    line.shadowySupplier:SetText(item == nil and self.GUI.deadTime or item.shadowySupplier)
end

function RepeatableActionTimer:InitializeTimeLines(self)
    for i = 1, self.character.total do
        self:FillLine(self, self.GUI.listHolder.lines[i], self.GUI.listHolder.dataLines[i])
    end
end

function RepeatableActionTimer:CreateListHolder(self)
    self.GUI.listHolder.dataLines = {}
    self.GUI.listHolder.lines = {}
    local predecessor
    for i = 1, self.character.total do
        self.GUI.listHolder.lines[i] = self:CreateLine(self, i, predecessor, self.GUI.listHolder)
        predecessor = self.GUI.listHolder.lines[i]
    end
    self:Redraw(self)
end

function RepeatableActionTimer:EventTime(self, timeStamp)
    if timeStamp == nil then
        return self.GUI.deadTime
    end
    local elapsed = timeStamp - GetTimeStamp()
    return ZO_FormatTime(elapsed < 0 and 0 or elapsed, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
end

function RepeatableActionTimer:Redraw(self)
    --[[
    if self.TimeStamp == nil then
        self.TimeStamp = GetTimeStamp()
    end
    d("Window Time:", GetDiffBetweenTimeStamps(GetTimeStamp(), self.TimeStamp))
    ]]
    local dataLines = {}
    for i = 1, self.character.total do
        local _, _, _, _, _, _, characterId = GetCharacterInfo(i)
        table.insert(dataLines, {
            name = self.character.names[characterId],
            shadowySupplier = self:EventTime(self, self.saveData.timers[characterId] and self.saveData.timers[characterId].shadowySupplier or nil),
            stables = self:EventTime(self, self.saveData.timers[characterId] and self.saveData.timers[characterId].stables or nil)
        })
    end
    self.GUI.listHolder.dataLines = dataLines
    self.GUI.listHolder:SetParent(self.GUI.topLevel)
    d(dataLines)
    self:InitializeTimeLines(self)
end

function RepeatableActionTimer:ToggleWindow(self)
    self.active = not self.active
    if (self.active) then
        self:Redraw(self)
    end
    if (self.GUI.topLevel ~= nil) then
        self.GUI.topLevel:SetHidden(not self.active)
    end
end

--------------------
-- Event Handlers --
--------------------

function RepeatableActionTimer:OnReticleHidden(self, eventCode, retHidden)
    if (self.GUI.topLevel ~= nil and self.active) then
        self.GUI.topLevel:SetHidden(not retHidden)
    end
end

function RepeatableActionTimer:OnPlayerMove(self, eventCode)
    -- close window if open
    if (self.active) then
        self:ToggleWindow(self)
    end
end

--[[
function RepeatableActionTimer:OnQuestRemoved(self, eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questId)
    d("GCCID:", GCCId())
    d("QuestID:", questId)
    d("Completed:", isCompleted)
end
]]

function RepeatableActionTimer:OnUpdate(self)
    self:Redraw(self)
end

----------------------
--  Register Events --
----------------------

EVENT_MANAGER:RegisterForEvent(RepeatableActionTimer.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
