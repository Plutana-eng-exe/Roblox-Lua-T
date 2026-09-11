-- AirHub V2 UI Library (native ScreenGui rewrite)
-- Replaces the broken Drawing-based renderer with real Roblox Instances.
-- Public API is identical to the original so main.lua needs zero changes.

local library = {}
library.flags  = {}
library.connections = {}
library.open   = false

-- ── services ──────────────────────────────────────────────────────────────────
local Players        = game:GetService("Players")
local UIS            = game:GetService("UserInputService")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local HttpService    = game:GetService("HttpService")
local LocalPlayer    = Players.LocalPlayer

-- ── helpers ───────────────────────────────────────────────────────────────────
local function make(class, props, parent)
	local obj = Instance.new(class)
	if parent then obj.Parent = parent end
	for k,v in pairs(props or {}) do obj[k] = v end
	return obj
end

local function makePadding(parent, t,b,l,r)
	make("UIPadding", {PaddingTop=UDim.new(0,t or 0), PaddingBottom=UDim.new(0,b or 0),
		PaddingLeft=UDim.new(0,l or 0), PaddingRight=UDim.new(0,r or 0)}, parent)
end

local function makeCorner(parent, r)
	make("UICorner", {CornerRadius=UDim.new(0, r or 4)}, parent)
end

local function makeStroke(parent, color, thickness, transparency)
	make("UIStroke", {Color=color or Color3.fromRGB(60,50,60),
		Thickness=thickness or 1, Transparency=transparency or 0}, parent)
end

local function makeList(parent, padding, fillDir)
	make("UIListLayout", {
		Padding          = UDim.new(0, padding or 4),
		FillDirection    = fillDir or Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment   = Enum.VerticalAlignment.Top,
		SortOrder        = Enum.SortOrder.LayoutOrder,
	}, parent)
end

-- colour palette
local C = {
	bg       = Color3.fromRGB(22, 18, 24),
	surface  = Color3.fromRGB(30, 24, 32),
	panel    = Color3.fromRGB(36, 28, 38),
	item     = Color3.fromRGB(44, 34, 46),
	border   = Color3.fromRGB(70, 50, 72),
	accent   = Color3.fromRGB(150, 100, 160),
	text     = Color3.fromRGB(210, 190, 215),
	textdim  = Color3.fromRGB(130, 110, 135),
	white    = Color3.fromRGB(255,255,255),
	black    = Color3.fromRGB(0,0,0),
	red      = Color3.fromRGB(200,70,70),
	green    = Color3.fromRGB(70,200,120),
	slider   = Color3.fromRGB(120,80,130),
}

-- ── dragging ──────────────────────────────────────────────────────────────────
local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging, dragInput, startPos, startFrame
	handle.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			startPos  = inp.Position
			startFrame = frame.Position
		end
	end)
	handle.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = inp.Position - startPos
			frame.Position = UDim2.new(
				startFrame.X.Scale, startFrame.X.Offset + delta.X,
				startFrame.Y.Scale, startFrame.Y.Offset + delta.Y)
		end
	end)
end

-- ── scrolling canvas ─────────────────────────────────────────────────────────
local function makeScrollFrame(parent, bgColor)
	local scroll = make("ScrollingFrame", {
		Size                  = UDim2.new(1,0,1,0),
		BackgroundTransparency= 1,
		BorderSizePixel       = 0,
		ScrollBarThickness    = 3,
		ScrollBarImageColor3  = C.accent,
		CanvasSize            = UDim2.new(0,0,0,0),
		AutomaticCanvasSize   = Enum.AutomaticSize.Y,
		ClipsDescendants      = true,
	}, parent)
	makeList(scroll, 5)
	makePadding(scroll, 4,4,4,4)
	return scroll
end

