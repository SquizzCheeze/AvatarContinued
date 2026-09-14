local addon_name, addon_shared = ...

local _G = getfenv(0);
local Addon = _G[addon_name];

-- ============================================================================
-- Frame Strata Data
-- ============================================================================

local frameStrataOptions = {
[1] = "BACKGROUND",
[2] = "LOW",
[3] = "MEDIUM",
[4] = "HIGH",
[5] = "DIALOG",
[6] = "FULLSCREEN",
[7] = "FULLSCREEN_DIALOG",
[8] = "TOOLTIP",
};

local frameStrataNums = {
["BACKGROUND"]          = 1,
["LOW"]                 = 2,
["MEDIUM"]              = 3,
["HIGH"]                = 4,
["DIALOG"]              = 5,
["FULLSCREEN"]          = 6,
["FULLSCREEN_DIALOG"]   = 7,
["TOOLTIP"]             = 8,
};

-- ============================================================================
-- Anchor Point Data
-- ============================================================================

local anchorPoints = {
[1] = "TOPLEFT",
[2] = "TOP",
[3] = "TOPRIGHT",
[4] = "LEFT",
[5] = "CENTER",
[6] = "RIGHT",
[7] = "BOTTOMLEFT",
[8] = "BOTTOM",
[9] = "BOTTOMRIGHT",
};

local anchorNums = {
["TOPLEFT"]     = 1,
["TOP"]         = 2,
["TOPRIGHT"]    = 3,
["LEFT"]        = 4,
["CENTER"]      = 5,
["RIGHT"]       = 6,
["BOTTOMLEFT"]  = 7,
["BOTTOM"]      = 8,
["BOTTOMRIGHT"] = 9,
};

-- ============================================================================
-- Color Palette  (matches Squizzumables)
-- ============================================================================

local AV_COLORS = {
bg          = { 0.06, 0.06, 0.08, 0.96 },
titleBar    = { 0.10, 0.10, 0.13, 1 },
border      = { 0.25, 0.25, 0.30, 1 },
accent      = { 0.78, 0.65, 0.30, 1 },
accentDim   = { 0.55, 0.45, 0.20, 0.6 },
text        = { 0.90, 0.90, 0.90, 1 },
textDim     = { 0.55, 0.55, 0.58, 1 },
textBright  = { 1, 1, 1, 1 },
control     = { 0.14, 0.14, 0.17, 1 },
controlHi   = { 0.20, 0.20, 0.24, 1 },
danger      = { 0.75, 0.25, 0.25, 1 },
dangerDim   = { 0.55, 0.20, 0.20, 0.6 },
section     = { 0.18, 0.18, 0.22, 0.5 },
};

-- ============================================================================
-- Widget Helpers
-- ============================================================================

local function ApplyAVBackdrop(frame, bgColor, borderColor)
if not frame.SetBackdrop then
Mixin(frame, BackdropTemplateMixin);
end
frame:SetBackdrop({
bgFile   = "Interface\\BUTTONS\\WHITE8X8",
edgeFile = "Interface\\BUTTONS\\WHITE8X8",
edgeSize = 1,
});
frame:SetBackdropColor(unpack(bgColor or AV_COLORS.bg));
frame:SetBackdropBorderColor(unpack(borderColor or AV_COLORS.border));
end

local function CreateAVButton(parent, text, width, height, color)
color = color or AV_COLORS.accent;
local dimColor = (color == AV_COLORS.danger) and AV_COLORS.dangerDim or AV_COLORS.accentDim;
local btn = CreateFrame("Button", nil, parent, "BackdropTemplate");
btn:SetSize(width or 100, height or 26);
btn:SetBackdrop({
bgFile   = "Interface\\BUTTONS\\WHITE8X8",
edgeFile = "Interface\\BUTTONS\\WHITE8X8",
edgeSize = 1,
});
btn:SetBackdropColor(AV_COLORS.control[1], AV_COLORS.control[2], AV_COLORS.control[3], 1);
btn:SetBackdropBorderColor(dimColor[1], dimColor[2], dimColor[3], dimColor[4]);
local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal");
label:SetPoint("CENTER");
label:SetText(text);
label:SetTextColor(color[1], color[2], color[3]);
btn.label = label;
btn:SetScript("OnEnter", function(self)
self:SetBackdropColor(AV_COLORS.controlHi[1], AV_COLORS.controlHi[2], AV_COLORS.controlHi[3], 1);
self:SetBackdropBorderColor(color[1], color[2], color[3], 1);
end);
btn:SetScript("OnLeave", function(self)
self:SetBackdropColor(AV_COLORS.control[1], AV_COLORS.control[2], AV_COLORS.control[3], 1);
self:SetBackdropBorderColor(dimColor[1], dimColor[2], dimColor[3], dimColor[4]);
end);
return btn;
end

-- displayFn: optional function(value)->string for the value label
local function CreateAVSlider(parent, labelText, width, minVal, maxVal, step, displayFn)
local container = CreateFrame("Frame", nil, parent);
container:SetSize(width, 40);

local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
label:SetPoint("TOPLEFT", 0, 0);
label:SetText(labelText);
label:SetTextColor(AV_COLORS.textDim[1], AV_COLORS.textDim[2], AV_COLORS.textDim[3]);

local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
valueText:SetPoint("TOPRIGHT", 0, 0);
valueText:SetTextColor(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3]);

local track = CreateFrame("Frame", nil, container, "BackdropTemplate");
track:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6);
track:SetSize(width, 6);
track:SetBackdrop({
bgFile   = "Interface\\BUTTONS\\WHITE8X8",
edgeFile = "Interface\\BUTTONS\\WHITE8X8",
edgeSize = 1,
});
track:SetBackdropColor(AV_COLORS.control[1], AV_COLORS.control[2], AV_COLORS.control[3], 1);
track:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.5);

