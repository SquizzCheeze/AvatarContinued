local addon_name, addon_shared = ...

local LibStub = LibStub;
local Addon = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceEvent-3.0");
_G[addon_name] = Addon;

local GENDER_ID = UnitSex("player")-2;
local _, _, RACE_ID = UnitRace("player");
-- Pandaren: faction-specific IDs (25/26) collapse to the neutral race ID that RACE_POSITIONS uses.
if(RACE_ID == 25 or RACE_ID == 26) then RACE_ID = 24 end

local function GetCurrentResolutionSize()
	return GetScreenWidth(), GetScreenHeight();
end

function Addon:OnInitialize()
	-- Does this player already have saved settings? welcome.lua uses it to
	-- tell a new install from an update. It has to be read HERE, first thing:
	--
	--   * NOT at file load. WoW runs an addon's Lua files first and only then
	--     loads its SavedVariables, so AvatarDB is always nil at that point and
	--     every install looked new (existing players got the welcome page).
	--   * NOT after AceDB:New below, which creates AvatarDB when it is missing.
	--
	-- OnInitialize runs on ADDON_LOADED, after the SavedVariables are in.
	Addon.hadSavedVariables = AvatarDB ~= nil;

	local screen_width, screen_height = GetCurrentResolutionSize();
	
	SLASH_AVATAR1	= "/avatar";
	SLASH_AVATAR2	= "/av";
	SlashCmdList["AVATAR"] = function(command) Addon:ConsoleHandler(command); end

	-- /rl -> ReloadUI, claimed only if nothing else answers it.
	--
	-- Blizzard ships /reload, never /rl; the short form is an addon
	-- convention. Taking it from an addon that already provides it would be
	-- rude and might replace a richer version, so this checks first and skips
	-- quietly. Deferred to PLAYER_LOGIN so addons loading after us are visible
	-- to the check. Both registries are consulted: hash_SlashCmdList
	-- (uppercased, slash included) holds what has been imported, SlashCmdList
	-- holds what came after -- the import wipes the latter as it moves them.
	do
		local function TakenAlready()
			local hash = _G.hash_SlashCmdList;
			if hash and hash["/RL"] then return true; end
			for name in pairs(SlashCmdList) do
				local i = 1;
				local cmd = _G["SLASH_" .. name .. i];
				while cmd do
					if strupper(cmd) == "/RL" then return true; end
					i = i + 1;
					cmd = _G["SLASH_" .. name .. i];
				end
			end
			return false;
		end

		local f = CreateFrame("Frame");
		f:RegisterEvent("PLAYER_LOGIN");
		f:SetScript("OnEvent", function(self)
			self:UnregisterEvent("PLAYER_LOGIN");
			if TakenAlready() then return; end
			SLASH_AVATARRELOAD1 = "/rl";
			SlashCmdList["AVATARRELOAD"] = function() ReloadUI(); end
		end);
	end
	
	local defaults = {
		profile = {
			enabled = true,
			alpha = 1.0,
			show = {
				weapon = true,
				armor = true,
				helm = true,
				tabard = true,
				shirt = true,
				pants = true,
			},
			hideInCombat = false,
			animation = 0,
			cameraZoomByRace = {},

			facing = 0.0,
			frameStrata = "BACKGROUND",
			frameLevel = 0,
			
			gearLevel = 1,
			gearLevelAll = false,
			
			gearLevelPerItem = {
				[1] = 1,
				[3] = 1,
				[5] = 1,
				[6] = 1,
				[7] = 1,
				[8] = 1,
				[9] = 1,
				[10] = 1,
				[15] = 1,
			},

			position = {
				point = "CENTER",
				relativePoint = "CENTER",
				x = 0,
				y = 0,
			},
			size = {
				w = screen_height,
				h = screen_height,
			},
			
			light = {
				dya = 0,
				dza = -10,
				
				dx = 0.93,	-- Direct Position
				dy = -0.98,
				dz = -0.17,
				
				di = 0.8,	-- Direct Intensity
				dr = 1.0,	-- Direct Colors
				dg = 0.9,
				db = 0.8,
				
				ai = 0.65,	-- Ambient Intensity
				ar = 1.0,	-- Ambient Colors
				ag = 1.0,
				ab = 1.0,
			},
		},

		-- Character-specific (not shared even when using a Global Profile),
		-- since a saved outfit choice is personal to each character.
		char = {
			outfitPreview = {
				enabled = false,
				customSetID = nil,
			},
		},
	};

	self.db = LibStub("AceDB-3.0"):New("AvatarDB", defaults);
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged");
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged");
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged");
	
	Addon:UpdateLightDirection();
