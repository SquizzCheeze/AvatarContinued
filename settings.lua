local addon_name, addon_shared = ...
local _G = getfenv(0);
local Addon = _G[addon_name];

-- ============================================================================
-- Constants & Data Tables
-- ============================================================================

local CATEGORIES = {
    { key = "general",       label = "General",       icon = nil },
    { key = "display",       label = "Display",       icon = nil },
    { key = "outfits",       label = "Outfits",       icon = nil },
    { key = "frame_settings",label = "Frame Settings", icon = nil },
    { key = "misc",          label = "Miscellaneous",  icon = nil },
    { key = "animation",     label = "Animation",      icon = nil },
    { key = "lighting",      label = "Lighting",       icon = nil },
    { key = "profiles",      label = "Profiles",       icon = nil },
};

local ANCHOR_OPTIONS = {
    { text = "TOPLEFT",      value = "TOPLEFT" },
    { text = "TOP",          value = "TOP" },
    { text = "TOPRIGHT",     value = "TOPRIGHT" },
    { text = "LEFT",         value = "LEFT" },
    { text = "CENTER",       value = "CENTER" },
    { text = "RIGHT",        value = "RIGHT" },
    { text = "BOTTOMLEFT",   value = "BOTTOMLEFT" },
    { text = "BOTTOM",       value = "BOTTOM" },
    { text = "BOTTOMRIGHT",  value = "BOTTOMRIGHT" },
};

local STRATA_OPTIONS = {
    { text = "BACKGROUND",          value = "BACKGROUND" },
    { text = "LOW",                 value = "LOW" },
    { text = "MEDIUM",              value = "MEDIUM" },
    { text = "HIGH",                value = "HIGH" },
    { text = "DIALOG",              value = "DIALOG" },
    { text = "FULLSCREEN",          value = "FULLSCREEN" },
    { text = "FULLSCREEN_DIALOG",   value = "FULLSCREEN_DIALOG" },
    { text = "TOOLTIP",             value = "TOOLTIP" },
};

local ANIMATION_OPTIONS = {
    { text = "Idle",       value = 0  },
    { text = "Walk",       value = 4  },
    { text = "Attack",     value = 26 },
    { text = "Spell Cast", value = 48 },
    { text = "Talk",       value = 60 },
    { text = "Dance",      value = 69 },
};

-- ============================================================================
-- Setting Variable Registry
-- Maps setting variables to their DB path, type, and default
-- ============================================================================

local SETTING_META = {
    -- GENERAL
    avatar_enabled       = { dbPath = "enabled",       type = "Boolean", default = true },
    -- DISPLAY
    avatar_show_weapon   = { dbPath = "show.weapon",   type = "Boolean", default = true },
    avatar_show_armor    = { dbPath = "show.armor",    type = "Boolean", default = true },
    avatar_show_tabard   = { dbPath = "show.tabard",   type = "Boolean", default = true },
    avatar_show_shirt    = { dbPath = "show.shirt",    type = "Boolean", default = true },
    avatar_show_pants    = { dbPath = "show.pants",    type = "Boolean", default = true, inverted = true },
    avatar_hide_helm     = { dbPath = "show.helm",     type = "Boolean", default = true, inverted = true },
    avatar_alpha         = { dbPath = "alpha",         type = "Number",  default = 1.0 },
    -- FRAME SETTINGS
    avatar_width         = { dbPath = "size.w",        type = "Number",  default = GetScreenHeight() },
    avatar_height        = { dbPath = "size.h",        type = "Number",  default = GetScreenHeight() },
    avatar_pos_x         = { dbPath = "position.x",    type = "Number",  default = 0 },
    avatar_pos_y         = { dbPath = "position.y",    type = "Number",  default = 0 },
    avatar_anchor_point  = { dbPath = "position.point",type = "String",  default = "CENTER" },
    avatar_rel_point     = { dbPath = "position.relativePoint", type = "String", default = "CENTER" },
    avatar_frame_strata  = { dbPath = "frameStrata",   type = "String",  default = "BACKGROUND" },
    avatar_frame_level   = { dbPath = "frameLevel",    type = "Number",  default = 0 },
    -- perRace: stored per current race+gender (Addon:GetCameraZoomOverride/
    -- SetCameraZoomOverride in core.lua) instead of a flat DB value, since a
    -- single shared zoom broke other races whenever one race (e.g. Dwarf)
    -- needed a very different value. dbPath is unused for this setting.
    avatar_camera_zoom   = { dbPath = "cameraZoom",    type = "Number",  default = 1.0, perRace = true },
    -- MISCELLANEOUS
    avatar_facing        = { dbPath = "facing",        type = "Number",  default = 0, isDegrees = true },
    avatar_hide_combat   = { dbPath = "hideInCombat",  type = "Boolean", default = false },
    -- ANIMATION
    avatar_animation     = { dbPath = "animation",     type = "Number",  default = 0 },
    -- LIGHTING
    avatar_light_yaw     = { dbPath = "light.dya",     type = "Number",  default = 0 },
    avatar_light_pitch   = { dbPath = "light.dza",     type = "Number",  default = -10 },
    avatar_light_di      = { dbPath = "light.di",      type = "Number",  default = 0.8 },
    avatar_light_ai      = { dbPath = "light.ai",      type = "Number",  default = 0.65 },
    avatar_light_direct_color = { dbPath = "light.dr,dg,db", type = "Color", default = { r = 1.0, g = 0.9, b = 0.8 } },
    avatar_light_ambient_color = { dbPath = "light.ar,ag,ab", type = "Color", default = { r = 1.0, g = 1.0, b = 1.0 } },
};

-- ============================================================================
-- Helper to get/set nested DB values
-- ============================================================================

