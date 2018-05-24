--------------------------
-- Initialize Variables --
--------------------------

RepeatableActionTimer = {}
RepeatableActionTimer.name = "RepeatableActionTimer"
RepeatableActionTimer.configVersion = 1
RepeatableActionTimer.controls = {}
RepeatableActionTimer.defaults = {
    ShadowySupplier = true
}
RepeatableActionTimer.timers = {}
RepeatableActionTimer.GUI = nil

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

    -- Register our keybinding names
    --ZO_CreateStringId("SI_BINDING_NAME_ACTION_TIMER_TOGGLE", "Toggle Window Visibility")
    ZO_CreateStringId("SI_BINDING_NAME_ACTION_TIMER_TOGGLE", "Display Cooldowns")

    -- System Hooks
    --SM:RegisterTopLevel(RepeatableActionTimer_GUI, false)

    -- Event Hooks
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_NEW_MOVEMENT_IN_UI_MODE, function (...)
      return self:OnPlayerMove(self, ...)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_REMOVED, function (...)
      return self:OnQuestRemoved(self, ...)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_RETICLE_HIDDEN_UPDATE, function (...)
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
        name = "Shadowy Supplier",
        tooltip = "Turn this off if you want to stop tracking Shadowy Supplier interactions.",
        requiresReload = true,
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

function RepeatableActionTimer:Redraw(self)
    --d('Redraw!')
end

function RepeatableActionTimer:ToggleWindow(self)
    --d('Window Toggled:', self.GUI, RepeatableActionTimer_GUI)
    d('Shadowy Supplier: ' .. self:Clock(self, GetTimeToShadowyConnectionsResetInSeconds()) .. ' remaining.')
    d('Stables: ' .. ZO_FormatTimeMilliseconds(GetTimeUntilCanBeTrained(), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR) .. ' remaining.')
    self.active = not self.active
  	if (self.active) then
      self:Redraw(self)
    end
  	--RepeatableActionTimer_GUI:SetHidden(not self.active)
end

--------------------
-- Event Handlers --
--------------------

function RepeatableActionTimer:OnReticleHidden(self, eventCode, retHidden)
  	-- possibly needed for window workflow
end

function RepeatableActionTimer:OnPlayerMove(self, eventCode)
  	-- close window if open
end

function RepeatableActionTimer:OnQuestRemoved(self, eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questID)
  	local charId = GCCId()
    --d('GCCID:', charId)
    --d('QuestID:', questID)
    --d('Completed:', isCompleted)
end

function RepeatableActionTimer:OnUpdate(self)
  	--d('Updated!')
end

----------------------
--  Register Events --
----------------------

EVENT_MANAGER:RegisterForEvent(RepeatableActionTimer.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
