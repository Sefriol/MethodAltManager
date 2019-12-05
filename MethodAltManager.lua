
local _, AltManager = ...;

_G["AltManager"] = AltManager;

-- Made by: Qooning - Tarren Mill <Method>, 2017-2018

local sizey = 220;
local instances_y_add = 1;
local xoffset = 0;
local yoffset = 150;
local alpha = 1;
local addon = "MethodAltManager";
local numel = table.getn;
local Aurora = _G.Aurora
local per_alt_x = 120;

local min_x_size = 300;

local min_level = 110;
local name_label = "Name"
local mythic_done_label = "Highest M+ done"
local mythic_keystone_label = "Keystone"
local seals_owned_label = "Seals owned"
local seals_bought_label = "Seals obtained"
local azerite_label = "Heart of Azeroth"
local depleted_label = "Depleted"

local VERSION = "2.0.2"

local favoriteTier = EJ_GetNumTiers()

-- BfA Currencies
local currencies = {
	[1560] = {},
	[1587] = {},
	[1721] = {},
	[1710] = {}
};

-- Mythic+ Dungeons
local dungeons = {}

local BfAWorldBosses = {
--[BossID] = QuestID
	[2139] = 52181, -- T'zane
	[2141] = 52169, -- Ji'arak
	[2197] = 52157, -- Hailstone Construct
	[2212] = 52848, -- The Lion's Roar (Horde)
	[2199] = 52163, -- Azurethos, The Winged Typhoon
	[2198] = 52166, -- Warbringer Yenajz
	[2210] = 52196, -- Dunegorger Kraulok
	[2213] = 52847, -- Doom's Howl (Alliance)
}

local raids = {}

SLASH_METHODALTMANAGER1 = "/mam";
SLASH_METHODALTMANAGER2 = "/alts";

local function spairs(t, order)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function SlashCmdList.METHODALTMANAGER(cmd, editbox)
	local rqst, arg = strsplit(' ', cmd)
	if rqst == "help" then
		print("Method Alt Manager help:")
		print("   \"/alts purge\" to remove all stored data.")
		print("   \"/alts remove name\" to remove characters by name.")
	elseif rqst == "purge" then
		AltManager:Purge();
	elseif rqst == "remove" then
		AltManager:RemoveCharactersByName(arg)
	else
		AltManager:ShowInterface();
	end
end

do
	local main_frame = CreateFrame("frame", "AltManagerFrame", UIParent);
	AltManager.main_frame = main_frame;
	main_frame:SetFrameStrata("MEDIUM");
	main_frame.background = main_frame:CreateTexture(nil, "BACKGROUND");
	main_frame.background:SetAllPoints();
	main_frame.background:SetDrawLayer("ARTWORK", 1);
	main_frame.background:SetColorTexture(0, 0, 0, 0.5);
	
	main_frame.scan_tooltip = CreateFrame('GameTooltip', 'DepletedTooltipScan', UIParent, 'GameTooltipTemplate');
	

	-- Set frame position
	main_frame:ClearAllPoints();
	main_frame:SetPoint("CENTER", UIParent, "CENTER", xoffset, yoffset);
	
	main_frame:RegisterEvent("ADDON_LOADED");
	main_frame:RegisterEvent("PLAYER_LOGIN");
	main_frame:RegisterEvent("QUEST_TURNED_IN");
	main_frame:RegisterEvent("BAG_UPDATE_DELAYED");
	main_frame:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED");
	main_frame:RegisterEvent("CHAT_MSG_CURRENCY");
	main_frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
	

	main_frame:SetScript("OnEvent", function(self, ...)
		local event, loaded = ...;
		if event == "ADDON_LOADED" then
			if addon == loaded then
				AltManager:OnLoad();
			end
		end
		if event == "PLAYER_LOGIN" then
			AltManager:OnLogin();
		end
		if event == "AZERITE_ITEM_EXPERIENCE_CHANGED" then
			local data = AltManager:CollectData();
			AltManager:StoreData(data);
		end
		if (event == "BAG_UPDATE_DELAYED" or event == "QUEST_TURNED_IN" or event == "CHAT_MSG_CURRENCY" or event == "CURRENCY_DISPLAY_UPDATE") and AltManager.addon_loaded then
			local data = AltManager:CollectData();
			AltManager:StoreData(data);
		end
		
	end)
	
	-- Show Frame
	main_frame:Hide();
end

function AltManager:InitDB()
	local t = {};
	t.alts = 0;
	return t;
end

-- because of guid...
function AltManager:OnLogin()
	self:GenerateDungeonTable()
	self:ValidateReset();
	self:StoreData(self:CollectData());
	
	local alts = MethodAltManagerDB.alts;
	
	AltManager:CreateMenu();
	self.main_frame:SetSize(max((alts + 1) * per_alt_x, min_x_size), sizey);
	self.main_frame.background:SetAllPoints();
	
	-- Create menus
	
	AltManager:MakeTopBottomTextures(self.main_frame);
	AltManager:MakeBorder(self.main_frame, 5);
end

