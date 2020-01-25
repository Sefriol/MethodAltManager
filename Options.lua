--[[
	DISCLAIMER
	Huge credit for this options menu goes to Stanzilla and Semlar, creators of AdvancedInterfaceOptions.
	These helperfunctions which create the options menu are straight by-products from their addon.
	https://www.curseforge.com/wow/addons/advancedinterfaceoptions
	https://github.com/Stanzilla/AdvancedInterfaceOptions
]]

local addonName, addon = ...

local function normalize(str)
	str = str and gsub(str, '|c........', '') or ''
	return str:gsub('(%d+)', function(d)
		local lenf = strlen(d)
		return lenf < 10 and (strsub('0000000000', lenf + 1) .. d) or d -- or ''
		--return (d + 0) < 2147483648 and string.format('%010d', d) or d -- possible integer overflow
	end):gsub('%W', ''):lower()
end
local function scrollscripts(scroll, scripts)
	for k,v in pairs(scripts) do
		scroll.scripts[k] = v
	end
	for line = 1, scroll.slots do
		for k,v in pairs(scroll.scripts) do
			scroll.slot[line]:SetScript(k,v)
		end
	end
end
local function sortItems(scroll, col)
	-- todo: Keep items sorted when :Update() is called
	-- todo: Show a direction icon on the sorted column
	-- Force it in one direction if we're sorting a different column than was previously sorted
	if not col then
		if scroll.sortCol then
			col = scroll.sortCol
			if scroll.sortUp then
				table.sort(scroll.items, function(a, b)
					local x, y = normalize(a[col]), normalize(b[col])
					if x ~= y then
						return x < y
					else
						return a[1] < b[1]
					end
				end)
			else
				table.sort(scroll.items, function(a, b)
					local x, y = normalize(a[col]), normalize(b[col])
					if x ~= y then
						return x > y
					else
						return a[1] > b[1]
					end
				end)
			end
		end
	else
		if col ~= scroll.sortCol then
			scroll.sortUp = nil
			scroll.sortCol = col
		end
		if scroll.sortUp then
			table.sort(scroll.items, function(a, b)
				local x, y = normalize(a[col]), normalize(b[col])
				if x ~= y then
					return x > y
				else
					return normalize(a[1]) > normalize(b[1])
				end
			end)
			scroll.sortUp = false
		else
			table.sort(scroll.items, function(a, b)
				local x, y = normalize(a[col]), normalize(b[col])
				if x ~= y then
					return x < y
				else
					return normalize(a[1]) < normalize(b[1])
				end
			end)
			scroll.sortUp = true
		end
	end
	scroll:Update()
end

local function setscrolllist(scroll, items)
	scroll.items = items
	scroll.itemcount = #items
	scroll.stepValue = min(ceil(scroll.slots / 2), max(floor(scroll.itemcount / scroll.slots), 1))
	scroll.maxValue = max(scroll.itemcount - scroll.slots, 0)
	--scroll.value = scroll.minValue
	scroll.value = scroll.value <= scroll.maxValue and scroll.value or scroll.maxValue
	scroll.scrollbar:SetMinMaxValues(0, scroll.maxValue)
	scroll.scrollbar:SetValue(scroll.value)
	scroll.scrollbar:SetValueStep(scroll.stepValue)

	--sortItems(scroll)

	scroll:Update()