local function GetDBValue(dbPath)
    -- Handle comma-separated color paths
    if dbPath:find(",") then
        local parts = { strsplit(",", dbPath) };
        local result = {};
        for _, part in ipairs(parts) do
            local keys = { strsplit(".", part) };
            local v = Addon.db.profile;
            for _, k in ipairs(keys) do v = v[k]; end
            result[#result + 1] = v;
        end
        return result;
    end

    local keys = { strsplit(".", dbPath) };
    local val = Addon.db.profile;
    for _, key in ipairs(keys) do
        if val == nil then return nil; end
        val = val[key];
    end
    return val;
end

local function SetDBValue(dbPath, value)
    -- Handle comma-separated color paths
    if dbPath:find(",") then
        local parts = { strsplit(",", dbPath) };
        local idx = 1;
        for _, part in ipairs(parts) do
            local keys = { strsplit(".", part) };
            local cursor = Addon.db.profile;
            for i = 1, #keys - 1 do
                if cursor[keys[i]] == nil then cursor[keys[i]] = {}; end
                cursor = cursor[keys[i]];
            end
            cursor[keys[#keys]] = value[idx];
            idx = idx + 1;
        end
        return;
    end

    local keys = { strsplit(".", dbPath) };
    local cursor = Addon.db.profile;
    for i = 1, #keys - 1 do
        if cursor[keys[i]] == nil then cursor[keys[i]] = {}; end
        cursor = cursor[keys[i]];
    end
    cursor[keys[#keys]] = value;
end

-- ============================================================================
-- Settings State
-- ============================================================================

local avatarSettingsPanel = nil;
local avatarSettingsCategory = nil;
local activeCategory = "general";
local categoryButtons = {};
local settingsGroups = {};

-- ============================================================================
-- Apply a setting change to AceDB and live preview
-- ============================================================================

local function ApplySettingChange(variable, rawValue)
    local meta = SETTING_META[variable];
    if not meta then return; end

    local value = rawValue;

    -- Invert for helm (Always Hide Helm = not show.helm)
    if meta.inverted then
        value = not value;
    end

    -- Convert degrees to radians for facing
    if meta.isDegrees then
        value = value * (math.pi / 180.0);
    end

    -- Write to AceDB
    if meta.perRace then
        Addon:SetCameraZoomOverride(value);
    else
        SetDBValue(meta.dbPath, value);
    end

    -- Apply to live model
    Addon:ApplySettingToPreview(variable, value);
end

-- ============================================================================
-- Public API: Apply setting to preview/live model
-- ============================================================================

function Addon:ApplySettingToPreview(variable, value)
    local p = self.db.profile;

    if variable == "avatar_enabled" then
        self:RefreshFrame();
    elseif variable:find("avatar_show_") or variable == "avatar_hide_helm" then
        -- Both directions work with a plain refresh now: ApplyAppearance
        -- either hides the slot (UndressSlot) or writes it back from the
        -- source list (SetItemTransmogInfo). No rebuild needed.
        self:RefreshFrame();
        if self.previewModel then
            self:RefreshEquipmentOnModel(self.previewModel);
        end
    elseif variable == "avatar_hide_combat" then
        -- No immediate visual change, handled by events
    elseif variable == "avatar_alpha" then
        AvatarModelFrame:SetModelAlpha(p.alpha);
        if self.previewModel then
            self.previewModel:SetModelAlpha(p.alpha);
        end
    elseif variable == "avatar_animation" then
        self:ApplyAnimation();
        if self.previewModel then
            self.previewModel:SetAnimation(p.animation);
        end
    elseif variable == "avatar_facing" then
        self:SetFrameSettings();
        if self.previewModel then
            self.previewModel:SetFacing(p.facing);
        end
    elseif variable:find("avatar_light_") then
        self:UpdateLightDirection();
        self:SetFrameSettings();
        if self.previewModel then
            self:ApplyLightingToModel(self.previewModel);
        end
    elseif variable:find("avatar_pos_") or variable:find("avatar_anchor") or
           variable:find("avatar_rel_point") or variable:find("avatar_frame_strata") or
           variable:find("avatar_frame_level") or variable:find("avatar_width") or
           variable:find("avatar_height") then
        self:SetFrameSettings();
    elseif variable == "avatar_camera_zoom" then
        self:UpdateAvatarPositioning();
        if self.previewModel then
            self:UpdateRaceOnModel(self.previewModel);
        end
    end
end

-- ============================================================================
-- Public API: Apply lighting to any model
-- ============================================================================

function Addon:ApplyLightingToModel(model)
    if not model then return; end
    local l = self.db.profile.light;
    model:SetLight(true, {
        omnidirectional = false,
        point = { x = l.dx, y = l.dy, z = l.dz },
        ambientIntensity = l.ai,
        ambientColor = { r = l.ar, g = l.ag, b = l.ab },
        diffuseIntensity = l.di,
        diffuseColor = { r = l.dr, g = l.dg, b = l.db },
    });
end

-- ============================================================================
-- Public API: Refresh equipment on preview model
-- ============================================================================

-- Applies the current settings to a model declaratively -- see
-- Addon:ApplyAppearance (core.lua). No Dress()/Undress()/TryOn() juggling and
-- no second SetUnit(), so this is safe to call as often as needed.
function Addon:RefreshEquipmentOnModel(model)
    if not model then return; end
    local p = self.db.profile;

    Addon:ApplyAppearance(model);

    model:SetModelAlpha(p.alpha);
    model:SetAnimation(p.animation or 0);
end

-- ============================================================================
-- Update Preview Model
-- ============================================================================

function Addon:UpdatePreviewModel()
    local model = self.previewModel;
    if not model then return; end
    local p = self.db.profile;

    -- Same readiness-gated, once-only setup as the main avatar -- see
    -- Addon:SetupModel (core.lua). If the unit isn't model-ready yet this
    -- flags the model and UNIT_MODEL_CHANGED retries it; no timers involved.
    Addon:SetupModel(model);
    Addon:CaptureBaseline(model);

    model:SetModelAlpha(p.alpha);
    model:SetFacing(p.facing);

    -- Scale preview relative to main frame (smaller)
    local previewScale = 0.4;
    model:SetWidth(p.size.w * previewScale);
    model:SetHeight(p.size.h * previewScale);

    self:RefreshEquipmentOnModel(model);
    self:ApplyLightingToModel(model);
    self:UpdateRaceOnModel(model);
end

-- ============================================================================
-- Update race positioning on model
-- ============================================================================

function Addon:UpdateRaceOnModel(model)
    if not model then return; end
    -- Shared with the main avatar frame's positioning (Addon:GetRacePosition /
    -- Addon:GetRaceCamScale in core.lua) so there is exactly one pair of
    -- per-race tables to keep up to date, not two.
    local pos = Addon:GetRacePosition();
    model:SetPosition(0, pos[1], pos[2]);
    model:SetCamDistanceScale(Addon:GetRaceCamScale());
end

-- ============================================================================
-- Profile Management
-- ============================================================================

function Addon:UpdateProfileDropdowns()
    if not avatarSettingsPanel then return; end
    local profiles = self:GetProfileList();
    local entries = {};
    for _, name in ipairs(profiles) do
        table.insert(entries, { text = name, value = name });
    end

    -- Update active profile dropdown
    local actContainer = _G["AVSettings_active_profile"];
    if actContainer and actContainer.UpdateEntries then
        actContainer:UpdateEntries(entries);
        UIDropDownMenu_SetText(actContainer.dropDown, Addon.db:GetCurrentProfile());
    end

    -- Update copy-from dropdown
    local cpContainer = _G["AVSettings_copy_profile"];
    if cpContainer and cpContainer.UpdateEntries then
        cpContainer:UpdateEntries(entries);
    end
end

function Addon:RefreshAllSettingsFromDB()
    -- Mapping: variable -> entries for dropdowns
    local DROPDOWN_ENTRIES = {
        avatar_anchor_point = ANCHOR_OPTIONS,
        avatar_rel_point    = ANCHOR_OPTIONS,
        avatar_frame_strata = STRATA_OPTIONS,
        avatar_animation    = ANIMATION_OPTIONS,
    };

    for variable, meta in pairs(SETTING_META) do
        local widget = _G["AVSettings_" .. variable];
        if widget then
            local rawValue = meta.perRace and Addon:GetCameraZoomOverride() or GetDBValue(meta.dbPath);
            local displayValue = rawValue;

            if meta.inverted then
                displayValue = not rawValue;
            end

            if meta.type == "Boolean" and widget.SetChecked then
                -- Checkbox
                widget:SetChecked(displayValue);

            elseif meta.type == "Number" and widget.slider then
                -- Slider widget
                local sliderValue = displayValue;
                if meta.isDegrees then
                    sliderValue = displayValue * (180.0 / math.pi);
                end
                widget.slider:SetValue(sliderValue);

            elseif meta.type == "Number" and widget.editBox then
                -- EditBox widget (width, height, pos_x, pos_y)
                local numVal = displayValue;
                if meta.isDegrees then
                    numVal = displayValue * (180.0 / math.pi);
                end
                widget.editBox:SetText(tostring(numVal));

            elseif meta.type == "String" and widget.dropDown then
                -- Dropdown widget
                local entries = DROPDOWN_ENTRIES[variable];
                if entries then
                    for _, entry in ipairs(entries) do
                        if entry.value == displayValue then
                            UIDropDownMenu_SetText(widget.dropDown, entry.text);
                            break;
                        end
                    end
                end

            elseif meta.type == "Color" and widget.colorTex then
                -- Color picker
                local r, g, b = 1, 1, 1;
                if rawValue and rawValue[1] then
                    r = rawValue[1] or 1;
                    g = rawValue[2] or 1;
                    b = rawValue[3] or 1;
                end
                widget.colorTex:SetVertexColor(r, g, b);
            end
        end
    end

    -- Update profile dropdowns
    self:UpdateProfileDropdowns();

    -- Update global profile checkbox
    local globalCB = _G["AVSettings_avatar_use_global"];
    if globalCB then
        globalCB:SetChecked(self.db:GetCurrentProfile() == "Global Profile");
    end

    -- Refresh preview
    self:RefreshOutfitsList();
    self:UpdatePreviewModel();
end

-- ============================================================================
-- Panel Script Handlers
-- ============================================================================

function AvatarSettingsPanel_OnLoad(self)
    self.name = "Avatar Continued";
    self:RegisterEvent("PLAYER_REGEN_DISABLED");
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
    self.wasShownForCombat = false;
end

function AvatarSettingsPanel_OnShow(self)
    -- RefreshAllSettingsFromDB() already ends by calling UpdatePreviewModel()
    -- -- calling it again here duplicated SetUnit()/Dress() calls on the
    -- preview model every time the panel opened, which is what was causing
    -- it to render correctly for a moment and then break a beat later.
    Addon:RefreshAllSettingsFromDB();

    -- Hide instructions frame when settings are open
    if AvatarInstructionsFrame then
        AvatarInstructionsFrame:Hide();
    end
end

function AvatarSettingsPanel_OnHide(self)
    -- Show instructions back if frame is unlocked
    if Addon.FrameUnlocked and AvatarInstructionsFrame then
        AvatarInstructionsFrame:Show();
    end
end

-- Event handler for combat hiding
local function HandlePanelEvents(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        if self:IsShown() then
            self.wasShownForCombat = true;
            self:Hide();
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.wasShownForCombat then
            self.wasShownForCombat = false;
            self:Show();
        end
    end
end

-- ============================================================================
-- Category Button Handlers
-- ============================================================================

function AvatarSettingsCategoryButton_OnClick(self)
    local categoryKey = self.categoryKey;
    if not categoryKey or activeCategory == categoryKey then return; end

    activeCategory = categoryKey;

    -- Update button visuals
    for key, btn in pairs(categoryButtons) do
        btn.Selected:Hide();
        btn.Text:SetTextColor(0.9, 0.9, 0.9, 1);
    end
    self.Selected:Show();
    self.Text:SetTextColor(0.78, 0.65, 0.30, 1);

    -- Show active settings group
    for key, group in pairs(settingsGroups) do
        if key == categoryKey then
            group:Show();
        else
            group:Hide();
        end
    end
end

function AvatarSettingsCategoryButton_OnEnter(self)
    if activeCategory ~= self.categoryKey then
        self.Highlight:Show();
    end
end

function AvatarSettingsCategoryButton_OnLeave(self)
    self.Highlight:Hide();
end

-- ============================================================================
-- Preview Frame Template Handler
-- ============================================================================

function AvatarSettingsPreviewTemplate_OnLoad(self)
    if not Mixin then return; end
    Mixin(self, BackdropTemplateMixin);
    self:SetBackdrop({
        bgFile   = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    });
    self:SetBackdropColor(0.06, 0.06, 0.08, 0.96);
    self:SetBackdropBorderColor(0.25, 0.25, 0.30, 1);
end

-- ============================================================================
-- Preview Model Handlers
-- ============================================================================

function AvatarSettingsPreviewModel_OnLoad(self)
    -- DressUpModel may not have SetCustomModel in all versions; guard it
    if self.SetCustomModel then
        self:SetCustomModel(true);
    end

    -- Keep the model loaded when this panel is closed. Without this the
    -- client discards the model on hide and reloads it on show, and that
    -- reload re-derives geosets through the path that corrupts Vulpera's
    -- face -- which is very likely why the Live Preview looked correct on
    -- first open but broken on every reopen. See the matching comment in
    -- AvatarModelFrame_OnLoad (core.lua).
    if self.SetKeepModelOnHide then
        self:SetKeepModelOnHide(true);
    end

    self:EnableMouse(false);
    self:EnableMouseWheel(false);
end

function AvatarSettingsPreviewModel_OnModelLoaded(self)
    -- IMPORTANT: Do NOT call RefreshEquipmentOnModel here — it calls Dress() which
    -- triggers OnModelLoaded again, creating an infinite loop.
    if Addon and Addon.db and Addon.db.profile then
        if self.SetModelAlpha then
            self:SetModelAlpha(Addon.db.profile.alpha);
        end
        if self.SetAnimation then
            self:SetAnimation(Addon.db.profile.animation or 0);
        end
        if Addon.ApplyLightingToModel then
            pcall(Addon.ApplyLightingToModel, Addon, self);
        end
    end
end

function AvatarSettingsPreviewLockButton_OnClick(self)
    if Addon.FrameUnlocked then
        Addon:LockFrame();
        self:SetText("Unlock");
        self:GetParent().Status:SetText("Avatar Locked");
    else
        Addon:UnlockFrame();
        self:SetText("Lock");
        self:GetParent().Status:SetText("Avatar Unlocked");
    end
end

-- ============================================================================
-- Manual Widget Builders (no Settings API initializers)
-- ============================================================================

--- Create a checkbox widget
--- @return table widget  The created frame
local function CreateAVCheckbox(parent, variable, label, tooltip)
    local cb = CreateFrame("CheckButton", "AVSettings_" .. variable, parent, "UICheckButtonTemplate");
    cb:SetSize(28, 28);
    cb:SetScript("OnClick", function(self)
        ApplySettingChange(variable, self:GetChecked());
    end);
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self);
            GameTooltip:SetText(label, 1, 1, 1);
            GameTooltip:AddLine(tooltip, nil, nil, nil, true);
            GameTooltip:Show();
        end);
        cb:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    end

    -- Label
    if cb.Text then
        cb.Text:SetText(label);
    end

    -- Initial value from DB
    local meta = SETTING_META[variable];
    if meta then
        local raw = GetDBValue(meta.dbPath);
        if meta.inverted then raw = not raw; end
        cb:SetChecked(raw);
    end

    return cb;
end

--- Create a slider widget
local function CreateAVSlider(parent, variable, label, tooltip, minVal, maxVal, step, displayFn, width)
    width = width or 380;
    local container = CreateFrame("Frame", "AVSettings_" .. variable, parent);
    container:SetSize(width, 44);

    -- Label
    local labelStr = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    labelStr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -2);
    labelStr:SetText(label);
    labelStr:SetTextColor(0.9, 0.9, 0.9);

    -- Slider (must have a name for OptionsSliderTemplate sub-frames like Low/High/Text)
    local slider = CreateFrame("Slider", "AVSettings_" .. variable .. "Slider", container, "OptionsSliderTemplate");
    slider:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -20);
    slider:SetSize(width - 60, 16);
    slider:SetMinMaxValues(minVal, maxVal);
    slider:SetValueStep(step);
    slider:SetObeyStepOnDrag(true);

    local lowText = _G[slider:GetName() .. "Low"];
    local highText = _G[slider:GetName() .. "High"];
    if lowText then lowText:SetText(tostring(minVal)); end
    if highText then highText:SetText(tostring(maxVal)); end

    -- Value text
    local valueStr = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    valueStr:SetPoint("LEFT", slider, "RIGHT", 8, 0);

    -- Tooltip
    if tooltip then
        slider:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self);
            GameTooltip:SetText(label, 1, 1, 1);
            GameTooltip:AddLine(tooltip, nil, nil, nil, true);
            GameTooltip:Show();
        end);
        slider:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    end

    -- Initial value
    local meta = SETTING_META[variable];
    local initVal;
    if meta and meta.perRace then
        initVal = Addon:GetCameraZoomOverride();
    else
        initVal = meta and GetDBValue(meta.dbPath);
        if initVal == nil then
            initVal = (meta and meta.default) or 0;
        end
    end
    if meta and meta.isDegrees then
        initVal = initVal * (180.0 / math.pi);
    end
    slider:SetValue(initVal);
    if displayFn then
        valueStr:SetText(displayFn(initVal));
    else
        valueStr:SetText(string.format("%.2f", initVal));
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if displayFn then
            valueStr:SetText(displayFn(value));
        else
            valueStr:SetText(string.format("%.2f", value));
        end
        ApplySettingChange(variable, value);
    end);

    container.slider = slider;
    container.valueStr = valueStr;
    return container;