local slider = CreateFrame("Slider", nil, container, "BackdropTemplate");
slider:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 3);
slider:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, -3);
slider:SetMinMaxValues(minVal, maxVal);
slider:SetValueStep(step);
slider:SetObeyStepOnDrag(true);
slider:SetOrientation("HORIZONTAL");

local thumb = slider:CreateTexture(nil, "OVERLAY");
thumb:SetSize(12, 14);
thumb:SetColorTexture(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3], 0.9);
slider:SetThumbTexture(thumb);

local fill = slider:CreateTexture(nil, "ARTWORK");
fill:SetHeight(4);
fill:SetPoint("LEFT", track, "LEFT", 1, 0);
fill:SetColorTexture(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3], 0.35);

slider:SetScript("OnValueChanged", function(self, value)
value = math.floor(value / step + 0.5) * step;
if displayFn then
valueText:SetText(displayFn(value));
elseif step < 1 then
valueText:SetText(string.format("%.2f", value));
else
valueText:SetText(tostring(math.floor(value)));
end
local range = maxVal - minVal;
if range > 0 then
local pct = (value - minVal) / range;
fill:SetWidth(math.max(1, pct * width));
end
if self.onValueChanged then self.onValueChanged(value); end
end);

container.slider = slider;
container.SetValue = function(self, v) self.slider:SetValue(v); end;
container.GetValue = function(self) return self.slider:GetValue(); end;
container.SetAfterValueChanged = function(self, fn) self.slider.onValueChanged = fn; end;
return container;
end

local function CreateAVCheckbox(parent, labelText, onChange)
local container = CreateFrame("Frame", nil, parent);
container:SetSize(300, 22);

local box = CreateFrame("CheckButton", nil, container);
box:SetSize(16, 16);
box:SetPoint("LEFT", 0, 0);

local boxBG = box:CreateTexture(nil, "BACKGROUND");
boxBG:SetAllPoints();
boxBG:SetColorTexture(AV_COLORS.control[1], AV_COLORS.control[2], AV_COLORS.control[3], 1);

local boxBorder = CreateFrame("Frame", nil, box, "BackdropTemplate");
boxBorder:SetAllPoints();
boxBorder:SetBackdrop({ edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 });
boxBorder:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.8);

local check = box:CreateTexture(nil, "OVERLAY");
check:SetSize(12, 12);
check:SetPoint("CENTER");
check:SetColorTexture(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3], 0.9);
box:SetCheckedTexture(check);

local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormal");
lbl:SetPoint("LEFT", box, "RIGHT", 8, 0);
lbl:SetText(labelText);
lbl:SetTextColor(AV_COLORS.text[1], AV_COLORS.text[2], AV_COLORS.text[3]);

box:SetScript("OnClick", function(self)
if onChange then onChange(self:GetChecked()); end
end);
box:SetScript("OnEnter", function()
boxBorder:SetBackdropBorderColor(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3], 0.6);
end);
box:SetScript("OnLeave", function()
boxBorder:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.8);
end);

container.checkbox = box;
container.SetChecked = function(self, v) self.checkbox:SetChecked(v); end;
container.GetChecked = function(self) return self.checkbox:GetChecked(); end;
return container;
end

local function CreateAVColorPicker(parent, labelText, r, g, b, onChange)
local container = CreateFrame("Frame", nil, parent);
container:SetSize(220, 22);

local swatch = CreateFrame("Button", nil, container, "BackdropTemplate");
swatch:SetSize(16, 16);
swatch:SetPoint("LEFT", 0, 0);
swatch:SetBackdrop({
bgFile   = "Interface\\BUTTONS\\WHITE8X8",
edgeFile = "Interface\\BUTTONS\\WHITE8X8",
edgeSize = 1,
});
swatch:SetBackdropColor(r or 1, g or 1, b or 1, 1);
swatch:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.8);

local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormal");
lbl:SetPoint("LEFT", swatch, "RIGHT", 8, 0);
lbl:SetText(labelText);
lbl:SetTextColor(AV_COLORS.text[1], AV_COLORS.text[2], AV_COLORS.text[3]);

swatch:SetScript("OnClick", function()
local info = {};
info.r, info.g, info.b = r or 1, g or 1, b or 1;
info.hasOpacity = false;
info.swatchFunc = function()
local cr, cg, cb = ColorPickerFrame:GetColorRGB();
swatch:SetBackdropColor(cr, cg, cb, 1);
r, g, b = cr, cg, cb;
if onChange then onChange(cr, cg, cb); end
end;
info.cancelFunc = function(prev)
swatch:SetBackdropColor(prev.r, prev.g, prev.b, 1);
r, g, b = prev.r, prev.g, prev.b;
if onChange then onChange(prev.r, prev.g, prev.b); end
end;
ColorPickerFrame:SetupColorPickerAndShow(info);
end);
swatch:SetScript("OnEnter", function(self)
self:SetBackdropBorderColor(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3], 0.6);
end);
swatch:SetScript("OnLeave", function(self)
self:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.8);
end);

container.swatch = swatch;
container.SetColor = function(self, nr, ng, nb)
r, g, b = nr, ng, nb;
self.swatch:SetBackdropColor(nr, ng, nb, 1);
end;
return container;
end

local function CreateAVDropdown(parent, labelText, width, items, onSelect)
local container = CreateFrame("Frame", nil, parent);
container:SetSize(width, 44);

local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
lbl:SetPoint("TOPLEFT", 0, 0);
lbl:SetText(labelText);
lbl:SetTextColor(AV_COLORS.textDim[1], AV_COLORS.textDim[2], AV_COLORS.textDim[3]);

local btn = CreateFrame("Button", nil, container, "BackdropTemplate");
btn:SetSize(width, 24);
btn:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4);
btn:SetBackdrop({
bgFile   = "Interface\\BUTTONS\\WHITE8X8",
edgeFile = "Interface\\BUTTONS\\WHITE8X8",
edgeSize = 1,
});
btn:SetBackdropColor(AV_COLORS.control[1], AV_COLORS.control[2], AV_COLORS.control[3], 1);
btn:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.8);