end

Addon.Visual = {
	Race = RACE_ID,
	Gender = GENDER_ID,
};

function Addon:OnEnable()
	Addon:RegisterEvent("UNIT_MODEL_CHANGED");
	Addon:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	
	Addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	Addon:RegisterEvent("PLAYER_REGEN_ENABLED");
	Addon:RegisterEvent("PLAYER_ENTERING_WORLD");
	
	Addon:RegisterEvent("BARBER_SHOP_APPEARANCE_APPLIED", "RefreshAvatar");
	Addon:RegisterEvent("TRANSMOGRIFY_SUCCESS", "RefreshAvatar");
	Addon:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
	Addon:RegisterEvent("LOADING_SCREEN_DISABLED");

	-- Player only, on a unit-filtered frame (events.lua) rather than AceEvent,
	-- which would run for every raid member and nameplate just to discard it.
	Addon.playerAuraWatcher:RegisterUnitEvent("UNIT_AURA", "player");

	-- No RefreshAvatar() call here. OnEnable() fires very early -- on a
	-- genuine login, potentially before equipment/customization data has
	-- finished syncing from the server. Since SetUnit() can only safely run
	-- once ever (see RefreshAvatar()) and there's no Dress() left to correct
	-- an incomplete snapshot afterward, calling it this early on a cold login
	-- can permanently lock in wrong-looking gear or broken face geosets.
	-- PLAYER_ENTERING_WORLD (events.lua) handles the actual first refresh,
	-- timed appropriately for login vs. reload.
end

-- "Hide Avatar in Combat". This used to set the hiddenInCombat flag and nothing
-- else, so the option did nothing. The frame is a plain DressUpModel parented to
-- UIParent, not a protected frame, so hiding and showing it in combat is legal.
function Addon:PLAYER_REGEN_DISABLED()
	if(Addon.db.profile.hideInCombat) then
		AvatarModelFrame.hiddenInCombat = true;
		Addon:UpdateVisibility();
	end
end

function Addon:PLAYER_REGEN_ENABLED()
	if(AvatarModelFrame.hiddenInCombat) then
		AvatarModelFrame.hiddenInCombat = false;
		Addon:UpdateVisibility();
	end
end

-- The one place that decides whether the avatar is on screen.
function Addon:UpdateVisibility()
	local shown = Addon.db.profile.enabled and not AvatarModelFrame.hiddenInCombat;
	AvatarModelFrame:SetShown(shown and true or false);
end

local _modelLoadedBusy = false;
function AvatarModelFrame_OnModelLoaded(self)
	if _modelLoadedBusy then
		-- A nested load is still a load: re-apply alpha before bailing, or a
		-- rebuild during the refresh below can come back at full opacity.
		if Addon and Addon.db and Addon.db.profile then
			self:SetModelAlpha(Addon.db.profile.alpha);
		end
		return;
	end
	if Addon and Addon.db and Addon.db.profile then
		self:SetModelAlpha(Addon.db.profile.alpha);
		-- Re-dressing the model during the refresh below fires OnModelLoaded
		-- again, synchronously; this guard is what stops it re-entering itself.
		-- The refresh runs under pcall so an error inside it cannot leave the
		-- guard stuck on, which would silently disable this handler until a
		-- /reload.
		_modelLoadedBusy = true;
		local ok, err = pcall(function()
			-- The model has just finished loading, so this is the point at which
			-- its transmog info list is readable -- capture the baseline before
			-- anything (an outfit, a hidden slot) alters it.
			Addon:CaptureBaseline(self);
			Addon:RefreshFrame();
		end);
		_modelLoadedBusy = false;
		if not ok then
			geterrorhandler()(err);
		end
	end
end

function Avatar_IsVisible()
	return Addon.db.profile.enabled and AvatarModelFrame and
		   AvatarModelFrame:IsShown() and not AvatarModelFrame.hiddenInCombat;
end

function Addon:OnDisable()
		
end

AVATAR_INSTRUCTIONS_TEXT = "|cffffc437Avatar Unlocked|r|n|nPan with Left Mouse|nResize with Right Mouse|nRotate with Mouse Wheel";
AVATAR_INSTRUCTIONS_LOCK = "Lock Avatar Model";