end

--- Create a dropdown widget
local function CreateAVDropdown(parent, variable, label, tooltip, entries)
    local container = CreateFrame("Frame", "AVSettings_" .. variable, parent);
    container:SetSize(380, 44);

    -- Label
    local labelStr = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    labelStr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -2);
    labelStr:SetText(label);
    labelStr:SetTextColor(0.9, 0.9, 0.9);

    -- DropDown
    local dd = CreateFrame("Frame", "AVSettings_" .. variable .. "DD", container, "UIDropDownMenuTemplate");
    dd:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -20);
    dd:SetSize(180, 24);

    -- Initial value
    local meta = SETTING_META[variable];
    local initVal = meta and GetDBValue(meta.dbPath) or nil;

    local function DD_OnClick(self)
        initVal = self.value;
        UIDropDownMenu_SetText(dd, self:GetText());
        UIDropDownMenu_SetSelectedValue(dd, self.value);
        ApplySettingChange(variable, self.value);
    end

    local function DD_Initialize()
        for _, entry in ipairs(entries) do
            local info = UIDropDownMenu_CreateInfo();
            info.text = entry.text;
            info.value = entry.value;
            info.func = DD_OnClick;
            info.checked = (entry.value == initVal);
            UIDropDownMenu_AddButton(info);
        end
    end

    dd:SetScript("OnMouseDown", function(self)
        ToggleDropDownMenu(nil, nil, self);
    end);

    UIDropDownMenu_Initialize(dd, DD_Initialize);
    UIDropDownMenu_SetWidth(dd, 170);

    -- Set initial text
    for _, entry in ipairs(entries) do
        if entry.value == initVal then
            UIDropDownMenu_SetText(dd, entry.text);
            break;
        end
    end

    if tooltip then
        dd:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self);
            GameTooltip:SetText(label, 1, 1, 1);
            GameTooltip:AddLine(tooltip, nil, nil, nil, true);
            GameTooltip:Show();
        end);
        dd:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    end

    container.dropDown = dd;
    container.DD_Initialize = DD_Initialize;
    container.DD_OnClick = DD_OnClick;

    -- Add a SetEntries function for dynamic update
    function container:SetEntries(newEntries)
        entries = newEntries;
        UIDropDownMenu_Initialize(dd, DD_Initialize);
    end

    return container;