local selectedText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal");
selectedText:SetPoint("LEFT", 8, 0);
selectedText:SetTextColor(AV_COLORS.text[1], AV_COLORS.text[2], AV_COLORS.text[3]);

local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
arrow:SetPoint("RIGHT", -8, 0);
arrow:SetText("v");
arrow:SetTextColor(AV_COLORS.textDim[1], AV_COLORS.textDim[2], AV_COLORS.textDim[3]);

local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate");
menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2);
menu:SetWidth(width);
menu:SetFrameStrata("FULLSCREEN_DIALOG");
menu:SetBackdrop({
bgFile   = "Interface\\BUTTONS\\WHITE8X8",
edgeFile = "Interface\\BUTTONS\\WHITE8X8",
edgeSize = 1,
});
menu:SetBackdropColor(AV_COLORS.bg[1], AV_COLORS.bg[2], AV_COLORS.bg[3], 0.98);
menu:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 1);
menu:Hide();

local selectedValue = nil;

local function BuildMenu()
for _, child in pairs({ menu:GetChildren() }) do child:Hide(); child:SetParent(nil); end
local scratch = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal");
local maxTextW = 0;
for _, item in ipairs(items) do
scratch:SetText(item.text);
local tw = scratch:GetStringWidth();
if tw > maxTextW then maxTextW = tw; end
end
scratch:SetText("");
local menuWidth = math.max(width, maxTextW + 24);
menu:SetWidth(menuWidth);
local y = -4;
for _, item in ipairs(items) do
local opt = CreateFrame("Button", nil, menu);
opt:SetSize(menuWidth - 8, 20);
opt:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, y);
local optBG = opt:CreateTexture(nil, "BACKGROUND");
optBG:SetAllPoints();
optBG:SetColorTexture(0, 0, 0, 0);
local optText = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal");
optText:SetPoint("LEFT", 6, 0);
optText:SetText(item.text);
if item.value == selectedValue then
optText:SetTextColor(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3]);
else
optText:SetTextColor(AV_COLORS.text[1], AV_COLORS.text[2], AV_COLORS.text[3]);
end
opt:SetScript("OnEnter", function()
optBG:SetColorTexture(AV_COLORS.controlHi[1], AV_COLORS.controlHi[2], AV_COLORS.controlHi[3], 1);
end);
opt:SetScript("OnLeave", function()
optBG:SetColorTexture(0, 0, 0, 0);
end);
opt:SetScript("OnClick", function()
selectedValue = item.value;
selectedText:SetText(item.text);
menu:Hide();
if onSelect then onSelect(item.value); end
end);
y = y - 20;
end
menu:SetHeight(math.abs(y) + 4);
end

btn:SetScript("OnClick", function()
if menu:IsShown() then
menu:Hide();
else
BuildMenu();
menu:Show();
end
end);
btn:SetScript("OnEnter", function(self)
self:SetBackdropBorderColor(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3], 0.6);
end);
btn:SetScript("OnLeave", function(self)
self:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.8);
end);

local closer = CreateFrame("Button", nil, menu);
closer:SetAllPoints(UIParent);
closer:SetFrameStrata("FULLSCREEN");
closer:SetScript("OnClick", function() menu:Hide(); closer:Hide(); end);
closer:Hide();
menu:HookScript("OnShow", function() closer:Show(); end);
menu:HookScript("OnHide", function() closer:Hide(); end);

container.btn = btn;
container.selectedText = selectedText;
container.SetSelectedValue = function(self, val)
selectedValue = val;
for _, item in ipairs(items) do
if item.value == val then
selectedText:SetText(item.text);
return;
end
end
selectedText:SetText("");
end;
container.GetSelectedValue = function(self) return selectedValue; end;
container.SetItems = function(self, newItems) items = newItems; end;
return container;
end

local function CreateAVDivider(parent, yOffset)
local line = parent:CreateTexture(nil, "ARTWORK");
line:SetHeight(1);
line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, yOffset);
line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset);
line:SetColorTexture(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.3);
return line;
end

local function CreateAVInputBox(parent, labelText, width, onChange)
local container = CreateFrame("Frame", nil, parent);
container:SetSize(width, 44);

local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
lbl:SetPoint("TOPLEFT", 0, 0);
lbl:SetText(labelText);
lbl:SetTextColor(AV_COLORS.textDim[1], AV_COLORS.textDim[2], AV_COLORS.textDim[3]);

local editBox = CreateFrame("EditBox", nil, container, "BackdropTemplate");
editBox:SetSize(width, 24);
editBox:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4);
editBox:SetBackdrop({
bgFile   = "Interface\\BUTTONS\\WHITE8X8",
edgeFile = "Interface\\BUTTONS\\WHITE8X8",
edgeSize = 1,
});
editBox:SetBackdropColor(AV_COLORS.control[1], AV_COLORS.control[2], AV_COLORS.control[3], 1);
editBox:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.8);
editBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "");
editBox:SetTextColor(AV_COLORS.text[1], AV_COLORS.text[2], AV_COLORS.text[3]);
editBox:SetTextInsets(8, 8, 0, 0);
editBox:SetAutoFocus(false);
editBox:SetMaxLetters(64);
editBox:SetScript("OnEnterPressed", function(self)
self:ClearFocus();
if onChange then onChange(self:GetText()); end
end);
editBox:SetScript("OnEscapePressed", function(self)
self:ClearFocus();
end);
editBox:SetScript("OnEditFocusGained", function(self)
self:SetBackdropBorderColor(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3], 0.8);
end);
editBox:SetScript("OnEditFocusLost", function(self)
self:SetBackdropBorderColor(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.8);
if onChange then onChange(self:GetText()); end
end);

