local addonName = ...
local defaults = { afk = 30, fishing = 60, normal = 100, instance = 120, quiet = 90, full = 120 }
local modeNames = { auto = "Auto", quiet = "Quiet", full = "Full" }
local nextMode = { auto = "quiet", quiet = "full", full = "auto" }
-- Forever uses an equipped main-hand fishing pole.
local db, button, settingsCategory
local events = CreateFrame("Frame")

local function ValidFPS(value)
    return type(value) == "number" and value >= 1 and value <= 1000
        and value == math.floor(value)
end

local function HasFishingPole()
    local itemID = GetInventoryItemID("player", GetInventorySlotInfo("MainHandSlot"))
    if not itemID then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    -- Weapon class and fishing-pole subclass IDs work in every locale.
    return classID == 2 and subclassID == 20
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
    if HasFishingPole() then return "fishing", "Fishing rod equipped / " .. location end
    if instanceType == "party" or instanceType == "raid" then
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
    description:SetText("QuietFrames adjusts your frame rate to match what you're doing, helping reduce fan noise, heat, and power use without changing your graphics settings. Choose the frame rates that work best for your system below.")
    description:SetPoint("TOPRIGHT", -16, -48)
    description:SetJustifyH("LEFT")

    -- Quiet section borders keep automatic values separate from manual overrides.
    local function CreateGroup(heading, top, height)
        local group = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        group:SetPoint("TOPLEFT", 16, top)
        group:SetPoint("TOPRIGHT", -16, top)
        group:SetHeight(height)
        group:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        group:SetBackdropColor(0, 0, 0, 0.12)
        group:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.45)
        local headingText = group:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        headingText:SetPoint("TOPLEFT", 14, -12)
        headingText:SetText(heading)
        return group
    end
    local autoGroup = CreateGroup("Auto Mode", -104, 168)
    local manualGroup = CreateGroup("Manual Overrides", -284, 104)

    local rows = {
        { "afk", "AFK", "Lower the frame rate while you're away." },
        { "fishing", "Fishing", "Keep things cool and quiet while you're fishing." },
        { "normal", "Open World", "Your everyday frame rate while exploring the world." },
        { "instance", "Dungeons & Raids", "Allow a higher frame rate when you're in group content." },
        { "quiet", "Quiet Mode", "Use this frame rate whenever Quiet Mode is selected." },
        { "full", "Full Mode", "Use this frame rate whenever Full Mode is selected." },
    }
    local inputs = {}
    for index, row in ipairs(rows) do
        local group = index <= 4 and autoGroup or manualGroup
        local groupIndex = index <= 4 and index or index - 4
        local label = group:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 14, -42 - (groupIndex - 1) * 30)
        label:SetText(row[2])
        local input = CreateFrame("EditBox", nil, group, "InputBoxTemplate")
        input:SetSize(80, 24)
        input:SetPoint("LEFT", group, "TOPLEFT", 284, -46 - (groupIndex - 1) * 30)
        input:SetAutoFocus(false)
        input:SetMaxLetters(4)
        input:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(row[2])
            GameTooltip:AddLine(row[3], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        input:SetScript("OnLeave", function() GameTooltip:Hide() end)
        input:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring(db.fps[row[1]]))
            self:ClearFocus()
        end)
        inputs[row[1]] = input
    end
    local feedback = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    feedback:SetPoint("TOPLEFT", 16, -446)
    feedback:SetWidth(460)
    feedback:SetJustifyH("LEFT")

    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetSize(120, 26)
    save:SetPoint("TOPLEFT", 16, -402)
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
        feedback:SetText("Your frame rates are saved.")
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
        feedback:SetText("In Auto Mode, QuietFrames chooses the appropriate frame rate based on what you're doing. AFK takes priority, then Fishing, followed by your current location. Quiet and Full modes manually override Auto Mode until Auto is selected again.")
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
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED") -- Recheck when the fishing pole is equipped or removed.
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")


events:RegisterEvent("PLAYER_FLAGS_CHANGED") -- Entering or leaving AFK.