function AltManager:OnLoad()
	self.main_frame:UnregisterEvent("ADDON_LOADED");
	tinsert(UISpecialFrames,"AltManagerFrame");

	MethodAltManagerDB = MethodAltManagerDB or self:InitDB();

	self.addon_loaded = true

	C_MythicPlus.RequestRewards();
	C_MythicPlus.RequestCurrentAffixes();
	C_MythicPlus.RequestMapInfo();
	for k,v in pairs(dungeons) do
		-- request info in advance
		C_MythicPlus.RequestMapInfo(k);
	end
end

function AltManager:CreateFontFrame(parent, x_size, height, relative_to, y_offset, label, justify)
	local f = CreateFrame("Button", nil, parent);
	f:SetSize(x_size, height);
	f:SetNormalFontObject(GameFontHighlightSmall)
	f:SetText(label)
	f:SetPoint("TOPLEFT", relative_to, "TOPLEFT", 0, y_offset);
	f:GetFontString():SetJustifyH(justify);
	f:GetFontString():SetJustifyV("CENTER");
	f:SetPushedTextOffset(0, 0);
	f:GetFontString():SetWidth(120)
	f:GetFontString():SetHeight(20)
	
	return f;
end

function AltManager:Keyset()
	local keyset = {}
	if MethodAltManagerDB and MethodAltManagerDB.data then
		for k in pairs(MethodAltManagerDB.data) do
			table.insert(keyset, k)
		end
	end
	return keyset
end

-- Use API to generate dungeons-table
function AltManager:GenerateDungeonTable()
	local tempMapTable = {};
	local emptyTable = true;
	local APITable = C_ChallengeMode.GetMapTable();
	for _, k in pairs(APITable) do
		local name = C_ChallengeMode.GetMapUIInfo(k);
		local shortHand = name:gsub("(%a)([%w_']*)", "%1"):gsub("%s+", "");
		table.insert(tempMapTable, k, shortHand);
		emptyTable = false;
	end
	if not emptyTable then
		dungeons = tempMapTable;
	end
end

function AltManager:GenerateRaidData()
	-- Select the latest tier
	EJ_SelectTier(favoriteTier);
	local raidData = {}
	if EJ_GetCurrentTier() == favoriteTier then
		local raid = {}
		local instanceIdx = 1
		local bossIdx = 1;
		-- Get raid instance from latest tier
		local instanceID, instanceName = EJ_GetInstanceByIndex(instanceIdx, true)
		while instanceID do
			raid["id"] = instanceID;
			raid["label"] = instanceName;
			raid["order"] = instanceIdx
			raid["killed"] = nil;
			local _, _, bossID = EJ_GetEncounterInfoByIndex(bossIdx, instanceID);
			while bossID do
				bossIdx = bossIdx + 1;
				_, _, bossID = EJ_GetEncounterInfoByIndex(bossIdx, instanceID);
			end
			raid["bosses"] = bossIdx - 1
			raid["data"] = function(alt_data, i) return self:MakeRaidString(alt_data.savedins, i) end
			raidData[instanceID] = raid;
			raid = {}
			bossIdx = 1
			instanceIdx = instanceIdx + 1;
			instanceID, instanceName = EJ_GetInstanceByIndex(instanceIdx, true)
		end
	end
	raids[favoriteTier] = raidData
end

function AltManager:ValidateReset()
	local db = MethodAltManagerDB
	if not db then return end;
	if not db.data then return end;
	
	local keyset = {}
	for k in pairs(db.data) do
		table.insert(keyset, k)
	end
	
	for alt = 1, db.alts do
		local expiry = db.data[keyset[alt]].expires or 0;
		local char_table = db.data[keyset[alt]];
		if time() > expiry then
			-- reset this alt
			char_table.seals_bought = 0;
			char_table.dungeon = "Unknown";
			char_table.level = "?";
			char_table.highest_mplus = 0;
			char_table.is_depleted = false;
			char_table.expires = self:GetNextWeeklyResetTime();
			char_table.savedins = {}
			if not char_table.heart_of_azeroth then else
				char_table.heart_of_azeroth.weekly = false
			end
		end
	end
end

function AltManager:Purge()
	MethodAltManagerDB = self:InitDB();
end