container.editBox = editBox;
container.SetText = function(self, t) self.editBox:SetText(t or ""); end;
container.GetText = function(self) return self.editBox:GetText(); end;
return container;
end

local function CreateSectionHeader(parent, text, yOffset, leftPad)
local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
header:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPad, yOffset);
header:SetText(text);
header:SetTextColor(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3]);
return header;
end

-- ============================================================================
-- Profile Management
-- ============================================================================

local AVATAR_DELETE_PROFILE_NAME = nil;

StaticPopupDialogs["AVATAR_DELETE_PROFILE_CONFIRM"] = {
text = "Are you sure you want to delete profile '%s'?",
button1 = YES,
button2 = NO,
sound = "igMainMenuOpen",
OnShow = function(self, data)
Addon:CloseOptions();
end,
OnAccept = function(self)
if AVATAR_DELETE_PROFILE_NAME then
Addon.db:DeleteProfile(AVATAR_DELETE_PROFILE_NAME);
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Deleted profile " .. AVATAR_DELETE_PROFILE_NAME .. ".");
AVATAR_DELETE_PROFILE_NAME = nil;
Addon:RefreshProfileDropdowns();
end
end,
OnCancel = function(self) end,
hideOnEscape = 1,
timeout = 0,
whileDead = 1,
};

StaticPopupDialogs["AVATAR_NEW_PROFILE"] = {
text = "Enter a name for the new profile:",
button1 = "Create",
button2 = CANCEL,
hasEditBox = 1,
maxLetters = 64,
OnAccept = function(self)
local name = self.editBox:GetText();
if name and name ~= "" then
Addon.db:SetProfile(name);
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Created and switched to profile " .. name .. ".");
Addon:RefreshProfileDropdowns();
end
end,
OnCancel = function(self) end,
EditBoxOnEnterPressed = function(self)
local parent = self:GetParent();
local name = self:GetText();
if name and name ~= "" then
Addon.db:SetProfile(name);
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Created and switched to profile " .. name .. ".");
Addon:RefreshProfileDropdowns();
end
parent:Hide();
end,
EditBoxOnEscapePressed = function(self) self:GetParent():Hide(); end,
hideOnEscape = 1,
timeout = 0,
whileDead = 1,
};

function Addon:GetProfileList()
local profiles = self.db:GetProfiles();
local list = {};
for _, name in pairs(profiles) do
table.insert(list, name);
end
table.sort(list);
return list;
end

function Addon:GetProfileDropdownItems()
local list = {};
for _, name in ipairs(self:GetProfileList()) do
table.insert(list, { text = name, value = name });
end
return list;
end

function Addon:RefreshProfileDropdowns()
if not Addon.optionsContent then return; end
local c = Addon.optionsContent;
local items = Addon:GetProfileDropdownItems();
if c.profileDropdown then
c.profileDropdown:SetItems(items);
c.profileDropdown:SetSelectedValue(Addon.db:GetCurrentProfile());
end
if c.copyProfileDropdown then
c.copyProfileDropdown:SetItems(items);
end
if c.globalProfileCB then
c.globalProfileCB:SetChecked(Addon.db:GetCurrentProfile() == "Global Profile");
end
end

-- ============================================================================
-- Options Panel Construction
-- ============================================================================

function Addon:CreateOptionsPanel()
if self.optionsPanel then
self.optionsPanel:Show();
self:RefreshOptionsPanel();
return;
end

local panel = CreateFrame("Frame", "AvatarOptionsPanel", UIParent, "BackdropTemplate");
panel:SetSize(500, 590);
panel:SetPoint("CENTER");
panel:SetFrameStrata("DIALOG");
panel:SetMovable(true);
panel:EnableMouse(true);
ApplyAVBackdrop(panel, AV_COLORS.bg, AV_COLORS.border);
self.optionsPanel = panel;
table.insert(UISpecialFrames, "AvatarOptionsPanel");

-- Hide during combat, restore after
panel:RegisterEvent("PLAYER_REGEN_DISABLED");
panel:RegisterEvent("PLAYER_REGEN_ENABLED");
panel.wasShown = false;
panel:SetScript("OnEvent", function(self, event)
if event == "PLAYER_REGEN_DISABLED" then
if self:IsShown() then
self.wasShown = true;
self:Hide();
end
elseif event == "PLAYER_REGEN_ENABLED" then
if self.wasShown then
self.wasShown = false;
self:Show();
end
end
end);

-- Title bar (draggable)
local titleBar = CreateFrame("Frame", nil, panel, "BackdropTemplate");
titleBar:SetHeight(32);
titleBar:SetPoint("TOPLEFT",  panel, "TOPLEFT",   1, -1);
titleBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT",  -1, -1);
titleBar:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" });
titleBar:SetBackdropColor(AV_COLORS.titleBar[1], AV_COLORS.titleBar[2], AV_COLORS.titleBar[3], AV_COLORS.titleBar[4]);
titleBar:EnableMouse(true);
titleBar:RegisterForDrag("LeftButton");
titleBar:SetScript("OnDragStart", function() panel:StartMoving(); end);
titleBar:SetScript("OnDragStop",  function() panel:StopMovingOrSizing(); end);

local titleMain = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal");
titleMain:SetPoint("LEFT", titleBar, "LEFT", 12, 0);
titleMain:SetText("AVATAR CONTINUED");
titleMain:SetTextColor(AV_COLORS.textBright[1], AV_COLORS.textBright[2], AV_COLORS.textBright[3]);

local titleSub = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
titleSub:SetPoint("LEFT", titleMain, "RIGHT", 6, 0);
titleSub:SetText("Configuration");
titleSub:SetTextColor(AV_COLORS.textDim[1], AV_COLORS.textDim[2], AV_COLORS.textDim[3]);