end
-- Scroll frame
local function updatescroll(scroll)
	for line = 1, scroll.slots do
		local lineoffset = line + scroll.value
		if lineoffset <= scroll.itemcount then
			-- If we're mousing over a row when its contents change
			-- call its OnLeave/OnEnter scripts if they exist
			local mousedOver = scroll.slot[line]:IsMouseOver()
			if mousedOver then
				local OnLeave = scroll.slot[line]:GetScript('OnLeave')
				if OnLeave then
					OnLeave(scroll.slot[line])
				end
			end

			scroll.slot[line].value = scroll.items[lineoffset][1]
			scroll.slot[line].offset = lineoffset
			--local text = scroll.items[lineoffset][2]
			--if(scroll.slot[line].value == scroll.selected) then
				--text = "|cffff0000"..text.."|r"
			--end
			--scroll.slot[line].text:SetText(text)
			for i, col in ipairs(scroll.slot[line].cols) do
				col.item = scroll.items[lineoffset][i+1]
				col:SetText(scroll.items[lineoffset][i+1])
				col.id = i
			end

			if mousedOver then
				local OnEnter = scroll.slot[line]:GetScript('OnEnter')
				if OnEnter then
					OnEnter(scroll.slot[line])
				end
			end
			--scroll.slot[line].cols[2]:SetText(text)
			scroll.slot[line]:Show()
		else
			--scroll.slot[line].cols[2]:SetText("")
			scroll.slot[line].value = nil
			scroll.slot[line]:Hide()
		end
	end

	--scroll.scrollbar:SetValue(scroll.value)
end
function CreateString(parent, text, width, justify)
	local str = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmallLeft')
	str:SetText(text)
	str:SetWordWrap(false) -- hacky bit to truncate string without elipsis
	str:SetNonSpaceWrap(true)
	str:SetHeight(10)
	str:SetMaxLines(2)
	if width then str:SetWidth(width) end
	if justify then str:SetJustifyH(justify) end
	return str
end

