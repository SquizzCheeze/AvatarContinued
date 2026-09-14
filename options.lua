local addon_name, addon_shared = ...

local _G = getfenv(0);
local Addon = _G[addon_name];

-- Profile management, frame lock/unlock and the /avatar slash command.
--
-- This file used to build a complete second options window as well
-- (CreateOptionsPanel and its widget helpers). settings.lua replaced it and
-- overrides ShowOptions, so none of that was reachable any more; it has been
-- removed rather than left to rot.

local CHAT_PREFIX = "|cff81e6fcAvatar Continued:|r ";

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. message);
end

-- ============================================================================
-- Profile popups
-- ============================================================================

StaticPopupDialogs["AVATAR_DELETE_PROFILE_CONFIRM"] = {
	text = "Are you sure you want to delete profile '%s'?",
	button1 = YES,
	button2 = NO,
	-- A SOUNDKIT id: PlaySound has only accepted numbers since 7.3, and the old
	-- "igMainMenuOpen" string made this popup error the moment it opened.
	sound = SOUNDKIT.IG_MAINMENU_OPEN,
	OnShow = function()
		Addon:CloseOptions();
	end,
	-- The profile name travels as the popup's data (StaticPopup_Show's fourth
	-- argument), which Blizzard hands to OnAccept as its second parameter. It
	-- used to go through a variable the settings panel wrote as a global while
	-- this file read a local of the same name, so Delete never did anything.
	OnAccept = function(_, profileName)
		if profileName then
			Addon:DeleteProfileByName(profileName);
		end
	end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
};

local function CreateProfileFromPopup(name)
	name = name and strtrim(name) or "";
	if name == "" then return; end
	Addon.db:SetProfile(name);
	Print("Created and switched to profile " .. name .. ".");
	Addon:UpdateProfileDropdowns();
end

StaticPopupDialogs["AVATAR_NEW_PROFILE"] = {
	text = "Enter a name for the new profile:",
	button1 = "Create",
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 64,
	-- 12.x dialogs expose their edit box through GetEditBox(); the old
	-- dialog.editBox field no longer exists, so clicking Create errored.
	OnAccept = function(dialog)
		local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.EditBox;
		CreateProfileFromPopup(editBox and editBox:GetText());
	end,
	EditBoxOnEnterPressed = function(editBox)
		CreateProfileFromPopup(editBox:GetText());
		editBox:GetParent():Hide();
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide();
	end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
};

-- ============================================================================
-- Profiles
-- ============================================================================

function Addon:GetProfileList()
	local list = {};
	for _, name in pairs(self.db:GetProfiles()) do
		table.insert(list, name);
	end
	table.sort(list);
	return list;
end

-- AceDB callback target (registered by name in core.lua). settings.lua wraps
-- this to refresh its own widgets as well.
function Addon:OnProfileChanged()
	Addon:RefreshAvatar();
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
		Print("Using Global Profile.");
	else
		local profileName = UnitName("player") .. " - " .. GetRealmName();
		self.db:SetProfile(profileName);
		Print("Using profile " .. profileName .. ".");
	end
	Addon:RefreshAvatar();
end

function Addon:ChangeProfileByName(name)
	Print("Using profile " .. name .. ".");
	self.db:SetProfile(name);
end

function Addon:CopyProfileByName(name)
	self.db:CopyProfile(name);
	Print("Copied settings from profile " .. name .. ".");
end

-- AceDB refuses to delete the active profile, and the settings panel's button
-- is "Delete Current" -- exactly that case. Move off it first: to this
-- character's own profile (AceDB's default key), or to "Default" when the
-- character's own profile is the one being deleted.
function Addon:DeleteProfileByName(name)
	local db = self.db;
	if db:GetCurrentProfile() == name then
		local fallback = UnitName("player") .. " - " .. GetRealmName();
		if fallback == name then
			fallback = "Default";
		end
		db:SetProfile(fallback);
	end
	db:DeleteProfile(name);
	Print("Deleted profile " .. name .. ".");
	Addon:UpdateProfileDropdowns();
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

local EQUIP_USAGE = "Usage: /avatar equip <item link, item ID, or itemID:bonusID>";

function Addon:ConsoleHandler(rawcommand)
	rawcommand = rawcommand or "";
	local command, arg1 = strsplit(" ", string.lower(rawcommand));
	-- Everything after the command word, in its original case. Profile names
	-- and item links are case-sensitive and can contain spaces; splitting the
	-- lowercased line turned "/avatar profile MyProfile" into a brand-new
	-- profile called "myprofile".
	local rest = rawcommand:match("^%s*%S+%s+(.-)%s*$");

	if command == "toggle" then

		local thing = arg1;

		if thing == nil or thing == "" then
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

		if not rest or rest == "" then
			Print(EQUIP_USAGE);
			return;
		end

		local item = rest;
		if not item:find("|Hitem") then
			local itemID, bonusID = item:match("^(%d+):(%d+)$");
			if itemID then
				item = string.format("item:%d:0:0:0:0:0:0:0:%d:0:0:1:%d", itemID, UnitLevel("player"), bonusID);
			elseif item:match("^%d+$") then
				-- A bare number is read by TryOn as an itemModifiedAppearanceID,
				-- not an item ID, so turn it into an item string first.
				item = "item:" .. item;
			else
				Print(EQUIP_USAGE);
				return;
			end
		end
		AvatarModelFrame:TryOn(item);

	elseif command == "profile" then

		if rest and rest ~= "" and rest ~= "Global Profile" then
			Addon.db:SetProfile(rest);
			Print("Using profile " .. rest .. ".");
		end

	elseif command == "unlock" then
		Addon:UnlockFrame();
		Print("Unlocked");

	elseif command == "lock" then
		Addon:LockFrame();
		Print("Locked");

	elseif command == "help" or command == "commands" or command == "?" then
		DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc======== Avatar Continued - Usage ========|r");
		DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar help or /av help|r - Show usage (Avatar Continued)");
		DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250toggle|r - Show/hide avatar (currently " .. (self.db.profile.enabled and "|cff82cd40visible|r" or "|cffc92222hidden|r") .. ")");
		DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250toggle [weapon/armor/tabard]|r - Show/hide avatar weapon, armor or tabard");
		DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250profile [profile name]|r - Change current profile (" .. Addon.db:GetCurrentProfile() .. ")");
		DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250equip [item link or item ID]|r - Try an item on the avatar");
		DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250lock|r - Lock avatar");
		DEFAULT_CHAT_FRAME:AddMessage("|cff81e6fc/avatar|r |cfff8e250unlock|r - Unlock avatar allowing positioning, scaling and rotating with the mouse");

	else
		Addon:RefreshAvatar();
		Addon:ShowOptions();
	end
end