function AvatarModelFrame_Lock(self)
	Addon:LockFrame();
end

-- Model alpha does not always survive the model being rebuilt. Every path
-- that changes the model re-applies it straight afterwards, but a piece that
-- finishes loading LATER (an item appearance streaming in, a reload the
-- client does on its own) can put the model back to full opacity with no
-- OnModelLoaded to answer it. Reported 2026-09-23 as "sometimes the
-- transparency is ignored", with no pinnable trigger -- which is what an
-- async load looks like from the outside.
--
-- So once a second, while shown, re-assert the configured alpha. It is
-- unconditional rather than a GetModelAlpha comparison because the getter
-- may keep reporting the stored value after the rebuild, and the comparison
-- would then never fire. Skipped at full opacity, where there is nothing to
-- lose. OnUpdate only runs while the frame is shown.
local ALPHA_WATCH_INTERVAL = 1.0;
local alphaWatchElapsed = 0;
local function AlphaWatch(self, elapsed)
	alphaWatchElapsed = alphaWatchElapsed + elapsed;
	if alphaWatchElapsed < ALPHA_WATCH_INTERVAL then return; end
	alphaWatchElapsed = 0;
	local p = Addon and Addon.db and Addon.db.profile;
	local a = p and p.alpha;
	if a and a < 1 then
		self:SetModelAlpha(a);
	end
end

function AvatarModelFrame_OnLoad(self)
	local screen_width, screen_height = GetCurrentResolutionSize();
	self:SetResizeBounds(screen_height * 0.05, screen_height * 0.05, screen_height * 2.0, screen_height * 2.0);

	self:EnableMouse(false);
	self:EnableMouseWheel(false);

	self:RegisterForDrag("LeftButton", "RightButton");
	self:SetMovable(true);
	self:SetResizable(true);

	-- By default the client DISCARDS a model's data when its frame is hidden
	-- and RELOADS it from scratch on show -- and that reload re-derives
	-- geosets through the same path that corrupts Vulpera's face.
	--
	-- This frame is parented to UIParent, so anything that hides UIParent
	-- triggers that discard/reload without our OnShow/OnHide ever firing.
	-- ElvUI's AFK screen does exactly that (UIParent:Hide() on AFK,
	-- :Show() on return), which is why going AFK reliably broke the face.
	-- It also explains why toggling the avatar off and on again can't repair
	-- it: each Hide/Show is another discard/reload, so it re-corrupts rather
	-- than fixing.
	--
	-- Blizzard uses this same call for models that must survive being hidden
	-- (Blizzard_TransmogShared sets it right after SetUnit()/TryOn();
	-- Blizzard_Wardrobe sets it back to false only when it's done and wants
	-- the model freed).
	if self.SetKeepModelOnHide then
		self:SetKeepModelOnHide(true);
	end

	self:HookScript("OnUpdate", AlphaWatch);
end

function AvatarModelFrame_OnMouseWheel(self, delta)
	local multiplier = IsControlKeyDown() and 0.3 or 0.15;
	self:SetFacing(self:GetFacing() + delta * multiplier);
	Addon.db.profile.facing = self:GetFacing();
end

function AvatarModelFrame_OnMouseUp(self, button)
	self:StopMovingOrSizing();
	Addon:SavePosition();
end

function AvatarModelFrame_OnMouseDown(self, button)
	if (button == "LeftButton") then
		self:StartMoving();
	elseif (button == "RightButton") then
		self:StartSizing();
	end
end

function AvatarModelFrame_OnShow(self)
	if not (Addon and Addon.db) then return; end
	-- Second retry point for setup that couldn't run while the unit wasn't
	-- model-ready (the other is UNIT_MODEL_CHANGED). Mirrors Blizzard's
	-- needsReload-on-OnShow pattern. No-op once setup has succeeded.
	Addon:RetryModelSetup(self);
	Addon:UpdateRace();
	Addon:RefreshEquipmentToggle();
end

function AvatarModelFrame_OnHide(self)
	self:StopMovingOrSizing();
end