function AltManager:RemoveCharactersByName(name)
	local db = MethodAltManagerDB;

	local indices = {};
	for guid, data in pairs(db.data) do
		if db.data[guid].name == name then
			indices[#indices+1] = guid
		end
	end

	db.alts = db.alts - #indices;
	for i = 1,#indices do
		db.data[indices[i]] = nil
	end

	print("Found " .. (#indices) .. " characters by the name of " .. name)
	print("Please reload ui to update the displayed info.")

	-- things wont be redrawn
end

function AltManager:StoreData(data)

	if not self.addon_loaded then
		return
	end

	-- This can happen shortly after logging in, the game doesn't know the characters guid yet
	if not data or not data.guid then
		return
	end

	if UnitLevel('player') < min_level then return end;
	
	local db = MethodAltManagerDB;
	local guid = data.guid;
	
	db.data = db.data or {};
	
	local update = false;
	for k, v in pairs(db.data) do
		if k == guid then
			update = true;
		end
	end
	if not update then
		db.data[guid] = data;
		db.alts = db.alts + 1;
	else
		db.data[guid] = data;
	end
end

function AltManager:CollectData()

	if UnitLevel('player') < min_level then return end;
	
	local name = UnitName('player')
	local _, class = UnitClass('player')
	local dungeon = nil;
	local expire = nil;
	local level = nil;
	local seals = nil;
	local seals_bought = nil;
	local highest_mplus = 0;
	local depleted = false;

	local guid = UnitGUID('player');

	local mine_old = nil
	if MethodAltManagerDB and MethodAltManagerDB.data then
		mine_old = MethodAltManagerDB.data[guid];
	end

	C_MythicPlus.RequestRewards();
	local l, cR, nR = C_MythicPlus.GetWeeklyChestRewardLevel();
	if l and l > highest_mplus then
		highest_mplus = l;
	end
	
	-- find keystone
	local keystone_found = false;
	for container=BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(container)
		for slot=1, slots do
			local _, _, _, _, _, _, slotLink, _, _, slotItemID = GetContainerItemInfo(container, slot)
			if slotItemID == 158923 then
				local itemString = slotLink:match("|Hkeystone:([0-9:]+)|h(%b[])|h")
				local info = { strsplit(":", itemString) }
				-- scan tooltip for depleted
				self.main_frame.scan_tooltip:SetOwner(UIParent, 'ANCHOR_NONE');
				self.main_frame.scan_tooltip:SetBagItem(container, slot);
				local regions = self.main_frame.scan_tooltip:GetRegions();
				for i = 1, self.main_frame.scan_tooltip:NumLines() do
					local left = _G["DepletedTooltipScanTextLeft"..i]:GetText();
					if string.find(left, depleted_label) then
						depleted = true
					end
				end
				self.main_frame.scan_tooltip:Hide();
				dungeon = tonumber(info[2])
				if not dungeon then print("MethodAltManager - Parse Failure, please let Qoning know that this happened."); end
				level = tonumber(info[3])
				if not level then print("MethodAltManager - Parse Failure, please let Qoning know that this happened."); end
				expire = tonumber(info[4])
				keystone_found = true;
			end
		end
	end
	if not keystone_found then
		dungeon = "Unknown";
		level = "?"
	end
	
	-- Heart of Azeroth Progress
	local heart_of_azeroth = nil
	local azeriteItemLocation = C_AzeriteItem.FindActiveAzeriteItem(); 

	if (azeriteItemLocation) then
		local xp, totalLevelXP = C_AzeriteItem.GetAzeriteItemXPInfo(azeriteItemLocation);
		heart_of_azeroth = {
			['lvl'] = C_AzeriteItem.GetPowerLevel(azeriteItemLocation),
			['xp'] = xp,
			['totalXP'] = totalLevelXP,
			['weekly'] = IsQuestFlaggedCompleted(53435) or IsQuestFlaggedCompleted(53436),
		}
	end

	-- Process currencies 
	i = 1
	for cid, cobj in pairs(currencies) do
		local label, count = GetCurrencyInfo(cid)
		currencies[cid]= {
			["order"] = i,
			["label"] = label,
			["count"] = count
		}
		i = i + 1;
	end

	_, seals = GetCurrencyInfo(1580);
	
	seals_bought = 0

	-- Seals - BfA
	local gold_1 = IsQuestFlaggedCompleted(52834)
	local gold_2 = IsQuestFlaggedCompleted(52838)
	local resources_1 = IsQuestFlaggedCompleted(52837)
	local resources_2 = IsQuestFlaggedCompleted(52840)
	local marks_1 = IsQuestFlaggedCompleted(52835)
	local marks_2 = IsQuestFlaggedCompleted(52839)

	if gold_1 then seals_bought = seals_bought + 1 end
	if gold_2 then seals_bought = seals_bought + 1 end
	
	if resources_1 then seals_bought = seals_bought + 1 end
	if resources_2 then seals_bought = seals_bought + 1 end

	if marks_1 then seals_bought = seals_bought + 1 end
	if marks_2 then seals_bought = seals_bought + 1 end


	local saves = GetNumSavedInstances();
	local char_table = {}
	char_table.savedins = {}
	for i = 1, saves do
		local instance = {}
		local name, iID, reset, difficultyID, _, _, instanceIDMostSig, isRaid, _, difficulty, bosses, killed_bosses = GetSavedInstanceInfo(i);
		if isRaid and reset > 0 then
			char_table.savedins[name] = char_table.savedins[name] or {}
			char_table.savedins[name][difficultyID] = {
				difficultyID,
				difficulty,
				bosses,
				killed_bosses
			}
		end
	end

	-- Check BfA World bosses
	local bfaworldtotal = 0
	for cid, cobj in pairs(BfAWorldBosses) do
		bfaworldtotal = IsQuestFlaggedCompleted(cobj) and bfaworldtotal+1 or bfaworldtotal
	end
	if (bfaworldtotal > 0) then
		char_table.savedins["Azeroth"] = char_table.savedins[name] or {}
		char_table.savedins["Azeroth"][4] = {
			4,
			"25 Player",
			2,
			bfaworldtotal,
		}
	end

	

	local _, ilevel = GetAverageItemLevel();

	-- store data into a table
	
	char_table.guid = UnitGUID('player');
	char_table.name = name;
	char_table.class = class;
	char_table.ilevel = ilevel;
	char_table.seals = seals;
	char_table.seals_bought = seals_bought;

	char_table.dungeon = dungeon;
	char_table.level = level;
	char_table.heart_of_azeroth = heart_of_azeroth;
	char_table.highest_mplus = highest_mplus;

	char_table.currencies = currencies
	char_table.is_depleted = depleted;
	char_table.expires = self:GetNextWeeklyResetTime();
	return char_table;
end

function AltManager:PopulateStrings()
	local font_height = 20;
	local db = MethodAltManagerDB;
	
	local keyset = {}
	for k in pairs(db.data) do
		table.insert(keyset, k)
	end
	
	self.main_frame.alt_columns = self.main_frame.alt_columns or {};
	
	local alt = 0
	for alt_guid, alt_data in spairs(db.data, function(t, a, b) return t[a].ilevel > t[b].ilevel end) do
		alt = alt + 1
		-- create the frame to which all the fontstrings anchor
		local anchor_frame = self.main_frame.alt_columns[alt] or CreateFrame("Button", nil, self.main_frame);
		if not self.main_frame.alt_columns[alt] then
			self.main_frame.alt_columns[alt] = anchor_frame;
		end
		anchor_frame:SetPoint("TOPLEFT", self.main_frame, "TOPLEFT", per_alt_x * alt, -1);
		-- init table for fontstring storage
		self.main_frame.alt_columns[alt].label_columns = self.main_frame.alt_columns[alt].label_columns or {};
		local label_columns = self.main_frame.alt_columns[alt].label_columns;
		-- create / fill fontstrings
		local i = 1;
		for column_iden, column in spairs(self.columns_table, function(t, a, b) return t[a].order < t[b].order end) do
			-- only display data with values
			if type(column.data) == "function" then
				local current_row = label_columns[i] or self:CreateFontFrame(
					self.main_frame,
					per_alt_x,
					column.font_height or font_height,
					anchor_frame,
					-(i - 1) * font_height,
					column.data(alt_data, i),
					"CENTER");
				-- insert it into storage if just created
				if not self.main_frame.alt_columns[alt].label_columns[i] then
					self.main_frame.alt_columns[alt].label_columns[i] = current_row;
				end
				if column.color then
					local color = column.color(alt_data)
					current_row:GetFontString():SetTextColor(color.r, color.g, color.b, 1);
				end
				current_row:SetText(column.data(alt_data, i))
				if column.font then
					current_row:GetFontString():SetFont(column.font, 8)
				else
					--current_row:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 14)
				end
				if column.justify then
					current_row:GetFontString():SetJustifyV(column.justify);
				end
			end
			if column.data == "currencies" then
				if(alt_data.currencies) then
					for cur_iden, cur in spairs(alt_data.currencies, function(t, a, b) return t[a].order < t[b].order end) do
						local current_row = label_columns[i] or self:CreateFontFrame(
							self.main_frame,
							per_alt_x,
							column.font_height or font_height,
							anchor_frame,
							-(i - 1) * font_height,
							tostring(cur.count),
							"CENTER");
						-- insert it into storage if just created
						if not self.main_frame.alt_columns[alt].label_columns[i] then
							self.main_frame.alt_columns[alt].label_columns[i] = current_row;
						end
						if column.color then
							local color = column.color(alt_data)
							current_row:GetFontString():SetTextColor(color.r, color.g, color.b, 1);
						end
						current_row:SetText(tostring(cur.count))
						if column.font then
							current_row:GetFontString():SetFont(column.font, 8)
						else
							--current_row:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 14)
						end
						if column.justify then
							current_row:GetFontString():SetJustifyV(column.justify);
						end
						i = i + 1
					end
				else
					-- To make previous' version data compatible since those characters don't have "currencies"
					for cur_iden, cur in spairs(currencies, function(t, a, b) return t[a].order < t[b].order end) do
						local current_row = label_columns[i] or self:CreateFontFrame(
							self.main_frame,
							per_alt_x,
							column.font_height or font_height,
							anchor_frame,
							-(i - 1) * font_height,
							"0",
							"CENTER");
						-- insert it into storage if just created
						if not self.main_frame.alt_columns[alt].label_columns[i] then
							self.main_frame.alt_columns[alt].label_columns[i] = current_row;
						end
						if column.color then
							local color = column.color(alt_data)
							current_row:GetFontString():SetTextColor(color.r, color.g, color.b, 1);
						end
						current_row:SetText("0")
						if column.font then
							current_row:GetFontString():SetFont(column.font, 8)
						else
							--current_row:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 14)
						end
						if column.justify then
							current_row:GetFontString():SetJustifyV(column.justify);
						end
						i = i + 1
					end
				end
			end
			i = i + 1
		end
		sizey = 20 * i
		anchor_frame:SetSize(per_alt_x, sizey);
	end
	