end

--- Create a color picker widget
local function CreateAVColorPicker(parent, variable, label, tooltip)
    local container = CreateFrame("Frame", "AVSettings_" .. variable, parent);
    container:SetSize(190, 44);

    -- Label
    local labelStr = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    labelStr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -2);
    labelStr:SetText(label);
    labelStr:SetTextColor(0.9, 0.9, 0.9);

    -- ColorSwatch button
    local swatch = CreateFrame("Button", nil, container);
    swatch:SetSize(24, 24);
    swatch:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -20);

    local bg = swatch:CreateTexture(nil, "BACKGROUND");
    bg:SetAllPoints();
    bg:SetColorTexture(0, 0, 0, 1);

    local color = swatch:CreateTexture(nil, "ARTWORK");
    color:SetAllPoints();
    color:SetDrawLayer("ARTWORK", 1);

    local border = swatch:CreateTexture(nil, "OVERLAY");
    border:SetAllPoints();
    border:SetTexture("Interface\\BUTTONS\\WHITE8X8");
    border:SetVertexColor(0.6, 0.6, 0.6, 1);
    border:SetDrawLayer("OVERLAY", 2);

    -- Initial color
    local meta = SETTING_META[variable];
    local r, g, b = 1, 1, 1;
    if meta then
        local raw = GetDBValue(meta.dbPath);
        if raw and raw[1] then
            r = raw[1] or 1;
            g = raw[2] or 1;
            b = raw[3] or 1;
        elseif raw and raw.r then
            r = raw.r or 1;
            g = raw.g or 1;
            b = raw.b or 1;
        end
    end
    color:SetVertexColor(r, g, b);

    swatch:SetScript("OnClick", function(self)
        ColorPickerFrame:SetupRGB(function(cInfo)
            local nr, ng, nb = ColorPickerFrame:GetColorRGB();
            color:SetVertexColor(nr, ng, nb);
            ApplySettingChange(variable, { nr, ng, nb });
        end, r, g, b, "Avatar: " .. label, nil, nil, nil, nil);
        ColorPickerFrame:Show();
    end);

    if tooltip then
        swatch:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self);
            GameTooltip:SetText(label, 1, 1, 1);
            GameTooltip:AddLine(tooltip, nil, nil, nil, true);
            GameTooltip:Show();
        end);
        swatch:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    end

    container.swatch = swatch;
    container.colorTex = color;
    return container;
end

--- Create an edit box widget
local function CreateAVEditBox(parent, variable, label, tooltip, width)
    local container = CreateFrame("Frame", "AVSettings_" .. variable, parent);
    container:SetSize(width or 180, 44);

    -- Label
    local labelStr = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    labelStr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -2);
    labelStr:SetText(label);
    labelStr:SetTextColor(0.9, 0.9, 0.9);

    -- EditBox
    local eb = CreateFrame("EditBox", "AVSettings_" .. variable .. "EB", container, "InputBoxTemplate");
    eb:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -20);
    eb:SetSize((width or 180) - 8, 20);
    eb:SetAutoFocus(false);

    -- Initial value
    local meta = SETTING_META[variable];
    local initVal = meta and GetDBValue(meta.dbPath) or "";
    eb:SetText(tostring(initVal));

    eb:SetScript("OnEnterPressed", function(self)
        local val = self:GetText();
        local num = tonumber(val);
        if num then
            ApplySettingChange(variable, num);
        else
            ApplySettingChange(variable, val);
        end
        self:ClearFocus();
    end);

    eb:SetScript("OnEditFocusLost", function(self)
        -- Restore value from DB on abandon
        local meta = SETTING_META[variable];
        if meta then
            local val = GetDBValue(meta.dbPath);
            self:SetText(tostring(val));
        end
    end);

    if tooltip then
        eb:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self);
            GameTooltip:SetText(label, 1, 1, 1);
            GameTooltip:AddLine(tooltip, nil, nil, nil, true);
            GameTooltip:Show();
        end);
        eb:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    end

    container.editBox = eb;
    return container;