function Addon:UpdateLightDirection()
	local l = self.db.profile.light;
	
	local ya = l.dya * (math.pi / 180.0);
	local za = l.dza * (math.pi / 180.0);
	
	ya = -ya + math.pi;
	
	l.dx = math.cos(ya) * math.cos(za);
	l.dy = math.sin(ya) * math.sin(za);
	l.dz = math.sin(za);
	
	local nl = sqrt((l.dx * l.dx) + (l.dy * l.dy) + (l.dz * l.dz));
	l.dx = l.dx / nl;
	l.dy = l.dy / nl;
	l.dz = l.dz / nl;
end

function Addon:SetFrameSettings()
	Addon:UpdateVisibility();

	AvatarModelFrame:ClearAllPoints();
	local validPoints = {
		TOPLEFT=true, TOP=true, TOPRIGHT=true,
		LEFT=true, CENTER=true, RIGHT=true,
		BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true,
	};
	local pt  = self.db.profile.position.point;
	local rpt = self.db.profile.position.relativePoint;
	if not validPoints[pt]  then pt  = "CENTER"; self.db.profile.position.point = pt; end
	if not validPoints[rpt] then rpt = "CENTER"; self.db.profile.position.relativePoint = rpt; end
	AvatarModelFrame:SetPoint(pt, UIParent, rpt, self.db.profile.position.x, self.db.profile.position.y);
	AvatarModelFrame:SetFrameStrata(self.db.profile.frameStrata);
	AvatarModelFrame:SetFrameLevel(self.db.profile.frameLevel);

	AvatarModelFrame:SetWidth(self.db.profile.size.w);
	AvatarModelFrame:SetHeight(self.db.profile.size.h);
	AvatarModelFrame:SetFacing(self.db.profile.facing);
	AvatarModelFrame:SetModelAlpha(self.db.profile.alpha);

	Addon:UpdateLightDirection();

	local l = self.db.profile.light;
	AvatarModelFrame:SetLight(true, {
		omnidirectional = false,
		point = { x = l.dx, y = l.dy, z = l.dz },
		ambientIntensity = l.ai,
		ambientColor = { r = l.ar, g = l.ag, b = l.ab },
		diffuseIntensity = l.di,
		diffuseColor = { r = l.dr, g = l.dg, b = l.db },
	});
end

-- Establishes the model's unit, exactly once per widget.
--
-- SetUnit() is the only call that builds the character model, and it must not
-- be repeated: mixing it with TryOn()/SetItemTransmogInfo() state (in either
-- order) corrupts face geosets on some races. Everything after setup is done
-- declaratively through Addon:ApplyAppearance instead.
--
-- Gated on IsUnitModelReadyForUI("player") rather than a delay. If the unit
-- isn't ready (mid-login, loading screen), the model is flagged and retried
-- from UNIT_MODEL_CHANGED / OnShow -- the same needsReload pattern Blizzard
-- uses in Blizzard_TransmogShared's ItemModelBaseMixin:Reload.
function Addon:SetupModel(model)
	if not model then return false; end
	if model._avatarSetupDone then return true; end

	if not IsUnitModelReadyForUI("player") then
		model._avatarNeedsSetup = true;
		return false;
	end

	model:SetUnit("player");

	-- Keep the model loaded when the frame is hidden. Without this the client
	-- discards and reloads it, and that reload re-derives geosets through the
	-- path that corrupts Vulpera's face -- which is what made ElvUI's AFK
	-- screen (UIParent:Hide()/:Show()) break the avatar.
	if model.SetKeepModelOnHide then
		model:SetKeepModelOnHide(true);
	end

	model._avatarSetupDone = true;
	model._avatarNeedsSetup = nil;
	-- Straight after SetUnit() the model shows the player's real gear and
	-- nothing else -- the one moment the baseline can be read even if an
	-- outfit preview is configured. CaptureBaseline honours this flag to
	-- bypass its usual "not while previewing" guard exactly once.
	model._avatarBaselinePending = true;
	return true;
end

-- Retries setup for a model that wasn't ready earlier. Safe to call often.
function Addon:RetryModelSetup(model)
	if model and model._avatarNeedsSetup then
		return Addon:SetupModel(model);
	end
	return false;
end

function Addon:RefreshAvatar()
	Addon:SetupModel(AvatarModelFrame);
	Addon:UpdateRace();
	Addon:RefreshFrame();
end

function Addon:RefreshFrame()
	Addon:SetFrameSettings();
	Addon:RefreshEquipmentToggle();
end

function Addon:UpdateRace()
	Addon:RefreshEquipmentToggle();
	Addon:UpdateAvatarPositioning();
end

