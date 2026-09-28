local addonName = ...
local defaults = { afk = 30, fishing = 60, normal = 100, instance = 141, quiet = 100, full = 141 }
local modeNames = { auto = "Auto", quiet = "Quiet", full = "Full" }
local nextMode = { auto = "quiet", quiet = "full", full = "auto" }
local fishingBuffIDs = { 394009, 1303610 }
local db, button, settingsCategory
local events = CreateFrame("Frame")

local function ValidFPS(value)
    return type(value) == "number" and value >= 1 and value <= 1000
        and value == math.floor(value)
end

local function HasFishingBuff()
    -- Both Retail versions of Fishing for Attention, including newer fishing tools.
    for _, spellID in ipairs(fishingBuffIDs) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        -- Restricted aura results cannot be used for addon decisions.
        if not issecretvalue(aura) and aura ~= nil then return true end
    end
    return false
end

local function Detect()
    local _, instanceType = IsInInstance()
    local locations = {
        none = "Open world", party = "Dungeon", raid = "Raid",
        pvp = "Battleground", arena = "Arena", scenario = "Scenario",
    }
    local location = locations[instanceType] or "Other location"
    local afk = UnitIsAFK("player")
    if not issecretvalue(afk) and afk then return "afk", "AFK / " .. location end
    if HasFishingBuff() then return "fishing", "Fishing for Attention / " .. location end
    if instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then
        return "instance", location
    end
    return "normal", location
end

local function Status()
    local _, activity = Detect()
    return string.format("%s | %s | maxFPS: %s", modeNames[db.mode], activity,
        C_CVar.GetCVar("maxFPS") or "unknown")
end

local function ShowTooltip()
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("QuietFrames", 0.4, 1, 0.7)
    GameTooltip:AddLine("Mode: " .. modeNames[db.mode], 1, 1, 1)
    local _, activity = Detect()
    GameTooltip:AddLine("Detected: " .. activity, 1, 1, 1)
    GameTooltip:AddLine("FPS cap: " .. (C_CVar.GetCVar("maxFPS") or "unknown"), 1, 1, 1)
    GameTooltip:AddLine("Left-click: Auto > Quiet > Full", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click: FPS settings", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function Apply()
    if not db then return end
    local rule = db.mode
    if rule == "auto" then rule = Detect() end
    local target = db.fps[rule]
    -- The only settings write in this addon. Never touch maxFPSBk or other CVars.
    if tonumber(C_CVar.GetCVar("maxFPS")) ~= target then
        C_CVar.SetCVar("maxFPS", tostring(target))
    end
    if button then
        if GameTooltip:IsOwned(button) then ShowTooltip() end
    end
end

local function SetMode(mode)
    db.mode = mode
    Apply()
    print("QuietFrames: " .. Status())
end

local function CreateSettings()
    local panel = CreateFrame("Frame")
    panel:Hide()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("QuietFrames")
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 16, -48)
    description:SetText("Choose your foreground FPS caps. Enter whole numbers from 1 to 1000.\nClick Save to apply and remember your changes.")
    description:SetJustifyH("LEFT")

    local rows = {
        { "afk", "Auto: AFK" },
        { "fishing", "Auto: Fishing for Attention" },
        { "normal", "Auto: Normal / open world" },
        { "instance", "Auto: Dungeon / raid / scenario" },
        { "quiet", "Quiet mode" },
        { "full", "Full mode" },
    }
    local inputs = {}
    for index, row in ipairs(rows) do
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 16, -100 - (index - 1) * 42)
        label:SetText(row[2])
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetSize(80, 24)
        input:SetPoint("LEFT", panel, "TOPLEFT", 300, -104 - (index - 1) * 42)
        input:SetAutoFocus(false)
        input:SetMaxLetters(4)
        input:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring(db.fps[row[1]]))
            self:ClearFocus()
        end)
        inputs[row[1]] = input
    end
    local feedback = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    feedback:SetPoint("TOPLEFT", 16, -412)
    feedback:SetWidth(460)
    feedback:SetJustifyH("LEFT")

    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetSize(120, 26)
    save:SetPoint("TOPLEFT", 16, -362)
    save:SetText("Save")
    save:SetScript("OnClick", function()
        -- Validate every field before changing any saved values.
        for _, row in ipairs(rows) do
            if not ValidFPS(tonumber(inputs[row[1]]:GetText())) then
                feedback:SetText(row[2] .. ": enter a whole number from 1 to 1000.")
                inputs[row[1]]:SetFocus()
                return
            end
        end
        for key, input in pairs(inputs) do
            db.fps[key] = tonumber(input:GetText())
            input:ClearFocus()
        end
        Apply()
        feedback:SetText("Saved. " .. Status())
    end)
    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(150, 26)
    reset:SetPoint("LEFT", save, "RIGHT", 12, 0)
    reset:SetText("Restore defaults")
    reset:SetScript("OnClick", function()
        for key, input in pairs(inputs) do input:SetText(tostring(defaults[key])) end
        feedback:SetText("Default values filled in. Click Save to apply them.")
    end)
    panel:SetScript("OnShow", function()
        for key, input in pairs(inputs) do input:SetText(tostring(db.fps[key])) end
        feedback:SetText("Auto priority: AFK > Fishing > Location. Quiet and Full override activity.")
    end)
    panel:SetScript("OnHide", function()
        for _, input in pairs(inputs) do input:ClearFocus() end
    end)
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "QuietFrames")
    Settings.RegisterAddOnCategory(settingsCategory)