end

function AltManager:CreateMenu()

	-- Close button
	self.main_frame.closeButton = CreateFrame("Button", "CloseButton", self.main_frame, "UIPanelCloseButton");
	if Aurora then Aurora.Skin.UIPanelCloseButton(self.main_frame.closeButton) end
	self.main_frame.closeButton:ClearAllPoints()
	self.main_frame.closeButton:SetFrameLevel(self.main_frame:GetFrameLevel() + 2);
	self.main_frame.closeButton:SetPoint("BOTTOMRIGHT", self.main_frame, "TOPRIGHT",Aurora and -5 or -10, Aurora and 5 or -2);
	self.main_frame.closeButton:SetScript("OnClick", function() AltManager:HideInterface(); end);

	local column_table = {
		name = {
			order = 1,
			label = name_label,
			data = function(alt_data) return alt_data.name end,
			color = function(alt_data) return RAID_CLASS_COLORS[alt_data.class] end,
		},
		ilevel = {
			order = 2,
			data = function(alt_data) return string.format("%.2f", alt_data.ilevel or 0) end,
			justify = "TOP",
			font = "Fonts\\FRIZQT__.TTF",
		},
		hoalevel = {
			order = 3,
			label = azerite_label,
			color = function(alt_data)
				if not alt_data.heart_of_azeroth then return {r=255, g=0, b=0}
				else
					return alt_data.heart_of_azeroth.weekly and {r=0, g=255, b=0} or {r=255, g=0, b=0};
				end
			end,
			data = function(alt_data)
				if not alt_data.heart_of_azeroth then return "-"
				else
					return tostring(alt_data.heart_of_azeroth.lvl) .. " (" .. tostring(alt_data.heart_of_azeroth.xp/alt_data.heart_of_azeroth.totalXP*100):gsub('(%-?%d+)%.%d+','%1') .. "%)"
				end
			end,
		},
		mplus = {
			order = 4,
			label = mythic_done_label,
			data = function(alt_data) return tostring(alt_data.highest_mplus) end, 
		},
		keystone = {
			order = 5,
			label = mythic_keystone_label,
			data = function(alt_data) local depleted_string = alt_data.is_depleted and " (D)" or ""; return (dungeons[alt_data.dungeon] or alt_data.dungeon) .. " +" .. tostring(alt_data.level) .. depleted_string; end,
		},
		seals_owned = {
			order = 6,
			label = seals_owned_label,
			data = function(alt_data) return tostring(alt_data.seals) end,
		},
		seals_bought = {
			order = 7,
			label = seals_bought_label,
			data = function(alt_data) return tostring(alt_data.seals_bought) end,
		},
		currencies = {
			order = 8,
			data = "currencies",
			currency_function = function(currencies) end,
		},
		dummy_empty_line = {
			order = 11,
			data = function(alt_data) return " " end,
		},
		raid_unroll = {
			order = 12,
			data = "unroll",
			name = "+ Instances",
			unroll_function = function(button)
				self.instances_unroll = self.instances_unroll or {};
				self.instances_unroll.state = self.instances_unroll.state or "closed";
				if self.instances_unroll.state == "closed" then
					self:CreateUnrollFrame()
					button:SetText("-  Instances");
					self.instances_unroll.state = "open";
				else
					-- do rollup
					self.main_frame:SetSize(max((MethodAltManagerDB.alts + 1) * per_alt_x, min_x_size), sizey);
					self.main_frame.background:SetAllPoints();
					self.instances_unroll.unroll_frame:Hide();
					button:SetText("+  Instances");
					self.instances_unroll.state = "closed";
				end
			end
		}
	}
	self.columns_table = column_table;

	-- create labels and unrolls
	local font_height = 20;
	local label_column = self.main_frame.label_column or CreateFrame("Button", nil, self.main_frame);
	if not self.main_frame.label_column then self.main_frame.label_column = label_column; end
	label_column:SetPoint("TOPLEFT", self.main_frame, "TOPLEFT", 4, -1);

	local i = 1;
	for row_iden, row in spairs(self.columns_table, function(t, a, b) return t[a].order < t[b].order end) do
		if row.label then
			local label_row = self:CreateFontFrame(self.main_frame, per_alt_x, font_height, label_column, -(i-1)*font_height, row.label..":", "RIGHT");
			self.main_frame.lowest_point = -(i-1)*font_height;
		end
		if row.data == "unroll" then
			-- create a button that will unroll it
			local unroll_button = CreateFrame("Button", nil, self.main_frame, "UIPanelButtonTemplate");
			unroll_button:SetText(row.name);
			unroll_button:SetFrameLevel(self.main_frame:GetFrameLevel() + 2);
			unroll_button:SetSize(unroll_button:GetTextWidth() + 20, 25);
			unroll_button:SetPoint("BOTTOMRIGHT", self.main_frame, "TOPLEFT", 4 + per_alt_x, -(i-1)*font_height-10);
			
			if Aurora then Aurora.Skin.UIPanelButtonTemplate(unroll_button) end
			unroll_button:SetScript("OnClick", function() row.unroll_function(unroll_button) end);

			local tierDropDown = CreateFrame("Frame", nil, self.main_frame, "UIDropDownMenuTemplate")
			if Aurora then Aurora.Skin.UIDropDownMenuTemplate(tierDropDown) end
			-- obj:SetPoint(point, relativeTo, relativePoint, ofsx, ofsy);
			tierDropDown:SetPoint("LEFT", unroll_button, "RIGHT");
			UIDropDownMenu_SetWidth(tierDropDown, 130) -- Use in place of dropDown:SetWidth
			UIDropDownMenu_SetText(tierDropDown, EJ_GetTierInfo(favoriteTier))
			UIDropDownMenu_Initialize(tierDropDown, AltManagerDropDown_Menu)
			self.main_frame.lowest_point = -(i-1)*font_height-10;

			function tierDropDown:SetTier(newValue)
				-- Change Encounter Journal to correct expansion
				favoriteTier = newValue
				EJ_SelectTier(newValue)

				-- Set correct value to dropdown menu
				UIDropDownMenu_SetText(tierDropDown, EJ_GetTierInfo(favoriteTier))
				-- Close the entire menu
				CloseDropDownMenus();

				-- Update unroll
				AltManager.instances_unroll = AltManager.instances_unroll or {};
				AltManager.instances_unroll.state = "closed";
				row.unroll_function(unroll_button)
			end
		end
		if row.data == "currencies" then
			for cur_iden, cur in spairs(currencies, function(t, a, b) return t[a].order < t[b].order end) do
				if cur.label then
					self:CreateFontFrame(self.main_frame, per_alt_x, font_height, label_column, -(i-1)*font_height, cur.label..":", "RIGHT");
					self.main_frame.lowest_point = -(i-1)*font_height;
				end
				i = i + 1
			end
		end
		i = i + 1
	end
	sizey = i * 20
	label_column:SetSize(per_alt_x, sizey);