-- Fine vertical/horizontal centering nudges only -- {y, z}. Zoom used to be
-- baked into a 3rd (x/depth) component here, translating the model through
-- raw 3D space relative to a fixed camera. That's what was clipping Vulpera's
-- nose/ear tips through the near clip plane (see RACE_CAM_SCALE below for the
-- replacement). These y/z values are unrelated to that and unchanged.
local RACE_POSITIONS = {
	-- Default
	[0]		= {0.01, -0.05},

	-- Orc
	[2]		= { [0] = {0.04, -0.1} },
	-- Mag'har Orc
	[36]	= { [0] = {0.04, -0.1} },

	-- Dwarf
	[3]		= { [0] = {0.0, -0.15}, [1] = {-0.03, -0.03} },
	-- Dark Iron
	[34]	= { [0] = {0.0, -0.15}, [1] = {-0.03, -0.03} },

	-- Tauren
	[6]		= { [0] = {0.02, 0.05}, [1] = {0.01, -0.18} },
	-- Highmountain Tauren
	[28]	= { [0] = {0.02, 0.25}, [1] = {0.01, -0.18} },

	-- Gnome
	[7]		= { [0] = {-0.03, -0.12}, [1] = {-0.03, -0.12} },

	-- Troll
	[8]		= { [0] = {0.02, -0.14} },

	-- Goblin
	[9]		= { [0] = {-0.02, -0.12}, [1] = {-0.04, -0.13} },

	-- Blood elf & Void Elf
	[10]	= { [0] = {-0.02, 0.02}, [1] = {0.04, -0.02} },
	[29]	= { [0] = {-0.02, 0.02}, [1] = {0.04, -0.02} },

	-- Draenei & Lightforged Draenei
	[11]	= { [0] = {0.04, -0.12}, [1] = {-0.04, -0.05} },
	[30]	= { [0] = {0.04, -0.12}, [1] = {-0.04, -0.05} },

	-- Worgen
	[22]	= { [0] = {-0.05, -0.12}, [1] = {-0.06, -0.05} },

	-- Panda
	[24]	= { [0] = {0.04, 0}, [1] = {0.02, 0} },

	-- Vulpera
	[35]	= { [0] = {-0.02, -0.12}, [1] = {-0.02, -0.12} },

	-- Zandalari Troll -- centering not visually verified, using the default nudge
	[31]	= { [0] = {0.01, -0.05}, [1] = {0.01, -0.05} },

	-- Kul Tiran -- centering not visually verified, using the default nudge
	[32]	= { [0] = {0.01, -0.05}, [1] = {0.01, -0.05} },

	-- Mechagnome -- centering not visually verified, using the default nudge
	[37]	= { [0] = {0.01, -0.05}, [1] = {0.01, -0.05} },
};

-- Zoom, via the camera-distance API instead of shoving the model through
-- space (see comment above). Mechanically converted from each race's old x
-- depth value as scale = x / -0.65 (the old default), clamped to [0.6, 2.5]
-- so nothing lands on a degenerate near-zero/negative distance. These are
-- first-pass estimates, not visually verified -- expect to retune via the
-- in-game "Camera Zoom" slider (Frame Settings), especially:
--   * Vulpera [35]: given extra margin (2.0, not the raw ~1.62 ratio) since
--     this is the race that was clipping -- verify this one first.
--   * Worgen female [22][1]: old x was exactly 0.0, which the ratio formula
--     can't convert -- falls back to the 1.0 default, not derived like the rest.
local RACE_CAM_SCALE = {
	[0]		= 1.0,

	[2]		= { [0] = 1.77 },	-- Orc
	[36]	= { [0] = 1.77 },	-- Mag'har Orc

	[3]		= { [0] = 1.10, [1] = 1.10 },	-- Dwarf (confirmed via user testing on Dark Iron Dwarf)
	[34]	= { [0] = 1.10, [1] = 1.10 },	-- Dark Iron Dwarf (confirmed via user testing)

	[6]		= { [0] = 1.15, [1] = 1.23 },	-- Tauren
	[28]	= { [0] = 1.15, [1] = 1.23 },	-- Highmountain Tauren

	[7]		= { [0] = 1.32, [1] = 1.32 },	-- Gnome

	[8]		= { [0] = 2.15 },	-- Troll

	[9]		= { [0] = 1.69, [1] = 1.85 },	-- Goblin

	[10]	= { [0] = 1.0, [1] = 1.0 },	-- Blood Elf
	[29]	= { [0] = 1.0, [1] = 1.0 },	-- Void Elf

	[11]	= { [0] = 1.46, [1] = 0.6 },	-- Draenei (clamped floor)
	[30]	= { [0] = 1.46, [1] = 0.6 },	-- Lightforged Draenei (clamped floor)

	[22]	= { [0] = 1.46, [1] = 1.0 },	-- Worgen (female = fallback, see above)

	[24]	= { [0] = 1.23, [1] = 1.77 },	-- Pandaren

	[35]	= { [0] = 0.75, [1] = 0.75 },	-- Vulpera (confirmed via user testing)

	-- Zandalari Troll -- taller/larger-framed than base Troll, estimated a bit above Troll's 2.15
	[31]	= { [0] = 2.3, [1] = 2.1 },

	-- Kul Tiran -- notably large/bulky build, estimated similar to Orc/Tauren scale
	[32]	= { [0] = 1.5, [1] = 1.35 },

	-- Mechagnome -- small build, similar in scale to Gnome
	[37]	= { [0] = 1.3, [1] = 1.3 },
};