local function CreateListFrame(parent, w, h, cols)
	-- Contents of the list frame should be completely contained within the outer frame
	local frame = CreateFrame('Frame', nil, parent, 'InsetFrameTemplate')

	local inset = CreateFrame('Frame', nil, frame, 'InsetFrameTemplate')


	frame:SetSize(w, h)
	frame:SetFrameLevel(1)

	frame.scripts = {
		--["OnMouseDown"] = function(self) print(self.text:GetText()) end
	}
	frame.selected = nil
	frame.items = {}
	frame.itemcount = 0
	frame.minValue = 0
	frame.itemheight = 15 -- todo: base this on font size
	frame.slots = floor((frame:GetHeight()-10)/frame.itemheight)
	frame.slot = {}
	frame.stepValue = min(frame.slots, max(floor(frame.itemcount / frame.slots), 1))
	frame.maxValue = max(frame.itemcount - frame.slots, 0)
	frame.value = frame.minValue

	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", scroll)

	frame.Update = updatescroll
	frame.SetItems = setscrolllist
	frame.SortBy = sortItems
	frame.SetScripts = scrollscripts

	-- scrollbar
	local scrollUpBg = frame:CreateTexture(nil, nil, 1)
	scrollUpBg:SetTexture([[Interface\ClassTrainerFrame\UI-ClassTrainer-ScrollBar]])
	scrollUpBg:SetPoint('TOPRIGHT', 0, -2)--TOPLEFT', scrollbar, 'TOPRIGHT', -3, 2)
	scrollUpBg:SetTexCoord(0, 0.46875, 0.0234375, 0.9609375)
	scrollUpBg:SetSize(30, 120)


	local scrollDownBg = frame:CreateTexture(nil, nil, 1)
	scrollDownBg:SetTexture([[Interface\ClassTrainerFrame\UI-ClassTrainer-ScrollBar]])
	scrollDownBg:SetPoint('BOTTOMRIGHT', 0, 1)
	scrollDownBg:SetTexCoord(0.53125, 1, 0.03125, 1)
	scrollDownBg:SetSize(30, 123)
	--scrollDownBg:SetAlpha(0)


	local scrollMidBg = frame:CreateTexture(nil, nil, 2) -- fill in the middle gap, a bit hacky
	scrollMidBg:SetTexture([[Interface\PaperDollInfoFrame\UI-Character-ScrollBar]], false, true)
	--scrollMidBg:SetPoint('RIGHT', -1, 0)
	scrollMidBg:SetTexCoord(0, 0.44, 0.75, 0.98)
	--scrollMidBg:SetSize(28, 80)
	--scrollMidBg:SetWidth(28)
	scrollMidBg:SetPoint('TOPLEFT', scrollUpBg, 'BOTTOMLEFT', 1, 2)
	scrollMidBg:SetPoint('BOTTOMRIGHT', scrollDownBg, 'TOPRIGHT', -1, -2)




	local scrollbar = CreateFrame('Slider', nil, frame, 'UIPanelScrollBarTemplate')
	--scrollbar:SetPoint('TOPLEFT', frame, 'TOPRIGHT', 4, -16)
	--scrollbar:SetPoint('BOTTOMLEFT', frame, 'BOTTOMRIGHT', 4, 16)
	scrollbar:SetPoint('TOP', scrollUpBg, 2, -18)
	scrollbar:SetPoint('BOTTOM', scrollDownBg, 2, 18)
	scrollbar.ScrollUpButton:SetScript('OnClick', function() scroll(frame, 1) end)
	scrollbar.ScrollDownButton:SetScript('OnClick', function() scroll(frame, -1) end)
	scrollbar:SetScript('OnValueChanged', function(self, value)
		frame.value = floor(value)
		frame:Update()
		if frame.value == frame.minValue then self.ScrollUpButton:Disable()
		else self.ScrollUpButton:Enable() end
		if frame.value >= frame.maxValue then self.ScrollDownButton:Disable()
		else self.ScrollDownButton:Enable() end
	end)
	frame.scrollbar = scrollbar

	local padding = 4
	-- columns
	frame.cols = {}
	local offset = 0
	for i, colTbl in ipairs(cols) do
		local name, width, justify = colTbl[1], colTbl[2], colTbl[3]
		local col = CreateFrame('Button', nil, frame)
		col:SetNormalFontObject('GameFontHighlightSmallLeft')
		col:SetHighlightFontObject('GameFontNormalSmallLeft')
		col:SetPoint('BOTTOMLEFT', frame, 'TOPLEFT', 8 + offset, 0)
		col:SetSize(width, 18)
		col:SetText(name)
		col:GetFontString():SetAllPoints()
		if justify then
			col:GetFontString():SetJustifyH(justify)
			col.justify = justify
		end
		col.offset = offset
		col.width = width
		offset = offset + width + padding
		frame.cols[i] = col

		col:SetScript('OnClick', function(self)
			frame:SortBy(i+1)
		end)
	end


	-- rows
	for slot = 1, frame.slots do
		local f = CreateFrame("frame", nil, frame)
		f.cols = {}

		local bg = f:CreateTexture()
		bg:SetAllPoints()
		bg:SetColorTexture(1,1,1,0.1)
		bg:Hide()
		f.bg = bg

		f:EnableMouse(true)
		f:SetWidth(frame:GetWidth() - 38)
		f:SetHeight(frame.itemheight)

		for i, col in ipairs(frame.cols) do
			local str = CreateString(f, 'x')
			str:SetPoint('LEFT', col.offset, 0)
			str:SetWidth(col.width)
			if col.justify then
				str:SetJustifyH(col.justify)
			end
			f.cols[i] = str
		end

		--[[
		local str = addon:CreateString(f, "Scroll_Slot_"..slot)
		str:SetAllPoints(f)
		str:SetWordWrap(false)
		str:SetNonSpaceWrap(false)
		--str:SetWidth(frame:GetWidth() - 50)
		--]]

		frame.slot[slot] = f
		if(slot > 1) then
			f:SetPoint("TOPLEFT", frame.slot[slot-1], "BOTTOMLEFT")
		else
			f:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
		end
		--f.text = str
	end


	frame:Update()
	return frame
end

local CurrencyVarTable = {}

local MainOptionsPage = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
MainOptionsPage:Hide()
MainOptionsPage:SetAllPoints()
MainOptionsPage.name = addonName
InterfaceOptions_AddCategory(MainOptionsPage, addonName)



addon.MAMO_CURR = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
local CurrencyListFrame = CreateListFrame(addon.MAMO_CURR, 615, 465, {{'Id', 50}, {'Name', 260, 'LEFT'}, {'Count', 100, 'RIGHT'},{'Order', 50, 'RIGHT'}})
--ListFrame:SetPoint('TOP', FilterBox, 'BOTTOM', 0, -20)
CurrencyListFrame:SetPoint('BOTTOMLEFT', 4, 6)
CurrencyListFrame:SetItems(CurrencyVarTable)

