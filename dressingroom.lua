-- ============================================================================
-- Dressing Room (V1.14)
--
-- A settings page for trying on any appearance in the game, collected or not,
-- and saving the result as a "look" the avatar can wear (it is listed on the
-- Outfits page beside the game's outfits). Works on retail and WoW Forever;
-- the Sets browser only appears where C_TransmogSets.GetAllSets() has any.
--
-- How it fits the rest of the addon:
--   * The in-progress look is Addon.lookDraft ({ [slotID] = { appearanceID,
--     secondaryAppearanceID, illusionID } or false }). While this page is open
--     the settings preview wears it through the per-model outfit override
--     (model._avatarOutfitOverride = Addon.DRAFT_LOOK), so every refresh that
--     already runs through Addon:ApplyAppearance re-dresses it in the draft.
--     Nothing here calls TryOn/Dress/SetUnit (see CLAUDE.md: face geosets).
--   * Saved looks live in AvatarDB.global.looks (core.lua) and are chosen with
--     the same customSetID fields as a game outfit, keyed "look:<n>".
--   * Appearance lists come from C_TransmogCollection.GetCategoryAppearances,
--     which is filtered C-side by the Wardrobe's own filters. Those are left
--     alone (see CategoryAppearances for why flipping them failed).
--   * On WoW Forever the model draws only what your character could display
--     (canDisplayOnPlayer): anything else is accepted with Success and
--     silently not drawn. Such appearances are dimmed and explained.
-- ============================================================================

local addon_name = ...
local _G = getfenv(0);
local Addon = _G[addon_name];

local C = C_TransmogCollection;

local GOLD = { 0.78, 0.65, 0.30 };
-- 5 x 3 model cells, as Blizzard's Wardrobe (18 per page) but sized to fit
-- the settings column. 3D models cost far more than icons, so few per page.
local CELL_W, CELL_H, CELL_GAP, COLS, ROWS = 68, 90, 6, 5, 3;
local PAGE_SIZE = COLS * ROWS;
local SET_ROWS = 12;

-- Slot order across the page, with each armour slot's appearance category
-- (Enum.TransmogCollectionType, identical on both clients). Weapon slots pick
-- their category from a dropdown.
local SLOTS = {
    { id = 1,  name = "HEADSLOT",          label = "Head",      cat = 1 },
    { id = 3,  name = "SHOULDERSLOT",      label = "Shoulder",  cat = 2 },
    { id = 15, name = "BACKSLOT",          label = "Back",      cat = 3 },
    { id = 5,  name = "CHESTSLOT",         label = "Chest",     cat = 4 },
    { id = 4,  name = "SHIRTSLOT",         label = "Shirt",     cat = 5 },
    { id = 19, name = "TABARDSLOT",        label = "Tabard",    cat = 6 },
    { id = 9,  name = "WRISTSLOT",         label = "Wrist",     cat = 7 },
    { id = 10, name = "HANDSSLOT",         label = "Hands",     cat = 8 },
    { id = 6,  name = "WAISTSLOT",         label = "Waist",     cat = 9 },
    { id = 7,  name = "LEGSSLOT",          label = "Legs",      cat = 10 },
    { id = 8,  name = "FEETSLOT",          label = "Feet",      cat = 11 },
    { id = 16, name = "MAINHANDSLOT",      label = "Main Hand", weapon = "main" },
    { id = 17, name = "SECONDARYHANDSLOT", label = "Off Hand",  weapon = "off" },
};
local SLOT_BY_ID = {};
for _, s in ipairs(SLOTS) do SLOT_BY_ID[s.id] = s; end

-- Armour category -> the slot it is worn in (for sets).
local CAT_TO_SLOT = { [1]=1, [2]=3, [3]=15, [4]=5, [5]=4, [6]=19, [7]=9, [8]=10, [9]=6, [10]=7, [11]=8 };
local SHIELD_CAT, HOLDABLE_CAT = 18, 19;

-- Icon order for a look's row on the Outfits page.
local ICON_PRIORITY = { 5, 1, 3, 15, 7, 16, 17, 10, 8, 6, 9, 4, 19 };

-- Page state (session only).
local DR = {
    slot = 1,                 -- the slot being browsed
    mode = "items",           -- "items" or "sets"
    weaponCat = {},           -- [16|17] = the weapon category being browsed
    page = 1,
    search = "",
    allClassSets = false,
};
Addon.DressingRoom = DR;

-- ============================================================================
-- Data
-- ============================================================================

-- The Wardrobe's own filters (collected / not collected / factions / races /
-- sources) apply to GetCategoryAppearances C-side, and they are deliberately
-- LEFT ALONE. V1.14 first flipped them all on around each call and back off
-- after, and on Forever that emptied the lists: a filter change is applied in
-- the background, so the call made straight after got a half-filtered answer
-- (head came back as 1 appearance, then 0, against 245 untouched; shoulders
-- as nothing at all until it settled). So whatever the player's Wardrobe
-- filters hide, the Dressing Room hides too.

-- A transmog location as TransmogLocationMixin:GetData() builds it, made
-- here because Blizzard_TransmogShared is load-on-demand on Forever. Only a
-- fallback: the plain call (no location) is the one measured to work.
local function LocationData(slotID)
    local T, M = Enum and Enum.TransmogType, Enum and Enum.TransmogModification;
    return {
        slotID = slotID,
        type = (T and T.Appearance) or 0,
        modification = (M and M.Main) or 0,
    };
end