-- Shared by the main avatar frame and the Settings panel's Live Preview model
-- (see Addon:UpdateRaceOnModel in settings.lua) so there is exactly one pair
-- of per-race tables to keep up to date, not two.
function Addon:GetRacePosition()
	local position = RACE_POSITIONS[0];

	if(RACE_POSITIONS[Addon.Visual.Race] and RACE_POSITIONS[Addon.Visual.Race][Addon.Visual.Gender]) then
		position = RACE_POSITIONS[Addon.Visual.Race][Addon.Visual.Gender];
	end

	return position;
end

-- The Camera Zoom slider used to write a single flat cameraZoom multiplier
-- shared by every race -- which meant getting Dwarf right (e.g. 1.1x) broke
-- every other race sharing the same profile (e.g. wanting 0.6x), and required
-- manually re-adjusting the slider every time you switched characters.
-- Stored per race+gender instead, so each race remembers its own value and
-- switching characters just recalls it automatically.
function Addon:GetCameraZoomOverride()
	local byRace = Addon.db.profile.cameraZoomByRace;
	local raceTable = byRace and byRace[Addon.Visual.Race];
	local zoom = raceTable and raceTable[Addon.Visual.Gender];

	-- Guards the same degenerate-zero case as before (a slider-init bug used
	-- to write literal 0, which collapses the camera to zero distance), plus
	-- the common case of no override ever set for this race.
	if not zoom or zoom <= 0 then
		return 1.0;
	end

	return zoom;
end

function Addon:SetCameraZoomOverride(value)
	if not value or value <= 0 then
		value = 1.0;
	end

	Addon.db.profile.cameraZoomByRace = Addon.db.profile.cameraZoomByRace or {};
	Addon.db.profile.cameraZoomByRace[Addon.Visual.Race] = Addon.db.profile.cameraZoomByRace[Addon.Visual.Race] or {};
	Addon.db.profile.cameraZoomByRace[Addon.Visual.Race][Addon.Visual.Gender] = value;
end

function Addon:GetRaceCamScale()
	local scale = RACE_CAM_SCALE[0];

	if(RACE_CAM_SCALE[Addon.Visual.Race] and RACE_CAM_SCALE[Addon.Visual.Race][Addon.Visual.Gender]) then
		scale = RACE_CAM_SCALE[Addon.Visual.Race][Addon.Visual.Gender];
	end

	return scale * Addon:GetCameraZoomOverride();
end

function Addon:UpdateAvatarPositioning()
	local pos = Addon:GetRacePosition();
	AvatarModelFrame:SetPosition(0, pos[1], pos[2]);
	AvatarModelFrame:SetCamDistanceScale(Addon:GetRaceCamScale());
end

-- Head 		1
-- Shoulder 	3
-- Shirt 		4
-- Chest 		5
-- Belt 		6
-- Legs 		7
-- Feet 		8
-- Wrist 		9
-- Gloves 		10
-- Back 		15
-- Main Hand 	16
-- Off Hand 	17
-- Tabard 		19