end

function AltManager:CreateCurrencyFrame()

end

function AltManager:CreateUnrollFrame()
	local my_rows = nil;
	if (raids[favoriteTier]) then
		my_rows = raids[favoriteTier];
	else
		self:GenerateRaidData();
		my_rows = raids[favoriteTier];
	end
	-- do unroll
	self.instances_unroll.unroll_frame = self.instances_unroll.unroll_frame or CreateFrame("Button", nil, self.main_frame);
	self.instances_unroll.unroll_frame:SetSize(per_alt_x, instances_y_add*20);
	self.instances_unroll.unroll_frame:SetPoint("TOPLEFT", self.main_frame, "TOPLEFT", 4, self.main_frame.lowest_point - 10);
	self.instances_unroll.unroll_frame:Show();
	
	local font_height = 20;
	-- create the rows for the unroll
	if not self.instances_unroll.labels then
		self.instances_unroll.labels = {};
		local i = 1
		for row_iden, row in spairs(my_rows, function(t, a, b) return t[a].order < t[b].order end) do
			if row.label then
				local label_row = self:CreateFontFrame(self.instances_unroll.unroll_frame, per_alt_x, font_height, self.instances_unroll.unroll_frame, -(i-1)*font_height, row.label, "RIGHT");
				table.insert(self.instances_unroll.labels, label_row)
			end
			i = i + 1
		end
		instances_y_add = i
	else
		local i = 1
		local idx, v = nil,nil
		for row_iden, row in spairs(my_rows, function(t, a, b) return t[a].order < t[b].order end) do
			if row.label then
				local tempIdx = idx
				idx, v = next(self.instances_unroll.labels,idx)
				if not (idx) then
					local label_row = self:CreateFontFrame(self.instances_unroll.unroll_frame, per_alt_x, font_height, self.instances_unroll.unroll_frame, -(i-1)*font_height, row.label, "RIGHT");
					table.insert(self.instances_unroll.labels, label_row)
					idx = tempIdx + 1 
				else
					v:SetText(row.label)
					v:Show()
				end
			end
			i = i + 1
		end
		while idx do
			idx, v = next(self.instances_unroll.labels,idx)
			if(v) then
				v:Hide()
			end
		end
		instances_y_add = i
	end
	
	-- populate it for alts
	self.instances_unroll.alt_columns = self.instances_unroll.alt_columns or {};
	local alt = 0
	local db = MethodAltManagerDB;
	for alt_guid, alt_data in spairs(db.data, function(t, a, b) return t[a].ilevel > t[b].ilevel end) do
		alt = alt + 1
		-- create the frame to which all the fontstrings anchor
		local anchor_frame = self.instances_unroll.alt_columns[alt] or CreateFrame("Button", nil, self.instances_unroll.unroll_frame);
		if not self.instances_unroll.alt_columns[alt] then
			self.instances_unroll.alt_columns[alt] = anchor_frame;
		end
		anchor_frame:SetPoint("TOPLEFT", self.instances_unroll.unroll_frame, "TOPLEFT", per_alt_x * alt, -1);
		anchor_frame:SetSize(per_alt_x, instances_y_add*20);
		-- init table for fontstring storage
		self.instances_unroll.alt_columns[alt].label_columns = self.instances_unroll.alt_columns[alt].label_columns or {};
		local label_columns = self.instances_unroll.alt_columns[alt].label_columns;
		-- create / fill fontstrings
		local i = 1;
		for column_iden, column in spairs(my_rows, function(t, a, b) return t[a].order < t[b].order end) do
			local current_row = 
				label_columns[i] or self:CreateFontFrame(
					self.instances_unroll.unroll_frame,
					per_alt_x,
					column.font_height or font_height,
					anchor_frame, -(i - 1) * font_height,
					column.data(alt_data,i),
					"CENTER");
			-- insert it into storage if just created
			if not self.instances_unroll.alt_columns[alt].label_columns[i] then
				self.instances_unroll.alt_columns[alt].label_columns[i] = current_row;
			end
			current_row:SetText(column.data(alt_data, i));
			current_row:Show();
			i = i + 1
		end
		i = i-1
		for idx, col  in pairs(self.instances_unroll.alt_columns[alt].label_columns) do
			if (idx > i) then
				col:Hide();
			end
		end
	end

	-- fixup the background
	self.main_frame:SetSize(max((alt + 1) * per_alt_x, min_x_size), sizey + (instances_y_add*20));
	self.main_frame.background:SetAllPoints();
