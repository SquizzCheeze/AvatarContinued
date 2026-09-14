--[[ Avatar Continued -- welcome / release notes

    The first-run greeting and the "what changed" note after an update. One
    frame serves both: they differ only in their heading and body, and both are
    "say this once, then never again".

    Ported from SquizzFrames' Modules/Welcome/Welcome.lua, which was itself
    ported from Squizzumables' Core/Welcome.lua. The details those two learned
    the hard way come with it: the scrolling body, the three-way
    first-run/update/nothing decision, and the seen-version key read straight
    off the SavedVariable root.

    WHY THE NOTES ARE DUPLICATED HERE rather than read from changelog.txt: an
    addon cannot read its own text files at runtime, so anything shown in game
    has to live in Lua. This is a HIGHLIGHT list, not a changelog. Keep it to
    what a player would notice.
]]

local addon_name = ...;
local Addon = _G[addon_name];
if not Addon then return; end

-- Highlights per version, newest first, keyed by the .toc Version string.
-- ADD AN ENTRY AS PART OF RELEASING -- see CLAUDE.md's Releasing section.
-- A version with no entry still shows the update note, just without bullets.
local RELEASE_NOTES = {
    ["1.7"] = {
        "This window is new: a short note about what changed, once per update. Type /avatar notes to see it again.",
        "Hide Avatar in Combat now actually hides it.",
        "Light colour swatches, creating a profile and deleting a profile all work again.",
        "The Avatar Continued entry under Options > AddOns no longer leaves the settings window stranded off screen.",
        "Opening the settings no longer nudges your saved values, such as avatar facing.",
    },
};

local function CurrentVersion()
    return (C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(addon_name, "Version")) or "?";
end

-- Same palette as the settings window.
local ACCENT = { 0.78, 0.65, 0.30 };

local frame;

-- Narrower than the frame by the scroll bar's gutter, so a long note is not
-- drawn underneath it.
local BODY_WIDTH = 404;

local function BuildFrame()
    if frame then return frame; end

    frame = CreateFrame("Frame", "AvatarContinuedWelcome", UIParent, "BackdropTemplate");
    frame:SetSize(460, 320);
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60);
    frame:SetFrameStrata("DIALOG");
    frame:SetMovable(true);
    frame:EnableMouse(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetScript("OnDragStart", frame.StartMoving);
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
    frame:SetBackdrop({
        bgFile   = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    });
    frame:SetBackdropColor(0.05, 0.05, 0.06, 0.97);
    frame:SetBackdropBorderColor(0.3, 0.3, 0.35, 1);
    frame:Hide();

    -- Escape closes it, like any other dialog.
    table.insert(UISpecialFrames, "AvatarContinuedWelcome");

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16);
    title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1);
    frame.title = title;

    -- THE NOTES SCROLL, and that is not optional.
    --
    -- Squizzumables first shipped this as one FontString on a fixed-height
    -- frame, which silently relied on every release having few enough bullets
    -- to fit. The release with eight ran under the buttons and off the bottom,
    -- and the last three were unreachable. Nothing warns you: the text simply
    -- draws outside its parent.
    --
    -- Bounded between the title and the buttons rather than sized to the text,
    -- so however long a future release's notes are, the frame stays put and the
    -- buttons stay reachable.
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate");
    scroll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12);
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 52);
    frame.scroll = scroll;

    local content = CreateFrame("Frame", nil, scroll);
    content:SetSize(BODY_WIDTH, 1);
    scroll:SetScrollChild(content);
    frame.content = content;

    local body = content:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0);
    body:SetWidth(BODY_WIDTH);
    body:SetJustifyH("LEFT");
    body:SetJustifyV("TOP");
    body:SetSpacing(4);
    body:SetTextColor(0.85, 0.85, 0.85, 1);
    frame.body = body;

    local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
    settingsButton:SetSize(130, 24);
    settingsButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 16);
    settingsButton:SetText("Open Settings");
    settingsButton:SetScript("OnClick", function()
        frame:Hide();
        Addon:ShowOptions();
    end);

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
    closeButton:SetSize(90, 24);
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 16);
    closeButton:SetText("Close");
    closeButton:SetScript("OnClick", function() frame:Hide(); end);

    return frame;
end

local function Show(titleText, bodyText)
    local f = BuildFrame();
    f.title:SetText(titleText);
    f.body:SetText(bodyText);

    -- Size the scroll child to the text, AFTER SetText so the height is the
    -- wrapped height rather than the pre-layout one. Without this the child
    -- keeps its placeholder height of 1, the scroll frame decides there is
    -- nothing to scroll, and the overflow bug comes straight back.
    f.content:SetHeight(math.max(1, f.body:GetStringHeight() + 4));

    -- Back to the top: the frame is reused, so re-opening it through
    -- /avatar notes would otherwise restore wherever the last read was left.
    f.scroll:SetVerticalScroll(0);

    f:Show();
end

-- The greeting for someone who has never run the addon.
local function ShowFirstRun()
    Show("Welcome to Avatar Continued",
        "Avatar Continued puts your character on screen as part of your UI.\n\n"
     .. "To place it, type /avatar unlock. Drag with the left mouse button to move it, "
     .. "drag with the right to resize it, and use the mouse wheel to turn it. "
     .. "Type /avatar lock when you are done.\n\n"
     .. "Everything else is under /avatar: lighting, pose, which parts of your gear show, "
     .. "and your saved Wardrobe outfits, with a live preview as you change them.");
end

-- The note after updating.
local function ShowUpdated(version)
    local notes = RELEASE_NOTES[version];
    local body = "Avatar Continued has been updated to " .. version .. ".\n\n";
    if notes then
        for _, line in ipairs(notes) do
            body = body .. "- " .. line .. "\n";
        end
        body = body .. "\nThe full changelog is in changelog.txt in the addon folder.";
    else
        body = body .. "See changelog.txt in the addon folder for what changed.";
    end
    Show("Avatar Continued updated", body);
end

-- Decide which, if either, to show.
--
-- Reads its key STRAIGHT OFF AvatarDB, never through the profile, so a profile
-- switch or copy cannot re-greet somebody who has been using the addon for
-- months.
local function CheckVersion()
    if not AvatarDB then return; end
    local version = CurrentVersion();
    local seen = AvatarDB.lastSeenVersion;

    if seen == nil then
        -- No record at all: either a genuinely new install, or an upgrade from
        -- a version that predates this file. Addon.hadSavedVariables, taken at
        -- the top of OnInitialize, is the only thing that can still tell them
        -- apart -- see the comment there for why it cannot be read any earlier
        -- or later. The original Avatar addon used the same AvatarDB, so its
        -- players correctly read as upgraders.
        if Addon.hadSavedVariables then
            ShowUpdated(version);
        else
            ShowFirstRun();
        end
    elseif seen ~= version then
        ShowUpdated(version);
    end

    AvatarDB.lastSeenVersion = version;
end

-- After PLAYER_LOGIN so AceDB has created AvatarDB, and on a delay so it does
-- not land in the middle of the loading screen.
local loader = CreateFrame("Frame");
loader:RegisterEvent("PLAYER_LOGIN");
loader:SetScript("OnEvent", function()
    C_Timer.After(4, CheckVersion);
end);

-- /avatar notes re-opens the current release notes on demand.
function Addon:ShowReleaseNotes()
    ShowUpdated(CurrentVersion());
end

function Addon:ShowWelcome()
    ShowFirstRun();
end