-- Which show.* flags must ALL be true for a slot to be visible. Some slots
-- are governed by more than one toggle (Head by both "armor" and "helm").
local SLOT_SHOW_FLAGS = {
	[1]  = {"armor", "helm"},
	[3]  = {"armor"},
	[4]  = {"armor", "shirt"},
	[5]  = {"armor"},
	[6]  = {"armor"},
	[7]  = {"armor", "pants"},
	[8]  = {"armor"},
	[9]  = {"armor"},
	[10] = {"armor"},
	[15] = {"armor"},
	[16] = {"weapon"},
	[17] = {"weapon"},
	[19] = {"tabard"},
};

local MAINHAND_SLOT = INVSLOT_MAINHAND or 16;

function Addon:IsSlotShown(slotID)
	local flags = SLOT_SHOW_FLAGS[slotID];
	if not flags then return true; end

	local p = Addon.db.profile;
	for _, flag in ipairs(flags) do
		if not p.show[flag] then return false; end
	end
	return true;
end

function Addon:IsOutfitPreviewActive()
	local outfitPreview = Addon.db and Addon.db.char and Addon.db.char.outfitPreview;
	return (outfitPreview and outfitPreview.enabled and outfitPreview.customSetID) and true or false;
end

-- Deep-copies an ItemTransmogInfo list by value.
--
-- GetItemTransmogInfoList() hands back the model's own live objects, not a
-- snapshot: keeping the returned table meant the stored "baseline" mutated in
-- step with the model, so after applying an outfit the baseline WAS the
-- outfit and switching back to real gear did nothing. Copying the three
-- fields into fresh ItemTransmogInfo objects freezes the values.
local function CopyTransmogInfoList(list)
	local copy = {};
	for slotID, info in pairs(list) do
		if type(info) == "table" then
			local new;
			if CreateAndInitFromMixin and ItemTransmogInfoMixin then
				new = CreateAndInitFromMixin(ItemTransmogInfoMixin,
					info.appearanceID or 0,
					info.secondaryAppearanceID or 0,
					info.illusionID or 0);
			else
				-- Plain-table fallback; SetItemTransmogInfo reads these fields.
				new = {
					appearanceID = info.appearanceID or 0,
					secondaryAppearanceID = info.secondaryAppearanceID or 0,
					illusionID = info.illusionID or 0,
				};
			end
			copy[slotID] = new;
		end
	end
	return copy;
end

-- Snapshot of the player's real equipped appearance, as ItemTransmogInfo
-- objects (transmog and weapon illusions included). This is what makes
-- "Show Equipped Gear" and re-showing a hidden slot possible without
-- Dress() or a second SetUnit(), both of which corrupt face geosets.
--
-- Only captured while no outfit preview is active, since the list reflects
-- what the model is currently wearing -- capturing during a preview would
-- store the outfit as if it were the player's real gear.
function Addon:CaptureBaseline(model)
	if not model or not model._avatarSetupDone then return; end

	-- Normally skipped while previewing, since the model is wearing the outfit
	-- rather than real gear. The exception is the first capture after
	-- SetUnit() (flagged by SetupModel), where the model still shows real gear
	-- -- without that, a profile with an outfit already enabled at login would
	-- never get a baseline and could never return to "Show Equipped Gear".
	if Addon:IsOutfitPreviewActive() and not model._avatarBaselinePending then
		return;
	end

	-- Requires a non-empty list: an empty one means the model isn't readable
	-- yet, and storing it would count as "captured", permanently blocking
	-- every later attempt and leaving the avatar stuck on real gear.
	local ok, list = pcall(model.GetItemTransmogInfoList, model);
	if ok and list and next(list) ~= nil then
		Addon._baselineTransmogInfo = CopyTransmogInfoList(list);
		model._avatarBaselinePending = nil;
	end
end

-- The ItemTransmogInfo list describing what SHOULD be shown right now: the
-- active outfit if one is selected, otherwise the player's real gear.
function Addon:GetAppearanceSourceList()
	if Addon:IsOutfitPreviewActive() then
		local customSetID = Addon.db.char.outfitPreview.customSetID;
		local ok, list = pcall(C_TransmogCollection.GetCustomSetItemTransmogInfoList, customSetID);
		if ok and list then return list; end
		-- Outfit data not cached yet (common right after login). Fall through
		-- to the baseline; UNIT_MODEL_CHANGED / TRANSMOG_COLLECTION_UPDATED
		-- will re-apply once it arrives -- no retry timer needed.
	end
	return Addon._baselineTransmogInfo;
end