local closeBtn = CreateFrame("Button", nil, titleBar);
closeBtn:SetSize(32, 32);
closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0);
local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal");
closeText:SetPoint("CENTER");
closeText:SetText("X");
closeText:SetTextColor(AV_COLORS.textDim[1], AV_COLORS.textDim[2], AV_COLORS.textDim[3]);
closeBtn:SetScript("OnEnter", function()
closeText:SetTextColor(AV_COLORS.danger[1], AV_COLORS.danger[2], AV_COLORS.danger[3]);
end);
closeBtn:SetScript("OnLeave", function()
closeText:SetTextColor(AV_COLORS.textDim[1], AV_COLORS.textDim[2], AV_COLORS.textDim[3]);
end);
closeBtn:SetScript("OnClick", function() panel:Hide(); end);

-- Accent line under title bar
local accentLine = titleBar:CreateTexture(nil, "OVERLAY");
accentLine:SetHeight(1);
accentLine:SetPoint("BOTTOMLEFT",  titleBar, "BOTTOMLEFT",  0, 0);
accentLine:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0);
accentLine:SetColorTexture(AV_COLORS.accent[1], AV_COLORS.accent[2], AV_COLORS.accent[3], 0.4);

-- Scrollable content area
local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate");
scrollFrame:SetPoint("TOPLEFT",     titleBar, "BOTTOMLEFT",   0,  -4);
scrollFrame:SetPoint("BOTTOMRIGHT", panel,    "BOTTOMRIGHT", -22,  40);

local content = CreateFrame("Frame", nil, scrollFrame);
content:SetWidth(454);
scrollFrame:SetScrollChild(content);

-- Bottom bar with close button
local bottomBar = CreateFrame("Frame", nil, panel);
bottomBar:SetHeight(38);
bottomBar:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",   1, 1);
bottomBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1);

local bottomLine = bottomBar:CreateTexture(nil, "OVERLAY");
bottomLine:SetHeight(1);
bottomLine:SetPoint("TOPLEFT",  bottomBar, "TOPLEFT",  0, 0);
bottomLine:SetPoint("TOPRIGHT", bottomBar, "TOPRIGHT", 0, 0);
bottomLine:SetColorTexture(AV_COLORS.border[1], AV_COLORS.border[2], AV_COLORS.border[3], 0.3);

local closeBtnBottom = CreateAVButton(bottomBar, "Close", 80, 26);
closeBtnBottom:SetPoint("CENTER", bottomBar, "CENTER", 0, 0);
closeBtnBottom:SetScript("OnClick", function() panel:Hide(); end);

self:BuildAvatarOptions(content);
panel:Show();
end

function Addon:BuildAvatarOptions(content)
local yOffset   = -14;
local leftPad   = 14;
local fullWidth = 426;
local halfWidth = (fullWidth - 10) / 2;

-- ==============================
-- GENERAL
-- ==============================
CreateSectionHeader(content, "GENERAL", yOffset, leftPad);
yOffset = yOffset - 22;

local unlockBtn = CreateAVButton(content, "Unlock Avatar Frame", 160, 26);
unlockBtn:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
unlockBtn:SetScript("OnClick", function()
Addon:UnlockFrame();
Addon:CloseOptions();
end);
yOffset = yOffset - 34;

local enableCB = CreateAVCheckbox(content, "Enable Avatar", function(checked)
Addon.db.profile.enabled = checked;
Addon:RefreshFrame();
end);
enableCB:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
yOffset = yOffset - 30;

CreateAVDivider(content, yOffset);
yOffset = yOffset - 14;

-- ==============================
-- DISPLAY
-- ==============================
CreateSectionHeader(content, "DISPLAY", yOffset, leftPad);
yOffset = yOffset - 22;

local weaponCB = CreateAVCheckbox(content, "Show Weapon", function(checked)
Addon.db.profile.show.weapon = checked;
Addon:RefreshFrame();
end);
weaponCB:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);

local armorCB = CreateAVCheckbox(content, "Show Armor", function(checked)
Addon.db.profile.show.armor = checked;
Addon:RefreshFrame();
end);
armorCB:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + halfWidth + 10, yOffset);
yOffset = yOffset - 26;

local tabardCB = CreateAVCheckbox(content, "Show Tabard", function(checked)
Addon.db.profile.show.tabard = checked;
Addon:RefreshFrame();
end);
tabardCB:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
yOffset = yOffset - 26;

local shirtCB = CreateAVCheckbox(content, "Show Shirt", function(checked)
Addon.db.profile.show.shirt = checked;
Addon:RefreshFrame();
end);
shirtCB:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);

local helmCB = CreateAVCheckbox(content, "Always Hide Helm", function(checked)
Addon.db.profile.show.helm = not checked;
Addon:RefreshFrame();
end);
helmCB:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + halfWidth + 10, yOffset);
yOffset = yOffset - 30;

local alphaSlider = CreateAVSlider(content, "Avatar Opacity", fullWidth, 0, 1, 0.01,
function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)); end);
alphaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
alphaSlider:SetAfterValueChanged(function(value)
Addon.db.profile.alpha = value;
AvatarModelFrame:SetModelAlpha(value);
end);
yOffset = yOffset - 50;

CreateAVDivider(content, yOffset);
yOffset = yOffset - 14;

-- ==============================
-- FRAME SETTINGS
-- ==============================
CreateSectionHeader(content, "FRAME SETTINGS", yOffset, leftPad);
yOffset = yOffset - 22;

local widthInput = CreateAVInputBox(content, "Frame Width", halfWidth, function(value)
local n = tonumber(value);
if n then Addon.db.profile.size.w = n; Addon:SetFrameSettings(); end
end);
widthInput:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);

local heightInput = CreateAVInputBox(content, "Frame Height", halfWidth, function(value)
local n = tonumber(value);
if n then Addon.db.profile.size.h = n; Addon:SetFrameSettings(); end
end);
heightInput:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + halfWidth + 10, yOffset);
yOffset = yOffset - 50;