CurrencyListFrame.Bg:SetAlpha(0.8)

--FilterBox:SetMaxLetters(100)
addon.MAMO_CURR:Hide()
addon.MAMO_CURR:SetAllPoints()
addon.MAMO_CURR.name = 'Currencies'
addon.MAMO_CURR.parent = addonName
local CurrencyTitle = addon.MAMO_CURR:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
CurrencyTitle:SetJustifyV('TOP')
CurrencyTitle:SetJustifyH('LEFT')
CurrencyTitle:SetPoint('TOPLEFT', 16, -16)
CurrencyTitle:SetText(addon.MAMO_CURR.name)

local CurrencySubText = addon.MAMO_CURR:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
CurrencySubText:SetMaxLines(3)
CurrencySubText:SetNonSpaceWrap(true)
CurrencySubText:SetJustifyV('TOP')
CurrencySubText:SetJustifyH('LEFT')
CurrencySubText:SetPoint('TOPLEFT', CurrencyTitle, 'BOTTOMLEFT', 0, -8)
CurrencySubText:SetPoint('RIGHT', -32, 0)
CurrencySubText:SetText('This Page allows you to setup trackable items and currencies.')
InterfaceOptions_AddCategory(addon.MAMO_CURR, addonName)




function RefreshCurrencyList()
    wipe(CurrencyVarTable)
	local options = MethodAltManagerDB.options
    for cid, cobj in pairs(addon.CurrencyTable) do  
        if(options and options.currencies and options.currencies[cid])then
            order =  options.currencies[cid]["order"]
        else 
            order = math.huge
        end
        tinsert(CurrencyVarTable, {cid, cid, cobj.label, cobj.count, order})
    end
end