end

local function OpenSettings()
    Settings.OpenToCategory(settingsCategory:GetID())
end

local function CreateButton()
    button = CreateFrame("Button", "QuietFramesMinimapButton", Minimap)
    button:SetSize(26, 26)
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:SetNormalTexture("Interface\\AddOns\\QuietFrames\\Media\\QuietFrames.tga")
    button:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            GameTooltip:Hide()
            OpenSettings()
        else
            SetMode(nextMode[db.mode])
        end
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

SLASH_QUIETFRAMES1 = "/qf"
SLASH_QUIETFRAMES2 = "/quietframes"
SlashCmdList.QUIETFRAMES = function(message)
    if not db then return end
    local command, key, value = message:lower():match("^%s*(%S*)%s*(%S*)%s*(.-)%s*$")
    if modeNames[command] then
        SetMode(command)
    elseif command == "settings" or command == "config" then
        OpenSettings()
    elseif command == "status" or command == "" then
        print("QuietFrames: " .. Status())
    elseif command == "set" and defaults[key] and ValidFPS(tonumber(value)) then
        db.fps[key] = tonumber(value)
        Apply()
        print("QuietFrames: " .. key .. " = " .. db.fps[key] .. " FPS")
    else
        print("QuietFrames: /qf auto | quiet | full | status | settings")
        print("/qf set afk|fishing|normal|instance|quiet|full <FPS integer 1-1000>")
    end
end

events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then return end
        if type(QuietFramesDB) ~= "table" then QuietFramesDB = {} end
        db = QuietFramesDB
        if not modeNames[db.mode] then db.mode = "auto" end
        if type(db.fps) ~= "table" then db.fps = {} end
        for key, value in pairs(defaults) do
            if not ValidFPS(db.fps[key]) then db.fps[key] = value end
        end
        events:UnregisterEvent("ADDON_LOADED")
        CreateSettings()
        CreateButton()
    else
        Apply()
    end
end)

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD") -- Includes login, reload, and instance transitions.
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED") -- Includes profession equipment.
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterUnitEvent("UNIT_AURA", "player") -- Buff gained, refreshed, or removed.
events:RegisterEvent("PLAYER_REGEN_ENABLED") -- Recheck after combat aura restrictions end.

events:RegisterEvent("PLAYER_FLAGS_CHANGED") -- Entering or leaving AFK.