end

function AltManagerDropDown_Menu(frame, level, menuList)
	local info = UIDropDownMenu_CreateInfo();
	local lenTiers = EJ_GetNumTiers();
	for i=1, lenTiers do
		info.text = EJ_GetTierInfo(i);
		info.func = frame.SetTier
		info.checked = i ==  EJ_GetCurrentTier();
		info.arg1 = i;
		UIDropDownMenu_AddButton(info, level)
	end
end

function AltManager:MakeHoAString(data)
	print(data,"---")
	if not data then return "-" end;
	if not data.heart_of_azeroth then return "-" end;
	return tostring(data.lvl) .. "(" .. tostring(data.xp/data.totalXP) .. ")";
end

function AltManager:MakeRaidString(data,i)
	if not data then return "-" end
	if not i then return "-" end
	local string = ""
	local legacy = 0
	local raid = data[self.instances_unroll.labels[i]:GetText()];
	if raid then
		for difi, iobj in pairs(raid) do
			if difi == 14 then -- "Normal" (Raids)
				string = string .. tostring(iobj[4]) .. "N";
			elseif difi == 15 then -- "Heroic" (Raids)
				string = string .. tostring(iobj[4]) .. "H";
			elseif difi == 16 then -- "Mythic" (Raids)
				string = string .. tostring(iobj[4]) .. "M";
			elseif difi == 17 then -- "Looking For Raid"
				string = string .. tostring(iobj[4]) .. "L";
			else -- Legacy raids	
				legacy = legacy + iobj[4];
			end
		end
	else
		return "-"
	end
	if legacy > 0 then
		return tostring(legacy);
	else
		return string;
	end