local xInput = CreateAVInputBox(content, "Position X", halfWidth, function(value)
local n = tonumber(value);
if n then Addon.db.profile.position.x = n; Addon:SetFrameSettings(); end
end);
xInput:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);

local yInput = CreateAVInputBox(content, "Position Y", halfWidth, function(value)
local n = tonumber(value);
if n then Addon.db.profile.position.y = n; Addon:SetFrameSettings(); end
end);
yInput:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + halfWidth + 10, yOffset);
yOffset = yOffset - 50;

local anchorItems = {};
for i, name in ipairs(anchorPoints) do
table.insert(anchorItems, { text = name, value = i });
end
local pointDropdown = CreateAVDropdown(content, "Anchor Point", halfWidth, anchorItems, function(value)
Addon.db.profile.position.point = anchorPoints[value];
Addon:SetFrameSettings();
end);
pointDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);

local relPointDropdown = CreateAVDropdown(content, "Relative Point", halfWidth, anchorItems, function(value)
Addon.db.profile.position.relativePoint = anchorPoints[value];
Addon:SetFrameSettings();
end);
relPointDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + halfWidth + 10, yOffset);
yOffset = yOffset - 50;

local strataItems = {};
for i, name in ipairs(frameStrataOptions) do
table.insert(strataItems, { text = name, value = i });
end
local strataDropdown = CreateAVDropdown(content, "Frame Strata", 200, strataItems, function(value)
Addon.db.profile.frameStrata = frameStrataOptions[value];
Addon:SetFrameSettings();
end);
strataDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
yOffset = yOffset - 50;

local levelSlider = CreateAVSlider(content, "Frame Level", fullWidth, 0, 100, 1);
levelSlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
levelSlider:SetAfterValueChanged(function(value)
Addon.db.profile.frameLevel = value;
Addon:SetFrameSettings();
end);
yOffset = yOffset - 50;

CreateAVDivider(content, yOffset);
yOffset = yOffset - 14;

-- ==============================
-- MISCELLANEOUS
-- ==============================
CreateSectionHeader(content, "MISCELLANEOUS", yOffset, leftPad);
yOffset = yOffset - 22;

local facingSlider = CreateAVSlider(content, "Avatar Facing (degrees)", fullWidth, -180, 180, 1);
facingSlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
facingSlider:SetAfterValueChanged(function(value)
Addon.db.profile.facing = value * (math.pi / 180.0);
Addon:SetFrameSettings();
end);
yOffset = yOffset - 50;

local combatCB = CreateAVCheckbox(content, "Hide Avatar in Combat", function(checked)
Addon.db.profile.hideInCombat = checked;
end);
combatCB:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
yOffset = yOffset - 30;

CreateAVDivider(content, yOffset);
yOffset = yOffset - 14;

-- ==============================
-- ANIMATION
-- ==============================
CreateSectionHeader(content, "ANIMATION", yOffset, leftPad);
yOffset = yOffset - 22;

local animationItems = {
    { text = "Idle",       value = 0  },
    { text = "Walk",       value = 4  },
    { text = "Attack",     value = 26 },
    { text = "Spell Cast", value = 48 },
    { text = "Talk",       value = 60 },
    { text = "Dance",      value = 69 },
};

local animationDropdown = CreateAVDropdown(content, "Pose / Animation", fullWidth, animationItems, function(value)
Addon.db.profile.animation = value;
Addon:ApplyAnimation();
end);
animationDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
yOffset = yOffset - 50;

CreateAVDivider(content, yOffset);
yOffset = yOffset - 14;

-- ==============================
-- LIGHTING
-- ==============================
CreateSectionHeader(content, "LIGHTING", yOffset, leftPad);
yOffset = yOffset - 22;

local dyaSlider = CreateAVSlider(content, "Light Direction Yaw", fullWidth, -180, 180, 1);
dyaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
dyaSlider:SetAfterValueChanged(function(value)
Addon.db.profile.light.dya = value;
Addon:UpdateLightDirection();
Addon:SetFrameSettings();
end);
yOffset = yOffset - 50;

local dzaSlider = CreateAVSlider(content, "Light Direction Pitch", fullWidth, -180, 180, 1);
dzaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
dzaSlider:SetAfterValueChanged(function(value)
Addon.db.profile.light.dza = value;
Addon:UpdateLightDirection();
Addon:SetFrameSettings();
end);
yOffset = yOffset - 50;

local halfW2 = (fullWidth - 10) / 2;

local diSlider = CreateAVSlider(content, "Direct Intensity", halfW2, 0, 1, 0.01,
function(v) return string.format("%.2f", v); end);
diSlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
diSlider:SetAfterValueChanged(function(value)
Addon.db.profile.light.di = value;
Addon:SetFrameSettings();
end);

local aiSlider = CreateAVSlider(content, "Ambient Intensity", halfW2, 0, 1, 0.01,
function(v) return string.format("%.2f", v); end);
aiSlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + halfW2 + 10, yOffset);
aiSlider:SetAfterValueChanged(function(value)
Addon.db.profile.light.ai = value;
Addon:SetFrameSettings();
end);
yOffset = yOffset - 50;

local dcPicker = CreateAVColorPicker(content, "Direct Light Color",
Addon.db.profile.light.dr, Addon.db.profile.light.dg, Addon.db.profile.light.db,
function(r, g, b)
Addon.db.profile.light.dr = r;
Addon.db.profile.light.dg = g;
Addon.db.profile.light.db = b;
Addon:SetFrameSettings();
end);
dcPicker:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);

local acPicker = CreateAVColorPicker(content, "Ambient Light Color",
Addon.db.profile.light.ar, Addon.db.profile.light.ag, Addon.db.profile.light.ab,
function(r, g, b)
Addon.db.profile.light.ar = r;
Addon.db.profile.light.ag = g;
Addon.db.profile.light.ab = b;
Addon:SetFrameSettings();
end);
acPicker:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + halfW2 + 10, yOffset);
yOffset = yOffset - 30;