-- Brings a model in line with the current settings, declaratively.
--
-- This replaces the old Dress()/Undress()/TryOn() juggling entirely. Every
-- slot is either hidden via UndressSlot() or set explicitly from the source
-- list via SetItemTransmogInfo() -- the same per-slot call Blizzard's own
-- outfit loader uses (DressUpFrames.lua, DressUpItemTransmogInfoList).
--
-- Because each slot is written explicitly, this is idempotent and fully
-- reversible: re-checking a hidden slot, switching outfits, and returning to
-- real gear are all the same operation with a different source list. Nothing
-- here re-issues SetUnit() or calls Dress(), so the face stays intact.
function Addon:ApplyAppearance(model)
	if not model or not model._avatarSetupDone then return; end

	-- Nothing may be applied until a baseline exists. The baseline can only be
	-- read while the model still shows real gear, so dressing it first would
	-- destroy the very thing we need to capture -- and worse, a later capture
	-- would then store the OUTFIT as if it were the player's gear, which is
	-- what made "Show Equipped Gear" a no-op. If the model isn't readable yet,
	-- leave it on its plain SetUnit() appearance (already real gear) and let
	-- OnModelLoaded / UNIT_MODEL_CHANGED come back to it.
	if not Addon._baselineTransmogInfo then
		Addon:CaptureBaseline(model);
		if not Addon._baselineTransmogInfo then return; end
	end

	local source = Addon:GetAppearanceSourceList();
	if not source then return; end

	for slotID in pairs(SLOT_SHOW_FLAGS) do
		if Addon:IsSlotShown(slotID) then
			local info = source[slotID];
			if info then
				-- ignoreChildItems matches Blizzard: only the main hand
				-- considers child items (paired/legion artifact offhands).
				pcall(model.SetItemTransmogInfo, model, info, slotID, slotID ~= MAINHAND_SLOT);
			end
		else
			model:UndressSlot(slotID);
		end
	end
end

function Addon:RefreshEquipmentToggle()
	Addon:ApplyAppearance(AvatarModelFrame);

	Addon:UpdateConditionalToggle();
	if Addon.db and Addon.db.profile then
		AvatarModelFrame:SetModelAlpha(Addon.db.profile.alpha);
		Addon:ApplyAnimation();
	end
end

local NATURALLY_LOOPING_ANIMS = { [0]=true, [4]=true, [69]=true };

function Addon:ApplyAnimation()
	local anim = Addon.db.profile.animation or 0;
	AvatarModelFrame:SetAnimation(anim);
	if not NATURALLY_LOOPING_ANIMS[anim] then
		AvatarModelFrame:SetScript("OnAnimFinished", function(self)
			-- Restart on the next frame, never from inside this handler. If the
			-- model can't play the animation right now (still loading, hidden)
			-- the engine can report it finished straight away, and restarting
			-- synchronously would re-enter this handler until the C stack
			-- overflowed. Deferred, the worst case is one restart per frame.
			if self._avatarAnimRestartQueued then return; end
			self._avatarAnimRestartQueued = true;
			C_Timer.After(0, function()
				self._avatarAnimRestartQueued = nil;
				if (Addon.db.profile.animation or 0) == anim then
					self:SetAnimation(anim);
				end
			end);
		end);
	else
		AvatarModelFrame:SetScript("OnAnimFinished", nil);
	end
end

-- The aura that strips the avatar down, inherited from the original addon.
Addon.UNDRESS_AURA_SPELL_ID = 176438;

-- true or false when the answer is knowable, nil when it is not.
--
-- On 12.x GetPlayerAuraBySpellID is SecretWhenUnitAuraRestricted and
-- RequiresNonSecretAura: while aura restrictions are in effect (combat,
-- encounters, Mythic+, PvP) it returns nothing at all, so an empty result then
-- does not mean the aura is absent.
function Addon:PlayerHasAura(spell_id)
	if C_Secrets then
		if C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
			return nil;
		end
		if C_Secrets.ShouldSpellAuraBeSecret and C_Secrets.ShouldSpellAuraBeSecret(spell_id) then
			return nil;
		end
	end
	return C_UnitAuras.GetPlayerAuraBySpellID(spell_id) ~= nil;
end

function Addon:UpdateConditionalToggle()
	if Addon:PlayerHasAura(Addon.UNDRESS_AURA_SPELL_ID) then
		AvatarModelFrame:Undress();
	end
end

