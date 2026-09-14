local addon_name = ...

local LibStub = LibStub;
local Addon = LibStub("AceAddon-3.0"):GetAddon(addon_name);

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

local SLOT_TYPE_WEAPON			= 0x01;
local SLOT_TYPE_ARMOR			= 0x02;
local SLOT_TYPE_TABARD			= 0x04;
local SLOT_TYPE_UNTRANSMOGGABLE	= 0x08;

local INVENTORY_SLOTS = {
	[1]		= SLOT_TYPE_ARMOR,
	[3]		= SLOT_TYPE_ARMOR,
	[4]		= SLOT_TYPE_ARMOR, -- Shirt
	[5]		= SLOT_TYPE_ARMOR,
	[6]		= SLOT_TYPE_ARMOR,
	[7]		= SLOT_TYPE_ARMOR,
	[8]		= SLOT_TYPE_ARMOR,
	[9]		= SLOT_TYPE_ARMOR,
	[10]	= SLOT_TYPE_ARMOR,
	[15]	= SLOT_TYPE_ARMOR,
	[16]	= SLOT_TYPE_WEAPON,
	[17]	= SLOT_TYPE_WEAPON,
	[19]	= SLOT_TYPE_TABARD,
};

function Addon:IsWeaponSlot(slot)
	return slot and INVENTORY_SLOTS[slot] == SLOT_TYPE_WEAPON;
end

function Addon:IsArmorSlot(slot)
	return slot and INVENTORY_SLOTS[slot] == SLOT_TYPE_ARMOR;
end

function Addon:IsTabardSlot(slot)
	return slot and INVENTORY_SLOTS[slot] == SLOT_TYPE_TABARD;
end

function Addon:IsSlotVisible(slot)
	return Addon:IsWeaponSlot(slot) or Addon:IsArmorSlot(slot) or Addon:IsTabardSlot(slot);
end

function Addon:IsSlotTransmoggable(slot)
	return slot and INVENTORY_SLOTS[slot] and bit.band(INVENTORY_SLOTS[slot], SLOT_TYPE_UNTRANSMOGGABLE) == 0;
end

-- No timers anywhere in here.
--
-- Model setup is gated on IsUnitModelReadyForUI("player") inside
-- Addon:SetupModel, and anything that couldn't run yet is retried from
-- UNIT_MODEL_CHANGED below -- the event the client fires precisely when the
-- player's model becomes available. This replaces the old stack of fixed
-- delays (0.5s/2s/3s/4s/25s) that were standing in for that signal.
function Addon:PLAYER_ENTERING_WORLD(event, isLogin, isReload)
	Addon:RefreshAvatar();
end

function Addon:LOADING_SCREEN_DISABLED()
	-- A genuine login usually isn't model-ready during PLAYER_ENTERING_WORLD;
	-- this is the natural second chance. Harmless if setup already succeeded.
	Addon:RetryModelSetup(AvatarModelFrame);
	Addon:RefreshAvatar();
end

function Addon:PLAYER_EQUIPMENT_CHANGED(event, slot_id, hasItem)
	if Addon:IsSlotVisible(slot_id) then
		-- Real gear changed, so the cached baseline is stale. Re-capture it
		-- (a no-op while an outfit preview is active) before re-applying.
		Addon:CaptureBaseline(AvatarModelFrame);
		Addon:RefreshEquipmentToggle();
		if Addon.previewModel then
			Addon:RefreshEquipmentOnModel(Addon.previewModel);
		end
	end
end

-- Was defined but never registered, so the undress aura was only noticed on the
-- next unrelated refresh. Now driven by playerAuraWatcher below, and it acts
-- only when the answer actually changes: player UNIT_AURA fires constantly and a
-- full re-dress on each one would be wasted work.
local lastUndressAura = nil;
function Addon:UNIT_AURA(event, unit_id)
	if unit_id ~= "player" then return; end

	-- nil means auras are secret right now and the answer is unknown. Leave the
	-- model as it is rather than guessing (see Addon:PlayerHasAura).
	local hasAura = Addon:PlayerHasAura(Addon.UNDRESS_AURA_SPELL_ID);
	if hasAura == nil or hasAura == lastUndressAura then return; end
	lastUndressAura = hasAura;

	-- Re-dresses from the source list, so the aura dropping off puts the gear
	-- back, then undresses again if the aura is still up.
	Addon:RefreshEquipmentToggle();
end

-- Registered for "player" only in Addon:OnEnable.
Addon.playerAuraWatcher = CreateFrame("Frame");
Addon.playerAuraWatcher:SetScript("OnEvent", function(_, event, unit)
	Addon:UNIT_AURA(event, unit);
end);

function Addon:UNIT_MODEL_CHANGED(event, unit)
	if(unit == "player") then
		-- The retry path for anything that was skipped because the model
		-- wasn't ready yet: run setup if it's still pending, then capture the
		-- baseline and re-apply.
		Addon:RetryModelSetup(AvatarModelFrame);
		Addon:CaptureBaseline(AvatarModelFrame);
		Addon:RefreshEquipmentToggle();

		if Addon.previewModel then
			Addon:RetryModelSetup(Addon.previewModel);
			Addon:RefreshEquipmentOnModel(Addon.previewModel);
		end
	end
end

function Addon:TRANSMOG_COLLECTION_UPDATED()
	-- Outfit data may only now have arrived; re-apply so a preview selected
	-- before the collection was cached resolves without needing a retry timer.
	if Addon:IsOutfitPreviewActive() then
		Addon:RefreshEquipmentToggle();
		if Addon.previewModel then
			Addon:RefreshEquipmentOnModel(Addon.previewModel);
		end
	end
	if Addon.RefreshOutfitsList then
		Addon:RefreshOutfitsList();
	end
end