function addon:MAMO_CURR_INIT()
    local options = MethodAltManagerDB.options
    RefreshCurrencyList()
	CurrencyListFrame:SetItems(CurrencyVarTable)
	CurrencyListFrame:SortBy(5)
	--FilterCurrencyList() -- Maybe in the future

	-- We don't really want the user to be able to do anything else while the input box is open
	-- I'd rather make this a child of the input box, but I can't get it to show up above its child
	-- todo: show default value around the input box somewhere while it's active
	local CurrencyInputBoxMouseBlocker = CreateFrame('frame', nil, CurrencyListFrame)
	CurrencyInputBoxMouseBlocker:SetFrameStrata('FULLSCREEN_DIALOG')
	CurrencyInputBoxMouseBlocker:Hide()

	local CurrencyInputBox = CreateFrame('editbox', nil, CurrencyInputBoxMouseBlocker, 'InputBoxTemplate')
	-- block clicking and cancel on any clicks outside the edit box
	CurrencyInputBoxMouseBlocker:EnableMouse(true)
	CurrencyInputBoxMouseBlocker:SetScript('OnMouseDown', function(self) CurrencyInputBox:ClearFocus() end)
	-- block scrolling
	CurrencyInputBoxMouseBlocker:EnableMouseWheel(true)
	CurrencyInputBoxMouseBlocker:SetScript('OnMouseWheel', function() end)
	CurrencyInputBoxMouseBlocker:SetAllPoints(nil)

	local blackout = CurrencyInputBoxMouseBlocker:CreateTexture(nil, 'BACKGROUND')
	blackout:SetAllPoints()
	blackout:SetColorTexture(0,0,0,0.2)

	CurrencyInputBox:Hide()
	CurrencyInputBox:SetSize(100, 20)
    CurrencyInputBox:SetJustifyH('RIGHT')
    CurrencyInputBox:SetNumeric()
	CurrencyInputBox:SetTextInsets(5, 10, 0, 0)
	CurrencyInputBox:SetScript('OnEscapePressed', function(self)
		self:ClearFocus()
		self:Hide()
	end)

	CurrencyInputBox:SetScript('OnEnterPressed', function(self)
        -- todo: I don't like this, change it
		if self:GetNumber() == 0 then 
			options.currencies[self.cvar] = nil
			self:ClearFocus()
		else
			local currency = {
				["label"] = addon.CurrencyTable[self.cvar].label,
				["order"] = self:GetNumber()
			}
			options.currencies[self.cvar] = currency
			currency = {}
		end
		addon:StoreOptions(options)
		options = MethodAltManagerDB.options
		
		self:Hide()
		RefreshCurrencyList()
		CurrencyListFrame:SetItems(CurrencyVarTable)
		CurrencyListFrame:SortBy(5)
		CurrencyListFrame:SortBy(5)
	end)
	CurrencyInputBox:SetScript('OnShow', function(self)
		self:SetFocus()
	end)
	CurrencyInputBox:SetScript('OnHide', function(self)
		CurrencyInputBoxMouseBlocker:Hide()
		if self.str then
			self.str:Show()
		end
	end)
	CurrencyInputBox:SetScript('OnEditFocusLost', function(self)
		self:Hide()
		-- FilterBox:SetFocus()
	end)


	local LastClickTime = 0 -- Track double clicks on rows
	CurrencyListFrame:SetScripts({
		OnEnter = function(self)
			if self.value ~= '' then
				GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
				local CurrencyTable = addon.CurrencyTable[self.value]
				GameTooltip:AddLine("CurrencyID: " ..tostring(self.value), nil, nil, nil, false)
 				if CurrencyTable['label'] then
					GameTooltip:AddLine(CurrencyTable['label'], 1, 1, 1, true)
				end 
				GameTooltip:AddLine("1. Double click to assign the order within AltManager Screen", 0.2, 1, 0.6, 0.2, 1, 0.6)
				GameTooltip:AddLine("2. Save on enter, discard on escape or losing focus. Saving Empty will remove order", 0.2, 1, 0.6, 0.2, 1, 0.6)
				GameTooltip:Show()
			end
			self.bg:Show()
		end,
		OnLeave = function(self)
			GameTooltip:Hide()
			self.bg:Hide()
		end,
		OnMouseDown = function(self)
			local now = GetTime()
			if now - LastClickTime <= 0.2 then
				if CurrencyInputBox.str then
					CurrencyInputBox.str:Show()
				end
				self.cols[#self.cols]:Hide()
                CurrencyInputBox.str = self.cols[#self.cols]
				CurrencyInputBox.cvar = self.value
				CurrencyInputBox.row = self
				CurrencyInputBox:SetPoint('RIGHT', self)
				local value = ''
				if options.currencies[self.value] and options.currencies[self.value]['order'] then
					value = options.currencies[self.value]['order']
				end
				CurrencyInputBox:SetText(value)
				CurrencyInputBox:HighlightText()
				CurrencyInputBoxMouseBlocker:Show()
				CurrencyInputBox:Show()
				CurrencyInputBox:SetFocus()
			else
				LastClickTime = now
			end
		end,
	})
end
local ItemsVarTable = {}

addon.MAMO_ITEMS = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
local ItemListFrame = CreateListFrame(addon.MAMO_ITEMS, 615, 465, {{'Id', 50}, {'Name', 260, 'LEFT'},{'Order', 50, 'RIGHT'}})
ItemListFrame:SetPoint('BOTTOMLEFT', 4, 6)
ItemListFrame:SetItems(ItemsVarTable)

ItemListFrame.Bg:SetAlpha(0.8)

local function OptionStoreItem(item)
	local options = MethodAltManagerDB.options
	options.items = options.items or {}
	if options.items[item.ID] then
		options.items[item.ID] = nil
	else
		options.items[item.ID] = item
	end
	addon:StoreOptions(options)
	options = MethodAltManagerDB.options
	
	RefreshItemList()
	ItemListFrame:SetItems(ItemsVarTable)
	ItemListFrame:SortBy(5)
	ItemListFrame:SortBy(5)
end

--FilterBox:SetMaxLetters(100)
addon.MAMO_ITEMS:Hide()
addon.MAMO_ITEMS:SetAllPoints()
addon.MAMO_ITEMS.name = 'Items'
addon.MAMO_ITEMS.parent = addonName
local ItemsTitle = addon.MAMO_ITEMS:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
ItemsTitle:SetJustifyV('TOP')
ItemsTitle:SetJustifyH('LEFT')
ItemsTitle:SetPoint('TOPLEFT', 16, -16)
ItemsTitle:SetText(addon.MAMO_ITEMS.name)

local ItemsSubText = addon.MAMO_ITEMS:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
ItemsSubText:SetMaxLines(3)
ItemsSubText:SetNonSpaceWrap(true)
ItemsSubText:SetJustifyV('TOP')
ItemsSubText:SetJustifyH('LEFT')
ItemsSubText:SetPoint('TOPLEFT', ItemsTitle, 'BOTTOMLEFT', 0, -8)
ItemsSubText:SetPoint('RIGHT', -32, 0)
ItemsSubText:SetText('This Page allows you to setup trackable items. Currently Addon only scans your inventory')

local InputBox = CreateFrame('editbox', nil, addon.MAMO_ITEMS, 'InputBoxTemplate')
InputBox:SetPoint('TOPLEFT', ItemsSubText, 'BOTTOMLEFT', 0, -5)
InputBox:SetPoint('RIGHT', addon.MAMO_ITEMS, 'RIGHT', -10, 0)
InputBox:SetHeight(20)
InputBox:SetNumeric(true)
InputBox:SetAutoFocus(false)
InputBox:ClearFocus()
InputBox:SetScript('OnEnter', function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	GameTooltip:AddLine("Instructions:", nil, nil, nil, false)
	GameTooltip:AddLine("1. Write itemID into the box (i.e. a number)", 0.2, 1, 0.6, 0.2, 1, 0.6)
	GameTooltip:AddLine("2. Save on enter, discard on escape or losing focus. Adding a same ID will remove the item from storage", 0.2, 1, 0.6, 0.2, 1, 0.6)
	GameTooltip:Show()
end)
InputBox:SetScript('OnEscapePressed', function(self)
	self:SetAutoFocus(false) -- Allow focus to clear when escape is pressed
	self:ClearFocus()
end)
InputBox:SetScript('OnEnterPressed', function(self)
	if self:GetNumber() == 0 then 
		options.currencies[self.cvar] = nil
		self:ClearFocus()
	else
		local item = nil
		itemID = self:GetNumber()
		itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount = GetItemInfo(itemID)
		if itemName then
			item =  {
				["ID"] = itemID,
				["label"] = itemName,
				["Link"] = itemLink,
				["Rarity"] = itemRarity,
				["Level"] = itemLevel,
				["MinLevel"] = itemMinLevel,
				["Type"] = itemType,
				["SubType"] = itemSubType,
				["order"] = math.huge,
				["StackCount"] = itemStackCount
			}
			OptionStoreItem(item)
		end
	end
	self:SetAutoFocus(false) -- Clear focus when enter is pressed because ketho said so
	self:ClearFocus()
end)
InputBox:SetScript('OnEditFocusGained', function(self)
	self:SetAutoFocus(true)
	self:HighlightText()
end)

InterfaceOptions_AddCategory(addon.MAMO_ITEMS, addonName)



function RefreshItemList(item)
	wipe(ItemsVarTable)
	local options = MethodAltManagerDB.options
	if(options and options.items) then
		for cid, cobj in pairs(MethodAltManagerDB.options.items) do  
			tinsert(ItemsVarTable, {cid, cid, cobj.Link, cobj.order or math.huge})
		end
	end
end

function addon:MAMO_ITEMS_INIT()
    local options = MethodAltManagerDB.options
    RefreshItemList()
	ItemListFrame:SetItems(ItemsVarTable)
	ItemListFrame:SortBy(5)
	--FilterCurrencyList() -- Maybe in the future

	-- We don't really want the user to be able to do anything else while the input box is open
	-- I'd rather make this a child of the input box, but I can't get it to show up above its child
	-- todo: show default value around the input box somewhere while it's active
	local ItemInputBoxMouseBlocker = CreateFrame('frame', nil, ItemListFrame)
	ItemInputBoxMouseBlocker:SetFrameStrata('FULLSCREEN_DIALOG')
	ItemInputBoxMouseBlocker:Hide()

	local ItemInputBox = CreateFrame('editbox', nil, ItemInputBoxMouseBlocker, 'InputBoxTemplate')
	-- block clicking and cancel on any clicks outside the edit box
	ItemInputBoxMouseBlocker:EnableMouse(true)
	ItemInputBoxMouseBlocker:SetScript('OnMouseDown', function(self) ItemInputBox:ClearFocus() end)
	-- block scrolling
	ItemInputBoxMouseBlocker:EnableMouseWheel(true)
	ItemInputBoxMouseBlocker:SetScript('OnMouseWheel', function() end)
	ItemInputBoxMouseBlocker:SetAllPoints(nil)

	local blackout = ItemInputBoxMouseBlocker:CreateTexture(nil, 'BACKGROUND')
	blackout:SetAllPoints()
	blackout:SetColorTexture(0,0,0,0.2)

	ItemInputBox:Hide()
	ItemInputBox:SetSize(100, 20)
    ItemInputBox:SetJustifyH('RIGHT')
    ItemInputBox:SetNumeric()
	ItemInputBox:SetTextInsets(5, 10, 0, 0)
	ItemInputBox:SetScript('OnEscapePressed', function(self)
		self:ClearFocus()
		self:Hide()
	end)

	ItemInputBox:SetScript('OnEnterPressed', function(self)
        -- todo: I don't like this, change it
		if self:GetNumber() == 0 then 
			options.items[self.cvar].order = math.huge
			self:ClearFocus()
		else
			options.items[self.cvar].order = self:GetNumber()
		end
		addon:StoreOptions(options)
		options = MethodAltManagerDB.options
		
		self:Hide()
		RefreshItemList()
		ItemListFrame:SetItems(ItemsVarTable)
		ItemListFrame:SortBy(3)
		ItemListFrame:SortBy(3)
		addon:DynamicUIReload()
	end)
	ItemInputBox:SetScript('OnShow', function(self)
		self:SetFocus()
	end)
	ItemInputBox:SetScript('OnHide', function(self)
		ItemInputBoxMouseBlocker:Hide()
		if self.str then
			self.str:Show()
		end
	end)
	ItemInputBox:SetScript('OnEditFocusLost', function(self)
		self:Hide()
		-- FilterBox:SetFocus()
	end)


	local LastClickTime = 0 -- Track double clicks on rows
	ItemListFrame:SetScripts({
		OnEnter = function(self)
			if self.value ~= '' then
				 GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
				local ItemTable = MethodAltManagerDB.options.items[self.value]
				GameTooltip:AddLine("ItemID: " ..tostring(self.value), nil, nil, nil, false)
 				if ItemTable['Name'] then
					GameTooltip:AddLine(ItemTable['Name'], 1, 1, 1, true)
				end 
				GameTooltip:AddLine("1. Double click to assign the order within AltManager Screen", 0.2, 1, 0.6, 0.2, 1, 0.6)
				GameTooltip:AddLine("2. Save on enter, discard on escape or losing focus. Saving Empty will remove order, but keep storage", 0.2, 1, 0.6, 0.2, 1, 0.6)
 	 			GameTooltip:Show()
			end
			self.bg:Show()
		end,
		OnLeave = function(self)
			GameTooltip:Hide()
			self.bg:Hide()
		end,
		OnMouseDown = function(self)
			local now = GetTime()
			if now - LastClickTime <= 0.2 then
				if ItemInputBox.str then
					ItemInputBox.str:Show()
				end
				self.cols[#self.cols]:Hide()
                ItemInputBox.str = self.cols[#self.cols]
				ItemInputBox.cvar = self.value
				ItemInputBox.row = self
				ItemInputBox:SetPoint('RIGHT', self)
				local value = options.items[self.value]['order']
				ItemInputBox:SetText(value or '')
				ItemInputBox:HighlightText()
				ItemInputBoxMouseBlocker:Show()
				ItemInputBox:Show()
				ItemInputBox:SetFocus()
			else
				LastClickTime = now
			end
		end,
	})
end