end

function AltManager:HideInterface()
	self.main_frame:Hide();
end

function AltManager:ShowInterface()
	self.main_frame:Show();
	self:StoreData(self:CollectData())
	self:PopulateStrings();
end

function AltManager:MakeTopBottomTextures(frame)
	if frame.bottomPanel == nil then
		frame.bottomPanel = frame:CreateTexture(nil);
	end
	if frame.topPanel == nil then
		frame.topPanel = CreateFrame("Frame", "AltManagerTopPanel", frame);
		frame.topPanelTex = frame.topPanel:CreateTexture(nil, "BACKGROUND");
		local logo = frame.topPanel:CreateTexture("logo","ARTWORK");
		logo:SetPoint("TOPLEFT");
		logo:SetTexture("Interface\\AddOns\\MethodAltManager\\Media\\AltManager64");
		frame.topPanelTex:SetAllPoints();
		frame.topPanelTex:SetDrawLayer("ARTWORK", -5);
		frame.topPanelTex:SetColorTexture(0, 0, 0, 0.7);
		
		frame.topPanelString = frame.topPanel:CreateFontString("Method name");
		frame.topPanelString:SetFont("Fonts\\FRIZQT__.TTF", 20)
		frame.topPanelString:SetTextColor(1, 1, 1, 1);
		frame.topPanelString:SetJustifyH("CENTER")
		frame.topPanelString:SetJustifyV("CENTER")
		frame.topPanelString:SetWidth(260)
		frame.topPanelString:SetHeight(20)
		frame.topPanelString:SetText("Method Alt Manager");
		frame.topPanelString:ClearAllPoints();
		frame.topPanelString:SetPoint("CENTER", frame.topPanel, "CENTER", 0, 0);
		frame.topPanelString:Show();
		
	end
	frame.bottomPanel:SetColorTexture(0, 0, 0, 0.7);
	frame.bottomPanel:ClearAllPoints();
	frame.bottomPanel:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0);
	frame.bottomPanel:SetSize(frame:GetWidth(), 30);
	frame.bottomPanel:SetDrawLayer("ARTWORK", 7);

	frame.topPanel:ClearAllPoints();
	frame.topPanel:SetSize(frame:GetWidth(), 30);
	frame.topPanel:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0);

	frame:SetMovable(true);
	frame.topPanel:EnableMouse(true);
	frame.topPanel:RegisterForDrag("LeftButton");
	frame.topPanel:SetScript("OnDragStart", function(self,button)
		frame:SetMovable(true);
        frame:StartMoving();
    end);
	frame.topPanel:SetScript("OnDragStop", function(self,button)
        frame:StopMovingOrSizing();
		frame:SetMovable(false);
    end);
end

function AltManager:MakeBorderPart(frame, x, y, xoff, yoff, part)
	if part == nil then
		part = frame:CreateTexture(nil);
	end
	part:SetTexture(0, 0, 0, 1);
	part:ClearAllPoints();
	part:SetPoint("TOPLEFT", frame, "TOPLEFT", xoff, yoff);
	part:SetSize(x, y);
	part:SetDrawLayer("ARTWORK", 7);
	return part;