end

-- ============================================================================
-- Section Header & Divider Helpers
-- ============================================================================

local function CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset);
    header:SetText(text);
    header:SetTextColor(0.78, 0.65, 0.30, 1);
    return header;
end

local function CreateDivider(parent, yOffset)
    local line = parent:CreateTexture(nil, "ARTWORK");
    line:SetHeight(1);
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset);
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset);
    line:SetColorTexture(0.25, 0.25, 0.30, 0.3);
    return line;
end

-- ============================================================================
-- Create the Settings Panel
-- ============================================================================

function Addon:CreateSettingsPanel()
    if avatarSettingsPanel then
        avatarSettingsPanel:Show();
        self:RefreshAllSettingsFromDB();
        return;
    end

    -- ==========================================================================
    -- Main panel frame
    -- ==========================================================================
    avatarSettingsPanel = CreateFrame("Frame", "AvatarSettingsPanel", UIParent, "BackdropTemplate");
    avatarSettingsPanel:SetSize(960, 680);
    avatarSettingsPanel:SetPoint("CENTER");
    avatarSettingsPanel:SetFrameStrata("DIALOG");
    avatarSettingsPanel:SetMovable(true);
    avatarSettingsPanel:EnableMouse(true);
    avatarSettingsPanel:EnableKeyboard(true);
    avatarSettingsPanel.name = "Avatar Continued";
    table.insert(UISpecialFrames, "AvatarSettingsPanel");
    avatarSettingsPanel:SetBackdrop({
        bgFile   = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    });
    avatarSettingsPanel:SetBackdropColor(0.05, 0.05, 0.06, 1);
    avatarSettingsPanel:SetBackdropBorderColor(0.3, 0.3, 0.35, 1);

    -- Drag-to-move mechanism
    avatarSettingsPanel:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving();
        end
    end);
    avatarSettingsPanel:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:StopMovingOrSizing();
        end
    end);

    -- Title bar / drag handle
    local titleBar = CreateFrame("Frame", nil, avatarSettingsPanel, "BackdropTemplate");
    titleBar:SetPoint("TOPLEFT", avatarSettingsPanel, "TOPLEFT", 0, 0);
    titleBar:SetPoint("TOPRIGHT", avatarSettingsPanel, "TOPRIGHT", 0, 0);
    titleBar:SetHeight(32);
    titleBar:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
    });
    titleBar:SetBackdropColor(0.1, 0.1, 0.14, 1);
    titleBar:SetBackdropBorderColor(0.3, 0.3, 0.35, 1);
    titleBar:EnableMouse(true);
    titleBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            avatarSettingsPanel:StartMoving();
        end
    end);
    titleBar:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            avatarSettingsPanel:StopMovingOrSizing();
        end
    end);

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    titleText:SetPoint("LEFT", titleBar, "LEFT", 12, 0);
    titleText:SetText("Avatar Continued — Settings");
    titleText:SetTextColor(0.78, 0.65, 0.30, 1);

    -- Close button (X) in title bar
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton");
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -4, -4);
    closeBtn:SetScript("OnClick", function()
        avatarSettingsPanel:Hide();
    end);

    -- Hook scripts
    AvatarSettingsPanel_OnLoad(avatarSettingsPanel);
    avatarSettingsPanel:SetScript("OnShow", AvatarSettingsPanel_OnShow);
    avatarSettingsPanel:SetScript("OnHide", AvatarSettingsPanel_OnHide);
    avatarSettingsPanel:SetScript("OnEvent", HandlePanelEvents);

    -- Register with Settings API (for Game Menu integration)
    -- FIXED: No extra 'Settings' argument in pcall — pass args directly
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, avatarSettingsPanel, avatarSettingsPanel.name);
    if ok then
        avatarSettingsCategory = cat;
        pcall(Settings.RegisterAddOnCategory, avatarSettingsCategory);
    else
        avatarSettingsCategory = nil;
    end

    -- ==========================================================================
    -- LEFT COLUMN: Category List
    -- ==========================================================================
    local categoryList = CreateFrame("Frame", nil, avatarSettingsPanel, "BackdropTemplate");
    categoryList:SetPoint("TOPLEFT", avatarSettingsPanel, "TOPLEFT", 4, -40);
    categoryList:SetSize(164, 640);
    categoryList:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    });
    categoryList:SetBackdropColor(0.1, 0.1, 0.13, 1);
    categoryList:SetBackdropBorderColor(0.25, 0.25, 0.30, 1);

    local categoryTitle = categoryList:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    categoryTitle:SetPoint("TOPLEFT", categoryList, "TOPLEFT", 12, -8);
    categoryTitle:SetText("CATEGORIES");
    categoryTitle:SetTextColor(0.55, 0.55, 0.58);

    local catY = -32;
    for _, cat in ipairs(CATEGORIES) do
        local btn = CreateFrame("Button", nil, categoryList, "AvatarSettingsCategoryButtonTemplate");
        btn:SetPoint("TOPLEFT", categoryList, "TOPLEFT", 2, catY);
        btn.categoryKey = cat.key;
        btn.Text:SetText(cat.label);
        categoryButtons[cat.key] = btn;
        catY = catY - 34;
    end

    -- ==========================================================================
    -- CENTER COLUMN: Settings Content (Scrollable)
    -- ==========================================================================
    local settingsFrame = CreateFrame("ScrollFrame", nil, avatarSettingsPanel, "UIPanelScrollFrameTemplate");
    settingsFrame:SetPoint("TOPLEFT", categoryList, "TOPRIGHT", 4, 0);
    settingsFrame:SetPoint("BOTTOMRIGHT", avatarSettingsPanel, "BOTTOMRIGHT", -390, 4);

    -- Hide the scrollbar (UIPanelScrollFrameTemplate creates it with parentKey="ScrollBar")
    if settingsFrame.ScrollBar then
        settingsFrame.ScrollBar:Hide();
    end

    local settingsContent = CreateFrame("Frame", nil, settingsFrame);
    settingsContent:SetWidth(390);
    settingsFrame:SetScrollChild(settingsContent);

    -- ==========================================================================
    -- Build each settings group
    -- ==========================================================================
    local maxY = 0;

    local function buildGroup(key, builder)
        local group = CreateFrame("Frame", nil, settingsContent);
        group:SetPoint("TOPLEFT", settingsContent, "TOPLEFT", 0, 0);
        group:SetSize(390, 1);
        local yEnd = builder(group, -12);
        local h = math.abs(yEnd) + 20;
        group:SetHeight(h);
        if h > maxY then maxY = h; end
        if key ~= "general" then group:Hide(); end
        settingsGroups[key] = group;
    end

    buildGroup("general", function(g, y) return self:BuildGeneralSettings(g, y); end);
    buildGroup("display", function(g, y) return self:BuildDisplaySettings(g, y); end);
    buildGroup("outfits", function(g, y) return self:BuildOutfitsSettings(g, y); end);
    buildGroup("frame_settings", function(g, y) return self:BuildFrameSettings(g, y); end);
    buildGroup("misc", function(g, y) return self:BuildMiscSettings(g, y); end);
    buildGroup("animation", function(g, y) return self:BuildAnimationSettings(g, y); end);
    buildGroup("lighting", function(g, y) return self:BuildLightingSettings(g, y); end);
    buildGroup("profiles", function(g, y) return self:BuildProfileSettings(g, y); end);

    settingsContent:SetHeight(maxY + 40);

    -- ==========================================================================
    -- RIGHT COLUMN: Live Preview
    -- ==========================================================================
    local previewFrame = CreateFrame("Frame", nil, avatarSettingsPanel, "AvatarSettingsPreviewTemplate");
    previewFrame:SetPoint("TOPRIGHT", avatarSettingsPanel, "TOPRIGHT", -4, -40);
    previewFrame.Model:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 4, -44);
    previewFrame.Model:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", -4, 44);
    previewFrame.Title:SetText("Live Preview");
    previewFrame.ControlBar.Status:SetText(Addon.FrameUnlocked and "Avatar Unlocked" or "Avatar Locked");
    previewFrame.ControlBar.LockButton:SetText(Addon.FrameUnlocked and "Lock" or "Unlock");

    -- Register the preview model for API access
    Addon.previewModel = previewFrame.Model;

    -- Initialize preview
    self:UpdatePreviewModel();

    -- Activate first category
    if categoryButtons["general"] then
        categoryButtons["general"]:GetScript("OnClick")(categoryButtons["general"]);
    end

    avatarSettingsPanel:Show();