-- ── root GUI ─────────────────────────────────────────────────────────────────
local screenGui
local function getGui()
	if screenGui and screenGui.Parent then return screenGui end
	local ok, hui = pcall(function() return gethui() end)
	local container = (ok and hui) or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")) or game:GetService("CoreGui")
	screenGui = make("ScreenGui", {
		Name              = "AirHubV2",
		ResetOnSpawn      = false,
		IgnoreGuiInset    = true,
		ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
		DisplayOrder      = 99,
	}, container)
	return screenGui
end

-- ── config stubs (keeps SaveConfig / LoadConfig from erroring) ────────────────
function library:SaveConfig()   end
function library:LoadConfig()   end
function library:DeleteConfig() end
function library:GetConfigs()   return {} end
function library:ConfigIgnore() end

-- ── Unload ────────────────────────────────────────────────────────────────────
function library:Unload()
	if screenGui then screenGui:Destroy() end
	for _,c in ipairs(self.connections) do pcall(function() c:Disconnect() end) end
	table.clear(self.connections)
	table.clear(self.flags)
end

-- ── Close (toggle) ────────────────────────────────────────────────────────────
function library:Close()
	self.open = not self.open
	if screenGui then screenGui.Enabled = self.open end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- library:Load()  — builds and returns the window object
-- ══════════════════════════════════════════════════════════════════════════════
function library:Load(options)
	options = options or {}
	local W = options.sizex or 860
	local H = options.sizey or 520

	local gui = getGui()
	gui.Enabled = false   -- closed until keybind opens it

	-- ── outer window ─────────────────────────────────────────────────────────
	local win = make("Frame", {
		Name             = "Window",
		Size             = UDim2.new(0, W, 0, H),
		Position         = UDim2.new(0.5, -W/2, 0.5, -H/2),
		BackgroundColor3 = C.bg,
		BorderSizePixel  = 0,
		ClipsDescendants = true,
	}, gui)
	makeCorner(win, 6)
	makeStroke(win, C.border, 1.5)

	-- title bar
	local titleBar = make("Frame", {
		Name             = "TitleBar",
		Size             = UDim2.new(1,0,0,32),
		BackgroundColor3 = C.surface,
		BorderSizePixel  = 0,
	}, win)
	makeCorner(titleBar, 6)
	-- cover bottom corners of title bar
	make("Frame",{Size=UDim2.new(1,0,0,8),Position=UDim2.new(0,0,1,-8),
		BackgroundColor3=C.surface,BorderSizePixel=0},titleBar)

	make("TextLabel", {
		Text             = "✦ AirHub V2",
		Size             = UDim2.new(1,-80,1,0),
		Position         = UDim2.new(0,10,0,0),
		BackgroundTransparency = 1,
		TextColor3       = C.text,
		TextXAlignment   = Enum.TextXAlignment.Left,
		Font             = Enum.Font.GothamBold,
		TextSize         = 14,
	}, titleBar)

	-- close button
	local closeBtn = make("TextButton", {
		Text             = "✕",
		Size             = UDim2.new(0,28,0,22),
		Position         = UDim2.new(1,-34,0,5),
		BackgroundColor3 = Color3.fromRGB(160,50,60),
		TextColor3       = C.white,
		Font             = Enum.Font.GothamBold,
		TextSize         = 13,
		BorderSizePixel  = 0,
	}, titleBar)
	makeCorner(closeBtn, 4)
	closeBtn.MouseButton1Click:Connect(function() library:Close() end)

	makeDraggable(win, titleBar)

	-- tab button strip
	local tabStrip = make("Frame", {
		Name             = "TabStrip",
		Size             = UDim2.new(1,0,0,28),
		Position         = UDim2.new(0,0,0,32),
		BackgroundColor3 = C.surface,
		BorderSizePixel  = 0,
	}, win)
	make("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),
		BackgroundColor3=C.border,BorderSizePixel=0},tabStrip)

	local tabBtnList = make("UIListLayout",{
		FillDirection       = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment   = Enum.VerticalAlignment.Center,
		Padding             = UDim.new(0,2),
		SortOrder           = Enum.SortOrder.LayoutOrder,
	}, tabStrip)
	makePadding(tabStrip, 0,0,6,6)

	-- content area
	local contentArea = make("Frame", {
		Name             = "Content",
		Size             = UDim2.new(1,0,1,-62),
		Position         = UDim2.new(0,0,0,62),
		BackgroundTransparency = 1,
		BorderSizePixel  = 0,
		ClipsDescendants = true,
	}, win)

	-- ── window object returned to main.lua ───────────────────────────────────
	local windowObj = {}
	local tabPages  = {}
	local tabBtns   = {}

	local function switchTab(idx)
		for i, page in ipairs(tabPages) do
			page.Visible = (i == idx)
		end
		for i, btn in ipairs(tabBtns) do
			btn.BackgroundColor3 = (i == idx) and C.accent or C.item
			btn.TextColor3       = (i == idx) and C.white  or C.textdim
		end
	end

	-- ── Tab() ─────────────────────────────────────────────────────────────────
	function windowObj:Tab(name)
		local tabIndex = #tabPages + 1

		-- button
		local btn = make("TextButton", {
			Text             = name,
			Size             = UDim2.new(0, math.max(70, #name*8+16), 0, 22),
			BackgroundColor3 = C.item,
			TextColor3       = C.textdim,
			Font             = Enum.Font.GothamSemibold,
			TextSize         = 12,
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
		}, tabStrip)
		makeCorner(btn, 3)
		table.insert(tabBtns, btn)

		-- page
		local page = make("Frame", {
			Size             = UDim2.new(1,0,1,0),
			BackgroundTransparency = 1,
			BorderSizePixel  = 0,
			Visible          = (tabIndex == 1),
		}, contentArea)

		-- two-column layout
		local colLeft = make("ScrollingFrame", {
			Size                  = UDim2.new(0.5,-6,1,-8),
			Position              = UDim2.new(0,4,0,4),
			BackgroundTransparency= 1,
			BorderSizePixel       = 0,
			ScrollBarThickness    = 3,
			ScrollBarImageColor3  = C.accent,
			CanvasSize            = UDim2.new(0,0,0,0),
			AutomaticCanvasSize   = Enum.AutomaticSize.Y,
			ClipsDescendants      = true,
		}, page)
		makeList(colLeft, 5)
		makePadding(colLeft, 2,2,2,2)

		local colRight = make("ScrollingFrame", {
			Size                  = UDim2.new(0.5,-6,1,-8),
			Position              = UDim2.new(0.5,2,0,4),
			BackgroundTransparency= 1,
			BorderSizePixel       = 0,
			ScrollBarThickness    = 3,
			ScrollBarImageColor3  = C.accent,
			CanvasSize            = UDim2.new(0,0,0,0),
			AutomaticCanvasSize   = Enum.AutomaticSize.Y,
			ClipsDescendants      = true,
		}, page)
		makeList(colRight, 5)
		makePadding(colRight, 2,2,2,2)

		table.insert(tabPages, page)

		btn.MouseButton1Click:Connect(function() switchTab(tabIndex) end)
		if tabIndex == 1 then switchTab(1) end

		-- ── Section() ─────────────────────────────────────────────────────────
		local tabObj = {}
		local firstTabSignal = {Fire = function() end}   -- stub for GeneralSignal

		function tabObj:Section(opts)
			opts = opts or {}
			local sname = opts.Name or opts.name or ""
			local side  = (opts.Side or opts.side or "Left"):lower()
			local col   = side == "right" and colRight or colLeft

			-- section frame
			local sec = make("Frame", {
				Size             = UDim2.new(1,-4,0,28),
				BackgroundColor3 = C.panel,
				BorderSizePixel  = 0,
				AutomaticSize    = Enum.AutomaticSize.Y,
				ClipsDescendants = false,
			}, col)
			makeCorner(sec, 5)
			makeStroke(sec, C.border, 1)

			-- header
			local hdr = make("Frame", {
				Size             = UDim2.new(1,0,0,22),
				BackgroundColor3 = C.surface,
				BorderSizePixel  = 0,
			}, sec)
			makeCorner(hdr, 5)
			make("Frame",{Size=UDim2.new(1,0,0,8),Position=UDim2.new(0,0,1,-8),
				BackgroundColor3=C.surface,BorderSizePixel=0},hdr)

			make("TextLabel", {
				Text             = sname,
				Size             = UDim2.new(1,-8,1,0),
				Position         = UDim2.new(0,8,0,0),
				BackgroundTransparency = 1,
				TextColor3       = C.accent,
				TextXAlignment   = Enum.TextXAlignment.Left,
				Font             = Enum.Font.GothamBold,
				TextSize         = 12,
			}, hdr)

			-- content list inside section
			local content = make("Frame", {
				Size             = UDim2.new(1,0,0,0),
				Position         = UDim2.new(0,0,0,22),
				BackgroundTransparency = 1,
				BorderSizePixel  = 0,
				AutomaticSize    = Enum.AutomaticSize.Y,
			}, sec)
			makeList(content, 3)
			makePadding(content, 2,4,4,4)

			-- ── helpers shared by all widgets ──────────────────────────────────
			local secObj = {}

			local function row(h)
				h = h or 22
				return make("Frame", {
					Size             = UDim2.new(1,0,0,h),
					BackgroundTransparency = 1,
					BorderSizePixel  = 0,
				}, content)
			end

			local function itemFrame(r)
				local f = make("Frame", {
					Size             = UDim2.new(1,0,1,0),
					BackgroundColor3 = C.item,
					BorderSizePixel  = 0,
				}, r)
				makeCorner(f,3)
				makePadding(f,0,0,6,6)
				return f
			end

			local function label(parent, txt, xalign, size)
				return make("TextLabel",{
					Text             = txt or "",
					Size             = UDim2.new(1,0,1,0),
					BackgroundTransparency=1,
					TextColor3       = C.text,
					TextXAlignment   = xalign or Enum.TextXAlignment.Left,
					Font             = Enum.Font.Gotham,
					TextSize         = size or 12,
					TextTruncate     = Enum.TextTruncate.AtEnd,
				}, parent)
			end

			-- ── Label ─────────────────────────────────────────────────────────
			function secObj:Label(txt)
				local r = row(18)
				local lbl = label(r, txt)
				lbl.TextColor3 = C.textdim
				lbl.Font = Enum.Font.Gotham
				return { Set = function(_, t) lbl.Text = t end }
			end

			-- ── Button ────────────────────────────────────────────────────────
			function secObj:Button(opts)
				opts = opts or {}
				local cb = opts.Callback or opts.callback or function() end
				local r  = row(24)
				local btn = make("TextButton",{
					Text             = opts.Name or opts.name or "",
					Size             = UDim2.new(1,0,1,0),
					BackgroundColor3 = C.item,
					TextColor3       = C.text,
					Font             = Enum.Font.GothamSemibold,
					TextSize         = 12,
					BorderSizePixel  = 0,
					AutoButtonColor  = false,
				}, r)
				makeCorner(btn,3)
				makeStroke(btn, C.border, 1)
				btn.MouseButton1Click:Connect(cb)
				btn.MouseEnter:Connect(function() btn.BackgroundColor3 = C.accent end)
				btn.MouseLeave:Connect(function() btn.BackgroundColor3 = C.item   end)
			end

			-- ── Toggle ────────────────────────────────────────────────────────
			function secObj:Toggle(opts)
				opts = opts or {}
				local flag = opts.Flag or opts.flag
				local cb   = opts.Callback or opts.callback or function() end
				local val  = opts.Default ~= nil and opts.Default or false
				if flag then library.flags[flag] = val end

				local r    = row(22)
				local f    = itemFrame(r)
				local lbl  = label(f, opts.Name or opts.name or "")
				lbl.Size   = UDim2.new(1,-36,1,0)

				local dot = make("Frame",{
					Size             = UDim2.new(0,28,0,14),
					Position         = UDim2.new(1,-30,0.5,-7),
					BackgroundColor3 = val and C.green or C.item,
					BorderSizePixel  = 0,
					AnchorPoint      = Vector2.new(0,0.5),
				}, r)
				makeCorner(dot, 7)
				makeStroke(dot, C.border, 1)

				local knob = make("Frame",{
					Size             = UDim2.new(0,10,0,10),
					Position         = val and UDim2.new(1,-12,0.5,-5) or UDim2.new(0,2,0.5,-5),
					BackgroundColor3 = C.white,
					BorderSizePixel  = 0,
				}, dot)
				makeCorner(knob, 5)

				local function setVal(v)
					val = v
					if flag then library.flags[flag] = v end
					dot.BackgroundColor3 = v and C.green or C.item
					knob.Position = v and UDim2.new(1,-12,0.5,-5) or UDim2.new(0,2,0.5,-5)
					pcall(cb, v)
				end

				f.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then setVal(not val) end
				end)

				return { Set = setVal }
			end

			-- ── Slider ────────────────────────────────────────────────────────
			function secObj:Slider(opts)
				opts = opts or {}
				local flag = opts.Flag or opts.flag
				local cb   = opts.Callback or opts.callback or function() end
				local min  = opts.Min or opts.min or 0
				local max  = opts.Max or opts.max or 100
				local val  = opts.Default ~= nil and opts.Default or min
				if flag then library.flags[flag] = val end

				local r   = row(32)
				local lbl = make("TextLabel",{
					Text             = (opts.Name or opts.name or "").."  "..tostring(val),
					Size             = UDim2.new(1,0,0,14),
					BackgroundTransparency=1,
					TextColor3       = C.text,
					TextXAlignment   = Enum.TextXAlignment.Left,
					Font             = Enum.Font.Gotham,
					TextSize         = 11,
				}, r)
				makePadding(lbl, 0,0,4,0)

				local track = make("Frame",{
					Size             = UDim2.new(1,-8,0,6),
					Position         = UDim2.new(0,4,0,18),
					BackgroundColor3 = C.surface,
					BorderSizePixel  = 0,
				}, r)
				makeCorner(track, 3)
				makeStroke(track, C.border, 1)

				local fill = make("Frame",{
					Size             = UDim2.new((val-min)/(max-min),0,1,0),
					BackgroundColor3 = C.slider,
					BorderSizePixel  = 0,
				}, track)
				makeCorner(fill, 3)

				local function setVal(v)
					v = math.clamp(math.floor(v + 0.5), min, max)
					val = v
					if flag then library.flags[flag] = v end
					fill.Size = UDim2.new((v-min)/(max-min),0,1,0)
					lbl.Text  = (opts.Name or opts.name or "").."  "..tostring(v)
					pcall(cb, v)
				end

				local dragging = false
				track.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = true
					end
				end)
				track.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
				end)
				UIS.InputChanged:Connect(function(inp)
					if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
						local abs = track.AbsolutePosition
						local sz  = track.AbsoluteSize
						local pct = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
						setVal(min + pct*(max-min))
					end
				end)

				return { Set = setVal }
			end

			-- ── Dropdown ──────────────────────────────────────────────────────
			function secObj:Dropdown(opts)
				opts = opts or {}
				local flag    = opts.Flag or opts.flag
				local cb      = opts.Callback or opts.callback or function() end
				local content_= opts.Content or opts.content or {}
				local defVal  = opts.Default or opts.default or (content_[1] or "")
				if flag then library.flags[flag] = defVal end

				local r = row(24)
				local lbl = make("TextLabel",{
					Text=opts.Name or opts.name or "",
					Size=UDim2.new(0.45,0,1,0),
					BackgroundTransparency=1,
					TextColor3=C.text, Font=Enum.Font.Gotham, TextSize=12,
					TextXAlignment=Enum.TextXAlignment.Left,
				}, r)
				makePadding(lbl,0,0,4,0)

				local display = make("TextButton",{
					Text             = tostring(defVal).." ▾",
					Size             = UDim2.new(0.55,-4,0,20),
					Position         = UDim2.new(0.45,2,0.5,-10),
					BackgroundColor3 = C.item,
					TextColor3       = C.text,
					Font             = Enum.Font.Gotham,
					TextSize         = 11,
					BorderSizePixel  = 0,
					AutoButtonColor  = false,
					ClipsDescendants = true,
				}, r)
				makeCorner(display,3)
				makeStroke(display, C.border, 1)

				-- dropdown list (hidden by default, parented to win so it overlaps)
				local list = make("Frame",{
					Size             = UDim2.new(0, display.AbsoluteSize.X, 0, 0),
					BackgroundColor3 = C.panel,
					BorderSizePixel  = 0,
					Visible          = false,
					ZIndex           = 20,
					ClipsDescendants = true,
				}, win)
				makeCorner(list,3)
				makeStroke(list, C.border, 1)

				local listLayout = make("UIListLayout",{
					Padding=UDim.new(0,1), FillDirection=Enum.FillDirection.Vertical,
					SortOrder=Enum.SortOrder.LayoutOrder,
				}, list)
				makePadding(list,2,2,2,2)

				local function close()
					list.Visible = false
					display.Text = tostring(library.flags[flag] or defVal).." ▾"
				end

				local function populate(tbl)
					for _,child in ipairs(list:GetChildren()) do
						if child:IsA("TextButton") then child:Destroy() end
					end
					for _, opt in ipairs(tbl) do
						local ob = make("TextButton",{
							Text=tostring(opt), Size=UDim2.new(1,0,0,20),
							BackgroundColor3=C.item, TextColor3=C.text,
							Font=Enum.Font.Gotham, TextSize=11,
							BorderSizePixel=0, AutoButtonColor=false, ZIndex=21,
						}, list)
						makeCorner(ob,2)
						ob.MouseEnter:Connect(function() ob.BackgroundColor3=C.accent end)
						ob.MouseLeave:Connect(function() ob.BackgroundColor3=C.item   end)
						ob.MouseButton1Click:Connect(function()
							if flag then library.flags[flag] = opt end
							pcall(cb, opt)
							close()
						end)
					end
					list.Size = UDim2.new(0, math.max(120, display.AbsoluteSize.X),
						0, math.min(#tbl*22+4, 180))
				end

				populate(content_)

				display.MouseButton1Click:Connect(function()
					if list.Visible then close(); return end
					local abs = display.AbsolutePosition
					local sz  = display.AbsoluteSize
					-- position list below button in win-space
					local winAbs = win.AbsolutePosition
					list.Position = UDim2.new(0, abs.X - winAbs.X,
						0, abs.Y - winAbs.Y + sz.Y + 2)
					list.Size = UDim2.new(0, sz.X, 0, math.min(#content_*22+4, 180))
					list.Visible = true
				end)

				return {
					Refresh = function(_, tbl)
						content_ = tbl
						populate(tbl)
					end,
					Set = function(_, v)
						if flag then library.flags[flag] = v end
						display.Text = tostring(v).." ▾"
					end
				}
			end

			-- ── Box (text input) ──────────────────────────────────────────────
			function secObj:Box(opts)
				opts = opts or {}
				local flag = opts.Flag or opts.flag
				local ph   = opts.Placeholder or opts.placeholder or ""
				local cb   = opts.Callback or opts.callback or function() end
				local def  = opts.Default or opts.default or ""
				if flag then library.flags[flag] = def end

				local r = row(24)
				local lbl = make("TextLabel",{
					Text=opts.Name or opts.name or "", Size=UDim2.new(0.4,0,1,0),
					BackgroundTransparency=1, TextColor3=C.text,
					Font=Enum.Font.Gotham, TextSize=12,
					TextXAlignment=Enum.TextXAlignment.Left,
				}, r)
				makePadding(lbl,0,0,4,0)

				local box = make("TextBox",{
					Text             = def,
					PlaceholderText  = ph,
					Size             = UDim2.new(0.6,-4,0,20),
					Position         = UDim2.new(0.4,2,0.5,-10),
					BackgroundColor3 = C.item,
					TextColor3       = C.text,
					PlaceholderColor3= C.textdim,
					Font             = Enum.Font.Gotham,
					TextSize         = 11,
					BorderSizePixel  = 0,
					ClearTextOnFocus = false,
				}, r)
				makeCorner(box,3)
				makeStroke(box, C.border, 1)
				makePadding(box,0,0,4,4)

				box.FocusLost:Connect(function()
					if flag then library.flags[flag] = box.Text end
					pcall(cb, box.Text)
				end)

				return { Set = function(_, v) box.Text = tostring(v) end }
			end

			-- ── Keybind ───────────────────────────────────────────────────────
			function secObj:Keybind(opts)
				opts = opts or {}
				local flag     = opts.Flag or opts.flag
				local cb       = opts.Callback or opts.callback or function() end
				local blacklist= opts.Blacklist or opts.blacklist or {}
				local current  = opts.Default or opts.default
				if flag then library.flags[flag] = current end

				local r = row(22)
				local lbl = make("TextLabel",{
					Text=opts.Name or opts.name or "", Size=UDim2.new(1,-70,1,0),
					BackgroundTransparency=1, TextColor3=C.text,
					Font=Enum.Font.Gotham, TextSize=12,
					TextXAlignment=Enum.TextXAlignment.Left,
				}, r)
				makePadding(lbl,0,0,4,0)

				local function keyName(k)
					if typeof(k) == "EnumItem" then return tostring(k):gsub("Enum%.",""):gsub("KeyCode%.",""):gsub("UserInputType%.","") end
					return "NONE"
				end

				local kbtn = make("TextButton",{
					Text             = "["..keyName(current).."]",
					Size             = UDim2.new(0,64,0,18),
					Position         = UDim2.new(1,-66,0.5,-9),
					BackgroundColor3 = C.item,
					TextColor3       = C.textdim,
					Font             = Enum.Font.Gotham,
					TextSize         = 10,
					BorderSizePixel  = 0,
					AutoButtonColor  = false,
				}, r)
				makeCorner(kbtn,3)
				makeStroke(kbtn, C.border, 1)

				local listening = false
				kbtn.MouseButton1Click:Connect(function()
					listening = true
					kbtn.Text = "[...]"
					kbtn.TextColor3 = C.accent
				end)

				UIS.InputBegan:Connect(function(inp, gpe)
					if not listening then
						-- trigger keybind
						if current and (typeof(current)=="EnumItem") then
							if inp.KeyCode == current or inp.UserInputType == current then
								pcall(cb, false, nil)
							end
						end
						return
					end
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then return end
					listening = false
					local isBlacklisted = false
					for _,bl in ipairs(blacklist) do
						if bl == inp.UserInputType or bl == inp.KeyCode then isBlacklisted = true break end
					end
					if not isBlacklisted then
						current = inp.KeyCode ~= Enum.KeyCode.Unknown and inp.KeyCode or inp.UserInputType
						if flag then library.flags[flag] = current end
						pcall(cb, true, current)
					end
					kbtn.Text = "["..keyName(current).."]"
					kbtn.TextColor3 = C.textdim
				end)

				-- GUI toggle keybind is handled in main.lua via SettingsSection
				return {}
			end

			-- ── Colorpicker ───────────────────────────────────────────────────
			function secObj:Colorpicker(opts)
				opts = opts or {}
				local flag = opts.Flag or opts.flag
				local cb   = opts.Callback or opts.callback or function() end
				local val  = opts.Default or opts.default or Color3.new(1,1,1)
				if flag then library.flags[flag] = val end

				local r = row(22)
				local lbl = make("TextLabel",{
					Text=opts.Name or opts.name or "", Size=UDim2.new(1,-30,1,0),
					BackgroundTransparency=1, TextColor3=C.text,
					Font=Enum.Font.Gotham, TextSize=12,
					TextXAlignment=Enum.TextXAlignment.Left,
				}, r)
				makePadding(lbl,0,0,4,0)

				local swatch = make("TextButton",{
					Text="", Size=UDim2.new(0,20,0,14),
					Position=UDim2.new(1,-22,0.5,-7),
					BackgroundColor3=val, BorderSizePixel=0,
					AutoButtonColor=false,
				}, r)
				makeCorner(swatch,2)
				makeStroke(swatch,C.border,1)

				-- minimal inline HSV picker (click to open)
				local picker = make("Frame",{
					Size=UDim2.new(0,160,0,140),
					BackgroundColor3=C.panel, BorderSizePixel=0,
					Visible=false, ZIndex=30,
				}, win)
				makeCorner(picker,4)
				makeStroke(picker,C.border,1)

				local hexBox = make("TextBox",{
					Text=string.format("%02X%02X%02X", math.floor(val.R*255), math.floor(val.G*255), math.floor(val.B*255)),
					Size=UDim2.new(1,-8,0,20), Position=UDim2.new(0,4,1,-28),
					BackgroundColor3=C.item, TextColor3=C.text,
					Font=Enum.Font.Code, TextSize=11,
					BorderSizePixel=0, PlaceholderText="RRGGBB",
					ClearTextOnFocus=false,
				}, picker)
				makeCorner(hexBox,3); makeStroke(hexBox,C.border,1); makePadding(hexBox,0,0,4,4)

				make("TextLabel",{Text="HEX #",Size=UDim2.new(0,40,0,20),
					Position=UDim2.new(0,4,1,-52),
					BackgroundTransparency=1,TextColor3=C.textdim,
					Font=Enum.Font.Gotham,TextSize=11,
					TextXAlignment=Enum.TextXAlignment.Left},picker)

				hexBox.FocusLost:Connect(function()
					local hex = hexBox.Text:gsub("[^%x]",""):sub(1,6)
					if #hex == 6 then
						local r_,g_,b_ = tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16)
						if r_ and g_ and b_ then
							val = Color3.fromRGB(r_,g_,b_)
							swatch.BackgroundColor3 = val
							if flag then library.flags[flag] = val end
							pcall(cb, val)
						end
					end
				end)

				swatch.MouseButton1Click:Connect(function()
					if picker.Visible then picker.Visible = false return end
					local abs = swatch.AbsolutePosition
					local winAbs = win.AbsolutePosition
					picker.Position = UDim2.new(0, abs.X-winAbs.X-140, 0, abs.Y-winAbs.Y+20)
					picker.Visible = true
				end)

				return {
					Set = function(_, c)
						val = c; swatch.BackgroundColor3 = c
						hexBox.Text = string.format("%02X%02X%02X", math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
						if flag then library.flags[flag] = c end
					end
				}
			end

			-- ── separator / stub ──────────────────────────────────────────────
			function secObj:Separator(opts)
				opts = opts or {}
				local r = row(12)
				make("Frame",{Size=UDim2.new(1,-8,0,1),Position=UDim2.new(0,4,0.5,0),
					BackgroundColor3=C.border,BorderSizePixel=0},r)
				if opts.Name or opts.name then
					make("TextLabel",{Text=opts.Name or opts.name,
						Size=UDim2.new(0,80,1,0), Position=UDim2.new(0.5,-40,0,0),
						BackgroundColor3=C.panel, TextColor3=C.textdim,
						Font=Enum.Font.Gotham, TextSize=10,
						TextXAlignment=Enum.TextXAlignment.Center,
						BorderSizePixel=0},r)
				end
			end
			secObj.seperator = secObj.Separator

			return secObj
		end -- Section

		return tabObj, { Fire = function() end }
	end -- Tab

	-- keybind handler for Show/Hide (RightShift default)
	table.insert(library.connections, UIS.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		local kb = library.flags["UI Toggle"]
		if kb and inp.KeyCode == kb then library:Close() end
	end))

	return windowObj
end -- library:Load

return library