end

function AltManager:MakeBorder(frame, size)
	if size == 0 then
		return;
	end
	frame.borderTop = self:MakeBorderPart(frame, frame:GetWidth(), size, 0, 0, frame.borderTop); -- top
	frame.borderLeft = self:MakeBorderPart(frame, size, frame:GetHeight(), 0, 0, frame.borderLeft); -- left
	frame.borderBottom = self:MakeBorderPart(frame, frame:GetWidth(), size, 0, -frame:GetHeight() + size, frame.borderBottom); -- bottom
	frame.borderRight = self:MakeBorderPart(frame, size, frame:GetHeight(), frame:GetWidth() - size, 0, frame.borderRight); -- right
end

-- shamelessly stolen from saved instances
function AltManager:GetNextWeeklyResetTime()
	if not self.resetDays then
		local region = self:GetRegion()
		if not region then return nil end
		self.resetDays = {}
		self.resetDays.DLHoffset = 0
		if region == "US" then
			self.resetDays["2"] = true -- tuesday
			-- ensure oceanic servers over the dateline still reset on tues UTC (wed 1/2 AM server)
			self.resetDays.DLHoffset = -3 
		elseif region == "EU" then
			self.resetDays["3"] = true -- wednesday
		elseif region == "CN" or region == "KR" or region == "TW" then -- XXX: codes unconfirmed
			self.resetDays["4"] = true -- thursday
		else
			self.resetDays["2"] = true -- tuesday?
		end
	end
	local offset = (self:GetServerOffset() + self.resetDays.DLHoffset) * 3600
	local nightlyReset = self:GetNextDailyResetTime()
	if not nightlyReset then return nil end
	while not self.resetDays[date("%w",nightlyReset+offset)] do
		nightlyReset = nightlyReset + 24 * 3600
	end
	return nightlyReset
end

function AltManager:GetNextDailyResetTime()
	local resettime = GetQuestResetTime()
	if not resettime or resettime <= 0 or -- ticket 43: can fail during startup
		-- also right after a daylight savings rollover, when it returns negative values >.<
		resettime > 24*3600+30 then -- can also be wrong near reset in an instance
		return nil
	end
	if false then -- this should no longer be a problem after the 7.0 reset time changes
		-- ticket 177/191: GetQuestResetTime() is wrong for Oceanic+Brazilian characters in PST instances
		local serverHour, serverMinute = GetGameTime()
		local serverResetTime = (serverHour*3600 + serverMinute*60 + resettime) % 86400 -- GetGameTime of the reported reset
		local diff = serverResetTime - 10800 -- how far from 3AM server
		if math.abs(diff) > 3.5*3600  -- more than 3.5 hours - ignore TZ differences of US continental servers
			and self:GetRegion() == "US" then
			local diffhours = math.floor((diff + 1800)/3600)
			resettime = resettime - diffhours*3600
			if resettime < -900 then -- reset already passed, next reset
				resettime = resettime + 86400
				elseif resettime > 86400+900 then
				resettime = resettime - 86400
			end
		end
	end
	return time() + resettime
end

function AltManager:GetServerOffset()
	local serverDay = C_Calendar.GetDate()['weekday'] - 1 -- 1-based starts on Sun
	local localDay = tonumber(date("%w")) -- 0-based starts on Sun
	local serverHour, serverMinute = GetGameTime()
	local localHour, localMinute = tonumber(date("%H")), tonumber(date("%M"))
	if serverDay == (localDay + 1)%7 then -- server is a day ahead
		serverHour = serverHour + 24
	elseif localDay == (serverDay + 1)%7 then -- local is a day ahead
		localHour = localHour + 24
	end
	local server = serverHour + serverMinute / 60
	local localT = localHour + localMinute / 60
	local offset = floor((server - localT) * 2 + 0.5) / 2
	return offset
end

function AltManager:GetRegion()
	if not self.region then
		local reg
		reg = GetCVar("portal")
		if reg == "public-test" then -- PTR uses US region resets, despite the misleading realm name suffix
			reg = "US"
		end
		if not reg or #reg ~= 2 then
			local gcr = GetCurrentRegion()
			reg = gcr and ({ "US", "KR", "EU", "TW", "CN" })[gcr]
		end
		if not reg or #reg ~= 2 then
			reg = (GetCVar("realmList") or ""):match("^(%a+)%.")
		end
		if not reg or #reg ~= 2 then -- other test realms?
			reg = (GetRealmName() or ""):match("%((%a%a)%)")
		end
		reg = reg and reg:upper()
		if reg and #reg == 2 then
			self.region = reg
		end
	end
	return self.region
end

function AltManager:GetWoWDate()
	local hour = tonumber(tonumber(date("%H")));
	local day = tonumber(C_Calendar.GetDate()["weekday"]);
	return day, hour;
end

function AltManager:TimeString(length)
	if length == 0 then
		return "Now";
	end
	if length < 3600 then
		return string.format("%d mins", length / 60);
	end
	if length < 86400 then
		return string.format("%d hrs %d mins", length / 3600, (length % 3600) / 60);
	end
	return string.format("%d days %d hrs", length / 86400, (length % 86400) / 3600);
end