local appearanceCache = {};
local function CategoryAppearances(cat, slotID)
    local key = cat .. ":" .. (slotID or 0);
    if appearanceCache[key] then return appearanceCache[key]; end
    local ok, list = pcall(C.GetCategoryAppearances, cat);
    if not (ok and list and #list > 0) and slotID then
        ok, list = pcall(C.GetCategoryAppearances, cat, LocationData(slotID));
    end
    if not ok then list = nil; end
    list = list or {};
    local out = {};
    for _, a in ipairs(list) do
        if a.visualID and not a.isHideVisual then out[#out + 1] = a; end
    end
    table.sort(out, function(x, y)
        local ox, oy = x.uiOrder or 0, y.uiOrder or 0;
        if ox ~= oy then return ox < oy; end
        return x.visualID < y.visualID;
    end);
    -- An empty answer may only mean the collection is not loaded yet; do not
    -- cache it, so the next look asks again.
    if #out > 0 then appearanceCache[key] = out; end
    return out;
end

-- Collection changes (a new appearance learned, the Wardrobe's filters
-- changed) invalidate the cached lists.
do
    local f = CreateFrame("Frame");
    f:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
    pcall(f.RegisterEvent, f, "TRANSMOG_SEARCH_UPDATED");
    f:SetScript("OnEvent", function()
        wipe(appearanceCache);
        if DR.built and Addon.dressingRoomActive and DR.mode == "items" then DR:Refresh(); end
    end);
end

local sourcesCache = {};
local function VisualSources(visualID)
    local s = sourcesCache[visualID];
    if not s then
        local ok, list = pcall(C.GetAllAppearanceSources, visualID);
        s = (ok and list) or {};
        sourcesCache[visualID] = s;
    end
    return s;
end

-- The source to wear for an appearance: a collected one if you have it.
local function PickSource(visualID)
    local sources = VisualSources(visualID);
    for _, sid in ipairs(sources) do
        local ok, info = pcall(C.GetSourceInfo, sid);
        if ok and info and info.isCollected then return sid; end
    end
    return sources[1];
end

local function SourceIcon(sourceID)
    if not sourceID or sourceID == 0 then return nil; end
    local ok, icon = pcall(C.GetSourceIcon, sourceID);
    if ok and icon and icon ~= 0 then return icon; end
    local ok2, info = pcall(C.GetSourceInfo, sourceID);
    if ok2 and info and info.itemID and C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(info.itemID);
    end
end

-- Lower-cased item name for a source, or nil while the item is not cached
-- (the request makes it arrive for the next search).
local nameCache = {};
local function SourceName(sourceID)
    local n = nameCache[sourceID];
    if n then return n; end
    local ok, info = pcall(C.GetSourceInfo, sourceID);
    if ok and info then
        if info.name and info.name ~= "" then
            nameCache[sourceID] = info.name;
            return info.name;
        end
        if info.itemID and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, info.itemID);
        end
    end
end

local function VisualName(visualID)
    for _, sid in ipairs(VisualSources(visualID)) do
        local n = SourceName(sid);
        if n then return n; end
    end
end

-- The category a slot is browsing.
-- Weapon types per hand. The game's own GetCategoryInfo is asked first, but
-- on Forever it answered nil (measured for category 2, 2026-11-18), so a
-- fixed table stands behind it. Names in English where the game gives none.
local WEAPON_FALLBACK = {
    main = { 14, 13, 15, 16, 17, 20, 21, 22, 23, 24, 25, 26, 27, 12, 28 },
    off  = { 18, 19, 14, 13, 15, 16, 17, 28 },
};
local WEAPON_NAMES = {
    [12] = "Wand", [13] = "One-Handed Axe", [14] = "One-Handed Sword", [15] = "One-Handed Mace",
    [16] = "Dagger", [17] = "Fist Weapon", [18] = "Shield", [19] = "Held In Off-hand",
    [20] = "Two-Handed Axe", [21] = "Two-Handed Sword", [22] = "Two-Handed Mace", [23] = "Staff",
    [24] = "Polearm", [25] = "Bow", [26] = "Gun", [27] = "Crossbow", [28] = "Warglaives", [29] = "Paired",
};
local weaponCatsCache = {};
local function WeaponCategories(which)
    if weaponCatsCache[which] then return weaponCatsCache[which]; end
    local list = {};
    for cat = 12, 29 do
        local ok, name, isWeapon, _, canMainHand, canOffHand, canRanged = pcall(C.GetCategoryInfo, cat);
        if ok and name and isWeapon ~= nil then
            local fits;
            if which == "main" then
                fits = (canMainHand or canRanged) and cat ~= SHIELD_CAT and cat ~= HOLDABLE_CAT;
            else
                fits = canOffHand;
            end
            if fits then list[#list + 1] = { cat = cat, name = name }; end
        end
    end
    if #list == 0 then
        for _, cat in ipairs(WEAPON_FALLBACK[which] or {}) do
            list[#list + 1] = { cat = cat, name = WEAPON_NAMES[cat] or ("Type " .. cat) };
        end
    end
    weaponCatsCache[which] = list;
    return list;
end

local function SlotCategory(slot)
    local s = SLOT_BY_ID[slot];
    if not s then return nil; end
    if s.cat then return s.cat; end
    if not DR.weaponCat[slot] then
        local cats = WeaponCategories(s.weapon);
        DR.weaponCat[slot] = cats[1] and cats[1].cat;
    end
    return DR.weaponCat[slot];
end

local function CategorySlot(cat)
    if CAT_TO_SLOT[cat] then return CAT_TO_SLOT[cat]; end
    if cat == SHIELD_CAT or cat == HOLDABLE_CAT then return 17; end
    if cat and cat >= 12 then return 16; end
end

local function HasSets()
    if not C_TransmogSets or not C_TransmogSets.GetAllSets then return false; end
    local ok, sets = pcall(C_TransmogSets.GetAllSets);
    return ok and sets and #sets > 0;
end

-- ============================================================================
-- Looks
-- ============================================================================

local function CopySlots(slots)
    local out = {};
    for slotID in pairs(Addon.LOOK_SLOT_FLAGS) do
        local s = slots and slots[slotID];
        if type(s) == "table" and (s[1] or 0) ~= 0 then
            out[slotID] = { s[1], s[2] or 0, s[3] or 0 };
        else
            out[slotID] = false;
        end
    end
    return out;
end

function Addon:SortedLookIDs()
    local looks = self.db and self.db.global and self.db.global.looks or {};
    local ids = {};
    for id in pairs(looks) do ids[#ids + 1] = id; end
    table.sort(ids, function(a, b)
        local na, nb = (looks[a].name or ""):lower(), (looks[b].name or ""):lower();
        if na ~= nb then return na < nb; end
        return a < b;
    end);
    return ids;
end

function Addon:LookIcon(look)
    local slots = look and look.slots;
    if not slots then return nil; end
    for _, slotID in ipairs(ICON_PRIORITY) do
        local s = slots[slotID];
        if type(s) == "table" then
            local icon = SourceIcon(s[1]);
            if icon then return icon; end
        end
    end
end

-- The draft starts as whatever the avatar on screen is wearing.
function Addon:ResetDraftFromAvatar()
    local list = AvatarModelFrame and self:GetAppearanceSourceList(AvatarModelFrame) or self._baselineTransmogInfo;
    local slots = {};
    for slotID in pairs(self.LOOK_SLOT_FLAGS) do
        local info = list and list[slotID];
        if type(info) == "table" and (info.appearanceID or 0) ~= 0 then
            slots[slotID] = { info.appearanceID, info.secondaryAppearanceID or 0, info.illusionID or 0 };
        else
            slots[slotID] = false;
        end
    end
    self.lookDraft = slots;
end

local function RefreshPreview()
    local pm = Addon.previewModel;
    if pm and Addon.dressingRoomActive then
        -- A new try-on earns a fresh set of DataPending retries (core.lua).
        pm._avatarRetries = 0;
        Addon:RefreshEquipmentOnModel(pm);
    end
end

-- Why the preview could not draw a slot, from the model's own answer
-- (Enum.ItemTryOnReason), or nil when it did.
local function TryOnProblem(slotID)
    local pm = Addon.previewModel;
    -- Forever accepts a piece your character could not display with Success
    -- and simply does not draw it, so ask the source itself first.
    local d = Addon.lookDraft and Addon.lookDraft[slotID];
    if type(d) == "table" then
        local ok, info = pcall(C.GetSourceInfo, d[1]);
        if ok and info and info.canDisplayOnPlayer == false then
            return "The game won't draw this on your character (usually an armour type your class can't wear).";
        end
    end
    local r = pm and pm._avatarTryOn and pm._avatarTryOn[slotID];
    local E = Enum and Enum.ItemTryOnReason;
    if not (r and E) or r == E.Success then return nil; end
    if r == E.WrongRace then return "Your race can't show this on the preview."; end
    if r == E.NotEquippable then return "The game won't show this on your character."; end
    if r == E.DataPending then return "Still loading..."; end
    return "Can't be shown (" .. tostring(r) .. ").";
end

local function SetDraftSlot(slotID, sourceID)
    if not Addon.lookDraft then Addon:ResetDraftFromAvatar(); end
    Addon.lookDraft[slotID] = sourceID and { sourceID, 0, 0 } or false;
    RefreshPreview();
    DR:Refresh();
end

-- After a saved look changes: the Outfits list, and the avatar if it wears it.
local function LooksChanged(id)
    local char = Addon.db.char;
    if id and char.outfitPreview.enabled and char.outfitPreview.customSetID == id then
        Addon:RefreshEquipmentToggle();
    end
    Addon:RefreshOutfitsList();
    DR:Refresh();
end

function Addon:SaveDraftAsLook(name, id)
    if not self.lookDraft then return; end
    local g = self.db.global;
    if not id then
        name = name and strtrim(name) or "";
        if name == "" then return; end
        id = "look:" .. (g.nextLookID or 1);
        g.nextLookID = (g.nextLookID or 1) + 1;
        g.looks[id] = { name = name };
    end
    local look = g.looks[id];
    if not look then return; end
    look.slots = CopySlots(self.lookDraft);
    DR.editingID = id;
    LooksChanged(id);
end

function Addon:DeleteLook(id)
    local g = self.db.global;
    if not (id and g.looks[id]) then return; end
    g.looks[id] = nil;
    -- This character stops wearing it; another character that chose it falls
    -- back to equipped gear by itself (Addon:ModelOutfit).
    local char = self.db.char;
    if char.outfitPreview.customSetID == id then
        char.outfitPreview.enabled = false;
        char.outfitPreview.customSetID = nil;
    end
    for spec, v in pairs(char.outfitBySpec) do
        if v == id then char.outfitBySpec[spec] = nil; end
    end
    if DR.editingID == id then DR.editingID = nil; end
    self:RefreshEquipmentToggle();
    LooksChanged(nil);
end

-- Put a saved look on the avatar, the same way picking it on the Outfits page does.
function Addon:WearLook(id)
    local char = self.db.char;
    char.outfitPreview.enabled = true;
    char.outfitPreview.customSetID = id;
    if char.outfitPerSpec then
        local spec = self:CurrentSpecID();
        if spec then char.outfitBySpec[spec] = id; end
    end
    self:RefreshEquipmentToggle();
    self:RefreshOutfitsList();
end

StaticPopupDialogs["AVATAR_SAVE_LOOK"] = {
    text = "Name this look:",
    button1 = SAVE,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 48,
    OnAccept = function(dialog)
        local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.EditBox;
        Addon:SaveDraftAsLook(editBox and editBox:GetText());
    end,
    EditBoxOnEnterPressed = function(editBox)
        Addon:SaveDraftAsLook(editBox:GetText());
        editBox:GetParent():Hide();
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide();
    end,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
};

StaticPopupDialogs["AVATAR_DELETE_LOOK"] = {
    text = "Delete the look '%s'?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, id) Addon:DeleteLook(id); end,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
};

-- The settings window is DIALOG strata, the same tier as the popups, so a
-- popup could open underneath it.
local function ShowPopup(which, textArg, data)
    local dialog = StaticPopup_Show(which, textArg, nil, data);
    if dialog then dialog:SetFrameStrata("FULLSCREEN_DIALOG"); end
    return dialog;
end

-- ============================================================================
-- Page activation
-- ============================================================================

-- WoW Forever's Wardrobe has no "Not Collected" checkbox, so if uncollected
-- appearances ever end up hidden (V1.14's first build did exactly that, by
-- switching filters around each lookup: Forever's getter and the state it
-- actually used disagreed, and the "restore" turned it off for good) the
-- player has no way back and every list shows only what they own. On
-- Forever only, put it back. The change applies in the background; the
-- TRANSMOG_* event handler above wipes the lists and re-draws when it lands.
local function IsForever()
    local toc = select(4, GetBuildInfo());
    return toc and toc >= 16000 and toc < 20000;
end

local function EnsureUncollectedShownOnForever()
    if not IsForever() then return; end
    if not (C.GetUncollectedShown and C.SetUncollectedShown) then return; end
    local ok, shown = pcall(C.GetUncollectedShown);
    if ok and shown == false then
        pcall(C.SetUncollectedShown, true);
        wipe(appearanceCache);
    end
end

function Addon:SetDressingRoomActive(on)
    on = on and true or false;
    if self.dressingRoomActive == on then return; end
    self.dressingRoomActive = on;
    local pm = self.previewModel;
    if on then
        EnsureUncollectedShownOnForever();
        if not self.lookDraft then self:ResetDraftFromAvatar(); end
        if pm then
            pm._avatarOutfitOverride = Addon.DRAFT_LOOK;
            self:RefreshEquipmentOnModel(pm);
        end
        DR:Refresh();
    else
        if pm then
            pm._avatarOutfitOverride = nil;
            pm:SetFacing(self.db.profile.facing or 0);
        end
        -- Puts back the spec override the Outfits page may want.
        self:RefreshOutfitsList();
        if pm then self:RefreshEquipmentOnModel(pm); end
    end
end

-- ============================================================================
-- UI
-- ============================================================================

local function SmallButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
    b:SetSize(width or 90, 22);
    b:SetText(text);
    return b;
end

local function Tip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP");
        GameTooltip:SetText(title, 1, 1, 1);
        if text then GameTooltip:AddLine(text, nil, nil, nil, true); end
        GameTooltip:Show();
    end);
    frame:HookScript("OnLeave", function() GameTooltip:Hide(); end);
end

-- The filtered list the grid/list is paging through.
local function CurrentList()
    local search = DR.search ~= "" and DR.search:lower() or nil;
    DR.namesPending = false;
    if DR.mode == "sets" then
        local ok, sets = pcall(C_TransmogSets.GetAllSets);
        local out = {};
        for _, set in ipairs(ok and sets or {}) do
            if DR.allClassSets or set.validForCharacter then
                local hay = ((set.name or "") .. " " .. (set.label or "") .. " " .. (set.description or "")):lower();
                if not search or hay:find(search, 1, true) then out[#out + 1] = set; end
            end
        end
        table.sort(out, function(a, b)
            local ea, eb = a.expansionID or 0, b.expansionID or 0;
            if ea ~= eb then return ea > eb; end
            local oa, ob = a.uiOrder or 0, b.uiOrder or 0;
            if oa ~= ob then return oa < ob; end
            return (a.setID or 0) < (b.setID or 0);
        end);
        return out;
    end
    local cat = SlotCategory(DR.slot);
    local all = cat and CategoryAppearances(cat, DR.slot) or {};
    if not search then return all; end
    local out = {};
    for _, a in ipairs(all) do
        local matched = false;
        for _, sid in ipairs(VisualSources(a.visualID)) do
            local n = SourceName(sid);
            if not n then
                DR.namesPending = true;
            elseif n:lower():find(search, 1, true) then
                matched = true;
                break;
            end
        end
        if matched then out[#out + 1] = a; end
    end
    return out;
end

-- Try on every primary piece of a set, keeping the slots it does not cover.
local function TryOnSet(setID)
    local ok, apps = pcall(C_TransmogSets.GetSetPrimaryAppearances, setID);
    if not (ok and apps) then return; end
    if not Addon.lookDraft then Addon:ResetDraftFromAvatar(); end
    for _, a in ipairs(apps) do
        local sid = a.appearanceID;
        local okc, cat = pcall(C.GetCategoryForItem, sid);
        if not (okc and cat and cat ~= 0) then
            local oki, info = pcall(C.GetSourceInfo, sid);
            cat = oki and info and info.categoryID;
        end
        local slot = CategorySlot(cat);
        -- Ask for the item now so a DataPending retry has something to find.
        local oki, info = pcall(C.GetSourceInfo, sid);
        if oki and info and info.itemID and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, info.itemID);
        end
        if slot and Addon.LOOK_SLOT_FLAGS[slot] then
            Addon.lookDraft[slot] = { sid, 0, 0 };
        end
    end
    RefreshPreview();
    DR:Refresh();
end

-- ============================================================================
-- Grid cell models. A copy of Blizzard's Wardrobe set-up (ItemModelBaseMixin
-- :Reload and WARDROBE_MODEL_SETUP in Blizzard_TransmogShared, identical on
-- retail and Forever), rewritten here because that file is load-on-demand on
-- Forever. Armour cells are your own character wearing a few plain "setup"
-- pieces (so a helm is not floating on a bare head) plus the appearance, and
-- a per-appearance camera frames the slot. Weapon cells draw the weapon alone.
-- These are throwaway models, separate from the avatar and the preview, so
-- re-running SetUnit on them is fine (the once-only rule in CLAUDE.md is
-- about the avatar's own models).
-- ============================================================================
local CELL_SETUP_GEAR = { [5] = 78420, [7] = 78425, [8] = 78427, [10] = 78426, [1] = 78416 };
local HEAD_ONLY = { 1 };
local CELL_SETUP = {
    [1]  = { skin = false, choices = false, obey = false, gear = { 5 } },
    [3]  = { skin = true,  choices = true,  obey = true,  gear = HEAD_ONLY },
    [15] = { skin = true,  choices = true,  obey = true,  gear = HEAD_ONLY },
    [5]  = { skin = true,  choices = true,  obey = true,  gear = HEAD_ONLY },
    [19] = { skin = true,  choices = true,  obey = true,  gear = HEAD_ONLY },
    [4]  = { skin = true,  choices = true,  obey = true,  gear = HEAD_ONLY },
    [9]  = { skin = true,  choices = true,  obey = true,  gear = HEAD_ONLY },
    [6]  = { skin = true,  choices = true,  obey = true,  gear = HEAD_ONLY },
    [7]  = { skin = true,  choices = true,  obey = true,  gear = HEAD_ONLY },
    [10] = { skin = false, choices = true,  obey = true,  gear = { 5, 7, 8, 1 } },
    [8]  = { skin = false, choices = true,  obey = true,  gear = { 5, 10, 7, 1 } },
};

-- Sets a cell model up for a slot. false while the player's model is not
-- ready yet (the next refresh tries again).
local function PrepareCellModel(m, slot)
    local setup = CELL_SETUP[slot];
    local key = setup and slot or "weapon";
    if m.setupKey == key then return true; end
    if setup then
        if not IsUnitModelReadyForUI("player") then return false; end
        pcall(m.SetUseTransmogSkin, m, setup.skin);
        pcall(m.SetUseTransmogChoices, m, setup.choices);
        pcall(m.SetObeyHideInTransmogFlag, m, setup.obey);
        local native = PlayerUtil and PlayerUtil.ShouldUseNativeFormInModelScene
            and PlayerUtil.ShouldUseNativeFormInModelScene() or nil;
        m:SetUnit("player", false, native);
        for _, s in ipairs(setup.gear) do
            pcall(m.TryOn, m, CELL_SETUP_GEAR[s]);
        end
    end
    pcall(m.SetKeepModelOnHide, m, true);
    m.setupKey = key;
    m.visualID = nil;
    m.cameraID = nil;
    return true;
end

local function ShowCellAppearance(m, slot, a)
    if not PrepareCellModel(m, slot) then return; end
    local okc, cam = pcall(C.GetAppearanceCameraID, a.visualID, 0);
    if okc and cam and cam ~= m.cameraID and Model_ApplyUICamera then
        m.cameraID = cam;
        Model_ApplyUICamera(m, cam);
    end
    if m.visualID ~= a.visualID then
        m.visualID = a.visualID;
        if CELL_SETUP[slot] then
            local sid = PickSource(a.visualID);
            if sid then pcall(m.TryOn, m, sid); end
        else
            pcall(m.SetItemAppearance, m, a.visualID);
        end
    end
    pcall(m.SetDesaturation, m, (a.canDisplayOnPlayer == false) and 1 or 0);
end

function Addon:BuildDressingRoom(parent, sy)
    local W = 370;

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    hint:SetWidth(W);
    hint:SetJustifyH("LEFT");
    hint:SetText("Try on anything, collected or not, then save it as a look. Saved looks are picked on the Outfits page like any outfit. Right-click a slot to empty it.");
    sy = sy - 34;

    -- Look picker + start-over buttons.
    local lookDD = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate");
    lookDD:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    lookDD:SetWidth(170);
    lookDD:SetupMenu(function(_, root)
        root:CreateRadio("New look", function() return DR.editingID == nil; end, function()
            DR.editingID = nil;
            DR:Refresh();
        end);
        for _, id in ipairs(Addon:SortedLookIDs()) do
            local look = Addon:GetLook(id);
            root:CreateRadio(look.name or id, function() return DR.editingID == id; end, function()
                DR.editingID = id;
                Addon.lookDraft = CopySlots(look.slots);
                RefreshPreview();
                DR:Refresh();
            end);
        end
    end);
    Tip(lookDD, "Look", "Start a new look, or load a saved one to change it.");
    DR.lookDD = lookDD;

    local fromAvatar = SmallButton(parent, "From Avatar", 92);
    fromAvatar:SetPoint("LEFT", lookDD, "RIGHT", 6, 0);
    fromAvatar:SetScript("OnClick", function()
        Addon:ResetDraftFromAvatar();
        RefreshPreview();
        DR:Refresh();
    end);
    Tip(fromAvatar, "From Avatar", "Start again from what your avatar is wearing now.");

    local strip = SmallButton(parent, "Strip All", 80);
    strip:SetPoint("LEFT", fromAvatar, "RIGHT", 4, 0);
    strip:SetScript("OnClick", function()
        if not Addon.lookDraft then Addon:ResetDraftFromAvatar(); end
        for slotID in pairs(Addon.LOOK_SLOT_FLAGS) do Addon.lookDraft[slotID] = false; end
        RefreshPreview();
        DR:Refresh();
    end);
    Tip(strip, "Strip All", "Empty every slot.");
    sy = sy - 34;

    -- Slot buttons.
    DR.slotButtons = {};
    for i, s in ipairs(SLOTS) do
        local b = CreateFrame("Button", nil, parent);
        b:SetSize(26, 26);
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", 4 + (i - 1) * 28, sy);
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp");
        b.ring = b:CreateTexture(nil, "BACKGROUND");
        b.ring:SetPoint("TOPLEFT", -2, 2);
        b.ring:SetPoint("BOTTOMRIGHT", 2, -2);
        b.ring:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9);
        b.icon = b:CreateTexture(nil, "ARTWORK");
        b.icon:SetAllPoints();
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
        local hl = b:CreateTexture(nil, "HIGHLIGHT");
        hl:SetAllPoints();
        hl:SetColorTexture(1, 1, 1, 0.15);
        local ok, _, emptyTex = pcall(GetInventorySlotInfo, s.name);
        b.emptyTex = ok and emptyTex or nil;
        b.slot = s;
        b:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                SetDraftSlot(s.id, nil);
                return;
            end
            DR.slot = s.id;
            DR.mode = "items";
            DR.page = 1;
            DR:Refresh();
        end);
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP");
            GameTooltip:SetText(s.label, 1, 1, 1);
            local d = Addon.lookDraft and Addon.lookDraft[s.id];
            if type(d) == "table" then
                GameTooltip:AddLine(SourceName(d[1]) or "Loading...", 0.9, 0.9, 0.9);
                local problem = TryOnProblem(s.id);
                if problem then GameTooltip:AddLine(problem, 1, 0.4, 0.4, true); end
            else
                GameTooltip:AddLine("Empty", 0.6, 0.6, 0.6);
            end
            GameTooltip:AddLine("Left-click to browse, right-click to empty.", 0.6, 0.6, 0.6, true);
            GameTooltip:Show();
        end);
        b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
        DR.slotButtons[#DR.slotButtons + 1] = b;
    end
    sy = sy - 36;

    -- Items / Sets toggle, weapon type, search.
    local itemsBtn = SmallButton(parent, "Items", 60);
    itemsBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    itemsBtn:SetScript("OnClick", function() DR.mode = "items"; DR.page = 1; DR:Refresh(); end);
    local setsBtn = SmallButton(parent, "Sets", 60);
    setsBtn:SetPoint("LEFT", itemsBtn, "RIGHT", 4, 0);
    setsBtn:SetScript("OnClick", function() DR.mode = "sets"; DR.page = 1; DR:Refresh(); end);
    Tip(setsBtn, "Sets", "Browse the game's armour sets and try on a whole set at once.");
    DR.itemsBtn, DR.setsBtn = itemsBtn, setsBtn;

    local weaponDD = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate");
    weaponDD:SetPoint("LEFT", setsBtn, "RIGHT", 6, 0);
    weaponDD:SetWidth(110);
    weaponDD:SetupMenu(function(_, root)
        local s = SLOT_BY_ID[DR.slot];
        if not (s and s.weapon) then return; end
        if root.SetScrollMode then root:SetScrollMode(20 * 20); end
        for _, c in ipairs(WeaponCategories(s.weapon)) do
            root:CreateRadio(c.name, function() return DR.weaponCat[DR.slot] == c.cat; end, function()
                DR.weaponCat[DR.slot] = c.cat;
                DR.page = 1;
                DR:Refresh();
            end);
        end
    end);
    DR.weaponDD = weaponDD;

    local allClasses = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate");
    allClasses:SetSize(24, 24);
    allClasses:SetPoint("LEFT", setsBtn, "RIGHT", 4, 0);
    allClasses.label = allClasses:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    allClasses.label:SetPoint("LEFT", allClasses, "RIGHT", 0, 0);
    allClasses.label:SetText("All classes");
    allClasses:SetScript("OnClick", function(cb)
        DR.allClassSets = cb:GetChecked() and true or false;
        DR.page = 1;
        DR:Refresh();
    end);
    DR.allClasses = allClasses;

    local search = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate");
    search:SetSize(110, 20);
    search:SetPoint("TOPRIGHT", parent, "TOPLEFT", 4 + W, sy - 1);
    search:SetAutoFocus(false);
    -- Search on Enter (and on clearing): a name search over a big category
    -- walks every source, which is too much to repeat per keystroke.
    search:HookScript("OnEnterPressed", function(self)
        DR.search = strtrim(self:GetText() or "");
        DR.page = 1;
        self:ClearFocus();
        DR:Refresh();
    end);
    search:HookScript("OnTextChanged", function(self)
        if (self:GetText() or "") == "" and DR.search ~= "" then
            DR.search = "";
            DR.page = 1;
            DR:Refresh();
        end
    end);
    Tip(search, "Search", "Type part of an item or set name and press Enter.");
    DR.searchBox = search;
    sy = sy - 30;

    -- Item grid: a small 3D model per appearance, framed on the slot the way
    -- Blizzard's Wardrobe does it (see PrepareCellModel / ShowCellAppearance).
    local gridTop = sy;
    DR.cells = {};
    for i = 1, PAGE_SIZE do
        local c = CreateFrame("Button", nil, parent);
        c:SetSize(CELL_W, CELL_H);
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS);
        c:SetPoint("TOPLEFT", parent, "TOPLEFT", 4 + col * (CELL_W + CELL_GAP), gridTop - row * (CELL_H + CELL_GAP));
        c.bg = c:CreateTexture(nil, "BACKGROUND");
        c.bg:SetAllPoints();
        c.bg:SetColorTexture(0.09, 0.09, 0.11, 1);

        local m = CreateFrame("DressUpModel", nil, c);
        m:SetPoint("TOPLEFT", 1, -1);
        m:SetPoint("BOTTOMRIGHT", -1, 1);
        m:EnableMouse(false);
        m:EnableMouseWheel(false);
        pcall(m.SetAutoDress, m, false);
        if CreateVector3D and CreateColor then
            pcall(m.SetLight, m, true, {
                omnidirectional = false,
                point = CreateVector3D(-1, 1, -1),
                ambientIntensity = 1.05,
                ambientColor = CreateColor(1, 1, 1),
                diffuseIntensity = 0,
                diffuseColor = CreateColor(1, 1, 1),
            });
        end
        -- A model that finishes loading resets its camera; put ours back.
        m:SetScript("OnModelLoaded", function(self)
            if self.cameraID and Model_ApplyUICamera then Model_ApplyUICamera(self, self.cameraID); end
        end);
        c.model = m;

        -- Border, owned tick and hover glow sit above the model.
        local over = CreateFrame("Frame", nil, c);
        over:SetAllPoints();
        over:SetFrameLevel(m:GetFrameLevel() + 2);
        c.edges = {};
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                             { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
            local t = over:CreateTexture(nil, "OVERLAY");
            t:SetPoint(e[1]);
            t:SetPoint(e[2]);
            if e[3] then t:SetHeight(2); else t:SetWidth(2); end
            c.edges[#c.edges + 1] = t;
        end
        c.owned = over:CreateTexture(nil, "OVERLAY");
        c.owned:SetSize(14, 14);
        c.owned:SetPoint("BOTTOMRIGHT", -3, 3);
        c.owned:SetAtlas("common-icon-checkmark");
        c.hl = over:CreateTexture(nil, "ARTWORK");
        c.hl:SetAllPoints();
        c.hl:SetColorTexture(1, 1, 1, 0.08);
        c.hl:Hide();
        c:HookScript("OnEnter", function(self) self.hl:Show(); end);
        c:HookScript("OnLeave", function(self) self.hl:Hide(); end);

        c:SetScript("OnClick", function(self)
            if not self.visualID then return; end
            local sid = PickSource(self.visualID);
            if sid then SetDraftSlot(DR.slot, sid); end
        end);
        c:HookScript("OnEnter", function(self)
            if not self.visualID then return; end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetText(VisualName(self.visualID) or "Loading...", 1, 1, 1);
            GameTooltip:AddLine(self.collected and "Collected" or "Not collected",
                self.collected and 0.3 or 0.7, self.collected and 1 or 0.7, self.collected and 0.3 or 0.7);
            if self.noDisplay then
                GameTooltip:AddLine("The game won't draw this on your character (usually an armour type your class can't wear).", 1, 0.4, 0.4, true);
            end
            GameTooltip:AddLine("Click to try it on.", 0.6, 0.6, 0.6);
            GameTooltip:Show();
        end);
        c:HookScript("OnLeave", function() GameTooltip:Hide(); end);
        DR.cells[i] = c;
    end

    -- Set list (same area as the grid).
    DR.setRows = {};
    for i = 1, SET_ROWS do
        local r = CreateFrame("Button", nil, parent);
        r:SetSize(W - 4, 22);
        r:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, gridTop - (i - 1) * 23);
        local bg = r:CreateTexture(nil, "BACKGROUND");
        bg:SetAllPoints();
        bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06);
        local hl = r:CreateTexture(nil, "HIGHLIGHT");
        hl:SetAllPoints();
        hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.2);
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        r.text:SetPoint("LEFT", r, "LEFT", 6, 0);
        r.text:SetPoint("RIGHT", r, "RIGHT", -6, 0);
        r.text:SetJustifyH("LEFT");
        r.text:SetWordWrap(false);
        r:SetScript("OnClick", function(self) if self.setID then TryOnSet(self.setID); end end);
        r:SetScript("OnEnter", function(self)
            if not self.set then return; end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetText(self.set.name or "", 1, 1, 1);
            if self.set.label and self.set.label ~= "" then GameTooltip:AddLine(self.set.label, 0.9, 0.8, 0.5); end
            if self.set.description and self.set.description ~= "" then GameTooltip:AddLine(self.set.description, 0.8, 0.8, 0.8, true); end
            GameTooltip:AddLine(self.set.collected and "Collected" or "Not collected", 0.7, 0.7, 0.7);
            GameTooltip:AddLine("Click to try on the whole set.", 0.6, 0.6, 0.6);
            GameTooltip:Show();
        end);
        r:SetScript("OnLeave", function() GameTooltip:Hide(); end);
        DR.setRows[i] = r;
    end
    sy = gridTop - ROWS * (CELL_H + CELL_GAP) - 4;

    -- Paging.
    local prev = SmallButton(parent, "<", 30);
    prev:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    prev:SetScript("OnClick", function() DR.page = math.max(1, DR.page - 1); DR:Refresh(); end);
    local nextB = SmallButton(parent, ">", 30);
    nextB:SetPoint("LEFT", prev, "RIGHT", 4, 0);
    nextB:SetScript("OnClick", function() DR.page = DR.page + 1; DR:Refresh(); end);
    local pageText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    pageText:SetPoint("LEFT", nextB, "RIGHT", 8, 0);
    pageText:SetPoint("RIGHT", parent, "LEFT", 4 + W, 0);
    pageText:SetJustifyH("LEFT");
    pageText:SetWordWrap(false);
    DR.prevBtn, DR.nextBtn, DR.pageText = prev, nextB, pageText;
    sy = sy - 32;

    -- Save / wear / delete, and turning the preview.
    local editing = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    editing:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    editing:SetWidth(W);
    editing:SetJustifyH("LEFT");
    DR.editingText = editing;
    sy = sy - 20;

    local save = SmallButton(parent, "Save", 70);
    save:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    save:SetScript("OnClick", function()
        if DR.editingID then
            Addon:SaveDraftAsLook(nil, DR.editingID);
        else
            ShowPopup("AVATAR_SAVE_LOOK");
        end
    end);
    Tip(save, "Save", "Save the look you are editing, or name a new one.");
    local saveAs = SmallButton(parent, "Save As New", 96);
    saveAs:SetPoint("LEFT", save, "RIGHT", 4, 0);
    saveAs:SetScript("OnClick", function() ShowPopup("AVATAR_SAVE_LOOK"); end);
    local wear = SmallButton(parent, "Wear", 60);
    wear:SetPoint("LEFT", saveAs, "RIGHT", 4, 0);
    wear:SetScript("OnClick", function()
        if DR.editingID then
            Addon:SaveDraftAsLook(nil, DR.editingID);
            Addon:WearLook(DR.editingID);
        end
    end);
    Tip(wear, "Wear", "Save this look and put it on your avatar now.");
    local delete = SmallButton(parent, "Delete", 64);
    delete:SetPoint("LEFT", wear, "RIGHT", 4, 0);
    delete:SetScript("OnClick", function()
        local look = DR.editingID and Addon:GetLook(DR.editingID);
        if look then ShowPopup("AVATAR_DELETE_LOOK", look.name or DR.editingID, DR.editingID); end
    end);
    DR.wearBtn, DR.deleteBtn = wear, delete;
    sy = sy - 30;

    local rotL = SmallButton(parent, "Turn Left", 84);
    rotL:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, sy);
    rotL:SetScript("OnClick", function()
        local pm = Addon.previewModel;
        if pm then pm:SetFacing(pm:GetFacing() - 0.5); end
    end);
    local rotR = SmallButton(parent, "Turn Right", 84);
    rotR:SetPoint("LEFT", rotL, "RIGHT", 4, 0);
    rotR:SetScript("OnClick", function()
        local pm = Addon.previewModel;
        if pm then pm:SetFacing(pm:GetFacing() + 0.5); end
    end);
    sy = sy - 30;

    DR.built = true;
    return sy;