CreateAVDivider(content, yOffset);
yOffset = yOffset - 14;

-- ==============================
-- PROFILES
-- ==============================
CreateSectionHeader(content, "PROFILES", yOffset, leftPad);
yOffset = yOffset - 22;

local globalProfileCB = CreateAVCheckbox(content,
"Use Global Profile  (shared across all characters)",
function(checked)
Addon:ToggleGlobalProfile(checked);
Addon:RefreshProfileDropdowns();
end);
globalProfileCB:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
yOffset = yOffset - 32;

local profileDropdown = CreateAVDropdown(content, "Active Profile", 220,
Addon:GetProfileDropdownItems(),
function(value)
Addon:ChangeProfileByName(value);
Addon:RefreshOptionsPanel();
end);
profileDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
yOffset = yOffset - 54;

local newProfileBtn = CreateAVButton(content, "New Profile", 100, 26);
newProfileBtn:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
newProfileBtn:SetScript("OnClick", function()
StaticPopup_Show("AVATAR_NEW_PROFILE");
end);

local deleteProfileBtn = CreateAVButton(content, "Delete", 80, 26, AV_COLORS.danger);
deleteProfileBtn:SetPoint("LEFT", newProfileBtn, "RIGHT", 8, 0);
deleteProfileBtn:SetScript("OnClick", function()
local name = Addon.db:GetCurrentProfile();
AVATAR_DELETE_PROFILE_NAME = name;
StaticPopup_Show("AVATAR_DELETE_PROFILE_CONFIRM", name);
end);
yOffset = yOffset - 34;

local copyNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
copyNote:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
copyNote:SetText("Copy settings from:");
copyNote:SetTextColor(AV_COLORS.textDim[1], AV_COLORS.textDim[2], AV_COLORS.textDim[3]);
yOffset = yOffset - 18;

local copyProfileDropdown = CreateAVDropdown(content, "", 220,
Addon:GetProfileDropdownItems(),
function(value)
Addon:CopyProfileByName(value);
end);
copyProfileDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOffset);
yOffset = yOffset - 50;

-- Finalize scroll height
content:SetHeight(math.abs(yOffset) + 20);

-- Store widget refs for RefreshOptionsPanel
Addon.optionsContent = {
enableCB            = enableCB,
weaponCB            = weaponCB,
armorCB             = armorCB,
tabardCB            = tabardCB,
shirtCB             = shirtCB,
helmCB              = helmCB,
alphaSlider         = alphaSlider,
widthInput          = widthInput,
heightInput         = heightInput,
xInput              = xInput,
yInput              = yInput,
pointDropdown       = pointDropdown,
relPointDropdown    = relPointDropdown,
strataDropdown      = strataDropdown,
levelSlider         = levelSlider,
facingSlider        = facingSlider,
combatCB            = combatCB,
dyaSlider           = dyaSlider,
dzaSlider           = dzaSlider,
diSlider            = diSlider,
aiSlider            = aiSlider,
dcPicker            = dcPicker,
acPicker            = acPicker,
globalProfileCB     = globalProfileCB,
profileDropdown     = profileDropdown,
copyProfileDropdown = copyProfileDropdown,
animationDropdown   = animationDropdown,
};
end

function Addon:RefreshOptionsPanel()
if not self.optionsContent then return; end
local c = self.optionsContent;
local p = self.db.profile;

c.enableCB:SetChecked(p.enabled);
c.weaponCB:SetChecked(p.show.weapon);
c.armorCB:SetChecked(p.show.armor);
c.tabardCB:SetChecked(p.show.tabard);
c.shirtCB:SetChecked(p.show.shirt);
c.helmCB:SetChecked(not p.show.helm);
c.alphaSlider:SetValue(p.alpha);

c.widthInput:SetText(string.format("%.2f", p.size.w));
c.heightInput:SetText(string.format("%.2f", p.size.h));
c.xInput:SetText(string.format("%.2f", p.position.x));
c.yInput:SetText(string.format("%.2f", p.position.y));
c.pointDropdown:SetSelectedValue(anchorNums[p.position.point] or 1);
c.relPointDropdown:SetSelectedValue(anchorNums[p.position.relativePoint] or 1);
c.strataDropdown:SetSelectedValue(frameStrataNums[p.frameStrata] or 1);
c.levelSlider:SetValue(p.frameLevel);

c.facingSlider:SetValue(p.facing * (180.0 / math.pi));
c.combatCB:SetChecked(p.hideInCombat);

c.dyaSlider:SetValue(p.light.dya);
c.dzaSlider:SetValue(p.light.dza);
c.diSlider:SetValue(p.light.di);
c.aiSlider:SetValue(p.light.ai);
c.dcPicker:SetColor(p.light.dr, p.light.dg, p.light.db);
c.acPicker:SetColor(p.light.ar, p.light.ag, p.light.ab);

c.globalProfileCB:SetChecked(self.db:GetCurrentProfile() == "Global Profile");
c.profileDropdown:SetSelectedValue(self.db:GetCurrentProfile());
c.animationDropdown:SetSelectedValue(p.animation or 0);

AvatarModelFrame:SetModelAlpha(p.alpha);
end

-- ============================================================================
-- Addon Interface
-- ============================================================================

function Addon:CloseOptions()
if self.optionsPanel then
self.optionsPanel:Hide();
end
GameTooltip:Hide();
end

function Addon:LoadOptions()
-- Options panel is built lazily on first ShowOptions call.
end

Addon:LoadOptions();

function Addon:ShowOptions()
Addon:LockFrame();
Addon:CreateOptionsPanel();
Addon:RefreshOptionsPanel();
end

