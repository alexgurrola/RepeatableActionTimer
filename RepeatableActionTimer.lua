--------------------------
-- Initialize Variables --
--------------------------

RepeatableActionTimer = {}
RepeatableActionTimer.name = "RepeatableActionTimer"
RepeatableActionTimer.configVersion = 1
RepeatableActionTimer.controls = {}
RepeatableActionTimer.defaults = {
    ShadowySupplier = true,
    Stables = true
}
RepeatableActionTimer.system = {
    CharTotal = GetNumCharacters(),
    CharID = GetCurrentCharacterId(),
    Chars = {}
}
RepeatableActionTimer.timers = {}
RepeatableActionTimer.GUI = {
    ListHolder = nil,
    TopLevel = nil
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

    -- Get Character Names
    for i = 1, self.system.CharTotal do
        local name, _, _, _, _, _, characterId = GetCharacterInfo(i)
        if self.system.Chars[characterId] == nil then
            --Strip the grammar markup
            self.system.Chars[characterId] = zo_strformat("<<1>>", name)
        end
    end

    d('System:', self.system)

    -- Register Key Bind Names
    ZO_CreateStringId("SI_BINDING_NAME_ACTION_TIMER_TOGGLE", "Toggle Window Visibility")
    --ZO_CreateStringId("SI_BINDING_NAME_ACTION_TIMER_TOGGLE", "Display Cooldowns")

    -- System Hooks
    if (RepeatableActionTimer_GUI ~= nil) then
        SCENE_MANAGER:RegisterTopLevel(RepeatableActionTimer_GUI, false)
        self.GUI.TopLevel = RepeatableActionTimer_GUI
        self.GUI.ListHolder = RepeatableActionTimer_GUI_ListHolder
        self:CreateListHolder(self)
    else
        d('Unable to initialize Action Timer GUI!')
    end

    -- Event Hooks
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_NEW_MOVEMENT_IN_UI_MODE, function(...)
        return self:OnPlayerMove(self, ...)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_REMOVED, function(...)
        return self:OnQuestRemoved(self, ...)
    end)
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
    -- localized names of the actors
    self.timers.actors = {
        -- Vendors
        ["Remains-Silent"] = self.saveData.ShadowySupplier, -- Shadowy Suppliers
    }
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
        version = "0.1",
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
        type = "checkbox",
        name = "Stables",
        tooltip = "Turn this off if you want to stop tracking Shadowy Supplier interactions.",
        requiresReload = false,
        default = self.defaults.Stables,
        getFunc = function()
            return self.saveData.Stables
        end,
        setFunc = function(newValue)
            self.saveData.Stables = newValue
        end,
    }
    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = "Shadowy Supplier",
        tooltip = "Turn this off if you want to stop tracking Shadowy Supplier interactions.",
        requiresReload = false,
        default = self.defaults.ShadowySupplier,
        getFunc = function()
            return self.saveData.ShadowySupplier
        end,
        setFunc = function(newValue)
            self.saveData.ShadowySupplier = newValue
        end,
    }
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
    local row = CreateControlFromVirtual("RepeatableActionTimer_Row_", parent, "RepeatableActionTimer_SlotTemplate", i)

    row.Name = row:GetNamedChild("_Name")
    row.Stables = row:GetNamedChild("_Stables")
    row.ShadowySupplier = row:GetNamedChild("_ShadowySupplier")

    row:SetHidden(false)
    row:SetMouseEnabled(true)
    row:SetHeight("24")

    if i == 1 then
        row:SetAnchor(TOPLEFT, self.GUI.ListHolder, TOPLEFT, 0, 0)
        row:SetAnchor(TOPRIGHT, self.GUI.ListHolder, TOPRIGHT, 0, 0)
    else
        row:SetAnchor(TOPLEFT, predecessor, BOTTOMLEFT, 0, self.GUI.ListHolder.rowHeight)
        row:SetAnchor(TOPRIGHT, predecessor, BOTTOMRIGHT, 0, self.GUI.ListHolder.rowHeight)
    end

    row:SetParent(self.GUI.ListHolder)

    return row
end

function RepeatableActionTimer:FillLine(self, line, item)
    line.Name:SetText(item == nil and "-" or item.Name)
    line.Stables:SetText(item == nil and "-" or item.Stables)
    line.ShadowySupplier:SetText(item == nil and "-" or item.ShadowySupplier)
end

function RepeatableActionTimer:InitializeTimeLines(self)
    for i = 1, self.system.CharTotal do
        self:FillLine(self, self.GUI.ListHolder.lines[i], self.GUI.ListHolder.dataLines[i])
    end
end

function RepeatableActionTimer:CreateListHolder(self)
    self.GUI.ListHolder.dataLines = {}
    self.GUI.ListHolder.lines = {}
    local predecessor
    for i = 1, self.system.CharTotal do
        self.GUI.ListHolder.lines[i] = self:CreateLine(self, i, predecessor, self.GUI.ListHolder)
        predecessor = self.GUI.ListHolder.lines[i]
    end
    self:Redraw(self)
end

function RepeatableActionTimer:Redraw(self)
    --d('Shadowy Supplier: ' .. ZO_FormatTime(GetTimeToShadowyConnectionsResetInSeconds(), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR) .. ' remaining.')
    --d('Stables: ' .. ZO_FormatTime(math.floor(GetTimeUntilCanBeTrained() / 1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR) .. ' remaining.')
    --[[
    if self.TimeStamp == nil then
        self.TimeStamp = GetTimeStamp()
    end
    d('Window Time:', GetDiffBetweenTimeStamps(GetTimeStamp(), self.TimeStamp))
    ]]
    local dataLines = {}
    table.insert(dataLines, {
        Name = 'me',
        ShadowySupplier = ZO_FormatTime(GetTimeToShadowyConnectionsResetInSeconds(), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR),
        Stables = ZO_FormatTime(math.floor(GetTimeUntilCanBeTrained() / 1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
    })
    self.GUI.ListHolder.dataLines = dataLines
    self.GUI.ListHolder:SetParent(self.GUI.TopLevel)
    self:InitializeTimeLines(self)
end

function RepeatableActionTimer:ToggleWindow(self)
    self.active = not self.active
    if (self.active) then
        self:Redraw(self)
    end
    if (self.GUI.TopLevel ~= nil) then
        self.GUI.TopLevel:SetHidden(not self.active)
    end
end

--------------------
-- Event Handlers --
--------------------

function RepeatableActionTimer:OnReticleHidden(self, eventCode, retHidden)
    if (self.GUI.TopLevel ~= nil) then
        self.GUI.TopLevel:SetHidden(not (self.active and not retHidden))
    end
end

function RepeatableActionTimer:OnPlayerMove(self, eventCode)
    -- close window if open
    if (self.active) then
        self:ToggleWindow(self)
    end
end

function RepeatableActionTimer:OnQuestRemoved(self, eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questId)
    --d('GCCID:', GCCId())
    --d('QuestID:', questId)
    --d('Completed:', isCompleted)
end

function RepeatableActionTimer:OnUpdate(self)
    self:Redraw(self)
end

----------------------
--  Register Events --
----------------------

EVENT_MANAGER:RegisterForEvent(RepeatableActionTimer.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