end

function DR:Refresh()
    if not self.built then return; end
    local draft = Addon.lookDraft or {};

    -- Look picker and buttons.
    local look = self.editingID and Addon:GetLook(self.editingID);
    if self.editingID and not look then self.editingID = nil; look = nil; end
    self.lookDD:GenerateMenu();
    self.lookDD:SetText(look and (look.name or self.editingID) or "New look");
    self.editingText:SetText(look and ("Editing: " .. (look.name or "")) or "Editing: a new look (Save names it)");
    self.wearBtn:SetEnabled(look ~= nil);
    self.deleteBtn:SetEnabled(look ~= nil);

    -- Slot buttons.
    for _, b in ipairs(self.slotButtons) do
        local d = draft[b.slot.id];
        local icon = type(d) == "table" and SourceIcon(d[1]) or nil;
        b.icon:SetTexture(icon or b.emptyTex);
        b.icon:SetDesaturated(icon == nil);
        -- Red: the preview could not draw this piece (see the tooltip).
        if icon and TryOnProblem(b.slot.id) then
            b.icon:SetVertexColor(1, 0.35, 0.35);
        else
            b.icon:SetVertexColor(1, 1, 1);
        end
        b.ring:SetShown(self.mode == "items" and self.slot == b.slot.id);
    end

    local sets = HasSets();
    if not sets and self.mode == "sets" then self.mode = "items"; end
    self.setsBtn:SetShown(sets);
    self.itemsBtn:SetEnabled(self.mode ~= "items");
    self.setsBtn:SetEnabled(self.mode ~= "sets");
    local s = SLOT_BY_ID[self.slot];
    local weapon = self.mode == "items" and s and s.weapon;
    self.weaponDD:SetShown(weapon and true or false);
    if weapon then
        SlotCategory(self.slot);
        self.weaponDD:GenerateMenu();
        for _, c in ipairs(WeaponCategories(s.weapon)) do
            if c.cat == self.weaponCat[self.slot] then self.weaponDD:SetText(c.name); end
        end
    end
    self.allClasses:SetShown(self.mode == "sets");
    self.allClasses:SetChecked(self.allClassSets);
    if (self.searchBox:GetText() or "") ~= self.search then self.searchBox:SetText(self.search); end

    local list = CurrentList();
    local perPage = self.mode == "sets" and SET_ROWS or PAGE_SIZE;
    local pages = math.max(1, math.ceil(#list / perPage));
    if self.page > pages then self.page = pages; end
    local first = (self.page - 1) * perPage;

    -- The draft's appearance in this slot, to mark it in the grid.
    local wornVisual;
    local d = draft[self.slot];
    if type(d) == "table" then
        local ok, info = pcall(C.GetSourceInfo, d[1]);
        wornVisual = ok and info and info.visualID;
    end

    for i, c in ipairs(self.cells) do
        local a = self.mode == "items" and list[first + i];
        if a then
            c.visualID = a.visualID;
            c.collected = a.isCollected;
            c.owned:SetShown(a.isCollected and true or false);
            -- Greyed: the model will not draw it on you (Forever, mostly).
            c.noDisplay = (a.canDisplayOnPlayer == false);
            local r, g, b = 0.25, 0.25, 0.30;
            if a.visualID == wornVisual then r, g, b = GOLD[1], GOLD[2], GOLD[3]; end
            for _, t in ipairs(c.edges) do t:SetColorTexture(r, g, b, 1); end
            c:Show();
            -- A model only loads while it can be seen; a hidden page is
            -- dressed by the Refresh that runs when it is shown.
            if c:IsVisible() then ShowCellAppearance(c.model, self.slot, a); end
        else
            c.visualID = nil;
            c:Hide();
        end
    end
    for i, r in ipairs(self.setRows) do
        local set = self.mode == "sets" and list[first + i];
        if set then
            r.setID, r.set = set.setID, set;
            local label = (set.label and set.label ~= "") and ("  |cff999999" .. set.label .. "|r") or "";
            r.text:SetText((set.collected and "|cff66ff66" or "|cffffffff") .. (set.name or "?") .. "|r" .. label);
            r:Show();
        else
            r.setID, r.set = nil, nil;
            r:Hide();
        end
    end

    self.prevBtn:SetEnabled(self.page > 1);
    self.nextBtn:SetEnabled(self.page < pages);
    local what;
    if self.mode == "sets" then
        what = #list .. " sets";
    else
        local owned = 0;
        for _, a in ipairs(list) do if a.isCollected then owned = owned + 1; end end
        what = #list .. " appearances, " .. owned .. " collected";
        if #list == 0 and self.search == "" then what = "Nothing listed yet - try again in a moment"; end
    end
    if self.namesPending then what = what .. " (names still loading, search again)"; end
    self.pageText:SetText(string.format("Page %d/%d  -  %s", self.page, pages, what));
end