end

-- ============================================================================
-- Build: GENERAL Settings
-- ============================================================================

function Addon:BuildGeneralSettings(parent, sy)
    local cb = CreateAVCheckbox(parent, "avatar_enabled", "Enable Avatar",
        "Show your character model on screen");
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 36;

    -- Unlock Frame button
    local unlockBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
    unlockBtn:SetSize(160, 24);
    unlockBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    unlockBtn:SetText("Toggle Unlock Frame");

    local function UpdateUnlockBtn()
        unlockBtn:SetText(Addon.FrameUnlocked and "Lock Frame" or "Unlock Frame");
    end

    unlockBtn:SetScript("OnClick", function()
        if Addon.FrameUnlocked then
            Addon:LockFrame();
        else
            Addon:UnlockFrame();
        end
        UpdateUnlockBtn();
        -- Update preview lock button too
        if Addon.previewModel then
            local cb = Addon.previewModel:GetParent().ControlBar;
            if cb then
                cb.Status:SetText(Addon.FrameUnlocked and "Avatar Unlocked" or "Avatar Locked");
                cb.LockButton:SetText(Addon.FrameUnlocked and "Lock" or "Unlock");
            end
        end
    end);
    UpdateUnlockBtn();
    sy = sy - 36;

    CreateDivider(parent, sy);
    sy = sy - 16;

    return sy;
end

-- ============================================================================
-- Build: DISPLAY Settings
-- ============================================================================

function Addon:BuildDisplaySettings(parent, sy)
    local function addCB(var, label, tip)
        local cb = CreateAVCheckbox(parent, var, label, tip);
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
        sy = sy - 36;
    end

    addCB("avatar_show_weapon", "Show Weapon", "Display or hide weapons");
    addCB("avatar_show_armor", "Show Armor", "Display or hide armor");
    addCB("avatar_show_tabard", "Show Tabard", "Display or hide tabard");
    addCB("avatar_show_shirt", "Show Shirt", "Display or hide shirt");
    addCB("avatar_show_pants", "Get Ya Pants Off", "Display or hide pants (legs)");

    local helmCB = CreateAVCheckbox(parent, "avatar_hide_helm", "Always Hide Helm",
        "Hide helmet display (checked = hide)");
    helmCB:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 36;

    -- Alpha slider
    local alpha = CreateAVSlider(parent, "avatar_alpha", "Avatar Opacity",
        "Adjust the transparency of your avatar", 0, 1, 0.01,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)); end);
    alpha:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 56;

    CreateDivider(parent, sy);
    sy = sy - 16;

    return sy;
end

-- ============================================================================
-- Build: OUTFITS Settings
-- ============================================================================

local OUTFIT_ROW_HEIGHT = 32;
local outfitRows = {};

--- Rebuilds the outfit list rows from C_TransmogCollection.GetCustomSets().
--- Safe to call any time (e.g. after TRANSMOG_COLLECTION_UPDATED) even if the
--- Outfits tab has never been shown yet.
function Addon:RefreshOutfitsList()
    local content = self.outfitsListContent;
    if not content then return; end

    for _, row in ipairs(outfitRows) do
        row:Hide();
        row:SetParent(nil);
    end
    wipe(outfitRows);

    local charData = self.db.char;
    local activeCustomSetID = charData.outfitPreview and charData.outfitPreview.enabled and charData.outfitPreview.customSetID or nil;

    local function CreateOutfitRow(label, icon, customSetID)
        local row = CreateFrame("Button", nil, content);
        row:SetSize(354, OUTFIT_ROW_HEIGHT - 2);

        local selectedTex = row:CreateTexture(nil, "BACKGROUND");
        selectedTex:SetAllPoints();
        selectedTex:SetColorTexture(0.78, 0.65, 0.30, 0.25);
        selectedTex:SetShown(activeCustomSetID == customSetID);
        row.selectedTex = selectedTex;

        local highlight = row:CreateTexture(nil, "HIGHLIGHT");
        highlight:SetAllPoints();
        highlight:SetColorTexture(1, 1, 1, 0.08);

        if icon then
            local ic = row:CreateTexture(nil, "ARTWORK");
            ic:SetSize(22, 22);
            ic:SetPoint("LEFT", row, "LEFT", 4, 0);
            ic:SetTexture(icon);
            row.icon = ic;
        end

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        text:SetPoint("LEFT", row, "LEFT", icon and 32 or 8, 0);
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0);
        text:SetJustifyH("LEFT");
        text:SetText(label);

        row:SetScript("OnClick", function()
            if customSetID then
                charData.outfitPreview.enabled = true;
                charData.outfitPreview.customSetID = customSetID;
            else
                charData.outfitPreview.enabled = false;
            end

            -- Selecting an outfit and going back to real gear are now the
            -- same operation with a different source list -- see
            -- Addon:ApplyAppearance (core.lua). No rebuild, no race gate,
            -- and nothing that needs a /reload.
            Addon:RefreshEquipmentToggle();
            if Addon.previewModel then
                Addon:RefreshEquipmentOnModel(Addon.previewModel);
            end

            Addon:RefreshOutfitsList();
        end);

        return row;
    end

    local y = 0;
    local noneRow = CreateOutfitRow("Show Equipped Gear (No Preview)", nil, nil);
    noneRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y);
    noneRow.selectedTex:SetShown(not activeCustomSetID);
    table.insert(outfitRows, noneRow);
    y = y - OUTFIT_ROW_HEIGHT;

    local customSets = C_TransmogCollection.GetCustomSets() or {};
    if #customSets == 0 then
        local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
        emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y - 6);
        emptyText:SetText("No saved outfits yet. Save one from the in-game Wardrobe (Dressing Room).");
        emptyText:SetWidth(354);
        emptyText:SetJustifyH("LEFT");
        table.insert(outfitRows, emptyText);
        y = y - 32;
    else
        for _, customSetID in ipairs(customSets) do
            local name, icon = C_TransmogCollection.GetCustomSetInfo(customSetID);
            if name then
                local row = CreateOutfitRow(name, icon, customSetID);
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y);
                table.insert(outfitRows, row);
                y = y - OUTFIT_ROW_HEIGHT;
            end
        end
    end

    content:SetHeight(math.max(math.abs(y), 1));
