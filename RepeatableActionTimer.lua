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
    ZO_CreateStringId("SI_BINDING_NAME_ACTION_TIMER_TOGGLE", "Toggle Window Visibility")

    -- Regular Hooks
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_NEW_MOVEMENT_IN_UI_MODE, self.OnPlayerMove)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_REMOVED, self.OnQuestRemoved)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_RETICLE_HIDDEN_UPDATE, self.OnReticleHidden)

    -- Interaction Hooks
    self:OverwritePopulateChatterOption(self, GAMEPAD_INTERACTION)
    self:OverwritePopulateChatterOption(self, INTERACTION) -- keyboard

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

------------------
-- System Hooks --
------------------

local lastInteractableName
ZO_PreHook(FISHING_MANAGER, "StartInteraction", function()
    local _, name = GetGameCameraInteractableActionInfo()
    lastInteractableName = name
end)

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
        version = "1.0",
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

function RepeatableActionTimer:ToggleWindow(self)
    d('Window Toggled!')
end

--------------------
-- Event Handlers --
--------------------

function RepeatableActionTimer.OnReticleHidden(eventCode, retHidden)
  	-- possibly needed for window workflow
    --d('Reticle Hidden!')
end

function RepeatableActionTimer.OnPlayerMove(eventCode)
  	-- close window if open
    d('Player Moved!')
end

function RepeatableActionTimer.OnQuestRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questID)
  	local charId = GCCId()
    d('GCCID:', charId)
    d('QuestID:', questID)
    d('Completed:', isCompleted)
end

function RepeatableActionTimer.OnUpdate()
  	d('Updated!')
end

---------------------
-- Event Overrides --
---------------------

-- override the chatter option function, so we have a location to check access
function RepeatableActionTimer:OverwritePopulateChatterOption(self, interaction)
    local _self = self
    local PopulateChatterOption = interaction.PopulateChatterOption
    interaction.PopulateChatterOption = function(self, index, fun, txt, type, ...)
        -- check if the current target actor is on a timer
        if not _self.timers.actors[lastInteractableName] then
            PopulateChatterOption(self, index, fun, txt, type, ...)
            return
        end
        -- gather data
        local offerText = GetOfferedQuestInfo()
        if (string.len(offerText) > 0) then
            d('Quest:', offerText)
        end
        local farewellText = GetChatterFarewell()
        if (string.len(offerText) > 0) then
            d('Farewell:', farewellText)
        end
        d('Zone:', GetZoneId(GetUnitZoneIndex("player")))
        -- continue
        PopulateChatterOption(self, index, fun, txt, type, ...)
        lastInteractableName = nil -- set this variable to nil, so the next dialog step isn't manipulated
    end
end

----------------------
--  Register Events --
----------------------

EVENT_MANAGER:RegisterForEvent(RepeatableActionTimer.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