function Addon:OnProfileChanged()
Addon:RefreshAvatar();
if Addon.optionsPanel and Addon.optionsPanel:IsShown() then
Addon:RefreshOptionsPanel();
Addon:RefreshProfileDropdowns();
end
end

function Addon:ToggleGlobalProfile(toggle)
if toggle then
local currentProfile = self.db:GetCurrentProfile();
local globalExists = false;
for _, value in pairs(self.db:GetProfiles()) do
if value == "Global Profile" then
globalExists = true;
break;
end
end
self.db:SetProfile("Global Profile");
if not globalExists then
self.db:CopyProfile(currentProfile, true);
end
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Using Global Profile.");
else
local name = UnitName("player");
local realm = GetRealmName();
local profileName = name .. " - " .. realm;
self.db:SetProfile(profileName);
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Using profile " .. profileName .. ".");
end
Addon:RefreshAvatar();
end

function Addon:ChangeProfileByName(name)
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Using profile " .. name .. ".");
self.db:SetProfile(name);
end

function Addon:CopyProfileByName(name)
self.db:CopyProfile(name);
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Copied settings from profile " .. name .. ".");
end

-- ============================================================================
-- Frame Lock / Unlock / Position
-- ============================================================================

function Addon:LockFrame()
if not Addon.FrameUnlocked then return end

AvatarModelFrame:SetFrameStrata(self.db.profile.frameStrata);
AvatarModelFrame:SetFrameLevel(self.db.profile.frameLevel);
AvatarModelFrame:EnableMouse(false);
AvatarModelFrame:EnableMouseWheel(false);

AvatarModelFrameBackdrop:Hide();
AvatarInstructionsFrame:Hide();

Addon.FrameUnlocked = false;
end

function Addon:SavePosition()
local point, _, relativePoint, x, y = AvatarModelFrame:GetPoint();
Addon.db.profile.position.point = point;
Addon.db.profile.position.relativePoint = relativePoint;
Addon.db.profile.position.x = tonumber(string.format("%.2f", x));
Addon.db.profile.position.y = tonumber(string.format("%.2f", y));

local w, h = AvatarModelFrame:GetSize();
Addon.db.profile.size.w = tonumber(string.format("%.2f", w));
Addon.db.profile.size.h = tonumber(string.format("%.2f", h));

Addon.db.profile.facing = AvatarModelFrame:GetFacing();
end

function Addon:UnlockFrame()
if Addon.FrameUnlocked then return end

if not self.db.profile.enabled then
self.db.profile.enabled = true;
Addon:RefreshAvatar();
end

AvatarModelFrame:SetFrameStrata("FULLSCREEN");
AvatarModelFrame:EnableMouse(true);
AvatarModelFrame:EnableMouseWheel(true);

AvatarModelFrameBackdrop:Show();
AvatarInstructionsFrame:Show();

Addon.FrameUnlocked = true;
end

-- ============================================================================
-- Console Handler  (/avatar or /av)
-- ============================================================================

function Addon:ConsoleHandler(rawcommand)
local command, arg1, arg2, arg3, arg4 = strsplit(" ", string.lower(rawcommand));

if command == "toggle" then

local thing = arg1;

if thing == nil then
self.db.profile.enabled = not self.db.profile.enabled;
Addon:RefreshFrame();
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued|r Avatar " .. (self.db.profile.enabled and "|cff82cd40enabled|r" or "|cffc92222disabled|r") .. ".");

elseif thing == "weapon" then
self.db.profile.show.weapon = not self.db.profile.show.weapon;
Addon:RefreshFrame();
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued|r Avatar weapon " .. (self.db.profile.show.weapon and "|cff82cd40visible|r" or "|cffc92222hidden|r") .. ".");

elseif thing == "armor" then
self.db.profile.show.armor = not self.db.profile.show.armor;
Addon:RefreshFrame();
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued|r Avatar armor " .. (self.db.profile.show.armor and "|cff82cd40visible|r" or "|cffc92222hidden|r") .. ".");

elseif thing == "tabard" then
self.db.profile.show.tabard = not self.db.profile.show.tabard;
Addon:RefreshFrame();
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued|r Avatar tabard " .. (self.db.profile.show.tabard and "|cff82cd40visible|r" or "|cffc92222hidden|r") .. ".");
end

elseif command == "equip" then

local _, item = strsplit(" ", string.lower(rawcommand), 2);
if not strfind(item, "|Hitem") then
local item_id, bonusId = item:match("(%d+):(%d+)");
if not item_id then item_id = tonumber(item); end
item = string.format("item:%d:0:0:0:0:0:0:0:%d:0:0:1:%d", item_id, UnitLevel("player"), bonusId);
end
if item then AvatarModelFrame:TryOn(item); end

elseif command == "profile" then

local profileName = arg1;
if profileName and profileName ~= "Global Profile" then
Addon.db:SetProfile(profileName);
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Using profile " .. profileName .. ".");
end

elseif command == "unlock" then
Addon:UnlockFrame();
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Unlocked");

elseif command == "lock" then
Addon:LockFrame();
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fcAvatar Continued:|r Locked");

elseif command == "help" or command == "commands" or command == "?" then
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc======== Avatar Continued - Usage ========|r");
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar help or /av help|r - Show usage (Avatar Continued)");
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250toggle|r - Show/hide avatar (currently " .. (self.db.profile.enabled and "|cff82cd40visible|r" or "|cffc92222hidden|r") .. ")");
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250toggle [weapon/armor/tabard]|r - Show/hide avatar weapon, armor or tabard");
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250profile [profile name]|r - Change current profile (" .. Addon.db:GetCurrentProfile() .. ")");
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250equip [equipment itemlink]|r - Equip avatar with an item");
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250lock|r - Lock avatar");
DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250unlock|r - Unlock avatar allowing positioning, scaling and rotating with the mouse");

else
Addon:RefreshAvatar();
Addon:ShowOptions();
end
end