end

function Addon:BuildOutfitsSettings(parent, sy)
    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    hint:SetWidth(370);
    hint:SetJustifyH("LEFT");
    hint:SetText("Preview a saved Wardrobe outfit on your Avatar instead of your currently equipped gear. The preview stays applied through gear/transmog changes until you pick \"Show Equipped Gear\" again.");
    sy = sy - 46;

    CreateDivider(parent, sy);
    sy = sy - 12;

    local listHeight = 420;
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate");
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    scrollFrame:SetSize(360, listHeight);
    scrollFrame:EnableMouseWheel(true);
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local sb = self.ScrollBar;
        if not sb then return; end
        local minV, maxV = sb:GetMinMaxValues();
        sb:SetValue(math.max(minV, math.min(maxV, sb:GetValue() - delta * 40)));
    end);

    local content = CreateFrame("Frame", nil, scrollFrame);
    content:SetWidth(354);
    content:SetHeight(1);
    scrollFrame:SetScrollChild(content);
    self.outfitsListContent = content;

    self:RefreshOutfitsList();

    sy = sy - listHeight - 16;

    return sy;
end

-- ============================================================================
-- Build: FRAME SETTINGS
-- ============================================================================

function Addon:BuildFrameSettings(parent, sy)
    -- Width & Height in one row (two columns)
    local wBox = CreateAVEditBox(parent, "avatar_width", "Frame Width",
        "Width of the avatar frame in pixels", 180);
    wBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);

    local hBox = CreateAVEditBox(parent, "avatar_height", "Frame Height",
        "Height of the avatar frame in pixels", 180);
    hBox:SetPoint("LEFT", wBox, "RIGHT", 8, 0);
    sy = sy - 52;

    -- Position X & Y
    local xBox = CreateAVEditBox(parent, "avatar_pos_x", "Position X",
        "Horizontal offset from anchor point", 180);
    xBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);

    local yBox = CreateAVEditBox(parent, "avatar_pos_y", "Position Y",
        "Vertical offset from anchor point", 180);
    yBox:SetPoint("LEFT", xBox, "RIGHT", 8, 0);
    sy = sy - 52;

    -- Anchor Point & Relative Point dropdowns
    local ptDD = CreateAVDropdown(parent, "avatar_anchor_point", "Anchor Point",
        "Which point on the frame is anchored", ANCHOR_OPTIONS);
    ptDD:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);

    local rpDD = CreateAVDropdown(parent, "avatar_rel_point", "Relative Point",
        "Which point of the parent anchors to", ANCHOR_OPTIONS);
    rpDD:SetPoint("LEFT", ptDD, "RIGHT", 8, 0);
    sy = sy - 52;

    -- Frame Strata dropdown
    local strDD = CreateAVDropdown(parent, "avatar_frame_strata", "Frame Strata",
        "Display layer of the avatar frame", STRATA_OPTIONS);
    strDD:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 52;

    -- Frame Level slider
    local lvl = CreateAVSlider(parent, "avatar_frame_level", "Frame Level",
        "Z-ordering within the strata (higher = on top)", 0, 100, 1);
    lvl:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 56;

    -- Camera Zoom slider (multiplies the per-race camera distance)
    local zoom = CreateAVSlider(parent, "avatar_camera_zoom", "Camera Zoom",
        "Multiplies the camera distance for your race -- use this to correct framing if your avatar looks too close/zoomed-in or too far away",
        0.3, 3.0, 0.05, function(v) return string.format("%.2fx", v); end);
    zoom:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 56;

    CreateDivider(parent, sy);
    sy = sy - 16;

    return sy;
end

-- ============================================================================
-- Build: MISCELLANEOUS Settings
-- ============================================================================

function Addon:BuildMiscSettings(parent, sy)
    -- Facing slider
    local facing = CreateAVSlider(parent, "avatar_facing", "Avatar Facing (degrees)",
        "Rotate your avatar left or right (-180 to 180)", -180, 180, 1);
    facing:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 56;

    -- Hide in Combat checkbox
    local combatCB = CreateAVCheckbox(parent, "avatar_hide_combat", "Hide Avatar in Combat",
        "Automatically hide the avatar when entering combat");
    combatCB:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 36;

    CreateDivider(parent, sy);
    sy = sy - 16;

    return sy;
end

-- ============================================================================
-- Build: ANIMATION Settings
-- ============================================================================

function Addon:BuildAnimationSettings(parent, sy)
    local animDD = CreateAVDropdown(parent, "avatar_animation", "Pose / Animation",
        "Choose which animation the avatar should play", ANIMATION_OPTIONS);
    animDD:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 52;

    CreateDivider(parent, sy);
    sy = sy - 16;

    return sy;
end

-- ============================================================================
-- Build: LIGHTING Settings
-- ============================================================================

function Addon:BuildLightingSettings(parent, sy)
    -- Yaw & Pitch sliders side by side
    local yaw = CreateAVSlider(parent, "avatar_light_yaw", "Light Yaw",
        "Horizontal direction of the direct light source", -180, 180, 1,
        function(v) return string.format("%.0f\194\176", v); end, 185);
    yaw:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);

    local pitch = CreateAVSlider(parent, "avatar_light_pitch", "Light Pitch",
        "Vertical direction of the direct light source", -180, 180, 1,
        function(v) return string.format("%.0f\194\176", v); end, 185);
    pitch:SetPoint("LEFT", yaw, "RIGHT", 8, 0);
    sy = sy - 56;

    -- Direct & Ambient Intensity
    local di = CreateAVSlider(parent, "avatar_light_di", "Direct Intensity",
        "Brightness of the direct light", 0, 1, 0.01,
        function(v) return string.format("%.2f", v); end, 185);
    di:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);

    local ai = CreateAVSlider(parent, "avatar_light_ai", "Ambient Intensity",
        "Brightness of the ambient (fill) light", 0, 1, 0.01,
        function(v) return string.format("%.2f", v); end, 185);
    ai:SetPoint("LEFT", di, "RIGHT", 8, 0);
    sy = sy - 56;

    -- Color pickers
    local dc = CreateAVColorPicker(parent, "avatar_light_direct_color", "Direct Light Color",
        "Color of the direct light source");
    dc:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);

    local ac = CreateAVColorPicker(parent, "avatar_light_ambient_color", "Ambient Light Color",
        "Color of the ambient (fill) light");
    ac:SetPoint("LEFT", dc, "RIGHT", 8, 0);
    sy = sy - 52;

    CreateDivider(parent, sy);
    sy = sy - 16;

    return sy;
end

-- ============================================================================
-- Build: PROFILE Settings
-- ============================================================================

function Addon:BuildProfileSettings(parent, sy)
    -- Use Global Profile checkbox
    local globalCB = CreateFrame("CheckButton", "AVSettings_avatar_use_global", parent, "UICheckButtonTemplate");
    globalCB:SetSize(28, 28);
    globalCB:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    if globalCB.Text then
        globalCB.Text:SetText("Use Global Profile (shared across all characters)");
    end
    globalCB:SetChecked(Addon.db:GetCurrentProfile() == "Global Profile");
    globalCB:SetScript("OnClick", function(self)
        Addon:ToggleGlobalProfile(self:GetChecked());
        Addon:UpdateProfileDropdowns();
    end);
    sy = sy - 36;

    -- Active Profile dropdown
    local profiles = Addon:GetProfileList();
    local profileEntries = {};
    for _, name in ipairs(profiles) do
        table.insert(profileEntries, { text = name, value = name });
    end

    -- Build active profile dropdown manually (non-standard behavior)
    local actContainer = CreateFrame("Frame", "AVSettings_active_profile", parent);
    actContainer:SetSize(380, 44);
    local actLabel = actContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    actLabel:SetPoint("TOPLEFT", actContainer, "TOPLEFT", 4, -2);
    actLabel:SetText("Active Profile");
    actLabel:SetTextColor(0.9, 0.9, 0.9);
    local actDD = CreateFrame("Frame", "AVSettings_active_profile_DD", actContainer, "UIDropDownMenuTemplate");
    actDD:SetPoint("TOPLEFT", actContainer, "TOPLEFT", 4, -20);
    actDD:SetSize(180, 24);
    UIDropDownMenu_SetWidth(actDD, 170);
    UIDropDownMenu_SetText(actDD, Addon.db:GetCurrentProfile());
    local actEntries = profileEntries;
    local function ActDD_OnClick(self)
        UIDropDownMenu_SetText(actDD, self:GetText());
        Addon:ChangeProfileByName(self.value);
    end
    local function ActDD_Init()
        local info = UIDropDownMenu_CreateInfo();
        for _, entry in ipairs(actEntries) do
            info.text = entry.text;
            info.value = entry.value;
            info.func = ActDD_OnClick;
            UIDropDownMenu_AddButton(info);
        end
    end
    UIDropDownMenu_Initialize(actDD, ActDD_Init);
    actDD:SetScript("OnMouseDown", function(self) ToggleDropDownMenu(nil, nil, self); end);
    actContainer.dropDown = actDD;
    function actContainer:UpdateEntries(newEntries)
        actEntries = newEntries;
        UIDropDownMenu_Initialize(actDD, ActDD_Init);
    end
    actContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 52;

    -- New Profile button
    local newBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
    newBtn:SetSize(120, 24);
    newBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    newBtn:SetText("New Profile");
    newBtn:SetScript("OnClick", function()
        StaticPopup_Show("AVATAR_NEW_PROFILE");
    end);

    -- Delete Profile button
    local delBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
    delBtn:SetSize(100, 24);
    delBtn:SetPoint("LEFT", newBtn, "RIGHT", 8, 0);
    delBtn:SetText("Delete Current");
    delBtn:SetScript("OnClick", function()
        local name = Addon.db:GetCurrentProfile();
        AVATAR_DELETE_PROFILE_NAME = name;
        if avatarSettingsPanel then
            avatarSettingsPanel:Hide();
        end
        StaticPopup_Show("AVATAR_DELETE_PROFILE_CONFIRM", name);
    end);
    sy = sy - 36;

    -- Copy from Profile dropdown
    local cpContainer = CreateFrame("Frame", "AVSettings_copy_profile", parent);
    cpContainer:SetSize(380, 44);
    local cpLabel = cpContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    cpLabel:SetPoint("TOPLEFT", cpContainer, "TOPLEFT", 4, -2);
    cpLabel:SetText("Copy settings from:");
    cpLabel:SetTextColor(0.9, 0.9, 0.9);
    local cpDD = CreateFrame("Frame", "AVSettings_copy_profile_DD", cpContainer, "UIDropDownMenuTemplate");
    cpDD:SetPoint("TOPLEFT", cpContainer, "TOPLEFT", 4, -20);
    cpDD:SetSize(180, 24);
    UIDropDownMenu_SetWidth(cpDD, 170);
    local cpEntries = profileEntries;
    local function CpDD_OnClick(self)
        UIDropDownMenu_SetText(cpDD, self:GetText());
        Addon:CopyProfileByName(self.value);
    end
    local function CpDD_Init()
        local info = UIDropDownMenu_CreateInfo();
        for _, entry in ipairs(cpEntries) do
            info.text = entry.text;
            info.value = entry.value;
            info.func = CpDD_OnClick;
            UIDropDownMenu_AddButton(info);
        end
    end
    UIDropDownMenu_Initialize(cpDD, CpDD_Init);
    cpDD:SetScript("OnMouseDown", function(self) ToggleDropDownMenu(nil, nil, self); end);
    cpContainer.dropDown = cpDD;
    function cpContainer:UpdateEntries(newEntries)
        cpEntries = newEntries;
        UIDropDownMenu_Initialize(cpDD, CpDD_Init);
    end
    cpContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, sy);
    sy = sy - 52;

    return sy;
end

-- ============================================================================
-- Refreshes the settings panel's data/preview-model path (building the panel
-- if it doesn't exist yet) without ever letting it actually render on screen
-- -- hidden in the same tick it's built, before it can be composited. Used
-- as a workaround nudge after a fresh login: something about building/
-- refreshing this path (specifically the preview DressUpModel it creates)
-- unsticks AvatarModelFrame's render when called right after the outfit
-- preview has just been applied to it. No visible flash needed.
-- ============================================================================

function Addon:RefreshSettingsDataOnly()
    if not avatarSettingsPanel then
        self:CreateSettingsPanel();
        avatarSettingsPanel:Hide();
    else
        self:RefreshAllSettingsFromDB();
    end
end

-- ============================================================================
-- Public API: Show settings panel
-- ============================================================================

function Addon:ShowSettingsPanel()
    if not avatarSettingsPanel then
        self:CreateSettingsPanel();
        return;
    end

    avatarSettingsPanel:Show();
    avatarSettingsPanel:Raise();

    -- Sync data
    self:RefreshAllSettingsFromDB();
    self:UpdateProfileDropdowns();

    -- Update lock button state
    if self.previewModel then
        local controlBar = self.previewModel:GetParent().ControlBar;
        if controlBar then
            controlBar.Status:SetText(Addon.FrameUnlocked and "Avatar Unlocked" or "Avatar Locked");
            controlBar.LockButton:SetText(Addon.FrameUnlocked and "Lock" or "Unlock");
        end
    end
end

-- ============================================================================
-- Override ShowOptions to use new panel
-- ============================================================================

function Addon:ShowOptions()
    Addon:LockFrame();
    self:ShowSettingsPanel();
end

-- ============================================================================
-- Handle OnProfileChanged from AceDB
-- ============================================================================

local _origOnProfileChanged = Addon.OnProfileChanged;
function Addon:OnProfileChanged(...)
    if _origOnProfileChanged then
        _origOnProfileChanged(self, ...);
    end
    if avatarSettingsPanel and avatarSettingsPanel:IsShown() then
        self:RefreshAllSettingsFromDB();
        self:UpdateProfileDropdowns();
    end
end

-- ============================================================================
-- Override CloseOptions
-- ============================================================================

function Addon:CloseOptions()
    if avatarSettingsPanel then
        avatarSettingsPanel:Hide();
    end
    GameTooltip:Hide();
end

-- ============================================================================
-- Initialize
-- ============================================================================

function Addon:InitializeSettings()
    self:CreateSettingsPanel();
end