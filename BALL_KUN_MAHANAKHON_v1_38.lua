local function __notify(title, msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = tostring(msg):sub(1, 200), Duration = 10})
	end)
end

local __Loading = nil -- [v1.28] หน้า Loading (ให้ handler ท้ายไฟล์แสดง Error ได้)
local __ok, __err = xpcall(function()
-- [[ BALL KUN v1.28 - MAP NATIVE EDITION ]]
--  Delta / Ninja

local function safeWaitLoaded()
	pcall(function()
		if game and not game:IsLoaded() then
			game.Loaded:Wait()
		end
	end)
end
safeWaitLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local okVU, VirtualUser = pcall(function()
	return game:GetService("VirtualUser")
end)

local player = Players.LocalPlayer
if not player then
	local t0 = tick()
	repeat
		task.wait(0.2)
		player = Players.LocalPlayer
	until player or (tick() - t0) > 15
end

if not player then
	warn("[BALL KUN v1.28] ไม่พบ Players.LocalPlayer")
	return
end

-- [v1.28] กันรันซ้ำซ้อน: ถ้ามีสคริปต์รุ่นก่อนรันค้างอยู่ ให้สั่งหยุดมันก่อน แล้วลงทะเบียนตัวนี้เป็นตัวปัจจุบัน
do
	local okG, genv = pcall(function() return getgenv and getgenv() end)
	local store = (okG and type(genv) == "table") and genv or _G
	local old = store.__BK_INSTANCE
	if type(old) == "table" and type(old.stop) == "function" then
		pcall(old.stop, "ถูกแทนที่ด้วยการรันใหม่")
	end
	local inst = { alive = true, conns = {}, hooks = {}, onStop = nil }
	inst.stop = function(reason)
		if not inst.alive then return end
		inst.alive = false
		for _, c in ipairs(inst.conns) do pcall(function() c:Disconnect() end) end
		inst.conns = {}
		if inst.onStop then pcall(inst.onStop, reason) end
		-- [v1.31] ฮุกหยุดงานหลายตัว (ไม่เขียนทับกัน): Farm, JobBot, Premium, Runner
		for _, h in ipairs(inst.hooks) do pcall(h, reason) end
		inst.hooks = {}
	end
	store.__BK_INSTANCE = inst
end

-- [v1.31] ตัวช่วยผูก connection/ฮุกเข้ากับรอบการรันนี้ เพื่อให้ล้างได้เมื่อปิดหรือรันใหม่
local __bkInst = nil
pcall(function() __bkInst = (getgenv and getgenv() or _G).__BK_INSTANCE end)
local function __bkTrack(c)
	if __bkInst and c then __bkInst.conns[#__bkInst.conns + 1] = c end
	return c
end
local function __bkHook(fn)
	if __bkInst then __bkInst.hooks[#__bkInst.hooks + 1] = fn end
end
local function __bkAlive()
	return not (__bkInst and __bkInst.alive == false)
end

-- [v1.33] หมุดกลาง: ทุกระบบ (Rider, JobBot, Garage/Care ฯลฯ) ส่งปลายทางเข้าที่เดียว
-- หน้า MAP NAVIGATION รับหมุดนี้ไปวาดเส้นนำทางสีฟ้า ระบบอื่น (Quest, Race) เรียกใช้ได้ด้วย
-- getgenv().__BK_PIN.set(source, x, z, label) / .clear(source)
local BKPin = { cur = nil, subs = {} }
-- [v1.34] ระบบที่นำทางเองอยู่แล้ว (เดิน/ขับเอง) หมุดจากระบบเหล่านี้แค่แสดงเส้น ไม่สั่งนำทางซ้ำ
-- เพื่อไม่ให้มีตัวควบคุมสองตัวแย่งกันขับ/เดิน
BKPin.selfNav = { rider = true, jobbot = true, care = true }
BKPin.active = {}
function BKPin.selfNavActive()
	for src in pairs(BKPin.selfNav) do
		if BKPin.active[src] then return true end
	end
	return false
end
function BKPin.set(source, x, z, label)
	if type(x) ~= "number" or type(z) ~= "number" then return false end
	BKPin.active[tostring(source)] = true
	local c = BKPin.cur
	if c and c.source == tostring(source) and math.abs(c.x - x) < 1 and math.abs(c.z - z) < 1 and c.label == tostring(label or source) then
		return true -- ซ้ำกับหมุดเดิม ไม่ต้องคำนวณเส้นใหม่
	end
	BKPin.cur = { source = tostring(source), x = x, z = z, label = tostring(label or source), at = os.clock() }
	for _, f in ipairs(BKPin.subs) do pcall(f, "set", BKPin.cur) end
	return true
end
function BKPin.clear(source)
	if source == nil then BKPin.active = {} else BKPin.active[tostring(source)] = nil end
	local c = BKPin.cur
	if c and (source == nil or c.source == tostring(source)) then
		BKPin.cur = nil
		for _, f in ipairs(BKPin.subs) do pcall(f, "clear", c) end
	end
end
function BKPin.subscribe(f) BKPin.subs[#BKPin.subs + 1] = f end
pcall(function() (getgenv and getgenv() or _G).__BK_PIN = BKPin end)
__bkHook(function() BKPin.subs = {} BKPin.cur = nil end)

local playerGui = player:FindFirstChild("PlayerGui")
if not playerGui then
	pcall(function()
		playerGui = player:WaitForChild("PlayerGui", 10)
	end)
end

--  Delta / Ninja:  PlayerGui  gethui  Parent
local function getDeltaNinjaParent()
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and typeof(hui) == "Instance" then
			local okAdd = pcall(function()
				local probe = Instance.new("Folder")
				probe.Name = "__Probe"
				probe.Parent = hui
				probe:Destroy()
			end)
			if okAdd then
				return hui
			end
		end
	end
	if playerGui and typeof(playerGui) == "Instance" then
		return playerGui
	end
	local okCore, testCore = pcall(function()
		local f = Instance.new("Folder")
		f.Parent = CoreGui
		f:Destroy()
		return CoreGui
	end)
	if okCore and testCore then
		return CoreGui
	end
	return nil
end

local uiParent = getDeltaNinjaParent()
if not uiParent then
	warn("[BALL KUN Vv1] ไม่สามารถหา Parent สำหรับสร้าง UI ได้")
	return
end


-- ============================================================================
-- [v1.28] PREMIUM LOADING SCREEN : BALL KUN PREMIUM / BLACK NEON GREEN EDITION
-- ความคืบหน้ามาจากขั้นตอนโหลดจริง (Loading.step) ไม่ใช่ตัวจับเวลา / ไม่แสดง 100% ก่อนเสร็จ
-- โลโก้นินจาฝังในสคริปต์ (JPEG) เขียนลงไฟล์แล้วโหลดด้วย getcustomasset ถ้าตัวรันไม่รองรับจะใช้โลโก้ข้อความแทน
-- ============================================================================
local Loading = (function()
	local L = { done = false, failed = false, target = 0, shown = 0, stage = "Initializing BALL KUN",
		t0 = os.clock(), lastStep = os.clock(), conns = {}, alive = true }
	local NEON, NEON2 = Color3.fromRGB(20, 255, 140), Color3.fromRGB(72, 255, 168)

	pcall(function() if uiParent:FindFirstChild("BALL_KUN_Loading") then uiParent.BALL_KUN_Loading:Destroy() end end)
	pcall(function()
		local pgOld = player:FindFirstChild("PlayerGui")
		if pgOld and pgOld:FindFirstChild("BALL_KUN_Loading") then pgOld.BALL_KUN_Loading:Destroy() end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "BALL_KUN_Loading"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("CanvasGroup")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	root.BorderSizePixel = 0
	root.GroupTransparency = 1
	root.Active = true -- กันการกดทะลุไปโดนปุ่มข้างหลัง
	root.Parent = gui

	-- แสงขอบจอเรืองเขียวบางๆ (ไม่หนัก)
	local vignette = Instance.new("Frame")
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.Parent = root
	local vg = Instance.new("UIStroke")
	vg.Color, vg.Thickness, vg.Transparency = NEON, 3, 0.7
	vg.Parent = vignette

	local center = Instance.new("Frame")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(380, 330)
	center.BackgroundTransparency = 1
	center.Parent = root
	local sizeC = Instance.new("UISizeConstraint")
	sizeC.MaxSize = Vector2.new(380, 330)
	sizeC.Parent = center
	local cscale = Instance.new("UIScale")
	cscale.Parent = center
	local function fitScale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		cscale.Scale = math.clamp(math.min(vp.X / 420, vp.Y / 360), 0.55, 1.15)
	end
	fitScale()
	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then L.conns[#L.conns + 1] = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale) end
	end)

	-- โลโก้ + แสงเรือง + วงหมุน
	local logoBox = Instance.new("Frame")
	logoBox.AnchorPoint = Vector2.new(0.5, 0)
	logoBox.Position = UDim2.new(0.5, 0, 0, 6)
	logoBox.Size = UDim2.fromOffset(132, 132)
	logoBox.BackgroundTransparency = 1
	logoBox.Parent = center

	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(150, 150)
	glow.BackgroundTransparency = 1
	glow.Parent = logoBox
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Color, glowStroke.Thickness, glowStroke.Transparency = NEON, 7, 0.75
	glowStroke.Parent = glow

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(140, 140)
	ring.BackgroundTransparency = 1
	ring.Parent = logoBox
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color, ringStroke.Thickness = Color3.fromRGB(255, 255, 255), 3
	ringStroke.Parent = ring
	local ringGrad = Instance.new("UIGradient")
	ringGrad.Color = ColorSequence.new(NEON)
	ringGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 0.15),
		NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) })
	ringGrad.Parent = ringStroke

	local logo = Instance.new("ImageLabel")
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.fromScale(0.5, 0.5)
	logo.Size = UDim2.fromOffset(112, 112)
	logo.BackgroundColor3 = Color3.fromRGB(8, 14, 12)
	logo.ScaleType = Enum.ScaleType.Crop
	logo.Parent = logoBox
	Instance.new("UICorner", logo).CornerRadius = UDim.new(1, 0)
	local logoStroke = Instance.new("UIStroke")
	logoStroke.Color, logoStroke.Thickness = NEON, 2
	logoStroke.Parent = logo

	local logoText = Instance.new("TextLabel") -- โลโก้สำรอง ถ้าโหลดรูปไม่ได้
	logoText.Size = UDim2.fromScale(1, 1)
	logoText.BackgroundTransparency = 1
	logoText.Text = "BK"
	logoText.Font = Enum.Font.GothamBlack
	logoText.TextSize = 38
	logoText.TextColor3 = NEON
	logoText.Visible = true
	logoText.Parent = logo

	task.spawn(function()
		pcall(function()
			if type(writefile) ~= "function" or type(getcustomasset) ~= "function" then return end
			local DATA = [=[
/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkI
CQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQ
EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAC4ALgDASIA
AhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQA
AAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3
ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWm
p6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEA
AwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSEx
BhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElK
U1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3
uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD4vooo
PsK7TIKKjkuIYsCSVVz0BOKeCCMjnNF+wC0UfhRQAUUUUCCijoM1j654lsdHTa7CSZuFReSTQ2lu
M0bu8t7KBp7mURqozyax7fXdWvYptSsNGlm0y3OJLhQTiubaLU/Ed0kmoSMIWOI4h2zX2b8HPBmj
aP4EtdHvrSFpLxDvRgCXBrCVV9C1HufNtjf2uoQrLbShgeozyKsV6F8TP2dLzR7ifxJ8PXKISXms
85z64ryjT9bWadtPv4mtbyI7XjkG3n8a0jUUiWrGr7UUf1oqyQooooGFFFBx1oAKKijuIJWKJKhY
dQDzUtABRRRQAVg+JfFFtoUWwMGnf7iVvZA61534x0rPiewnuDuhu5VRs9AM1E20hpXOd1S/1zVJ
lvbl2AzuRVbsK9O8K6sNW0qOZj+8UbWHpiqWueGtLi8YPoOhR74444xuByCWHP5VUtLI+CPF914V
muhKGCuGB457VjTlZltaaHYUUUV0mYUjMiKWdgABnJpa5TxjrDqF0Wzb9/cdWHYUpOyuCVyHWfF8
ssrWGiL5r/dZ+y1mWelbZTeXjmWduSW5AqxYWUNjCAigMRl27k1Gl+bi7a3t+Vj++1cspORolY1d
PnS1vYbh1BWJg2PXFfSHwO8Q3fjHxFd6jcuwisEVIIweF4r5nr3D9mDVo7bxBdaWT812OB9KkZ9O
sA+dwzk15X8VvgXoHj2NtStFWy1VRlZoxt3HtwK9UYHlQec4rzm7+K1r4b8cHwj4mjEEdwQLS6bg
SGgD5Z1mz8T/AA/1X+xfGNi8cZbbDc4yritCORJkEkbAqwyCK+rviH4J0X4g+FrrT7uCOWR4y1vM
Bkg44wa+MdJS+8M65eeDNZBW4snIUN/d7VvTqdGRJHRUUUVsSFZuv6kml6ZLdOcEDAFaVcX4lf8A
4SHXbPw3DcCMM3ztnjrUzdkNK5xlld63BevqNtK3mE7sFuCK7/wv4wh1XFndny7kcY/vU+Hwtp2j
eM7PTteTdZxxkTDOMkjiueh0WJPH1xbaeMW9u27IOQATxzWEJO5cloejUUA9h24orpMzT8LWVvqf
iG20+7IWKVW5/wBrsK5b4i+G7mBbzT7qJo7q0YsqnggdjWxa3L2WoWd7GSDBcRufoDk19AftTfDz
T5PDXhL4x+Hh5tt4nt1iv9i/LEUGKiXYasfLnwemjNzcapfPvezjZZGY5OccVzus6Zq19cTeI4Q8
sttKzSPnJ254pl3LfeGNYuLS1k8uzvyCT616DpEkNh4E1ae5QZuwFQkdfXFczVmablPQdUTVtNhu
1IyRgj0IrRxXnmgazB4dvbi3uGcWjfNGzDAJ9BVyDxxdzatCktlJBZynAdlIB/GuiNRW1M2jtXOE
Y+gzXnG9r3xLc3DHIjOF9q9ElkU20kgPBjJH5V5XZ6gltBeahIcsXYAevNTWY4oteI9aFlEbaA/v
X6n0pnhea3Wzy0g8xzlsmqKaFJq0B1Ca42mTkZpbLwZqt5KsNlIzSMcKo71gWdWrox4YH8a6XwB4
nfwj4mtdaR9oibB57HrVDSf2d/ivqVotzYwlgRnBbpT5v2fvi/b6ha6ZLDtmu8mIbuuKAPt3w/4n
0nX9Kh1OyvYWSRQTlxkHvXz3+2Jd6BNoen3EWoxDUrdwYREwLdfUV5jq3w0+OXw90yS9bUZoLY8S
Krk4+grzXVNJ1/U5Tc6zqUs0jHkuxOPwoA+mv2YvjnNrcaeDvElzuuUAW3kY8sBWD+1J4Zj0bxpY
eLrYbWvSBMw714TYRXngy/tfEGn3ZEtswfI4yO4r374xeKbP4lfBfR/FVoQLqJlWZB1QjvTTs7gz
k4zujRv7yg06q1hcLNp8E3YRLn8BXIXPjPUItYmFtZS3NnCQGZFJA/GupyUdTJK51WtalFpWnS3k
p4UYA964ex0TUi8fiG+Rk+0yiSJ89gc07X9aHie5gs7FXeEfNLgZAx2NegXUkGsfD+zFnFsOlgrK
B1H1rCpLm2NIqxkfFS8W/wBKtddQ/NdIse4dSVFVPh1oNzIbf5GkuNRmjjPdiCcVzi3GoeIL+20C
SUvZ2h3D0Wvsv9jf4S6frs+vfEvxBiPSfB1s5RJB8k7leDn2NEFbUHroeP8AxH8Nx+DfF9x4YiYO
ttDHIWB7sM4oqh4u12XxN4q1TW5WJM1w6qT/AHA3H6UV0rYzZkyLuUr/AHgRX018IPip4K8T/s7+
Kfg18TNUWyl01d+gSsu4u3UjPavmhFMkqRDrIwRfqelTeINH1Dw5fS6dqVu8dxEgk2njIIyMVMkC
ZynjPSVvdOkMZG+2ciNumVHQ1Vl8ZwavoOieHrGFzcWm5bgKud57VzXiPxDq19efZJg9nbFwrHHQ
Z613MPiz4dfDnRo4/CqJrmtXCAveMuPKY+1c82my4qx0Fp4N0g6VbeIfipJFp1hZDfbW6433HoCK
5Dxbr8nxIu7a08O6NHpuk2LYjKgZwO+ferfhnSNT+JOqpPr+qvcyTkgW38MYPtTLjRpvh14vn8JX
UgaJ/mifpnPalFJvUbZZ1Rm0zw84eTcY02lvXivHri6JTyV+7uJNeqeP5/K8PyIv8deQd8mrqb2F
E7rQdO1bVLOK207dNI/3YlGSa7vwo+qeB/EtrqPivw/eW1tCp3FoDj61zXwl8Yp4V1zTtaiCPLYS
q5jbowB5Ffqd4e/am/Y0+JfgmL/hYegWWm6iIFjuIRAp5AxnPvWRR8teD/jz8L7e1ZLnX5ImY527
DxU998avhzdeLNJvodZmkgtg291jJ25ql8efh5+zXq1reeLfhd43hsIocslj5QzMf6Vxv7OKeCp0
1OPXhatKGAi8zbz+dAHe+Nvin4L8RwJp+mXF1drKG3gwHGe1eKQ/A/4o+NdRkfQvCc5tHfKykEYX
1r9Afhd4J+CUUMGs6/q1gYzy9qsSkr+Ne533xe+APgnw+3/CN2NrPcCMqiFQv40AfkP8U/gPeeAP
Bk2qa/qRe7AAFuRjYa8q8KeLmtvC+peHrqU+RMAUB6A19Kftq/FDRPEMRsrG9ikubuQs0cZyFGel
fGQZl6HFAHs/haX7d4dQbvvArn0FVvD3iK7+F95cLqOmQ6npN8cSoyjJB68+1VvhxchtFdXbAi5p
2kaTN8T/ABzD4bt5dtrEctJ247VtKziStGdo/hbQ9R0y48QfCWSK5N2N9zYvgNF6gVxdl4wXwrY6
7pOo2r+ZqICiN1xtb2ra8a6FJ4AvZZdB1F7O+tsBIlOFlx1yKr2/j7wL4/0p9O8d2cenalCh2aii
j5mx6VjsMzvBGlrBYG7kIMl0/wAzdSqmvsvx98W/BPgL9mLQPhR8NNQF5qXiEFtbuUG1ocdAfWvg
jSdZ1PSdQa202Z7y0DlVOPvLng16ppFvc6s0MNvAzXEq5EQ5PvxW8bMl6CxKFUDuOp9TRUs0TW87
QP8AeThvY0VsSMV/IuILkDPkzJLj2U5r7kuvgz4I/bD+GWleIPhdqVpY+M9DgWO+tJJAjXBAwBz1
r4bIzWl4Z8WeKPBOpJq/hLW7nTrpDkNFIVBPuB1qZRb1Q00b3xV/Zs+J3w4u3074g+CJoT0DwoZA
w9civE/E3gWys7CSextXimi5KsMEfhX3x8MP+ChOv2ttB4d+MPg+38VxTOsJv5lG6NScZ5rwX9ou
78Lat8YtdvvCMca6PdxxyRIg+VSw5FZ8t9GO9jwj4S+PIPCGtw6pf/NHDkSA96tfEfXj8QPFTa3p
QKwRkMJm4xWJrWiaFo2oy389wHjblbYetcxqviK4vj5Vun2e3HCxrxxWduVlbnR+K/Fdrc6WNHU+
dKoAaT0rhaDk8nnNFS3cErHQ+HfCWu6/a3N/ocTSmyGZVU8gfTvUQvvENu5gMFwHBwR5Jzmuj+Cn
jg+CPG1ne3AEllMwjuIm6MDxzX33YeF/Aur28WqWui2kq3CiQOIx1PNIZ+f2m+FfiH4jCpZ6fdMH
4A2lRVPxHoHjL4f38cWrNNaTvyoVyM1+k1po2k2WFtNPgiGR0QV8a/tkIq+NLcKMDb0oA8w0r40f
EDRwFs9clAHZjkVNq/xy+IutRGG91typGPl4rz+igCa7vLm+ma4up5JZGOSztmi0tZ7yZbe2jLyN
91QOTUNepfs5aCuufEmxSSISRxHLAjIoApaHdw6Zpcnh67SSwvZRjc64zUng3V9W+F/iFddNt9ph
3ZJU53CvUv2w7TR9Lv8AS4rCzjguXB3Mi4PFeDaJ4unsD5F9H9qtzwUbnFXzJ6MVjp/ih8Ro/G+r
S6xbp5RkACJ/d9ag8J+CrW+s/tep25czEbB3zS2mgeHPEF3HeWVysQzuaH1r1fwF/Ztl4r0l9QRf
sVtIssinoQpziqjDqyWze+Fn7MXxS+Id0tj4C8CzTZ6yToYwo9cmvqrS/wBnjwP+yX4KvvHnxn1W
zv8AxVeQPHpdhHIHNuzDByBXN/FP/goP4ovbRfDnwh8M2/haG2hWA38KANNgYJ4r5X8TeLvFfjbU
G1Txbr11qVyx3MZZSy59gelWk2F0Ubq4+2391fbdonneUD0DHIoqNRgUVqiRaQjPaloxnigBjKAC
WIAHJzXH+J/G0dkWstOcyXDcbuuK3PFAuTpE32RiHwenWvOvC9rbTySzXB3TI3RuayqStsUkYOpS
Xstyz3zsZG5OTVSt/wAWw7LsSgcPWBXOWFFFFACo5RgynBHI+tfVH7NP7QFvZRReDPFdzjJ2287n
9K+VqfFNJA6yQuUdTkMOoNAH6tW88dzHHPC6uj4KspyCK+Lv2y/+Rztj7VZ+Bf7Td1oPkeGvF7GW
zDKsdyx5QZrF/av8Q6R4i8TWd/o96lzA6ZDKc0AeCUUUUAAr7F/ZD+H9pb6OnjaSP99McKT3r5Bs
bd7u7htY1JaVwgA9+K/Rf4VaND4C+E9lYXbCI2ts8zMfUjIoA+X/ANrHUZNd+J0Oi2+ZJISEVV55
Y1Q1T9ljxxaeF7XXrRPOlmTzJIO6CvSfhN8Prn4k/ES9+J/iC2YW8M7LArjh9p4NfUohj2CMKNoG
AvbFAH5b3Vlrfhi+MVzBPazxN/EpAruvC/jqK9CWmoOFnHAfpur7f8Z/CbwV45tWt9a0iIsR8roo
Ug+tfHXx5+C+j/Cq4t59K1v7QbpvlhHBjqoycRNXNpFDAFSOemKdgCsLwa102iRNeOSSOCa3TXWn
dGbVgooopgFLHKIJ4piMqkqlx6oD836UlMlG5GQ9GUj8xSYHovxd+Hi6Tpmj/EDR7Yr4d8Tw7LUA
ZCOo+bn618xalbyeGfEOOfIkbIPrmv0A+Btsvx8+AurfBFyv9seGI3udHB+86gZfFfF/xB8Oyy29
wskTJdabK8DqwwwKnBrCXvIpaM5HxaqzWsVynKsM5FcnWzDdm60x9PmPzRfdzWO3BxjpWJYlFFFA
EzWsiwLcYyp/Soa3/DaxXkU9hNyGHy/Ws2e0Nhe+TOvAbH1FAFIEg5zzT3mlkADyOwHTc2cV1Z8L
2V3As9vJs3DpVX/hDpd3+u4oA5uiuu/4Riys7d7i4fftHSubgtJNQvVtrVMs7bQB2HrQB6p+zh8O
Z/GnjOC+ki3WentvlyOM9q+6tf8AD0Wt6ONE8wxwMFVsdwO1eV/svaJo+h+GrywsFV7lFU3M+Pvk
9h9K9mubiK1t5LidwkcSGQknHA5oAwUvdD8JXOneF7CBIRcDCIvHI6mujIxzXzj4N8bN8T/jPLqF
o5On6Q7Rw+mehr6OJABz0zQBU1XU7XR9Pn1K8lWOGBC7MxwOK/P74j+LLz4qfEW4kjlY2cUuIh2U
A17T+1j8WxBaN4C0e65uMfaSh5FeK/DvQZI4op/LLXF/IsEYAydzHA/WqirsTPa/gr8LJ/HmpztJ
EYdB0e3Z7+5PCxsBwPxrjL54X1C6FsMRJM8ae4U4Br6y+JMFp+zf+zRB8M54lTxb43RJ7p1Pzwpj
Iz9RXyJEpCru6gDJ9TjmuiDuQ9CSiiirEFFFFAHdfAj4oXvwe+KOj+MrQkxLKLe4TPDo5wc/hXq3
7bHwksdD8S2nxR8L26P4f8WwrM4iGY4XYZbkcda+bJEDDH1/Cvrv9l7xnovxg+Get/sz+PrpTcXC
FvD9xMcsrj+EE+9ZyVncaPzm8XaG+i6i01uCIJeUP1rmycnJr6M+M3wo1rwV4j1X4feKrU2+p6Y5
x6FP4SD3yK+er20msbl7adCrocYNYzVndFpkFKuNwz0pKKgZr2QfTb6C6QExvwK3vEelC+t/tkA/
eKAeO9Z2iLFqdk9nKfni5Q966LTRJ9kEE4+ZeDn0oAxvC+qgj7BcNhl4XPeulrjde02XTbsX1tkB
jnjtT/8AhLZvsezy/wB5jGaALPinV1UfYYW+b+OsjQb46dP9ohXNw58uPjpnis2aWSeRpZDknrXo
HwP8ES+N/HNnpwiLxRuHfjgYoA+2PgR4Yk8MfD6xiuVP2q5HmysepzyK4z9qX4nDwr4W/sLT7jZe
3ylSFPIGK9G8Q+O/Dfgjw7cGe+jEulwhTEDyCBxXwD8SfHOpfETxbda1eOxE8myJM8KO2KAPo/8A
Yy0J5dO1XXZV5dsg+pNem/HX4v2Pw28POIJFfUbpCsUeeVz3rkvh14g0r4LfA+HVNVZUvZ0LJCer
k9K+TfHfjfW/iR4mm1PUJHdpnxFH2UduKNwGWEepeOfEj6lqk7TGRzJK7du+K+3/ANin4M2Pi3xb
N468SWqjw54RjNxIsvEcrqMryeO1fO/wc+Fuu+K9e03wN4Ysjc6vqrgBB2T+Ik+1fYX7SnivRfgR
8I9F/Zv8DXanVZEDeIbmE4YMf4SRWyVlYl9zwX9of4r3Xxl+Kmq+KpGP2OKQ2trETwiRnAx+FedA
Y7UyNAB6+vufWpK2SsiAooopiCiiigYHmrvh7xBqnhHX7LxLok7QXmnyrKjKeSAckfjVKkIz2oau
B9rfFrwzo37XXwg034wfD+zRPG2jwbdZ05TmSVUH3j3PSvz18deFHvFkvIIGjubclJYyMMGHUY+t
e9/AD44a98CPHMHiHTmabTrhhFqFoTlZIm4Y49hXuf7TfwA0Dxx4eb9oT4FtHqWhXSCXVbaEfNBI
eWGwe9YtdGUu5+YTo0bFHBBBwQaSvQfGng4tv1LT4Tu/5aR4wQfpXn7qyMVZSCOxrKUeUpO5b0m8
ayvElU8ZwRXokMqTRrKmCGGa8vBwc12fhTUBPbm2dvmTpnvUjNq6tY7yFoJACGrgdW0qXTbhkYEo
T8rV6E5IUkdQKozW9vq9sUmAJ6e4oA8/ghe4mSCMZaRgoHuelfTXhHUND/Z88A/23evFP4k1WM+X
CrAmMEcH2r531DTLzR7pZ0U7VO5GHtVbU9X1DWLg3Wo3Uk0hAGWbIAHp6UAa3iDx14j8Q319d32o
yP8Ab23SqTwR2FZGlvBHfwS3LbYo5Fkb3wc4qpSgFjhRkntQB3PxJ+J2peP7yCKNWgsbWNYorcHj
gYzVzwH4VeLy9RuoC8sxCQRgZJY9BiqXg3we0m3VNRiO0cxp3Y/Svvz9lv8AZ50TQNEX4/fG/Zpn
hixUzaZDMMNcuvKjafetIxtqyWzo/gf4R0X9lX4U6l8dfiPZK3im+gK6JpznEke8cMO/evj3xT4m
1bxv4lv/ABXrk7TXmoStKzMeQpOQPwrvf2ifjtrfx48cTazcs0GkWbGHTrReESNeAcdORXmCrxWs
Y9WS3fYUcUUUVoIKKKKACiiigA/GiiigQx1BGD0Neyfs2ftF6v8AA7xH9k1FG1HwrqR8rUNPkOYy
h4Jx04FePUx0BGCMilKNxn11+0X+zH4e8VaEnxw/Z9nXVtF1FTNe6dCMtak8sMCvhDxb4FW5MlxZ
RNDcxkh4GGGz3yO1fSH7PP7SfjH9n7xCtzYE6joNydl/pkvzI6HqQDwMCvo/4ifs7/DX9qPw7efF
b9njUraHXkTzrzRwwUzt1YBfasmraMpan5MXNrPaSmGeMqy8EGpdOvHsrlJ0ONpr2rx78Nbyy1G5
0PxJpkmnapasUcOu0Bh6Z615LrPhXVNIc+bCWjHRgOtZuNikzsrO4jurdJUOQw5rKvJpNH1AXA5g
m+8PSsLRtel00+VIC0Z7HtW3qGq6Vf6cwaUYI/EGoGazC1voMuFdHFcbr2nWFnIWtrgFj/AKqx6v
e28b20ExKHpVnS/D2ra3L+5iYhjyzdqaVwMqCCW4kEUKFmbgAV6H4S8CmPy7zUoi8zkeXAoySe3F
dL4E+Gtzc39vpOh6fJqWq3LBIwi7ssexx0r78+Gf7NPw7/Zu8N2nxZ/aU1O3/tV08+00bcGaBhyo
I75rRRS1ZLdzi/2bf2W9H07Rn+Nnx4mGj+G9LAmtLCcbWvCORwa89/ab/aR1D4068NF0BTp3hDS/
3VhZxfKjKOMkDiqn7RX7TvjD4/66yuDpfhy0Pl2Omw/IioOhIHByK8bRABgDAFaRV9WS2KqAKAOg
6U6iitBBRRRTAKKKKQBRRRQAUUUUAFFFFADWQEGul+HXxN8a/CbxFB4m8E6zNZXMDAsisdki91K9
Oa5ykIB7UmrgnY+99I+If7Nf7YOiQ6T8RtPt/CfjLYI1uhgB5P7xP15r56+OX7GnxE+FUs13YW7e
KPDh+ePUrdd4KHpwK8LAeNxLA7wuDkPGdrA/Wvof4Gftu/FD4SBND8Q7PFHhoDYbC5XeVX6mocXH
Yq9z5J1/4f2V27/Z0ayuB1jkG1ifoa41/BetpdfZhbkjPB7V+rw0D9kb9rO0lOhm38KeNbr5lkZx
HHG57elcyf8Agl54n83C/F7RTFnO/wC0rnb61D5XuPVH56eH/h7a27K92TdTN0hQbmB+lfUHwM/Y
5+IvxXuIZpbJvDfh4fNLqVwhQKo9jX0gPB/7JP7JtlFJ4qnt/FfjS1+bejh43b044rxH44ftyfEv
4qRv4f8ACkUfhTw4BsNnbLtMi/UU12iHqe3aj40/Zo/Y30WWw8EWVv4v8a7CjTnDBZP7wPbB5r4u
+JnxV8c/F/xFP4k8baxNdyysTHEzHZGvZdvTiuUYyzSNNcSvLIxyXkbcSfrTgNvHpVxhbclvsIq4
p1FFWSFFFFAwooooAKKKKLBcKKKKBBRRRQMKKKKACiiigAPPWmsgPaiigBqCaBg9tcTW7jo0L7G/
MVY/tTxB/wBDTrn/AIMJP8aKKVkwK8nnTv5l1dT3Df3p5DI35mnBR24oop2sA6iiimAUUUUgCiii
gAooooAKKKKAP//Z
]=]
			local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
			local map = {}
			for i = 1, 64 do map[chars:byte(i)] = i - 1 end
			local s = DATA:gsub("[^A-Za-z0-9%+/]", "")
			local out = {}
			for i = 1, #s, 4 do
				local c1, c2, c3, c4 = s:byte(i, i + 3)
				local v1, v2, v3, v4 = map[c1], map[c2], c3 and map[c3], c4 and map[c4]
				local num = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
				local b1, b2, b3 = math.floor(num / 65536), math.floor(num / 256) % 256, num % 256
				if v4 then out[#out + 1] = string.char(b1, b2, b3)
				elseif v3 then out[#out + 1] = string.char(b1, b2)
				else out[#out + 1] = string.char(b1) end
			end
			writefile("BALL_KUN_Vv1_loading_logo.jpg", table.concat(out))
			local asset = getcustomasset("BALL_KUN_Vv1_loading_logo.jpg")
			if asset and asset ~= "" and logo.Parent then
				logo.Image = asset
				logoText.Visible = false
			end
		end)
	end)

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 150)
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(245, 255, 250)
	title.Text = "BALL KUN PREMIUM"
	title.Parent = center
	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0, 180)
	sub.Size = UDim2.new(1, 0, 0, 18)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 13
	sub.TextColor3 = NEON2
	sub.Text = "BLACK NEON GREEN EDITION"
	sub.Parent = center

	-- Progress bar + แสงวิ่ง
	local barBg = Instance.new("Frame")
	barBg.AnchorPoint = Vector2.new(0.5, 0)
	barBg.Position = UDim2.new(0.5, 0, 0, 214)
	barBg.Size = UDim2.new(0.86, 0, 0, 12)
	barBg.BackgroundColor3 = Color3.fromRGB(14, 24, 21)
	barBg.BorderSizePixel = 0
	barBg.Parent = center
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
	local barStroke = Instance.new("UIStroke")
	barStroke.Color, barStroke.Thickness, barStroke.Transparency = NEON, 1.5, 0.45
	barStroke.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = NEON
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local sweep = Instance.new("UIGradient")
	sweep.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, NEON), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 255, 245)),
		ColorSequenceKeypoint.new(1, NEON) })
	sweep.Parent = fill

	local pct = Instance.new("TextLabel")
	pct.AnchorPoint = Vector2.new(1, 0)
	pct.Position = UDim2.new(0.93, 0, 0, 232)
	pct.Size = UDim2.fromOffset(70, 18)
	pct.BackgroundTransparency = 1
	pct.Font = Enum.Font.GothamBold
	pct.TextSize = 13
	pct.TextXAlignment = Enum.TextXAlignment.Right
	pct.TextColor3 = NEON2
	pct.Text = "0%"
	pct.Parent = center

	local status = Instance.new("TextLabel")
	status.Position = UDim2.new(0.07, 0, 0, 232)
	status.Size = UDim2.new(0.68, 0, 0, 36)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 13
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextColor3 = Color3.fromRGB(205, 220, 212)
	status.Text = L.stage
	status.Parent = center

	-- ปุ่ม Retry / Close (โชว์เฉพาะตอน Error หรือโหลดค้าง)
	local btnRow = Instance.new("Frame")
	btnRow.AnchorPoint = Vector2.new(0.5, 0)
	btnRow.Position = UDim2.new(0.5, 0, 0, 276)
	btnRow.Size = UDim2.new(0.86, 0, 0, 38)
	btnRow.BackgroundTransparency = 1
	btnRow.Visible = false
	btnRow.Parent = center
	local function mkBtn(text, x, col, txtCol)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.48, 0, 1, 0)
		b.Position = UDim2.new(x, 0, 0, 0)
		b.BackgroundColor3 = col
		b.TextColor3 = txtCol
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.Text = text
		b.AutoButtonColor = true
		b.Parent = btnRow
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
		return b
	end
	local retryBtn = mkBtn("RETRY", 0, NEON, Color3.fromRGB(0, 0, 0))
	local closeBtn = mkBtn("CLOSE", 0.52, Color3.fromRGB(30, 40, 37), Color3.fromRGB(235, 245, 240))

	local function cleanup()
		L.alive = false
		for _, c in ipairs(L.conns) do pcall(function() c:Disconnect() end) end
		L.conns = {}
		pcall(function() gui:Destroy() end)
	end

	-- Animation: เชื่อม Heartbeat ตัวเดียว (เบา) และตัดทิ้งเมื่อจบ
	L.conns[#L.conns + 1] = RunService.Heartbeat:Connect(function(dt)
		if not L.alive then return end
		local t = os.clock() - L.t0
		local cap = L.done and 1 or 0.99
		local tgt = math.min(L.target, cap)
		L.shown = L.shown + (tgt - L.shown) * math.min(1, dt * 5)
		fill.Size = UDim2.fromScale(math.clamp(L.shown, 0, 1), 1)
		local p = math.floor(L.shown * 100 + 0.5)
		if not (L.done and L.shown > 0.995) then p = math.min(p, 99) else p = 100 end
		pct.Text = p .. "%"
		if not L.failed then
			glowStroke.Transparency = 0.6 + 0.25 * math.sin(t * 3)
			local s = 112 + 4 * math.sin(t * 2.4)
			logo.Size = UDim2.fromOffset(s, s)
			ringGrad.Rotation = (t * 240) % 360
			sweep.Offset = Vector2.new(((t * 0.9) % 2) - 1, 0)
		end
	end)

	local function fade(to, dur)
		pcall(function()
			TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = to }):Play()
		end)
	end

	gui.Parent = uiParent
	fade(0, 0.45) -- Smooth Fade In

	-- ---------------- API ----------------
	function L.step(frac, text)
		if not L.alive then return end
		if L.failed then -- โหลดต่อได้ ซ่อน Error
			L.failed = false
			btnRow.Visible = false
			status.TextColor3 = Color3.fromRGB(205, 220, 212)
			ringStroke.Color = Color3.fromRGB(255, 255, 255)
		end
		L.target = math.max(L.target, frac or 0)
		if text then L.stage = text status.Text = text end
		L.lastStep = os.clock()
	end

	function L.fail(msg)
		if not L.alive or L.done then return end
		L.failed = true
		status.TextColor3 = Color3.fromRGB(255, 90, 105)
		status.Text = "ERROR: " .. tostring(msg):sub(1, 140)
		btnRow.Visible = true
		glowStroke.Color = Color3.fromRGB(255, 90, 105)
	end

	function L.finish(checks)
		if not L.alive or L.done then return end
		task.spawn(function()
			-- Smooth: อย่างน้อย ~1.6 วินาทีรวม แต่ไม่หน่วงระบบอื่น (ระบบทำงานไปแล้ว)
			local left = 1.6 - (os.clock() - L.t0)
			if left > 0 then task.wait(left) end
			local okAll, bad = true, {}
			for name, ok in pairs(checks or {}) do
				if not ok then okAll = false bad[#bad + 1] = name end
			end
			if not okAll then
				L.fail("ตรวจสอบไม่ผ่าน: " .. table.concat(bad, ", "))
				return
			end
			L.target = 1
			L.done = true -- ตรวจสอบผ่านครบแล้ว ถึงอนุญาตให้แถบไปถึง 100%
			L.stage = "Preparing Main Interface"
			status.Text = L.stage
			local t1 = os.clock()
			while L.shown < 0.995 and os.clock() - t1 < 2 and L.alive do task.wait(0.05) end
			status.Text = "Loading Complete"
			task.wait(0.55)
			fade(1, 0.5) -- Smooth Fade Out
			task.wait(0.6)
			cleanup()
		end)
	end

	retryBtn.MouseButton1Click:Connect(function()
		local ok, genv = pcall(function() return getgenv() end)
		local rerun = ok and type(genv) == "table" and genv.__BALLKUN_RERUN or nil
		cleanup()
		if type(rerun) == "function" then
			task.defer(rerun)
		else
			__notify("BALL KUN", "ไม่พบฟังก์ชันรันซ้ำ กรุณารัน Loader ใหม่")
		end
	end)
	closeBtn.MouseButton1Click:Connect(function()
		L.done = true
		fade(1, 0.25)
		task.delay(0.3, cleanup)
	end)

	-- Watchdog: ป้องกัน Loading ค้างเงียบๆ
	task.spawn(function()
		while L.alive and not L.done do
			task.wait(1)
			if L.alive and not L.done and not L.failed and os.clock() - L.lastStep > 25 then
				L.fail("โหลดช้าผิดปกติที่ขั้น: " .. tostring(L.stage))
			end
		end
	end)

	return L
end)()
__Loading = Loading
Loading.step(0.06, "Initializing BALL KUN")

local Meta = {
	ScriptName = "BALL KUN Vv1",
	Credit = "BALL KUN",
	Creator = "BALL KUN",
	MapName = "MAHANAKHON RACING",
	PlaceId = 104549080643413,
	UniverseId = 10771935715,
	ConfigFile = "BALL_KUN_Vv1_MAHANAKHON_Config.json",
}
-- [v15] ไฟล์เซฟแยกตาม UserId (ไม่ให้หลายบัญชีทับกัน) / ยังอ่านไฟล์เก่าได้ถ้าไฟล์ใหม่ยังไม่มี
Meta.LegacyConfigFile = Meta.ConfigFile
Meta.ConfigFile = "BALL_KUN_Vv1_MAHANAKHON_" .. tostring(player and player.UserId or 0) .. "_Config.json"

local State = {
	CurrentJob = "ไรเดอร์ (Rider)",
	CompletedJobs = 0,
	SolvedFarmChecks = 0,
	WorkStatus = "ว่าง",
	AutoBuilder = false,
	AutoMechanic = false,
	RiderStatus = "พร้อมรับออเดอร์",
	RiderMode = "ทั้งหมด",
	AutoRiderDelivery = false,

	SelectedVehicle = "MAHANAKHON GT-R",
	MaxSpeedKmh = 180,
	CornerSpeedKmh = 85,
	NoCollisionSmartNav = true,
	PinNavMode = "auto", -- [v1.34] off | route | walk | drive | auto (ใช้กับหมุดจากระบบที่ไม่ได้นำทางเอง)
	NavVerifiedRuns = 0, -- [v1.34] จำนวนรอบขับตามหมุดที่ถึงจุดหมายจริงติดต่อกัน (ใช้เลื่อนสถานะ TEST -> ใช้งานจริง)
	StuckStopSeconds = 4,
	StuckResetSeconds = 12,
	AutoRefuel = false,
	RefuelBelowPercent = 30,
	AutoRepair = false,
	RepairBelowPercent = 45,

	AutoTuneECU = false,
	TuneVehicle = "MAHANAKHON GT-R",
	EcuMap = "Stage 2 - Street Pro",
	AutoDriveToTuner = false,
	EcuConsoleLog = "[ECU] พร้อมใช้งาน • รอคำสั่งจูนหรือขับไปร้านจูน",

	AutoBuyPiston = false,
	TargetPistonSize = "90 mm",
	MaxPistonsInBag = 5,
	AutoInstallPiston = false,
	HopBuyPiston = false,
	PistonsInBag = 0,
	PistonShopLog = "[PISTON] ขนาดเป้าหมาย: 90 mm • กระเป๋า: 0/5 ลูก",

	Language = "ไทย",
	ToggleKey = Enum.KeyCode.RightShift,
	BoostFPS = false,
	WalkMode = true,
	SafeStealthMode = true,
	AutoPanicOnSuspicious = true,
	LastEmojiPrompt = "รอคำถามทายอีโมจิ...",
	EmojiDelayMs = 650,
	EmojiPickFirstOnUnknown = true,
	AutoSaveConfig = true,

	StaffStatus = "ปลอดภัย (ไม่พบทีมงาน)",
	StaffDetection = true,
	AutoStopOnStaff = true,
	KickOnStaff = false,
	HopOnStaff = false,

	AutoExecOnHop = false,
	AutoRejoin = true,
	AutoResumeFarm = true,
	FarmWanted = false,
	StepDistanceStuds = 14,
	StepIntervalSec = 0.22,
	StealthExtraDelay = 1.4,
	WebhookUrl = "",
	BlockRemotes = true, -- ห้ามยิง RemoteEvent/RemoteFunction จากฟีเจอร์เดิม (ล็อกเป็น true ตลอด)
	AntiAFK = true,
	UIOpen = true,
}

local VehiclesList = { "MAHANAKHON GT-R", "Supra MK5 Street", "Civic Type-R FK8", "Pickup Delivery Truck", "City Scooter 155" }
local RiderModesList = { "ส่งอาหาร", "ส่งคน", "ทั้งหมด" }
local EcuMapsList = { "Stage 1 - Eco Boost", "Stage 2 - Street Pro", "Stage 3 - Track Race", "Custom Dyno Tune" }
local PistonSizesList = { "82 mm", "86 mm", "90 mm", "94 mm", "98 mm" }
local LanguagesList = { "ไทย", "English" }

local Theme = {
	BgMain = Color3.fromRGB(9, 13, 11),
	BgSidebar = Color3.fromRGB(13, 19, 16),
	BgCard = Color3.fromRGB(17, 25, 21),
	BgInput = Color3.fromRGB(11, 17, 14),
	BgViewport = Color3.fromRGB(12, 19, 15),
	GreenPrimary = Color3.fromRGB(16, 235, 130),
	GreenBright = Color3.fromRGB(72, 255, 168),
	GreenDark = Color3.fromRGB(12, 92, 54),
	GreenGlow = Color3.fromRGB(28, 175, 105),
	TextMain = Color3.fromRGB(232, 252, 241),
	TextMuted = Color3.fromRGB(134, 173, 153),
	Danger = Color3.fromRGB(255, 82, 108),
}

local function appendEcuLog(msg)
	local stamp = os.date("%H:%M:%S")
	State.EcuConsoleLog = "[" .. stamp .. "] " .. tostring(msg)
end

local function appendPistonLog(msg)
	local stamp = os.date("%H:%M:%S")
	State.PistonShopLog = "[" .. stamp .. "] " .. tostring(msg)
end

-- [v1.34] CollisionKeeper: จดค่า CanCollide เดิมก่อนปิด แล้วคืนค่าเดิมจริง (นับเจ้าของแยกกัน)
--  * จดเฉพาะชิ้นส่วนที่เดิม CanCollide = true เท่านั้น (ไม่เคยบังคับชิ้นที่เดิมเป็น false ให้เป็น true)
--  * คืนค่าเฉพาะชิ้นที่ยังเป็น false จากการแก้ของเรา (ถ้าเกม/Humanoid ปรับกลับไปแล้วจะไม่ไปทับ)
--  * เจ้าของหลายระบบ (nav / ghost) ใช้ชิ้นเดียวกันได้ จะคืนค่าเมื่อทุกเจ้าของปล่อยแล้วเท่านั้น
--  * ทะเบียนเก็บข้ามการรันซ้ำ (getgenv) เพื่อกู้ชิ้นที่ค้างจากรอบก่อนที่ปิดไม่สมบูรณ์
local CollisionKeeper = {}
do
	local store = nil
	pcall(function() store = (getgenv and getgenv()) or _G end)
	local reg = nil
	if type(store) == "table" then
		reg = store.__BK_COLLISION
		if type(reg) ~= "table" then
			reg = setmetatable({}, { __mode = "k" })
			store.__BK_COLLISION = reg
		end
	else
		reg = setmetatable({}, { __mode = "k" })
	end
	CollisionKeeper.saved = reg
	function CollisionKeeper.has(part)
		return reg[part] ~= nil
	end
	function CollisionKeeper.disable(part, owner)
		if typeof(part) ~= "Instance" or not part:IsA("BasePart") then return false end
		local rec = reg[part]
		if not rec then
			if not part.CanCollide then return false end
			rec = { owners = {} }
			reg[part] = rec
		end
		rec.owners[owner] = true
		if part.CanCollide then part.CanCollide = false end
		return true
	end
	function CollisionKeeper.release(owner)
		for part, rec in pairs(reg) do
			if rec.owners[owner] then
				rec.owners[owner] = nil
				if next(rec.owners) == nil then
					reg[part] = nil
					if part.Parent and part.CanCollide == false then
						pcall(function() part.CanCollide = true end)
					end
				end
			end
		end
	end
	function CollisionKeeper.count(owner)
		local n = 0
		for _, rec in pairs(reg) do
			if rec.owners[owner] then n = n + 1 end
		end
		return n
	end
end
-- กู้ชิ้นที่ค้างจากการรันครั้งก่อน และคืนค่าเมื่อหยุด/ปิดสคริปต์
CollisionKeeper.release("nav")
CollisionKeeper.release("ghost")
__bkHook(function()
	CollisionKeeper.release("nav")
	CollisionKeeper.release("ghost")
end)

local activeTween = nil
local isMovingStep = false
local lastPistonAttemptAt = 0
-- keepCollision = true: ใช้เฉพาะตอนเริ่มเคลื่อนที่ใหม่ (ห้ามคืน Collision ก่อนเริ่ม)
local function stopNavigation(keepCollision)
	isMovingStep = false
	if activeTween then
		pcall(function() activeTween:Cancel() end)
		activeTween = nil
	end
	if not keepCollision then
		pcall(CollisionKeeper.release, "nav")
	end
end

-- [v8] ถอดระบบดักจับและยิงซ้ำ Remote ออกทั้งหมด (ไม่ใช้ hookmetamethod, ไม่เรียก FireServer/InvokeServer)
-- เหตุผล: เป็นการข้ามขั้นตอนปกติของเกมและเสี่ยงโดนเตะ ฟังก์ชันด้านล่างคงชื่อไว้เพื่อให้โค้ดเดิมยังเรียกได้ แต่ไม่ทำอะไร
local remoteNoticeShown = false
local function invokeTargetedRemote(category, ...)
	if not remoteNoticeShown then
		remoteNoticeShown = true
		appendEcuLog("[ปิดใช้งาน] ฟีเจอร์ที่ต้องยิง Remote ถูกปิดถาวร (ใช้ได้เฉพาะการเดิน/กดปุ่มที่เกมเปิดให้)")
	end
	return false, "ปิดใช้งาน: ไม่เรียก Remote โดยตรง"
end

-- [v15] ตัวจัดการงานกลาง: Cancel() ตัดงานเก่าทันที (session id) + ล้าง connection + หยุดเดิน
local Runner = { SessionId = 0, Connections = {}, Persistent = {}, onCancel = {} }
-- JobBot จะลงทะเบียน stop hook ภายหลัง เพื่อให้ Cancel/STOP ALL หยุดงานนี้ด้วย
function Runner:Track(conn)
	self.Connections[#self.Connections + 1] = conn
	return conn
end
function Runner:TrackPersistent(conn)
	self.Persistent[#self.Persistent + 1] = conn
	return conn
end
local function disconnectAll(list)
	for i = #list, 1, -1 do
		local c = list[i]
		if c then pcall(function() c:Disconnect() end) end
		list[i] = nil
	end
end
function Runner:Cancel(reason)
	self.SessionId = self.SessionId + 1
	disconnectAll(self.Connections)
	pcall(stopNavigation)
	for _, fn in ipairs(self.onCancel) do pcall(fn, reason) end
end
function Runner:Destroy()
	self:Cancel("destroy")
	disconnectAll(self.Persistent)
end
__bkHook(function() pcall(function() Runner:Destroy() end) end)

local EmergencyStopHooks = {}
local function triggerEmergencyStop(reasonText)
	for _, stopFn in ipairs(EmergencyStopHooks) do pcall(stopFn, reasonText or "STOP ALL") end
	State.AutoBuilder = false
	State.AutoMechanic = false
	State.AutoRiderDelivery = false
	State.AutoDriveToTuner = false
	State.AutoTuneECU = false
	State.AutoBuyPiston = false
	State.HopBuyPiston = false
	State.WorkStatus = "ว่าง (หยุดฉุกเฉิน)"
	pcall(function() BKPin.clear() end)
	Runner:Cancel("emergency")
	appendEcuLog("หยุดระบบอัตโนมัติทั้งหมด: " .. tostring(reasonText))
end

local function getHttpRequestFunc()
	if type(request) == "function" then return request end
	if type(http_request) == "function" then return http_request end
	if type(http) == "table" and type(http.request) == "function" then return http.request end
	if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
	if type(fluxus) == "table" and type(fluxus.request) == "function" then return fluxus.request end
	return nil
end

local function sendWebhook(titleText, descText)
	local url = (State.WebhookUrl or ""):match("^%s*(.-)%s*$") or ""
	if url == "" then return false, "ยังไม่ได้กรอก Webhook URL" end
	local reqFunc = getHttpRequestFunc()
	if not reqFunc then return false, "ตัวรันไม่รองรับ HTTP Request" end
	local ok, err = pcall(function()
		reqFunc({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				username = Meta.ScriptName .. " | " .. Meta.MapName,
				embeds = {{
					title = titleText,
					description = descText,
					color = 1174290,
					footer = { text = "เครดิต: " .. Meta.Credit .. " • ผู้สร้าง: " .. Meta.Creator },
					timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				}},
			}),
		})
	end)
	return ok, ok and "ส่ง Webhook สำเร็จ" or ("ส่งไม่สำเร็จ: " .. tostring(err))
end

local function saveConfigToFile()
	if type(writefile) ~= "function" then return false end
	local serializable = {
		CurrentJob = State.CurrentJob,
		AutoBuilder = State.AutoBuilder,
		AutoMechanic = State.AutoMechanic,
		RiderMode = State.RiderMode,
		AutoRiderDelivery = State.AutoRiderDelivery,
		SelectedVehicle = State.SelectedVehicle,
		MaxSpeedKmh = State.MaxSpeedKmh,
		CornerSpeedKmh = State.CornerSpeedKmh,
		NoCollisionSmartNav = State.NoCollisionSmartNav,
		PinNavMode = State.PinNavMode,
		NavVerifiedRuns = State.NavVerifiedRuns,
		StuckStopSeconds = State.StuckStopSeconds,
		StuckResetSeconds = State.StuckResetSeconds,
		AutoRefuel = State.AutoRefuel,
		RefuelBelowPercent = State.RefuelBelowPercent,
		AutoRepair = State.AutoRepair,
		RepairBelowPercent = State.RepairBelowPercent,
		AutoTuneECU = State.AutoTuneECU,
		TuneVehicle = State.TuneVehicle,
		EcuMap = State.EcuMap,
		AutoDriveToTuner = State.AutoDriveToTuner,
		AutoBuyPiston = State.AutoBuyPiston,
		TargetPistonSize = State.TargetPistonSize,
		MaxPistonsInBag = State.MaxPistonsInBag,
		AutoInstallPiston = State.AutoInstallPiston,
		HopBuyPiston = State.HopBuyPiston,
		Language = State.Language,
		ToggleKeyName = State.ToggleKey.Name,
		BoostFPS = State.BoostFPS,
		SafeStealthMode = State.SafeStealthMode,
		AutoPanicOnSuspicious = State.AutoPanicOnSuspicious,
		EmojiDelayMs = State.EmojiDelayMs,
		EmojiPickFirstOnUnknown = State.EmojiPickFirstOnUnknown,
		AutoSaveConfig = State.AutoSaveConfig,
		StaffDetection = State.StaffDetection,
		AutoStopOnStaff = State.AutoStopOnStaff,
		KickOnStaff = State.KickOnStaff,
		HopOnStaff = State.HopOnStaff,
		AutoExecOnHop = State.AutoExecOnHop,
		AutoRejoin = State.AutoRejoin,
		AutoResumeFarm = State.AutoResumeFarm,
		FarmWanted = State.FarmWanted,
		WebhookUrl = State.WebhookUrl,
		StepDistanceStuds = State.StepDistanceStuds,
		StepIntervalSec = State.StepIntervalSec,
		StealthExtraDelay = State.StealthExtraDelay,
	}
	local ok = pcall(writefile, Meta.ConfigFile, HttpService:JSONEncode(serializable))
	return ok
end

local function loadConfigFromFile()
	if type(isfile) ~= "function" or type(readfile) ~= "function" then return false end
	local cfgFile = Meta.ConfigFile
	local exists = false
	pcall(function() exists = isfile(cfgFile) end)
	if not exists and Meta.LegacyConfigFile then
		pcall(function() exists = isfile(Meta.LegacyConfigFile) end)
		if exists then cfgFile = Meta.LegacyConfigFile end
	end
	if not exists then return false end
	local raw = nil
	pcall(function() raw = readfile(cfgFile) end)
	if type(raw) ~= "string" or raw == "" then return false end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and type(decoded) == "table" then
		for k, v in pairs(decoded) do
			if k == "ToggleKeyName" and type(v) == "string" and Enum.KeyCode[v] then
				State.ToggleKey = Enum.KeyCode[v]
			elseif State[k] ~= nil then
				State[k] = v
			end
		end
		return true
	end
	return false
end

pcall(loadConfigFromFile)
Loading.step(0.22, "Loading Configuration")

local function dumpMapRemotesAndGuis()
	pcall(function()
		print("==========================================")
		print("[BALL KUN Vv1] DUMP REMOTE EVENTS & GUIs - " .. Meta.MapName)
		for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
			if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
				print(string.format("[%s] %s", obj.ClassName, obj:GetFullName()))
			end
		end
		if playerGui then
			for _, guiObj in ipairs(playerGui:GetChildren()) do
				if guiObj:IsA("ScreenGui") then
					print(string.format("[ScreenGui] %s (Enabled=%s)", guiObj.Name, tostring(guiObj.Enabled)))
				end
			end
		end
		print("==========================================")
	end)
	appendEcuLog("Dump รายชื่อ Remote ลง Console แล้ว (กด F9 เพื่อดู)")
end

pcall(function()
	__bkTrack(player.Idled:Connect(function()
		if State.AntiAFK and okVU and VirtualUser then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end))
end)

local function hopServerNow(reason)
	if State.AutoExecOnHop then
		local qFunc = (type(queue_on_teleport) == "function" and queue_on_teleport)
			or (type(queueonteleport) == "function" and queueonteleport)
			or (syn and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
			or (fluxus and type(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)
		if qFunc then
			-- [v21] ไม่ดึงโค้ดจาก Gist ภายนอกแล้ว: รันซ้ำจากไฟล์ในเครื่องที่ loader บันทึกไว้ (ถ้าไม่มีไฟล์ก็ไม่ตั้งรันซ้ำ)
			local localFile = "BallKun_v1_35_src.lua"
			local haveFile = false
			pcall(function() haveFile = type(isfile) == "function" and isfile(localFile) end)
			if haveFile then
				pcall(qFunc, string.format('pcall(function() loadstring(readfile("%s"))() end)', localFile))
			end
		end
	end
	pcall(function()
		sendWebhook("Hop Server | " .. Meta.ScriptName, "เหตุผล: " .. tostring(reason) .. "\nผู้เล่น: " .. player.Name)
	end)
	pcall(function()
		TeleportService:Teleport(Meta.PlaceId, player)
	end)
end

local guiRootName = "BALL_KUN_Vv1_Mahanakhon_UI"

local function getCharacterParts()
	local char = player.Character
	if not char then return nil, nil, nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	return char, hrp, hum
end

-- [v9] แคชวัตถุใน Workspace แบบใช้เหตุการณ์ (DescendantAdded/Removing) แทนการวน GetDescendants() ทุกครั้ง
local WorldCache = {
	sets = { all = {}, prompt = {}, seat = {} },
	arrays = {}, built = {},
	dirty = { all = true, prompt = true, seat = true },
	minGap = { all = 5, prompt = 0.5, seat = 0.5 }, -- ระยะเวลาขั้นต่ำก่อนสร้างลิสต์ใหม่ (วินาที)
	started = false,
	names = setmetatable({}, { __mode = "k" }),
	boostConn = nil,
}
function WorldCache.track(o, add)
	local v = add and true or nil
	local c = WorldCache
	if o:IsA("ProximityPrompt") then
		c.sets.prompt[o] = v; c.dirty.prompt = true
	elseif o:IsA("VehicleSeat") then
		c.sets.seat[o] = v; c.dirty.seat = true
	end
	if o:IsA("BasePart") or o:IsA("Model") or o:IsA("ProximityPrompt") then
		c.sets.all[o] = v; c.dirty.all = true
	end
end
function WorldCache.start()
	if WorldCache.started then return end
	for _, o in ipairs(workspace:GetDescendants()) do WorldCache.track(o, true) end
	WorldCache.addConn = __bkTrack(workspace.DescendantAdded:Connect(function(o) WorldCache.track(o, true) end))
	WorldCache.remConn = __bkTrack(workspace.DescendantRemoving:Connect(function(o) WorldCache.track(o, false) end))
	WorldCache.started = true
end
-- คืนลิสต์วัตถุตามชนิด ("all" / "prompt" / "seat"); ถ้าแคชพัง จะถอยกลับไปสแกนเต็มแบบเดิม
function WorldCache.list(kind)
	local c = WorldCache
	if not c.started then
		local ok = pcall(c.start)
		if not ok then return workspace:GetDescendants() end
	end
	local arr = c.arrays[kind]
	local now = os.clock()
	if c.dirty[kind] and (not arr or now - (c.built[kind] or 0) >= c.minGap[kind]) then
		arr = {}
		for o in pairs(c.sets[kind]) do arr[#arr + 1] = o end
		c.arrays[kind] = arr; c.built[kind] = now; c.dirty[kind] = false
	end
	return arr or {}
end
function WorldCache.fullLow(o)
	local e = WorldCache.names[o]
	local now = os.clock()
	if e and now - e.t < 30 then return e.v end
	local v = o:GetFullName():lower()
	WorldCache.names[o] = { t = now, v = v }
	return v
end
-- ปรับแต่งวัตถุเดียวสำหรับโหมดเพิ่ม FPS
function WorldCache.applyBoost(obj)
	pcall(function()
		if obj:IsA("BasePart") and obj.Parent and not obj.Parent:FindFirstChildOfClass("Humanoid") then
			obj.Material = Enum.Material.SmoothPlastic
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
			obj.Enabled = false
		end
	end)
end

local function getPlayerVehicle()
	local char, hrp, hum = getCharacterParts()
	if not char then return nil, nil, nil end
	if hum and hum.SeatPart then
		local seat = hum.SeatPart
		local model = seat:FindFirstAncestorOfClass("Model")
		if model then
			return model, model.PrimaryPart or seat, seat
		end
	end
	for _, obj in ipairs(WorldCache.list("seat")) do
		if obj.Parent and obj:IsA("VehicleSeat") and obj.Occupant == hum then
			local model = obj:FindFirstAncestorOfClass("Model")
			return model, (model and model.PrimaryPart) or obj, obj
		end
	end
	return nil, nil, nil
end

-- [v12] ข้อความที่ห้ามโต้ตอบอัตโนมัติ (โดเนท/ซื้อด้วย Robux/วาป/ถอดชุด/ออกกะ) กันกดผิดจุด
local BLOCKED_WORDS = {
	"donate", "โดเนท", "บริจาค", "robux", "gamepass", "premium",
	"get ฿", "teleport", "เทเลพอร์ต", "วาป",
	"ถอดชุด", "clock out", "ออกกะ",
	"เติมเงิน", "top up", "topup", -- [v13] ปุ่ม + ข้าง CASH
}
local function isBlockedText(t)
	local low = tostring(t or ""):lower()
	for _, w in ipairs(BLOCKED_WORDS) do
		if low:find(w, 1, true) then return true, w end
	end
	return false
end

local function firePromptSafe(prompt)
	if prompt and prompt:IsA("ProximityPrompt") and isBlockedText((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "")) then
		return false
	end
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
	if type(fireproximityprompt) == "function" then
		pcall(fireproximityprompt, prompt)
		return true
	end
	pcall(function()
		prompt:InputHoldBegin()
		task.wait(math.max(prompt.HoldDuration or 0.1, 0.05))
		prompt:InputHoldEnd()
	end)
	return true
end

local function clickGuiButtonSafe(btn)
	if btn then
		local okT, txt = pcall(function() return btn.Text end)
		if isBlockedText((okT and txt or "") .. " " .. btn.Name) then return false end
	end
	if not btn or not btn:IsA("GuiButton") or not btn.Visible then return false end
	if type(firesignal) == "function" then
		pcall(firesignal, btn.MouseButton1Click)
		pcall(firesignal, btn.Activated)
		return true
	end
	return false
end

local function findNearestObjectByKeywords(keywords, maxDist)
	local _, hrp = getCharacterParts()
	if not hrp then return nil, nil end
	local bestObj, bestPos, bestDist = nil, nil, maxDist or 3000

	for _, obj in ipairs(WorldCache.list("all")) do
		local nameLow = obj.Name:lower()
		local fullLow = WorldCache.fullLow(obj)
		local matched = false
		for _, kw in ipairs(keywords) do
			if nameLow:find(kw, 1, true) or fullLow:find(kw, 1, true) then
				matched = true
				break
			end
		end
		if matched and obj.Parent then
			local pos = nil
			if obj:IsA("BasePart") then
				pos = obj.Position
			elseif obj:IsA("Model") then
				local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
				if p then pos = p.Position end
			elseif obj:IsA("ProximityPrompt") and obj.Parent and obj.Parent:IsA("BasePart") then
				pos = obj.Parent.Position
			end
			if pos then
				local d = (pos - hrp.Position).Magnitude
				if d < bestDist then
					bestDist = d
					bestObj = obj
					bestPos = pos
				end
			end
		end
	end
	return bestObj, bestPos, bestDist
end

local function moveToPositionTween(targetPos, speedKmh)
	local char, hrp = getCharacterParts()
	if not char or not hrp or not targetPos then return false end

	local vehModel, vehRoot = getPlayerVehicle()
	local movePart = vehRoot or hrp
	local dist = (targetPos - movePart.Position).Magnitude
	if dist <= 12 then
		stopNavigation()
		return true
	end

	if State.NoCollisionSmartNav then
		for _, part in ipairs(char:GetDescendants()) do
			CollisionKeeper.disable(part, "nav")
		end
		if vehModel then
			for _, part in ipairs(vehModel:GetDescendants()) do
				CollisionKeeper.disable(part, "nav")
			end
		end
	else
		CollisionKeeper.release("nav")
	end

	local studsPerSec = math.clamp((speedKmh or 150) * 0.9, 45, 320)
	local duration = math.clamp(dist / studsPerSec, 0.15, 18)
	local targetCF = CFrame.new(targetPos + Vector3.new(0, 3, 0))

	stopNavigation(true)
	local ti = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	local targetInst = (vehModel and vehModel.PrimaryPart) or hrp
	local thisTween = TweenService:Create(targetInst, ti, { CFrame = targetCF })
	activeTween = thisTween
	thisTween.Completed:Connect(function()
		-- คืน Collision เมื่อ Tween นี้จบเอง (Tween เก่าที่ถูกยกเลิกจะไม่มาคืนทับ Tween ใหม่)
		if activeTween == thisTween or activeTween == nil then
			pcall(CollisionKeeper.release, "nav")
		end
	end)
	thisTween:Play()
	return false
end

-- เคลื่อนที่ทีละสเต็ปสั้นๆ (จากระบบโหมดระวังตัว)
local function moveToPositionStep(targetPos, speedKmh)
	if isMovingStep or not targetPos then
		return false
	end
	local char, hrp = getCharacterParts()
	if not char or not hrp then
		return false
	end
	local vehModel, vehRoot = getPlayerVehicle()
	local movePart = vehRoot or hrp
	local dist = (targetPos - movePart.Position).Magnitude
	if dist <= 11 then
		stopNavigation()
		return true
	end

	if State.NoCollisionSmartNav then
		for _, part in ipairs(char:GetDescendants()) do
			CollisionKeeper.disable(part, "nav")
		end
		if vehModel then
			for _, part in ipairs(vehModel:GetDescendants()) do
				CollisionKeeper.disable(part, "nav")
			end
		end
	end

	isMovingStep = true
	local ok, arrived = pcall(function()
		while movePart and movePart.Parent and isMovingStep do
			local cur = movePart.Position
			local delta = targetPos - cur
			local remain = delta.Magnitude
			if remain <= 11 then
				return true
			end

			local maxStep = math.max(5, tonumber(State.StepDistanceStuds) or 14)
			local stepLen = math.min(maxStep, remain)
			local nextPos = cur + (delta.Unit * stepLen)
			local lookPos = Vector3.new(targetPos.X, nextPos.Y, targetPos.Z)

			local spd = math.clamp(tonumber(speedKmh or State.MaxSpeedKmh) or 100, 35, 160)
			local stepDelay = math.clamp((stepLen / (spd * 0.65)), 0.08, 0.45)
			if State.SafeStealthMode then
				stepDelay = stepDelay + (tonumber(State.StepIntervalSec) or 0.22) * 0.5
			end

			movePart.AssemblyLinearVelocity = Vector3.zero
			movePart.AssemblyAngularVelocity = Vector3.zero
			movePart.CFrame = CFrame.lookAt(nextPos, lookPos)
			task.wait(stepDelay)
		end
		return false
	end)
	isMovingStep = false
	pcall(CollisionKeeper.release, "nav")
	return ok and arrived
end

-- เลือกโหมดเดิน: โหมดระวังตัว = ทีละสเต็ป / ปกติ = Tween เดิม
local WalkBridge = {} -- filled by MAP ADAPTIVE: walk instead of teleport
Runner.onCancel[#Runner.onCancel + 1] = function(reason)
	if WalkBridge.stop then WalkBridge.stop(reason) end
end
local function moveToPositionSmart(targetPos, speedKmh)
	-- [v12] ตัดการเลื่อน CFrame/ทีเวนตัวละครและยานพาหนะออก (เสี่ยงถูกระบบตรวจจับ "บิน/ลอย" ของเกมเตะ)
	if getPlayerVehicle() then
		State.RiderStatus = "ระบบเดิมไม่เคลื่อนรถด้วยการวาป/ลอย: ใช้ AUTO RIDER ของ MAP ADAPTIVE (ขับจริง) หรือลงจากรถ"
		return false
	end
	if WalkBridge.walkTo then
		return WalkBridge.walkTo(targetPos)
	end
	State.RiderStatus = "ยังไม่พร้อมเดิน (MAP ADAPTIVE ยังไม่เริ่ม)"
	return false
end

local function interactWithNearbyPrompts(keywords, radius)
	local _, hrp = getCharacterParts()
	if not hrp then return false end
	local triggered = false
	for _, obj in ipairs(WorldCache.list("prompt")) do
		if obj.Parent and obj:IsA("ProximityPrompt") and obj.Enabled then
			local parentPart = obj.Parent and (obj.Parent:IsA("BasePart") and obj.Parent or obj.Parent:FindFirstAncestorWhichIsA("BasePart"))
			if parentPart and (parentPart.Position - hrp.Position).Magnitude <= (radius or 22) then
				local txt = (obj.ActionText .. " " .. obj.ObjectText .. " " .. obj:GetFullName()):lower()
				if not keywords or #keywords == 0 then
					firePromptSafe(obj)
					triggered = true
				else
					for _, kw in ipairs(keywords) do
						if txt:find(kw, 1, true) then
							firePromptSafe(obj)
							triggered = true
							break
						end
					end
				end
			end
		end
	end
	return triggered
end

local function autoClickGameGuiButtons(keywords)
	if not playerGui then return false end
	local clicked = false
	for _, sg in ipairs(playerGui:GetChildren()) do
		if sg:IsA("ScreenGui") and sg.Name ~= guiRootName and sg.Enabled then
			for _, btn in ipairs(sg:GetDescendants()) do
				if btn:IsA("TextButton") and btn.Visible then
					local tLow = (btn.Text .. " " .. btn.Name):lower()
					for _, kw in ipairs(keywords) do
						if tLow:find(kw, 1, true) then
							if clickGuiButtonSafe(btn) then
								clicked = true
							end
							break
						end
					end
				end
			end
		end
	end
	return clicked
end

local lastSolvedStamp = 0
local lastCheckAlertAt = -1000
-- [v1.32] เจอหน้าตรวจสอบผู้เล่นของเกม (FarmCheck/ยืนยันตัวตน): ไม่กดตอบแทนอีกต่อไป
-- หยุดทุกระบบอัตโนมัติ แจ้งเตือน แล้วให้ผู้เล่นตอบเอง จากนั้นค่อยเปิดระบบใหม่
local function checkAndSolveEmojiCaptcha()
	if not playerGui then return false end
	if (tick() - lastSolvedStamp) < 2.5 then return false end

	for _, sg in ipairs(playerGui:GetChildren()) do
		if sg:IsA("ScreenGui") and sg.Name ~= guiRootName and sg.Enabled then
			local promptText = nil
			local optionCount = 0
			for _, desc in ipairs(sg:GetDescendants()) do
				if desc:IsA("TextLabel") and desc.Visible then
					local txt = tostring(desc.Text)
					if txt:find("อีโมจิ") or txt:lower():find("emoji") or txt:lower():find("captcha") or txt:lower():find("verify") or txt:find("เลือกภาพ") or txt:find("กดรูป") then
						promptText = txt
					end
				elseif desc:IsA("TextButton") or desc:IsA("ImageButton") then
					if desc.Visible and desc.AbsoluteSize.X >= 28 and desc.AbsoluteSize.Y >= 28 then
						optionCount = optionCount + 1
					end
				end
			end

			if promptText and optionCount >= 2 then
				lastSolvedStamp = tick()
				State.LastEmojiPrompt = promptText:gsub("\n", " "):sub(1, 45)
				if (tick() - lastCheckAlertAt) > 30 then
					lastCheckAlertAt = tick()
					State.SolvedFarmChecks = State.SolvedFarmChecks + 1 -- นับจำนวนครั้งที่พบ (ไม่ใช่ที่แก้)
					pcall(triggerEmergencyStop, "พบหน้าตรวจสอบผู้เล่นของเกม - หยุดให้ตอบเอง")
					pcall(__notify, "พบหน้าตรวจสอบผู้เล่น", "หยุดระบบอัตโนมัติแล้ว กรุณาตอบเอง แล้วค่อยเปิดระบบใหม่")
				end
				return true
			end
		end
	end
	return false
end

local lastCheckPos = nil
local stuckTimer = 0
local function processAntiStuck(dt)
	local isMovingJob = State.AutoRiderDelivery or State.AutoBuilder or State.AutoMechanic or State.AutoDriveToTuner or State.AutoBuyPiston
	if not isMovingJob then
		stuckTimer = 0
		lastCheckPos = nil
		return
	end
	-- [v9] โหมดเดิน (WalkNav) มีระบบตรวจติดขัดของตัวเอง จึงไม่ยุ่งซ้ำ
	if State.WalkMode then
		stuckTimer = 0
		lastCheckPos = nil
		return
	end
	local _, hrp = getCharacterParts()
	if not hrp then return end

	if lastCheckPos then
		local moved = (hrp.Position - lastCheckPos).Magnitude
		if moved < 2.5 then
			stuckTimer = stuckTimer + dt
			if stuckTimer >= State.StuckResetSeconds then
				stuckTimer = 0
				stopNavigation()
				-- [v9] ไม่ดีดตัวละครขึ้นแล้ว: หยุดนำทางและให้ลูปหลักคำนวณใหม่
			elseif stuckTimer >= State.StuckStopSeconds then
				stopNavigation()
				-- [v9] ไม่วาร์ปถอยแล้ว: หยุดนำทางและให้ลูปหลักคำนวณใหม่
			end
		else
			stuckTimer = 0
		end
	end
	lastCheckPos = hrp.Position
end

-- [v8] ไม่กวาดยิง Remote ตามชื่ออีกต่อไป คืนค่า 0 เสมอ
local function fireMatchingRemotes(keywords, arg1, arg2)
	return 0
end

-- [v8] คงชื่อฟังก์ชันไว้เพื่อความเข้ากันได้ (ไม่ส่ง Remote จริง)
local function fireRemotesSmart(category, keywords, arg1, arg2)
	local ok = invokeTargetedRemote(category, arg1, arg2)
	if ok then
		return 1
	end
	return fireMatchingRemotes(keywords, arg1, arg2)
end

pcall(function()
	if uiParent:FindFirstChild(guiRootName) then
		uiParent[guiRootName]:Destroy()
	end
end)
pcall(function()
	if playerGui and playerGui:FindFirstChild(guiRootName) then
		playerGui[guiRootName]:Destroy()
	end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = guiRootName
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
screenGui.Parent = uiParent
Loading.step(0.36, "Loading UI Components")

local uiScale = Instance.new("UIScale")
uiScale.Name = "AutoResponsiveScale"
uiScale.Parent = screenGui

local camConn = nil
local function updateResponsiveScale()
	local cam = workspace.CurrentCamera
	local vpSize = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local minDim = math.min(vpSize.X, vpSize.Y)
	local scaleVal = 1
	if vpSize.X < 700 or minDim < 460 then
		scaleVal = math.clamp(math.min(vpSize.X / 840, vpSize.Y / 560), 0.55, 0.92)
	elseif vpSize.X < 1024 then
		scaleVal = math.clamp(math.min(vpSize.X / 960, vpSize.Y / 620), 0.72, 1)
	end
	uiScale.Scale = scaleVal
	if cam and not camConn then
		camConn = Runner:TrackPersistent(cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale))
	end
end
updateResponsiveScale()
Runner:TrackPersistent(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	updateResponsiveScale()
end))

local function addCorner(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
	return c
end

local function addStroke(inst, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function makeDraggable(guiObject)
	local dragging = false
	local dragInput, dragStart, startPos

	guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = guiObject.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	guiObject.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	__bkTrack(UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			local sc = uiScale.Scale > 0 and uiScale.Scale or 1
			guiObject.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + (delta.X / sc),
				startPos.Y.Scale,
				startPos.Y.Offset + (delta.Y / sc)
			)
		end
	end))
end

local floatingBtn = Instance.new("TextButton")
floatingBtn.Name = "FloatingToggleButton"
floatingBtn.Size = UDim2.fromOffset(64, 64)
floatingBtn.Position = UDim2.new(0.02, 0, 0.42, 0)
floatingBtn.BackgroundColor3 = Theme.BgCard
floatingBtn.TextColor3 = Theme.GreenBright
floatingBtn.Font = Enum.Font.GothamBold
floatingBtn.TextSize = 12
floatingBtn.TextWrapped = true
floatingBtn.Text = "BALL KUN\nVv1"
floatingBtn.BorderSizePixel = 0
floatingBtn.ZIndex = 20
floatingBtn.Parent = screenGui
addCorner(floatingBtn, 16)
addStroke(floatingBtn, Theme.GreenPrimary, 2, 0.05)
makeDraggable(floatingBtn)
if COVER_IMAGE then
	floatingBtn.Text = ""
	local fbImg = Instance.new("ImageLabel")
	fbImg.Size = UDim2.fromScale(1, 1)
	fbImg.BackgroundTransparency = 1
	fbImg.Image = COVER_IMAGE
	fbImg.ScaleType = Enum.ScaleType.Crop
	fbImg.ZIndex = 21
	fbImg.Parent = floatingBtn
	addCorner(fbImg, 16)
end

-- [v18] รูปปกสคริปต์ (พื้นหลัง UI). ถ้า Executor ไม่รองรับ writefile/getcustomasset จะข้ามไปเอง
-- [v1.28] ใส่ลิงก์รูปของคุณที่นี่ (หรือสั่งก่อนรัน: getgenv().BALLKUN_IMAGE_URL = "https://...") ต้องเป็นไฟล์ภาพ PNG/JPG ตรง ๆ
-- ลำดับการใช้รูป: ลิงก์ของคุณ > COVER_ASSET_ID > รูปที่ฝังมา
local COVER_IMAGE_URL = ""
local function __loadUserCover(url)
	pcall(function()
		local g = getgenv()
		if (not url or url == "") and type(g) == "table" and type(g.BALLKUN_IMAGE_URL) == "string" then url = g.BALLKUN_IMAGE_URL end
	end)
	if not url or url == "" then return nil end
	if type(writefile) ~= "function" or type(getcustomasset) ~= "function" then return nil end
	local body
	local reqf = (syn and syn.request) or http_request or request
	if reqf then
		local ok, res = pcall(reqf, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and type(res.Body) == "string" and (res.StatusCode == nil or res.StatusCode == 200) then body = res.Body end
	end
	if not body then
		local ok, b = pcall(function() return game:HttpGet(url) end)
		if ok and type(b) == "string" then body = b end
	end
	-- ต้องเป็นไฟล์ภาพจริง (PNG หรือ JPEG) ไม่ใช่หน้าเว็บ/ข้อความผิดพลาด
	if not body or #body < 200 then return nil end
	local isPng = body:sub(1, 4) == "\137PNG"
	local isJpg = body:byte(1) == 255 and body:byte(2) == 216
	if not (isPng or isJpg) then return nil end
	local path = "BALL_KUN_Vv1_cover_user." .. (isPng and "png" or "jpg")
	local okW = pcall(writefile, path, body)
	if not okW then return nil end
	local okA, asset = pcall(getcustomasset, path)
	if okA and type(asset) == "string" and asset ~= "" then return asset end
	return nil
end
local COVER_ASSET_ID = ""  -- ใส่เลข rbxassetid ของรูปตัวเองที่นี่ได้ (ถ้ามี) จะใช้แทนรูปที่ฝังไว้
local COVER_IMAGE = (function()
	local userImg = __loadUserCover(COVER_IMAGE_URL)
	if userImg then return userImg end
	if COVER_ASSET_ID ~= "" then return "rbxassetid://" .. tostring(COVER_ASSET_ID) end
	if type(writefile) ~= "function" or type(getcustomasset) ~= "function" then return nil end
	local ok, res = pcall(function()
		local DATA = [=[
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
]=]
		local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
		local map = {}
		for i = 1, 64 do map[chars:byte(i)] = i - 1 end
		DATA = DATA:gsub("[^A-Za-z0-9%+/]", "")
		local out, n = {}, #DATA
		for i = 1, n, 4 do
			local c1, c2, c3, c4 = DATA:byte(i, i + 3)
			local v1, v2 = map[c1], map[c2]
			local v3 = c3 and map[c3]
			local v4 = c4 and map[c4]
			local num = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
			local b1 = math.floor(num / 65536)
			local b2 = math.floor(num / 256) % 256
			local b3 = num % 256
			if v4 then out[#out + 1] = string.char(b1, b2, b3)
			elseif v3 then out[#out + 1] = string.char(b1, b2)
			else out[#out + 1] = string.char(b1) end
		end
		local path = "BALL_KUN_Vv1_cover.jpg"
		writefile(path, table.concat(out))
		return getcustomasset(path)
	end)
	if ok and type(res) == "string" and res ~= "" then return res end
	return nil
end)()

local mainWindow = Instance.new("Frame")
mainWindow.Name = "MainWindow"
mainWindow.Size = UDim2.fromOffset(820, 520)
mainWindow.Position = UDim2.new(0.5, -410, 0.5, -260)
mainWindow.BackgroundColor3 = Theme.BgMain
mainWindow.BorderSizePixel = 0
mainWindow.Parent = screenGui
addCorner(mainWindow, 14)
addStroke(mainWindow, Theme.GreenPrimary, 1.6, 0.12)

if COVER_IMAGE then
	local bgArt = Instance.new("ImageLabel")
	bgArt.Name = "BgArt"
	bgArt.Size = UDim2.fromScale(1, 1)
	bgArt.BackgroundTransparency = 1
	bgArt.Image = COVER_IMAGE
	bgArt.ScaleType = Enum.ScaleType.Crop
	bgArt.ImageTransparency = 0.72
	bgArt.ZIndex = 0
	bgArt.Parent = mainWindow
	addCorner(bgArt, 14)
end

local topHeader = Instance.new("Frame")
topHeader.Name = "TopHeader"
topHeader.Size = UDim2.new(1, -16, 0, 48)
topHeader.Position = UDim2.fromOffset(8, 8)
topHeader.BackgroundColor3 = Theme.BgSidebar
topHeader.BackgroundTransparency = COVER_IMAGE and 0.08 or 0
topHeader.BorderSizePixel = 0
topHeader.Parent = mainWindow
addCorner(topHeader, 10)
addStroke(topHeader, Theme.GreenGlow, 1, 0.45)
makeDraggable(mainWindow)

local logoAccent = Instance.new("Frame")
logoAccent.Size = UDim2.fromOffset(5, 28)
logoAccent.Position = UDim2.fromOffset(12, 10)
logoAccent.BackgroundColor3 = Theme.GreenPrimary
logoAccent.BorderSizePixel = 0
logoAccent.Parent = topHeader
addCorner(logoAccent, 3)

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(0.56, -24, 1, 0)
headerTitle.Position = UDim2.fromOffset(24, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 14
headerTitle.TextColor3 = Theme.TextMain
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Text = string.format("%s  •  %s", Meta.ScriptName, Meta.MapName)
headerTitle.Parent = topHeader

local panicBtn = Instance.new("TextButton")
panicBtn.Size = UDim2.fromOffset(92, 26)
panicBtn.Position = UDim2.new(1, -254, 0.5, -13)
panicBtn.BackgroundColor3 = Theme.Danger
panicBtn.TextColor3 = Theme.TextMain
panicBtn.Font = Enum.Font.GothamBold
panicBtn.TextSize = 10
panicBtn.Text = "STOP ALL"
panicBtn.BorderSizePixel = 0
panicBtn.Parent = topHeader
addCorner(panicBtn, 7)

local antiAfkPill = Instance.new("TextLabel")
antiAfkPill.Size = UDim2.fromOffset(118, 26)
antiAfkPill.Position = UDim2.new(1, -156, 0.5, -13)
antiAfkPill.BackgroundColor3 = Theme.GreenDark
antiAfkPill.TextColor3 = Theme.GreenBright
antiAfkPill.Font = Enum.Font.GothamBold
antiAfkPill.TextSize = 11
antiAfkPill.Text = "ANTI-AFK: ON"
antiAfkPill.Parent = topHeader
addCorner(antiAfkPill, 7)
addStroke(antiAfkPill, Theme.GreenPrimary, 1, 0.3)

local closeWinBtn = Instance.new("TextButton")
closeWinBtn.Size = UDim2.fromOffset(28, 28)
closeWinBtn.Position = UDim2.new(1, -34, 0.5, -14)
closeWinBtn.BackgroundColor3 = Theme.GreenPrimary
closeWinBtn.TextColor3 = Theme.BgMain
closeWinBtn.Font = Enum.Font.GothamBold
closeWinBtn.TextSize = 14
closeWinBtn.Text = "×"
closeWinBtn.BorderSizePixel = 0
closeWinBtn.Parent = topHeader
addCorner(closeWinBtn, 7)

local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.fromOffset(215, 448)
sidebar.Position = UDim2.fromOffset(8, 64)
sidebar.BackgroundColor3 = Theme.BgSidebar
sidebar.BackgroundTransparency = COVER_IMAGE and 0.1 or 0
sidebar.BorderSizePixel = 0
sidebar.Parent = mainWindow
addCorner(sidebar, 12)
addStroke(sidebar, Theme.GreenGlow, 1, 0.45)

local charBox = Instance.new("Frame")
charBox.Name = "PlayerCharacterBox"
charBox.Size = UDim2.new(1, -16, 0, 178)
charBox.Position = UDim2.fromOffset(8, 8)
charBox.BackgroundColor3 = Theme.BgCard
charBox.BorderSizePixel = 0
charBox.Parent = sidebar
addCorner(charBox, 10)
addStroke(charBox, Theme.GreenPrimary, 1.1, 0.35)

local charNameLbl = Instance.new("TextLabel")
charNameLbl.Size = UDim2.new(1, -78, 0, 22)
charNameLbl.Position = UDim2.fromOffset(8, 4)
charNameLbl.BackgroundTransparency = 1
charNameLbl.Font = Enum.Font.GothamBold
charNameLbl.TextSize = 11
charNameLbl.TextColor3 = Theme.GreenBright
charNameLbl.TextXAlignment = Enum.TextXAlignment.Left
charNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
charNameLbl.Text = tostring(player.DisplayName) .. " (@" .. tostring(player.Name) .. ")"
charNameLbl.Parent = charBox

local refreshCharBtn = Instance.new("TextButton")
refreshCharBtn.Size = UDim2.fromOffset(62, 20)
refreshCharBtn.Position = UDim2.new(1, -70, 0, 5)
refreshCharBtn.BackgroundColor3 = Theme.GreenPrimary
refreshCharBtn.TextColor3 = Theme.BgMain
refreshCharBtn.Font = Enum.Font.GothamBold
refreshCharBtn.TextSize = 10
refreshCharBtn.Text = "รีเฟรช"
refreshCharBtn.BorderSizePixel = 0
refreshCharBtn.Parent = charBox
addCorner(refreshCharBtn, 5)

local viewport = Instance.new("ViewportFrame")
viewport.Name = "CharacterViewport"
viewport.Size = UDim2.new(1, -16, 1, -34)
viewport.Position = UDim2.fromOffset(8, 28)
viewport.BackgroundColor3 = Theme.BgViewport
viewport.BorderSizePixel = 0
viewport.Parent = charBox
addCorner(viewport, 8)
addStroke(viewport, Theme.GreenGlow, 1, 0.5)

local vpCamera = Instance.new("Camera")
vpCamera.FieldOfView = 42
viewport.CurrentCamera = vpCamera
vpCamera.Parent = viewport

local spinConn = nil
__bkHook(function() pcall(function() if spinConn then spinConn:Disconnect() spinConn = nil end end) end) -- [v1.37] ตัดตอนปิดสคริปต์
local function rebuildCharacterPreview()
	pcall(function()
		if spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
		for _, ch in ipairs(viewport:GetChildren()) do
			if ch:IsA("Model") or ch:IsA("WorldModel") then
				ch:Destroy()
			end
		end
		local char = player.Character
		if not char then return end
		char.Archivable = true
		local ok, clone = pcall(function() return char:Clone() end)
		char.Archivable = false
		if not ok or not clone then return end
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
				desc:Destroy()
			end
		end
		local wm = Instance.new("WorldModel")
		wm.Parent = viewport
		clone.Parent = wm

		local root = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
		if root and clone:IsA("Model") then
			clone.PrimaryPart = root
			local angle = 0
			spinConn = RunService.RenderStepped:Connect(function(dt)
				if not clone or not clone.Parent or not mainWindow.Visible then return end
				angle = angle + dt * 0.9
				pcall(function()
					clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, angle, 0))
					vpCamera.CFrame = CFrame.new(Vector3.new(0, 1.25, 5.2), Vector3.new(0, 0.85, 0))
				end)
			end)
		end
	end)
end

refreshCharBtn.MouseButton1Click:Connect(rebuildCharacterPreview)
__bkTrack(player.CharacterAdded:Connect(function()
	task.wait(0.6)
	rebuildCharacterPreview()
end))
rebuildCharacterPreview()

local navHolder = Instance.new("ScrollingFrame") -- [v1.28] เลื่อนดูหมวดได้ครบทุกหมวด (รองรับนิ้ว)
navHolder.Size = UDim2.new(1, -16, 1, -234)
navHolder.Position = UDim2.fromOffset(8, 194)
navHolder.BackgroundTransparency = 1
navHolder.BorderSizePixel = 0
navHolder.ScrollBarThickness = 3
navHolder.ScrollBarImageColor3 = Theme.GreenPrimary
navHolder.CanvasSize = UDim2.new()
navHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
navHolder.ScrollingDirection = Enum.ScrollingDirection.Y
navHolder.Parent = sidebar

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 6)
navLayout.Parent = navHolder

local creditFooter = Instance.new("TextLabel")
creditFooter.Size = UDim2.new(1, -16, 0, 28)
creditFooter.Position = UDim2.fromOffset(8, 414)
creditFooter.BackgroundColor3 = Theme.BgCard
creditFooter.TextColor3 = Theme.TextMuted
creditFooter.Font = Enum.Font.GothamBold
creditFooter.TextSize = 10
creditFooter.Text = "BALL KUN Vv1 • v1.38 • By BALL KUN"
creditFooter.Parent = sidebar
addCorner(creditFooter, 7)

local pagesContainer = Instance.new("Frame")
pagesContainer.Name = "PagesContainer"
pagesContainer.Size = UDim2.new(1, -239, 1, -72)
pagesContainer.Position = UDim2.fromOffset(231, 64)
pagesContainer.BackgroundColor3 = Theme.BgSidebar
pagesContainer.BackgroundTransparency = COVER_IMAGE and 0.15 or 0
pagesContainer.BorderSizePixel = 0
pagesContainer.Parent = mainWindow
addCorner(pagesContainer, 12)
addStroke(pagesContainer, Theme.GreenGlow, 1, 0.4)

local pages = {}
local navButtons = {}
local refreshCallbacks = {}

local function registerRefresh(fn)
	table.insert(refreshCallbacks, fn)
end

local function refreshAllUI()
	for _, fn in ipairs(refreshCallbacks) do
		pcall(fn)
	end
	if State.AutoSaveConfig then
		pcall(saveConfigToFile)
	end
end

local function selectPage(pageId)
	for id, pg in pairs(pages) do
		pg.Visible = (id == pageId)
	end
	for id, bData in pairs(navButtons) do
		local active = (id == pageId)
		bData.btn.BackgroundColor3 = active and Theme.GreenDark or Theme.BgCard
		bData.btn.TextColor3 = active and Theme.GreenBright or Theme.TextMuted
		bData.stroke.Transparency = active and 0.1 or 0.65
	end
end

local function createPage(pageId, navLabel)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = pageId
	scroll.Size = UDim2.new(1, -14, 1, -14)
	scroll.Position = UDim2.fromOffset(7, 7)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Theme.GreenPrimary
	scroll.Visible = false
	scroll.Parent = pagesContainer

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 14)
	end)

	local btn = Instance.new("TextButton")
	btn.Name = "Nav_" .. pageId
	btn.Size = UDim2.new(1, 0, 0, 44)
	btn.BackgroundColor3 = Theme.BgCard
	btn.TextColor3 = Theme.TextMuted
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = "  " .. navLabel
	btn.BorderSizePixel = 0
	btn.Parent = navHolder
	addCorner(btn, 8)
	local stroke = addStroke(btn, Theme.GreenPrimary, 1, 0.65)

	btn.MouseButton1Click:Connect(function()
		selectPage(pageId)
	end)

	pages[pageId] = scroll
	navButtons[pageId] = { btn = btn, stroke = stroke }
	return scroll
end

local function makeCard(parent, titleText, heightPx, order)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, heightPx)
	card.BackgroundColor3 = Theme.BgCard
	card.BackgroundTransparency = COVER_IMAGE and 0.05 or 0
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = parent
	addCorner(card, 10)
	addStroke(card, Theme.GreenGlow, 1, 0.45)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 0, 24)
	lbl.Position = UDim2.fromOffset(10, 6)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextColor3 = Theme.GreenBright
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = titleText
	lbl.Parent = card

	return card
end

local function makeToggle(parent, labelText, yPos, getter, setter)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 32)
	row.Position = UDim2.fromOffset(10, yPos)
	row.BackgroundColor3 = Theme.BgInput
	row.BorderSizePixel = 0
	row.Parent = parent
	addCorner(row, 7)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -74, 1, 0)
	lbl.Position = UDim2.fromOffset(10, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 11
	lbl.TextColor3 = Theme.TextMain
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.Parent = row

	local swBtn = Instance.new("TextButton")
	swBtn.Size = UDim2.fromOffset(54, 22)
	swBtn.Position = UDim2.new(1, -62, 0.5, -11)
	swBtn.Font = Enum.Font.GothamBold
	swBtn.TextSize = 10
	swBtn.BorderSizePixel = 0
	swBtn.Parent = row
	addCorner(swBtn, 6)

	local function sync()
		local on = getter()
		swBtn.Text = on and "ON" or "OFF"
		swBtn.BackgroundColor3 = on and Theme.GreenPrimary or Theme.BgCard
		swBtn.TextColor3 = on and Theme.BgMain or Theme.TextMuted
	end

	swBtn.MouseButton1Click:Connect(function()
		setter(not getter())
		sync()
		refreshAllUI()
	end)

	registerRefresh(sync)
	sync()
	return row
end

local function makeSlider(parent, labelText, yPos, minVal, maxVal, unitText, getter, setter)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 42)
	row.Position = UDim2.fromOffset(10, yPos)
	row.BackgroundColor3 = Theme.BgInput
	row.BorderSizePixel = 0
	row.Parent = parent
	addCorner(row, 7)

	local topLbl = Instance.new("TextLabel")
	topLbl.Size = UDim2.new(1, -16, 0, 18)
	topLbl.Position = UDim2.fromOffset(8, 2)
	topLbl.BackgroundTransparency = 1
	topLbl.Font = Enum.Font.GothamMedium
	topLbl.TextSize = 11
	topLbl.TextColor3 = Theme.TextMain
	topLbl.TextXAlignment = Enum.TextXAlignment.Left
	topLbl.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -16, 0, 10)
	track.Position = UDim2.fromOffset(8, 24)
	track.BackgroundColor3 = Theme.BgCard
	track.BorderSizePixel = 0
	track.Parent = row
	addCorner(track, 5)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0.5, 0, 1, 0)
	fill.BackgroundColor3 = Theme.GreenPrimary
	fill.BorderSizePixel = 0
	fill.Parent = track
	addCorner(fill, 5)

	local dragging = false
	local function applyRatio(r)
		local clamped = math.clamp(r, 0, 1)
		local val = math.floor(minVal + (maxVal - minVal) * clamped + 0.5)
		setter(val)
		fill.Size = UDim2.new(clamped, 0, 1, 0)
		topLbl.Text = string.format("%s : %d %s", labelText, val, unitText)
	end

	local function sync()
		local v = getter()
		local r = (maxVal > minVal) and ((v - minVal) / (maxVal - minVal)) or 0
		fill.Size = UDim2.new(math.clamp(r, 0, 1), 0, 1, 0)
		topLbl.Text = string.format("%s : %d %s", labelText, v, unitText)
	end

	track.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local relX = (inp.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
			applyRatio(relX)
		end
	end)

	__bkTrack(UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local relX = (inp.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
			applyRatio(relX)
		end
	end))

	__bkTrack(UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				if State.AutoSaveConfig then pcall(saveConfigToFile) end
			end
		end
	end))

	registerRefresh(sync)
	sync()
	return row
end

local function makeSelector(parent, labelText, yPos, options, getter, setter)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 32)
	row.Position = UDim2.fromOffset(10, yPos)
	row.BackgroundColor3 = Theme.BgInput
	row.BorderSizePixel = 0
	row.Parent = parent
	addCorner(row, 7)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.42, -8, 1, 0)
	lbl.Position = UDim2.fromOffset(8, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 11
	lbl.TextColor3 = Theme.TextMain
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.Parent = row

	local cycleBtn = Instance.new("TextButton")
	cycleBtn.Size = UDim2.new(0.56, -4, 0, 24)
	cycleBtn.Position = UDim2.new(0.43, 0, 0.5, -12)
	cycleBtn.BackgroundColor3 = Theme.GreenDark
	cycleBtn.TextColor3 = Theme.GreenBright
	cycleBtn.Font = Enum.Font.GothamBold
	cycleBtn.TextSize = 11
	cycleBtn.BorderSizePixel = 0
	cycleBtn.Parent = row
	addCorner(cycleBtn, 6)
	addStroke(cycleBtn, Theme.GreenPrimary, 1, 0.4)

	local function sync()
		cycleBtn.Text = tostring(getter()) .. "  ▸"
	end

	cycleBtn.MouseButton1Click:Connect(function()
		local cur = getter()
		local idx = 1
		for i, v in ipairs(options) do
			if v == cur then idx = i break end
		end
		setter(options[(idx % #options) + 1])
		sync()
		refreshAllUI()
	end)

	registerRefresh(sync)
	sync()
	return row
end

local function makeActionButton(parent, btnText, xScale, wScale, yPos, hPx, onClick)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(wScale, -6, 0, hPx)
	btn.Position = UDim2.new(xScale, 3, 0, yPos)
	btn.BackgroundColor3 = Theme.GreenPrimary
	btn.TextColor3 = Theme.BgMain
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Text = btnText
	btn.BorderSizePixel = 0
	btn.Parent = parent
	addCorner(btn, 7)
	btn.MouseButton1Click:Connect(onClick)
	return btn
end

local pageHome = createPage("HomeJobs", "1. หน้าหลัก & งานอาชีพ")
local pageVehicle = createPage("VehicleCare", "2. การขับขี่ & ดูแลรถ")
local pageEcu = createPage("EcuPistons", "3. จูน ECU & ซื้อลูกสูบ")
local pageSettings = createPage("SettingsSafety", "4. ตั้งค่า & Webhook")

-- [v19] หน้าฟังก์ชันเสริม (ฝั่งผู้เล่นล้วนๆ: กราฟิก/กล้อง/เซิร์ฟเวอร์)
local pageExtra = createPage("ExtraTools", "6. ฟังก์ชันเสริม")
do
	local X = { FPS = false, Bright = false, HideOthers = false, FOVLock = false, FOV = 80 }
	local saved = { fx = {}, emit = {}, hidden = {}, light = nil }
	local Stats = game:GetService("Stats")

	-- ลดกราฟิก (FPS Boost)
	local function setFpsBoost(on)
		X.FPS = on
		pcall(function()
			if on then
				saved.shadows = Lighting.GlobalShadows
				pcall(function() saved.quality = settings().Rendering.QualityLevel end)
				Lighting.GlobalShadows = false
				pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
				saved.fx = {}
				for _, v in ipairs(Lighting:GetChildren()) do
					if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
						if v.Enabled then saved.fx[#saved.fx + 1] = v; v.Enabled = false end
					end
				end
				saved.emit = {}
				task.spawn(function()
					local list = workspace:GetDescendants()
					for i, v in ipairs(list) do
						if not X.FPS then break end
						if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
							if v.Enabled then saved.emit[#saved.emit + 1] = v; v.Enabled = false end
						end
						if i % 2500 == 0 then task.wait() end
					end
				end)
			else
				if saved.shadows ~= nil then Lighting.GlobalShadows = saved.shadows end
				if saved.quality then pcall(function() settings().Rendering.QualityLevel = saved.quality end) end
				for _, v in ipairs(saved.fx) do pcall(function() v.Enabled = true end) end
				for _, v in ipairs(saved.emit) do pcall(function() if v.Parent then v.Enabled = true end end) end
				saved.fx, saved.emit = {}, {}
			end
		end)
	end

	-- สว่างตลอด (Fullbright)
	local function setBright(on)
		X.Bright = on
		pcall(function()
			if on then
				saved.light = { Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.Ambient, Lighting.OutdoorAmbient }
				Lighting.Brightness = 2
				Lighting.ClockTime = 14
				Lighting.FogEnd = 1e6
				Lighting.Ambient = Color3.fromRGB(150, 150, 150)
				Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
			elseif saved.light then
				Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = saved.light[1], saved.light[2], saved.light[3]
				Lighting.Ambient, Lighting.OutdoorAmbient = saved.light[4], saved.light[5]
				saved.light = nil
			end
		end)
	end

	-- ซ่อนผู้เล่นคนอื่น (เห็นเฉพาะในเครื่องเรา)
	local function hideOthersNow()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character then
				for _, d in ipairs(p.Character:GetDescendants()) do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 1
					elseif d:IsA("Decal") then
						if saved.hidden[d] == nil then saved.hidden[d] = d.Transparency end
						d.Transparency = 1
					end
				end
			end
		end
	end
	local function setHideOthers(on)
		X.HideOthers = on
		if on then
			pcall(hideOthersNow)
		else
			pcall(function()
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player and p.Character then
						for _, d in ipairs(p.Character:GetDescendants()) do
							if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
						end
					end
				end
				for d, t in pairs(saved.hidden) do pcall(function() d.Transparency = t end) end
				saved.hidden = {}
			end)
		end
	end
	task.spawn(function()
		local okI, I = pcall(function() return (getgenv and getgenv() or _G).__BK_INSTANCE end)
		while not (okI and type(I) == "table" and I.alive == false) do
			task.wait(1)
			if X.HideOthers then pcall(hideOthersNow) end
		end
	end)

	-- ล็อก FOV
	do
		local cFov = RunService.RenderStepped:Connect(function()
			if X.FOVLock then
				local cam = workspace.CurrentCamera
				if cam then cam.FieldOfView = X.FOV end
			end
		end)
		pcall(function() local I = (getgenv and getgenv() or _G).__BK_INSTANCE; I.conns[#I.conns + 1] = cFov end)
	end

	-- ตัวนับ FPS / Ping
	local frames = 0
	do
		local cHb = RunService.Heartbeat:Connect(function() frames = frames + 1 end)
		pcall(function() local I = (getgenv and getgenv() or _G).__BK_INSTANCE; I.conns[#I.conns + 1] = cHb end)
	end

	-- การ์ด 1: ประสิทธิภาพ & ภาพ
	local cardGfx = makeCard(pageExtra, "ประสิทธิภาพ & ภาพ", 190, 1)
	local statLbl = Instance.new("TextLabel")
	statLbl.Size = UDim2.new(1, -20, 0, 24)
	statLbl.Position = UDim2.fromOffset(10, 32)
	statLbl.BackgroundTransparency = 1
	statLbl.Font = Enum.Font.GothamBold
	statLbl.TextSize = 14
	statLbl.TextColor3 = Theme.GreenBright
	statLbl.TextXAlignment = Enum.TextXAlignment.Left
	statLbl.Text = "FPS: -  |  Ping: - ms"
	statLbl.Parent = cardGfx
	task.spawn(function()
		while statLbl.Parent do
			task.wait(1)
			local fps = frames; frames = 0
			local ping = 0
			pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			statLbl.Text = string.format("FPS: %d  |  Ping: %d ms", fps, ping)
		end
	end)
	makeToggle(cardGfx, "ลดกราฟิก (FPS Boost) ลดเงา/เอฟเฟกต์", 62, function() return X.FPS end, setFpsBoost)
	makeToggle(cardGfx, "สว่างตลอด (Fullbright)", 100, function() return X.Bright end, setBright)
	makeToggle(cardGfx, "ซ่อนผู้เล่นคนอื่น (ช่วยลดแลค)", 138, function() return X.HideOthers end, setHideOthers)

	-- การ์ด 2: กล้อง
	local cardCam = makeCard(pageExtra, "กล้อง", 180, 2)
	makeToggle(cardCam, "ล็อกค่า FOV (มุมมองกล้อง)", 34, function() return X.FOVLock end, function(v) X.FOVLock = v end)
	makeSlider(cardCam, "ค่า FOV", 74, 50, 120, "องศา", function() return X.FOV end, function(v) X.FOV = math.floor(v) end)
	makeActionButton(cardCam, "เปิด/ปิดกล้องฟรี (FreeCam ของเกม)", 0, 1, 130, 36, function()
		local ok = pcall(function()
			local ev = player.PlayerGui:FindFirstChild("FreeCamUI") and player.PlayerGui.FreeCamUI:FindFirstChild("ToggleFreeCam")
			assert(ev and ev:IsA("BindableEvent"))
			ev:Fire()
		end)
		if not ok then pcall(__notify, "ball kunVv1", "ไม่พบระบบกล้องฟรีของเกมในแมพนี้") end
	end)

	-- การ์ด 3: เซิร์ฟเวอร์
	local cardSrv = makeCard(pageExtra, "เซิร์ฟเวอร์ & ระบบ", 130, 3)
	makeActionButton(cardSrv, "รีจอยเซิร์ฟเวอร์นี้", 0, 0.5, 36, 36, function()
		pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end)
	end)
	makeActionButton(cardSrv, "คัดลอก JobId", 0.5, 0.5, 36, 36, function()
		local fn = rawget(_G, "setclipboard") or (getgenv and getgenv().setclipboard)
		if type(fn) == "function" then pcall(fn, tostring(game.JobId)); pcall(__notify, "ball kunVv1", "คัดลอก JobId แล้ว")
		else pcall(__notify, "ball kunVv1", "Executor ไม่รองรับการคัดลอก") end
	end)
	makeActionButton(cardSrv, "ย้ายเซิร์ฟเวอร์ (Hop)", 0, 1, 80, 36, function()
		hopServerNow("กดจากหน้าฟังก์ชันเสริม")
	end)
end

-- [v20] งานอัตโนมัติจากข้อมูลจริงของแมพ (ใช้ Prompt ของเกมเอง: ตู้เก็บของ -> กระดานงาน -> จุดทำงาน)
local pageJobBot = createPage("JobBot", "8. งานอัตโนมัติ (ข้อมูลจริง)")
local stopActiveJobBot = nil
do
	local PathfindingService = game:GetService("PathfindingService")
	local JB = { on = false, jobIndex = 1, status = "ปิดอยู่", lastFire = 0, gen = 0,
		busy = false, lastStatusNotice = "", lastNoticeAt = 0, lastActionKey = "", lastActionAt = 0 }
	local function stopJobBot(reason)
		JB.on = false
		pcall(function() BKPin.clear("jobbot") end)
		JB.gen = JB.gen + 1 -- [v1.31] ตัดรอบงานที่กำลังเดิน/รออยู่ทันที (ทุกจุดเช็ก live())
		JB.busy = false
		JB.status = "หยุดแล้ว" .. (reason and (": " .. tostring(reason)) or "")
	end
	stopActiveJobBot = stopJobBot
	EmergencyStopHooks[#EmergencyStopHooks + 1] = stopJobBot
	__bkHook(stopJobBot)
	Runner.onCancel[#Runner.onCancel + 1] = function(reason)
		stopJobBot("Runner:Cancel / " .. tostring(reason or "cancel"))
	end
	local JOBS = {
		{ id = "Builder", label = "Builder (ช่างก่อสร้าง)" },
		{ id = "Mechanic", label = "Mechanic (ช่างซ่อมรถ)" },
	}
	local jobLabels = {}
	for i, j in ipairs(JOBS) do jobLabels[i] = j.label end

	local function promptPart(p)
		local par = p.Parent
		if not par then return nil end
		if par:IsA("BasePart") then return par end
		if par:IsA("Attachment") then return par.Parent end
		return par:FindFirstAncestorWhichIsA("BasePart")
	end

	-- [v1.35] แมพเก็บ Job/StationId ไว้บน WorkStation/JobLocker (Parent) ไม่ใช่บน ProximityPrompt
	-- จึงอ่านจากตัว prompt ก่อน แล้วไล่ขึ้น Ancestor ที่ใกล้ที่สุดที่มี attribute นั้น
	local function promptAttr(p, key)
		local o, depth = p, 0
		while o and o ~= workspace and depth < 10 do
			local v = o:GetAttribute(key)
			if v ~= nil then return v end
			o = o.Parent
			depth = depth + 1
		end
		return nil
	end

	local function findPrompt(name, jobId, stationId)
		local _, hrp = getCharacterParts()
		local best, bestD
		for _, p in ipairs(WorldCache.list("prompt")) do
			if p.Parent and p:IsA("ProximityPrompt") and p.Name == name and promptAttr(p, "Job") == jobId
				and (stationId == nil or promptAttr(p, "StationId") == stationId) then
				local part = promptPart(p)
				if part then
					local d = hrp and (part.Position - hrp.Position).Magnitude or 0
					if not bestD or d < bestD then best, bestD = p, d end
				end
			end
		end
		return best
	end

	-- เดินจริงด้วย Pathfinding (ไม่วาป)
	local function walkNear(pos, stopDist, timeout, live)
		live = live or function() return JB.on end
		local char, hrp, hum = getCharacterParts()
		if not (hrp and hum) or hum.Health <= 0 or not char.Parent then
			JB.status = "รอตัวละครเกิดใหม่/โหลดตัวละคร"
			return false
		end
		local t0 = tick()
		local ok, path = pcall(function()
			local pa = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
			pa:ComputeAsync(hrp.Position, pos)
			return pa
		end)
		local points = {}
		if ok and path and path.Status == Enum.PathStatus.Success then
			for _, w in ipairs(path:GetWaypoints()) do points[#points + 1] = w end
		else
			JB.status = "Pathfinding ไม่พบเส้นทาง ใช้ทางตรงแบบจำกัดระยะ"
			points[1] = { Position = pos, Action = Enum.PathWaypointAction.Walk }
		end
		for _, w in ipairs(points) do
			if not live() then return false end
			if not char.Parent or hum.Health <= 0 then
				JB.status = "หยุดเดิน: ตัวละครรีเซ็ต/ไม่พร้อม"
				return false
			end
			if w.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
			-- จำกัดการส่ง MoveTo ซ้ำระหว่างโหลด/คำนวณเส้นทาง
			hum:MoveTo(w.Position)
			local reached = false
			local c = hum.MoveToFinished:Connect(function() reached = true end)
			local ws = tick()
			while live() and not reached and tick() - ws < 4 do
				task.wait(0.1)
				if (hrp.Position - pos).Magnitude <= stopDist then reached = true end
			end
			c:Disconnect()
			if (hrp.Position - pos).Magnitude <= stopDist then return true end
			if tick() - t0 > (timeout or 90) then return false end
		end
		return (hrp.Position - pos).Magnitude <= stopDist + 4
	end

	local function goAndFire(prompt, label, live)
		live = live or function() return JB.on end
		local part = promptPart(prompt)
		if not part then return false end
		JB.status = label .. " (กำลังเดิน)"
		pcall(function() BKPin.set("jobbot", part.Position.X, part.Position.Z, label) end)
		local reached = walkNear(part.Position, math.max(3, math.min(prompt.MaxActivationDistance - 3, 7)), 90, live)
		if not reached or not live() then return false end
		local now = tick()
		local key = prompt:GetFullName()
		if JB.lastActionKey == key and now - JB.lastActionAt < 4 then
			JB.status = "รอป้องกันคำสั่งซ้ำ: " .. label
			return false
		end
		JB.status = label .. " (กำลังโต้ตอบ)"
		-- คูลดาวน์คงที่เพื่อป้องกันการยิงซ้ำ ไม่ใช่การหลบเลี่ยงระบบตรวจจับ
		task.wait(0.5)
		if not live() or not prompt.Parent or not prompt.Enabled then
			JB.status = "ยกเลิก: จุดโต้ตอบไม่พร้อม"
			return false
		end
		local okFire = pcall(firePromptSafe, prompt)
		if not okFire then JB.status = "Error: กด Prompt ไม่สำเร็จ"; return false end
		JB.lastActionKey, JB.lastActionAt = key, now
		JB.lastFire = tick()
		pcall(function() BKPin.clear("jobbot") end)
		return true
	end

	-- [v1.35] ถ้า Prompt ยังไม่ Stream เข้ามา: เดินไปยังตำแหน่งที่ Auto Map Scanner เคย "เห็นจริง" (ไม่ใช้พิกัดเดา)
	-- ต้องมีเส้นทางเดินจริงเท่านั้น (Pathfinding สำเร็จ) ไม่วาป ถ้าไม่มีข้อมูลหรือไม่มีเส้นทางจะคืน false
	local function approachKnown(job, station, sub, label, live)
		local AMs = BKPin.scan
		if not (AMs and AMs.lastKnown) then return false end
		local pt = AMs.lastKnown({ kind = "work", job = job, station = station, sub = sub })
		if not pt then return false end
		local _, hrp = getCharacterParts()
		if not hrp then return false end
		local pos = Vector3.new(pt.x, pt.y, pt.z)
		if (pos - hrp.Position).Magnitude < 8 then return false end
		local okP, why = AMs.pathExists(pos)
		if not okP then
			JB.status = label .. ": มีพิกัดที่เคยสแกนได้ แต่ไม่มีเส้นทางเดินจริง (" .. tostring(why) .. ")"
			return false
		end
		JB.status = label .. ": เดินไปจุดที่เคยสแกนได้ (รอฉากโหลด)"
		pcall(function() BKPin.set("jobbot", pt.x, pt.z, label) end)
		walkNear(pos, 10, 60, live)
		pcall(function() BKPin.clear("jobbot") end)
		return true
	end

	task.spawn(function()
		while __bkAlive() do
			task.wait(0.6)
			if not JB.on or JB.busy then continue end
			JB.busy = true
			local myGen = JB.gen
			local function live() return JB.on and JB.gen == myGen end
			local ok, err = pcall(function()
				local job = JOBS[JB.jobIndex].id
				local nextAt = player:GetAttribute("WorkNextAt")
				if nextAt and nextAt > workspace:GetServerTimeNow() then
					JB.status = string.format("รอคูลดาวน์งาน %d วินาที", math.ceil(nextAt - workspace:GetServerTimeNow()))
					return
				end
				if player:GetAttribute("Job") ~= job then
					local locker = findPrompt("LockerPrompt", job, nil)
					if not locker then
						if approachKnown(job, nil, "LockerPrompt", "ตู้เก็บของ", live) then task.wait(1) return end
						if not JB.status:find("ไม่มีเส้นทางเดินจริง", 1, true) then JB.status = "ไม่พบตู้เก็บของของงานนี้ (อาจอยู่ไกลจนยังไม่โหลดฉาก)" end
						return
					end
					goAndFire(locker, "สวมชุดงาน", live)
					task.wait(2)
					return
				end
				local raw = player:GetAttribute("WorkTask")
				local taskTbl
				if type(raw) == "string" and raw ~= "" then
					local okJ, dec = pcall(function() return HttpService:JSONDecode(raw) end)
					if okJ and type(dec) == "table" then taskTbl = dec end
				end
				if not taskTbl then
					local board = findPrompt("WorkPrompt", job, "Board")
					if not board then
						if approachKnown(job, "Board", "WorkPrompt", "กระดานรับงาน", live) then task.wait(1) return end
						if not JB.status:find("ไม่มีเส้นทางเดินจริง", 1, true) then JB.status = "ไม่พบกระดานรับงาน" end
						return
					end
					goAndFire(board, "รับงานสุ่มที่กระดาน", live)
					task.wait(2)
					return
				end
				local st = taskTbl.station
				if not st then JB.status = "รอข้อมูลงานจากเกม" return end
				local target = findPrompt("WorkPrompt", job, st)
				if not target then
					if approachKnown(job, st, "WorkPrompt", "จุดทำงาน " .. tostring(st), live) then task.wait(1) return end
					if not JB.status:find("ไม่มีเส้นทางเดินจริง", 1, true) then JB.status = "ไม่พบจุดทำงาน: " .. tostring(st) end
					return
				end
				if tick() - JB.lastFire < 2.5 then return end
				goAndFire(target, "ทำงานที่จุด " .. tostring(st) .. " (ขั้น: " .. tostring(taskTbl.step) .. ")", live)
			end)
			if not ok and live() then
				JB.status = "Error: " .. tostring(err):sub(1, 90)
				pcall(__notify, "JobBot Error", JB.status)
			end
			if JB.gen == myGen then JB.busy = false end
		end
	end)

	local cardJob = makeCard(pageJobBot, "ระบบงานอัตโนมัติ (ใช้ได้กับ 2 งาน)", 250, 1)
	makeSelector(cardJob, "เลือกงาน", 34, jobLabels, function() return JOBS[JB.jobIndex].label end, function(v)
		for i, j in ipairs(JOBS) do if j.label == v then JB.jobIndex = i end end
	end)
	makeToggle(cardJob, "เปิดระบบงานอัตโนมัติ", 74, function() return JB.on end, function(v)
		JB.on = v
		JB.status = v and "เริ่มทำงาน..." or "ปิดอยู่"
		if v then
			JB.lastActionKey, JB.lastActionAt = "", 0
			pcall(function() State.AutoBuilder = false; State.AutoMechanic = false; State.AutoRiderDelivery = false end)
		else
			stopJobBot("ปิดจากสวิตช์")
		end
	end)
	makeActionButton(cardJob, "STOP JOBBOT (หยุดเฉพาะงานนี้)", 0, 1, 210, 28, function()
		stopJobBot("กด STOP JOBBOT")
		pcall(__notify, "JobBot", "หยุดเฉพาะ JobBot แล้ว ระบบอื่นยังทำงานต่อ")
	end)
	local stLbl = Instance.new("TextLabel")
	stLbl.Size = UDim2.new(1, -20, 0, 40)
	stLbl.Position = UDim2.fromOffset(10, 114)
	stLbl.BackgroundTransparency = 1
	stLbl.Font = Enum.Font.GothamBold
	stLbl.TextSize = 14
	stLbl.TextWrapped = true
	stLbl.TextColor3 = Theme.GreenBright
	stLbl.TextXAlignment = Enum.TextXAlignment.Left
	stLbl.TextYAlignment = Enum.TextYAlignment.Top
	stLbl.Text = "สถานะ: ปิดอยู่"
	stLbl.Parent = cardJob
	local note = Instance.new("TextLabel")
	note.Size = UDim2.new(1, -20, 0, 44)
	note.Position = UDim2.fromOffset(10, 160)
	note.BackgroundTransparency = 1
	note.Font = Enum.Font.Gotham
	note.TextSize = 13
	note.TextWrapped = true
	note.TextColor3 = Theme.TextMuted
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextYAlignment = Enum.TextYAlignment.Top
	note.Text = "ระบบเดินไปสวมชุด รับงาน และกดจุดทำงานตามที่เกมสั่ง ถ้าเกมมีมินิเกมให้ทำเอง ถ้าเกมถามยืนยันตัวตนให้ตอบเอง"
	note.Parent = cardJob
	task.spawn(function()
		while stLbl.Parent do
			task.wait(0.5)
			stLbl.Text = "สถานะ: " .. JB.status
			if JB.on and JB.status ~= JB.lastStatusNotice and tick() - JB.lastNoticeAt >= 8 then
				JB.lastStatusNotice = JB.status
				JB.lastNoticeAt = tick()
				if JB.status:find("ไม่พบ", 1, true) or JB.status:find("Error", 1, true)
					or JB.status:find("ผิดพลาด", 1, true) or JB.status:find("รอตัวละคร", 1, true) then
					pcall(__notify, "JobBot: " .. JB.status:sub(1, 45), "ตรวจสอบสถานะในหน้า JobBot")
				end
			end
		end
	end)
end

-- [v19] ทำตัวหนังสือให้อ่านง่ายขึ้น: ขยายตัวอักษรที่เล็กกว่า 13
task.delay(3, function()
	pcall(function()
		for _, d in ipairs(mainWindow:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.TextSize <= 12 then
				d.TextSize = math.min(d.TextSize + 2, 14)
			end
		end
	end)
end)

local statCard = makeCard(pageHome, "การ์ดสถานะเรียลไทม์ (MAHANAKHON RACING)", 108, 1)
local statGrid = Instance.new("Frame")
statGrid.Size = UDim2.new(1, -20, 0, 68)
statGrid.Position = UDim2.fromOffset(10, 32)
statGrid.BackgroundTransparency = 1
statGrid.Parent = statCard

local function makeStatBox(colIndex, titleTxt)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(0.25, -6, 1, 0)
	box.Position = UDim2.new(0.25 * colIndex, 3, 0, 0)
	box.BackgroundColor3 = Theme.BgInput
	box.BorderSizePixel = 0
	box.Parent = statGrid
	addCorner(box, 8)
	addStroke(box, Theme.GreenGlow, 1, 0.5)

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(1, -8, 0, 20)
	tLbl.Position = UDim2.fromOffset(4, 5)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.Gotham
	tLbl.TextSize = 10
	tLbl.TextColor3 = Theme.TextMuted
	tLbl.Text = titleTxt
	tLbl.Parent = box

	local vLbl = Instance.new("TextLabel")
	vLbl.Size = UDim2.new(1, -8, 0, 32)
	vLbl.Position = UDim2.fromOffset(4, 26)
	vLbl.BackgroundTransparency = 1
	vLbl.Font = Enum.Font.GothamBold
	vLbl.TextSize = 12
	vLbl.TextColor3 = Theme.GreenBright
	vLbl.TextWrapped = true
	vLbl.Parent = box

	return vLbl
end

local stJobVal = makeStatBox(0, "อาชีพปัจจุบัน")
local stDoneVal = makeStatBox(1, "งานทำสำเร็จ")
local stCheckVal = makeStatBox(2, "FarmCheck ที่พบ (ตอบเอง)")
local stLiveVal = makeStatBox(3, "สถานะเรียลไทม์")

local function updateWorkLiveStatus()
	local working = State.AutoBuilder or State.AutoMechanic or State.AutoRiderDelivery or State.AutoDriveToTuner or State.AutoTuneECU or State.AutoBuyPiston
	if not working and State.WorkStatus:find("หยุดฉุกเฉิน") then return end
	State.WorkStatus = working and "กำลังทำงาน" or "ว่าง"
	if State.AutoRiderDelivery then
		State.CurrentJob = "ไรเดอร์ (" .. State.RiderMode .. ")"
	elseif State.AutoBuilder then
		State.CurrentJob = "ช่างก่อสร้าง"
	elseif State.AutoMechanic then
		State.CurrentJob = "ช่างซ่อมรถ"
	else
		State.CurrentJob = "อิสระ / ไรเดอร์"
	end
end

registerRefresh(function()
	updateWorkLiveStatus()
	stJobVal.Text = State.CurrentJob
	stDoneVal.Text = tostring(State.CompletedJobs) .. " งาน"
	stCheckVal.Text = tostring(State.SolvedFarmChecks) .. " ครั้ง"
	stLiveVal.Text = State.WorkStatus
	stLiveVal.TextColor3 = (State.WorkStatus == "กำลังทำงาน") and Theme.GreenBright or Theme.TextMuted
end)

local generalJobCard = makeCard(pageHome, "งานอาชีพทั่วไป (เดินไปรับงาน & ทำมินิเกมอัตโนมัติ)", 114, 2)
makeToggle(generalJobCard, "งานช่างก่อสร้าง (Auto Builder)", 34, function() return State.AutoBuilder end, function(v)
	if v and stopActiveJobBot then stopActiveJobBot("สลับไปใช้ Auto Builder") end
	State.AutoBuilder = v
	Runner:Cancel("toggle")
	if v then State.AutoMechanic = false; State.AutoRiderDelivery = false end
end)
makeToggle(generalJobCard, "งานช่างซ่อมรถ (Auto Mechanic)", 72, function() return State.AutoMechanic end, function(v)
	if v and stopActiveJobBot then stopActiveJobBot("สลับไปใช้ Auto Mechanic") end
	State.AutoMechanic = v
	Runner:Cancel("toggle")
	if v then State.AutoBuilder = false; State.AutoRiderDelivery = false end
end)

local riderCard = makeCard(pageHome, "งานไรเดอร์ (Rider Delivery System)", 152, 3)
local riderStatusLbl = Instance.new("TextLabel")
riderStatusLbl.Size = UDim2.new(1, -20, 0, 22)
riderStatusLbl.Position = UDim2.fromOffset(10, 30)
riderStatusLbl.BackgroundTransparency = 1
riderStatusLbl.Font = Enum.Font.GothamBold
riderStatusLbl.TextSize = 11
riderStatusLbl.TextColor3 = Theme.GreenBright
riderStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
riderStatusLbl.Text = "สถานะไรเดอร์: " .. State.RiderStatus
riderStatusLbl.Parent = riderCard

makeSelector(riderCard, "โหมดงานไรเดอร์", 56, RiderModesList, function() return State.RiderMode end, function(v)
	State.RiderMode = v
	State.RiderStatus = State.AutoRiderDelivery and ("กำลังวิ่งโหมด: " .. v) or ("พร้อมรับออเดอร์ (" .. v .. ")")
end)

makeToggle(riderCard, "เปิดระบบ Rider Delivery (รับงาน / เปิดรับงาน / รับออเดอร์ / ขับส่ง)", 96, function()
	return State.AutoRiderDelivery
end, function(v)
	if v and stopActiveJobBot then stopActiveJobBot("สลับไปใช้ Auto Rider Delivery") end
	State.AutoRiderDelivery = v
	Runner:Cancel("toggle")
	if v then State.AutoBuilder = false; State.AutoMechanic = false end
	State.RiderStatus = v and ("กำลังค้นหาจุดรับงาน (" .. State.RiderMode .. ")...") or "หยุดงานไรเดอร์"
	riderStatusLbl.Text = "สถานะไรเดอร์: " .. State.RiderStatus
end)

local driveCard = makeCard(pageVehicle, "ตั้งค่าการขับขี่ & ความเร็ว (Driving & Speed)", 168, 1)
makeSelector(driveCard, "เลือกรถ (Farm Vehicle)", 34, VehiclesList, function() return State.SelectedVehicle end, function(v)
	State.SelectedVehicle = v
	State.TuneVehicle = v
	fireRemotesSmart("vehicle", { "vehicle", "spawn", "car", "selectcar" }, v)
end)
makeSlider(driveCard, "ความเร็วสูงสุดทางตรง", 74, 60, 360, "km/h", function() return State.MaxSpeedKmh end, function(v) State.MaxSpeedKmh = v end)
makeSlider(driveCard, "ความเร็วขณะเข้าโค้ง / เลี้ยว", 120, 25, 200, "km/h", function() return State.CornerSpeedKmh end, function(v) State.CornerSpeedKmh = v end)

local navCard = makeCard(pageVehicle, "โหมดไร้แรงชน & นำทางอัจฉริยะ (Smart Nav & Anti-Stuck)", 168, 2)
makeToggle(navCard, "โหมดไร้แรงชน + นำทางอัจฉริยะ (หลบสิ่งกีดขวาง / แก้รถติด)", 34, function() return State.NoCollisionSmartNav end, function(v) State.NoCollisionSmartNav = v end)
makeSlider(navCard, "เวลาหยุดนิ่งก่อนแก้ติด", 74, 1, 20, "วินาที", function() return State.StuckStopSeconds end, function(v) State.StuckStopSeconds = v end)
makeSlider(navCard, "เวลารถติดค้างก่อนรีเซ็ตตัว", 120, 5, 60, "วินาที", function() return State.StuckResetSeconds end, function(v) State.StuckResetSeconds = v end)

local function executeRefuelNow()
	local _, pos = findNearestObjectByKeywords({ "fuel", "gas", "petrol", "pump", "น้ำมัน", "ปั๊ม" }, 2500)
	if pos then
		moveToPositionSmart(pos, State.MaxSpeedKmh)
		interactWithNearbyPrompts({ "fuel", "gas", "refuel", "เติม" }, 30)
	end
	fireRemotesSmart("refuel", { "refuel", "fuel", "gas" }, State.SelectedVehicle, 100)
	autoClickGameGuiButtons({ "เติมน้ำมัน", "refuel", "fill" })
	appendEcuLog("ดำเนินการเติมน้ำมันรถ " .. State.SelectedVehicle .. " แล้ว")
end

local function executeRepairNow()
	local _, pos = findNearestObjectByKeywords({ "repair", "fix", "garage", "mechanic", "ซ่อม", "อู่" }, 2500)
	if pos then
		moveToPositionSmart(pos, State.MaxSpeedKmh)
		interactWithNearbyPrompts({ "repair", "fix", "ซ่อม" }, 30)
	end
	fireRemotesSmart("repair", { "repair", "fix", "healcar" }, State.SelectedVehicle)
	autoClickGameGuiButtons({ "ซ่อมรถ", "repair", "fix" })
	appendEcuLog("ดำเนินการซ่อมรถ " .. State.SelectedVehicle .. " แล้ว")
end

local careCard = makeCard(pageVehicle, "ระบบเติมน้ำมัน & ซ่อมรถอัตโนมัติ (Fuel & Repair)", 228, 3)
makeToggle(careCard, "ออโต้เติมน้ำมัน (Auto Refuel)", 34, function() return State.AutoRefuel end, function(v) State.AutoRefuel = v end)
makeSlider(careCard, "เติมน้ำมันเมื่อต่ำกว่า", 72, 5, 85, "%", function() return State.RefuelBelowPercent end, function(v) State.RefuelBelowPercent = v end)
makeActionButton(careCard, "เติมน้ำมันตอนนี้ทันที (Refuel Now)", 0, 1, 116, 28, function()
	executeRefuelNow()
	refreshAllUI()
end)
makeToggle(careCard, "ออโต้ซ่อมรถ (Auto Repair)", 150, function() return State.AutoRepair end, function(v) State.AutoRepair = v end)
makeSlider(careCard, "ซ่อมรถเมื่อความทนทานต่ำกว่า", 188, 5, 90, "%", function() return State.RepairBelowPercent end, function(v) State.RepairBelowPercent = v end)

local ecuCard = makeCard(pageEcu, "ควบคุมการจูน ECU (ECU Tuning Control)", 246, 1)
makeToggle(ecuCard, "ออโต้จูนรถ (Auto Tune ECU)", 34, function() return State.AutoTuneECU end, function(v)
	State.AutoTuneECU = v
	appendEcuLog(v and ("เปิดออโต้จูน [" .. State.EcuMap .. "]") or "ปิดออโต้จูน ECU")
end)
makeSelector(ecuCard, "เลือกรถที่จะจูน", 72, VehiclesList, function() return State.TuneVehicle end, function(v) State.TuneVehicle = v end)
makeSelector(ecuCard, "เลือกตาราง ECU", 110, EcuMapsList, function() return State.EcuMap end, function(v) State.EcuMap = v end)
makeToggle(ecuCard, "ขับไปร้านจูนอัตโนมัติ (Auto Drive to Tuner)", 148, function() return State.AutoDriveToTuner end, function(v)
	State.AutoDriveToTuner = v
	if not v then Runner:Cancel("toggle") end
	appendEcuLog(v and "กำลังขับรถไปยังร้านจูน ECU..." or "หยุดขับไปร้านจูน")
end)

local ecuConsole = Instance.new("TextLabel")
ecuConsole.Size = UDim2.new(1, -20, 0, 50)
ecuConsole.Position = UDim2.fromOffset(10, 188)
ecuConsole.BackgroundColor3 = Theme.BgInput
ecuConsole.TextColor3 = Theme.GreenBright
ecuConsole.Font = Enum.Font.Code
ecuConsole.TextSize = 11
ecuConsole.TextWrapped = true
ecuConsole.TextXAlignment = Enum.TextXAlignment.Left
ecuConsole.TextYAlignment = Enum.TextYAlignment.Top
ecuConsole.Parent = ecuCard
addCorner(ecuConsole, 7)
addStroke(ecuConsole, Theme.GreenPrimary, 1, 0.45)

registerRefresh(function()
	ecuConsole.Text = "  " .. State.EcuConsoleLog
end)

local pistonCard = makeCard(pageEcu, "ตั้งค่าซื้อลูกสูบ & ร้านลูกสูบ (Piston Shop & Hop)", 294, 2)
makeToggle(pistonCard, "ซื้อลูกสูบอัตโนมัติ (Auto Buy Piston)", 34, function() return State.AutoBuyPiston end, function(v)
	State.AutoBuyPiston = v
	appendPistonLog(v and ("เริ่มซื้อลูกสูบขนาด " .. State.TargetPistonSize) or "หยุดซื้อลูกสูบอัตโนมัติ")
end)
makeSelector(pistonCard, "ขนาดลูกสูบเป้าหมาย", 72, PistonSizesList, function() return State.TargetPistonSize end, function(v) State.TargetPistonSize = v end)
makeSlider(pistonCard, "จำกัดจำนวนสูงสุดในกระเป๋า", 110, 1, 30, "ลูก", function() return State.MaxPistonsInBag end, function(v) State.MaxPistonsInBag = v end)
makeToggle(pistonCard, "ติดตั้งลูกสูบใส่รถอัตโนมัติ", 156, function() return State.AutoInstallPiston end, function(v) State.AutoInstallPiston = v end)
makeToggle(pistonCard, "ซื้อลูกสูบแบบ Hop Server (ย้ายเซิร์ฟเวอร์หา/เช็คร้าน)", 194, function() return State.HopBuyPiston end, function(v)
	State.HopBuyPiston = v
	if v then
		appendPistonLog("เปิดโหมด Hop Server เช็คร้านลูกสูบ...")
		hopServerNow("Hop Buy Piston (" .. State.TargetPistonSize .. ")")
	end
end)

local pistonStatus = Instance.new("TextLabel")
pistonStatus.Size = UDim2.new(1, -20, 0, 26)
pistonStatus.Position = UDim2.fromOffset(10, 232)
pistonStatus.BackgroundColor3 = Theme.BgInput
pistonStatus.TextColor3 = Theme.TextMain
pistonStatus.Font = Enum.Font.Code
pistonStatus.TextSize = 11
pistonStatus.TextXAlignment = Enum.TextXAlignment.Left
pistonStatus.Parent = pistonCard
addCorner(pistonStatus, 6)

makeActionButton(pistonCard, "ขับรถไปร้านลูกสูบทันที (Drive to Piston Shop)", 0, 1, 262, 26, function()
	local _, pos = findNearestObjectByKeywords({ "piston", "part", "engine", "shop", "ลูกสูบ", "อะไหล่" }, 3500)
	if pos then
		moveToPositionSmart(pos, State.MaxSpeedKmh)
		appendPistonLog("กำลังขับไปยังร้านลูกสูบ (" .. State.TargetPistonSize .. ")")
	else
		appendPistonLog("ไม่พบพิกัดร้านลูกสูบในระยะสแกน • ลองกด Dump Remotes")
	end
	refreshAllUI()
end)

registerRefresh(function()
	pistonStatus.Text = "  " .. State.PistonShopLog .. " | สูงสุด: " .. tostring(State.MaxPistonsInBag)
end)

local langCard = makeCard(pageSettings, "ภาษาและการควบคุม (Language & Keybind)", 118, 1)
makeSelector(langCard, "ภาษา (Language)", 34, LanguagesList, function() return State.Language end, function(v) State.Language = v end)

local keyRow = Instance.new("Frame")
keyRow.Size = UDim2.new(1, -20, 0, 34)
keyRow.Position = UDim2.fromOffset(10, 74)
keyRow.BackgroundColor3 = Theme.BgInput
keyRow.BorderSizePixel = 0
keyRow.Parent = langCard
addCorner(keyRow, 7)

local keyLbl = Instance.new("TextLabel")
keyLbl.Size = UDim2.new(0.55, -8, 1, 0)
keyLbl.Position = UDim2.fromOffset(8, 0)
keyLbl.BackgroundTransparency = 1
keyLbl.Font = Enum.Font.GothamMedium
keyLbl.TextSize = 11
keyLbl.TextColor3 = Theme.TextMain
keyLbl.TextXAlignment = Enum.TextXAlignment.Left
keyLbl.Text = "ปุ่มเปิด/ปิดหน้าต่าง UI"
keyLbl.Parent = keyRow

local keyBindBtn = Instance.new("TextButton")
keyBindBtn.Size = UDim2.new(0.42, -4, 0, 26)
keyBindBtn.Position = UDim2.new(0.56, 0, 0.5, -13)
keyBindBtn.BackgroundColor3 = Theme.GreenDark
keyBindBtn.TextColor3 = Theme.GreenBright
keyBindBtn.Font = Enum.Font.GothamBold
keyBindBtn.TextSize = 11
keyBindBtn.Text = "[" .. State.ToggleKey.Name .. "]"
keyBindBtn.BorderSizePixel = 0
keyBindBtn.Parent = keyRow
addCorner(keyBindBtn, 6)

local waitingKeyBind = false
keyBindBtn.MouseButton1Click:Connect(function()
	waitingKeyBind = true
	keyBindBtn.Text = "กดปุ่มที่ต้องการ..."
end)

__bkTrack(UserInputService.InputBegan:Connect(function(inp, gameProcessed)
	if waitingKeyBind and inp.UserInputType == Enum.UserInputType.Keyboard then
		waitingKeyBind = false
		State.ToggleKey = inp.KeyCode
		keyBindBtn.Text = "[" .. State.ToggleKey.Name .. "]"
		if State.AutoSaveConfig then pcall(saveConfigToFile) end
		return
	end
	if not gameProcessed and inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == State.ToggleKey then
		State.UIOpen = not State.UIOpen
		mainWindow.Visible = State.UIOpen
	end
end))

local perfCard = makeCard(pageSettings, "ลดความเสี่ยง & ประสิทธิภาพ (Risk Reduction & FPS)", 152, 2)
makeToggle(perfCard, "โหมดลดความเสี่ยง (เว้นจังหวะลูป & ลดการสแกนถี่)", 34, function() return State.SafeStealthMode end, function(v) State.SafeStealthMode = v end)
makeToggle(perfCard, "หยุดระบบอัตโนมัติทันทีเมื่อพบทีมงาน/จุดเสี่ยง", 72, function() return State.AutoPanicOnSuspicious end, function(v) State.AutoPanicOnSuspicious = v end)
makeToggle(perfCard, "เพิ่ม FPS (ปรับวัสดุแมพเป็นพลาสติก / ลดเงาและเอฟเฟกต์)", 110, function() return State.BoostFPS end, function(v)
	State.BoostFPS = v
	if WorldCache.boostConn then
		WorldCache.boostConn:Disconnect()
		WorldCache.boostConn = nil
	end
	if v then
		pcall(function()
			Lighting.GlobalShadows = false
			Lighting.Brightness = 2
		end)
		task.spawn(function() -- [v1.28] แบ่งชุดทำงาน กันเฟรมตกตอนเปิดโหมดนี้ในแมพใหญ่/มือถือ
			local list = workspace:GetDescendants()
			for i = 1, #list do
				if not State.BoostFPS then return end
				pcall(WorldCache.applyBoost, list[i])
				if i % 300 == 0 then task.wait() end
			end
		end)
		-- [v9] ปรับแต่งวัตถุที่เกิดใหม่ทีหลังด้วย (เฉพาะตอนเปิดโหมดนี้)
		WorldCache.boostConn = __bkTrack(workspace.DescendantAdded:Connect(function(obj)
			WorldCache.applyBoost(obj)
		end))
	end
end)

local emojiCard = makeCard(pageSettings, "ตั้งค่าทายอีโมจิ (Emoji Solver)", 152, 3)
local emojiLastLbl = Instance.new("TextLabel")
emojiLastLbl.Size = UDim2.new(1, -20, 0, 24)
emojiLastLbl.Position = UDim2.fromOffset(10, 32)
emojiLastLbl.BackgroundColor3 = Theme.BgInput
emojiLastLbl.TextColor3 = Theme.GreenBright
emojiLastLbl.Font = Enum.Font.Code
emojiLastLbl.TextSize = 11
emojiLastLbl.TextXAlignment = Enum.TextXAlignment.Left
emojiLastLbl.Text = "  ผลทายอีโมจิล่าสุด: " .. State.LastEmojiPrompt
emojiLastLbl.Parent = emojiCard
addCorner(emojiLastLbl, 6)

makeSlider(emojiCard, "หน่วงเวลาก่อนตอบ", 62, 50, 3000, "ms", function() return State.EmojiDelayMs end, function(v) State.EmojiDelayMs = v end)
makeToggle(emojiCard, "กดตัวแรกเมื่อไม่รู้จักคำถาม", 108, function() return State.EmojiPickFirstOnUnknown end, function(v) State.EmojiPickFirstOnUnknown = v end)

local cfgCard = makeCard(pageSettings, "บันทึก & โหลดค่า + คอมมูนิตี้ + Dump Remotes", 152, 4)
makeToggle(cfgCard, "บันทึกการตั้งค่าอัตโนมัติ (Auto Save)", 34, function() return State.AutoSaveConfig end, function(v) State.AutoSaveConfig = v end)
makeActionButton(cfgCard, "บันทึกค่า", 0, 0.25, 72, 30, function()
	saveConfigToFile()
	appendEcuLog("บันทึกการตั้งค่าลงไฟล์แล้ว")
	refreshAllUI()
end)
makeActionButton(cfgCard, "โหลดค่า", 0.25, 0.25, 72, 30, function()
	loadConfigFromFile()
	refreshAllUI()
end)
makeActionButton(cfgCard, "คอมมูนิตี้", 0.5, 0.25, 72, 30, function()
	appendEcuLog("BALL KUN Vv1 • เครดิต & ผู้สร้าง: BALL KUN (MAHANAKHON RACING)")
	refreshAllUI()
end)
makeActionButton(cfgCard, "Dump Remotes", 0.75, 0.25, 72, 30, function()
	dumpMapRemotesAndGuis()
	refreshAllUI()
end)
makeActionButton(cfgCard, "กันหลุด (Anti-AFK): สลับสถานะ", 0, 1, 108, 28, function()
	State.AntiAFK = not State.AntiAFK
	antiAfkPill.Text = State.AntiAFK and "ANTI-AFK: ON" or "ANTI-AFK: OFF"
end)

local staffCard = makeCard(pageSettings, "ระบบตรวจจับทีมงาน (Staff Detection)", 228, 5)
local staffStatusLbl = Instance.new("TextLabel")
staffStatusLbl.Size = UDim2.new(1, -20, 0, 22)
staffStatusLbl.Position = UDim2.fromOffset(10, 30)
staffStatusLbl.BackgroundTransparency = 1
staffStatusLbl.Font = Enum.Font.GothamBold
staffStatusLbl.TextSize = 11
staffStatusLbl.TextColor3 = Theme.GreenBright
staffStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
staffStatusLbl.Text = "สถานะตรวจจับทีมงาน: " .. State.StaffStatus
staffStatusLbl.Parent = staffCard

local function scanForStaffNow(isAuto)
	local foundStaff = nil
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local inGroup = false
			pcall(function()
				local rank = plr:GetRankInGroup(Meta.UniverseId)
				if rank and rank >= 100 then inGroup = true end
			end)
			local nLow = plr.Name:lower()
			if inGroup or nLow:find("admin") or nLow:find("mod") or nLow:find("staff") or nLow:find("dev") then
				foundStaff = plr.Name
				break
			end
		end
	end
	if foundStaff then
		State.StaffStatus = "พบทีมงาน: " .. foundStaff
		staffStatusLbl.TextColor3 = Theme.Danger
		if State.AutoStopOnStaff or State.AutoPanicOnSuspicious then
			triggerEmergencyStop("พบทีมงาน: " .. foundStaff)
		end
		if State.HopOnStaff then
			hopServerNow("พบทีมงานในเซิร์ฟเวอร์: " .. foundStaff)
		elseif State.KickOnStaff then
			pcall(function() player:Kick("[" .. Meta.ScriptName .. "] ตรวจพบทีมงานในเซิร์ฟเวอร์: " .. foundStaff) end)
		end
	else
		State.StaffStatus = "ปลอดภัย (ไม่พบทีมงานในเซิร์ฟเวอร์)"
		staffStatusLbl.TextColor3 = Theme.GreenBright
	end
	staffStatusLbl.Text = "สถานะตรวจจับทีมงาน: " .. State.StaffStatus
	if not isAuto then refreshAllUI() end
end

makeToggle(staffCard, "เปิดระบบตรวจจับทีมงาน", 54, function() return State.StaffDetection end, function(v) State.StaffDetection = v end)
makeToggle(staffCard, "Auto Stop Bot on Staff", 90, function() return State.AutoStopOnStaff end, function(v) State.AutoStopOnStaff = v end)
makeToggle(staffCard, "ออกจากเซิร์ฟเวอร์ทันทีเมื่อพบทีมงาน", 126, function() return State.KickOnStaff end, function(v) State.KickOnStaff = v end)
makeToggle(staffCard, "ย้ายเซิร์ฟเวอร์อัตโนมัติเมื่อพบทีมงาน", 162, function() return State.HopOnStaff end, function(v) State.HopOnStaff = v end)
makeActionButton(staffCard, "สแกนเซิร์ฟเวอร์หาทีมงานทันที (Scan Staff Now)", 0, 1, 198, 24, function() scanForStaffNow(false) end)

local hopWebCard = makeCard(pageSettings, "Hop Server & Webhook แจ้งเตือน", 164, 6)
makeToggle(hopWebCard, "รันสคริปต์อัตโนมัติเมื่อ Hop Server (Auto Exec Queue)", 34, function() return State.AutoExecOnHop end, function(v) State.AutoExecOnHop = v end)

local webhookBox = Instance.new("TextBox")
webhookBox.Size = UDim2.new(1, -20, 0, 32)
webhookBox.Position = UDim2.fromOffset(10, 72)
webhookBox.BackgroundColor3 = Theme.BgInput
webhookBox.TextColor3 = Theme.TextMain
webhookBox.PlaceholderColor3 = Theme.TextMuted
webhookBox.Font = Enum.Font.Code
webhookBox.TextSize = 11
webhookBox.ClearTextOnFocus = false
webhookBox.PlaceholderText = "วาง Discord Webhook URL ที่นี่..."
-- [v10] แสดง URL แบบปิดบังเมื่อไม่ได้พิมพ์ เพื่อไม่ให้หลุดตอนอัดหน้าจอ/แคปภาพ
local WEBHOOK_MASK = "••••••••"
local function webhookShown()
	if (State.WebhookUrl or "") == "" then return "" end
	return WEBHOOK_MASK .. " (ตั้งค่าแล้ว)"
end
local function webhookCommit()
	local t = webhookBox.Text
	if t == "" then
		State.WebhookUrl = ""
	elseif not t:find(WEBHOOK_MASK, 1, true) then
		State.WebhookUrl = t
	end
end
webhookBox.Text = webhookShown()
webhookBox.Parent = hopWebCard
addCorner(webhookBox, 7)
addStroke(webhookBox, Theme.GreenGlow, 1, 0.45)

webhookBox.Focused:Connect(function()
	webhookBox.Text = State.WebhookUrl or ""
end)
webhookBox.FocusLost:Connect(function()
	webhookCommit()
	webhookBox.Text = webhookShown()
	if State.AutoSaveConfig then pcall(saveConfigToFile) end
end)

makeActionButton(hopWebCard, "ทดสอบ Webhook", 0, 0.5, 114, 34, function()
	webhookCommit()
	local _, msg = sendWebhook("ทดสอบ Webhook | " .. Meta.ScriptName, "แมพ: " .. Meta.MapName .. "\nผู้เล่น: " .. tostring(player.DisplayName) .. " (@" .. tostring(player.Name) .. ")")
	appendEcuLog(msg)
	refreshAllUI()
end)

makeActionButton(hopWebCard, "Hop Server ทันที", 0.5, 0.5, 114, 34, function()
	hopServerNow("กดปุ่ม Hop Server ทันทีจากหน้าตั้งค่า")
end)

panicBtn.MouseButton1Click:Connect(function()
	triggerEmergencyStop("กดปุ่ม STOP ALL")
	refreshAllUI()
end)

Loading.step(0.62, "Loading UI Components (pages ready)")
selectPage("HomeJobs")
refreshAllUI()

floatingBtn.MouseButton1Click:Connect(function()
	State.UIOpen = not State.UIOpen
	mainWindow.Visible = State.UIOpen
end)

closeWinBtn.MouseButton1Click:Connect(function()
	State.UIOpen = false
	mainWindow.Visible = false
end)

local lastActionTick = 0
local lastStaffScanTick = 0
local riderNextScan = 0
-- [v15] ปิดหน้าต่าง/สคริปต์ -> ยกเลิกงานและ disconnect ทุก connection ที่ลงทะเบียนไว้
screenGui.AncestryChanged:Connect(function(_, parent)
	if not parent then Runner:Destroy() end
end)
-- [v15] ตัวละครเกิดใหม่ (รีเซ็ต) -> ตัดงานเดิน/ขับที่ค้างอยู่ทันที ลูปหลักจะเริ่มรอบใหม่เอง
__bkTrack(player.CharacterAdded:Connect(function() Runner:Cancel("respawn") end))

task.spawn(function()
	while screenGui and screenGui.Parent do
		local loopDelay = State.SafeStealthMode and (1.2 + (tonumber(State.StealthExtraDelay) or 1.4)) or 0.55
		local now = tick()

		if State.StaffDetection and (now - lastStaffScanTick) >= 8 then
			lastStaffScanTick = now
			pcall(scanForStaffNow, true)
		end

		pcall(checkAndSolveEmojiCaptcha)
		pcall(processAntiStuck, loopDelay)

		if State.AutoRiderDelivery and now >= riderNextScan then
			local sid = Runner.SessionId
			local function stale() return Runner.SessionId ~= sid or not State.AutoRiderDelivery end
			pcall(function()
				autoClickGameGuiButtons({ "เปิดรับงาน", "รับงาน", "รับออเดอร์", "accept", "deliver", "ส่งของ" })
				if stale() then return end
				local targetKeywords = { "delivery", "drop", "dropoff", "customer", "waypoint", "destination", "ส่งอาหาร", "ส่งคน", "จุดส่ง" }
				local _, destPos = findNearestObjectByKeywords(targetKeywords, 4500)
				if stale() then return end
				if destPos then
					State.RiderStatus = "กำลังขับไปส่งออเดอร์ (" .. State.RiderMode .. ")"
					local arrived = moveToPositionSmart(destPos, State.MaxSpeedKmh)
					if stale() then return end
					if arrived then
						local jobs0 = tonumber(player:GetAttribute("DeliveryJobs")) or 0
						local didAct = interactWithNearbyPrompts({ "deliver", "complete", "drop", "ส่ง" }, 25)
						task.wait(1.5)
						if stale() then return end
						-- [v21] นับสำเร็จเมื่อเกมยืนยันเท่านั้น (DeliveryJobs เพิ่มขึ้น) ไม่เชื่อแค่ว่ากดได้
						if (tonumber(player:GetAttribute("DeliveryJobs")) or 0) > jobs0 then
							State.CompletedJobs = State.CompletedJobs + 1
							State.RiderStatus = "ส่งสำเร็จ (เกมยืนยันแล้ว) รอออเดอร์ถัดไป..."
						else
							State.RiderStatus = didAct and "กดแล้วแต่เกมยังไม่ยืนยันงาน" or "ถึงจุดแล้วแต่ไม่มีปุ่มโต้ตอบ (งานไรเดอร์ยืนยันด้วยแถบปัดบนมือถือ: ใช้โหมด FARM)"
						end
					end
				else
					local _, startPos = findNearestObjectByKeywords({ "rider", "grab", "lineman", "food", "ไรเดอร์", "รับงาน" }, 3500)
					if stale() then return end
					if startPos then
						State.RiderStatus = "กำลังไปจุดรับงานไรเดอร์..."
						local atStart = moveToPositionSmart(startPos, State.MaxSpeedKmh)
						if stale() then return end
						if atStart then
							interactWithNearbyPrompts({ "rider", "job", "order", "รับ" }, 25)
							fireMatchingRemotes({ "startjob", "rider", "acceptorder" }, State.RiderMode)
						end
					else
						State.RiderStatus = "กำลังรอออเดอร์ (" .. State.RiderMode .. ")..."
						riderNextScan = tick() + 1.5 -- [v15] ตอนไม่มีงาน เว้นการสแกนหนักให้ห่างขึ้น
					end
				end
			end)
		end

		if State.AutoBuilder then
			pcall(function()
				autoClickGameGuiButtons({ "รับงาน", "ก่อสร้าง", "build", "start" })
				local _, bPos = findNearestObjectByKeywords({ "build", "construct", "brick", "wood", "ก่อสร้าง", "ซ่อมสร้าง" }, 3500)
				if bPos then
					local arrived = moveToPositionSmart(bPos, State.CornerSpeedKmh)
					if arrived then
						local didAct = interactWithNearbyPrompts({ "build", "construct", "สร้าง", "ทำงาน" }, 25)
						if didAct then State.WorkStatus = "ส่งคำสั่งงานแล้ว — รอเกมยืนยันผล" end -- ไม่เพิ่ม CompletedJobs จากการกด Prompt อย่างเดียว
					end
				end
			end)
		end

		if State.AutoMechanic then
			pcall(function()
				autoClickGameGuiButtons({ "รับงาน", "ช่างซ่อม", "mechanic", "repair" })
				local _, mPos = findNearestObjectByKeywords({ "mechanic", "garage", "repairjob", "ช่างซ่อม", "อู่ซ่อม" }, 3500)
				if mPos then
					local arrived = moveToPositionSmart(mPos, State.CornerSpeedKmh)
					if arrived then
						local didAct = interactWithNearbyPrompts({ "mechanic", "repair", "fix", "ซ่อม" }, 25)
						if didAct then State.WorkStatus = "ส่งคำสั่งงานแล้ว — รอเกมยืนยันผล" end -- ไม่เพิ่ม CompletedJobs จากการกด Prompt อย่างเดียว
					end
				end
			end)
		end

		if (now - lastActionTick) >= 3 then
			lastActionTick = now
			local vehModel = getPlayerVehicle()
			if vehModel then
				local fuelVal = vehModel:GetAttribute("Fuel") or vehModel:GetAttribute("Gas")
				if State.AutoRefuel and type(fuelVal) == "number" and fuelVal <= State.RefuelBelowPercent then
					pcall(executeRefuelNow)
				end
				local hpVal = vehModel:GetAttribute("Health") or vehModel:GetAttribute("Durability")
				if State.AutoRepair and type(hpVal) == "number" and hpVal <= State.RepairBelowPercent then
					pcall(executeRepairNow)
				end
			end
		end

		if State.AutoDriveToTuner or State.AutoTuneECU then
			pcall(function()
				local _, tPos = findNearestObjectByKeywords({ "tuner", "ecu", "dyno", "tune", "จูน", "ร้านจูน" }, 3500)
				if State.AutoDriveToTuner and tPos then
					local arrived = moveToPositionSmart(tPos, State.MaxSpeedKmh)
					if arrived then
						State.AutoDriveToTuner = false
						appendEcuLog("ถึงร้านจูน ECU แล้ว!")
					end
				end
				if State.AutoTuneECU then
					interactWithNearbyPrompts({ "tune", "ecu", "dyno", "จูน" }, 28)
					fireRemotesSmart("tune", { "ecu", "tune", "remap", "dyno" }, State.TuneVehicle, State.EcuMap)
					autoClickGameGuiButtons({ "จูน", "tune", "apply", "ติดตั้ง" })
				end
			end)
		end

		if State.AutoBuyPiston then
			pcall(function()
				if State.PistonsInBag < State.MaxPistonsInBag and (tick() - lastPistonAttemptAt) >= 5 then
					local _, pPos = findNearestObjectByKeywords({ "piston", "part", "shop", "ลูกสูบ", "ร้านอะไหล่" }, 3500)
					if pPos then
						local arrived = moveToPositionSmart(pPos, State.MaxSpeedKmh)
						if arrived then
							local didAct = interactWithNearbyPrompts({ "piston", "buy", "shop", "ซื้อ", "ลูกสูบ" }, 28)
							local didClick = autoClickGameGuiButtons({ "ซื้อ", "buy", State.TargetPistonSize:lower() })
							if didAct or didClick then
								lastPistonAttemptAt = tick()
								appendPistonLog("ส่งคำสั่งซื้อแล้ว — ยังไม่เพิ่มจำนวนจนกว่าจะยืนยันไอเทมเข้ากระเป๋าจริง")
							end
						end
					end
				end
				if State.AutoInstallPiston then
					fireMatchingRemotes({ "install", "equip", "piston", "upgrade" }, State.SelectedVehicle, State.TargetPistonSize)
					autoClickGameGuiButtons({ "ติดตั้ง", "install", "equip" })
				end
			end)
		end

		if mainWindow.Visible then
			pcall(function()
				updateWorkLiveStatus()
				stJobVal.Text = State.CurrentJob
				stDoneVal.Text = tostring(State.CompletedJobs) .. " งาน"
				stCheckVal.Text = tostring(State.SolvedFarmChecks) .. " ครั้ง"
				stLiveVal.Text = State.WorkStatus
				stLiveVal.TextColor3 = (State.WorkStatus == "กำลังทำงาน") and Theme.GreenBright or Theme.TextMuted
				riderStatusLbl.Text = "สถานะไรเดอร์: " .. State.RiderStatus
				pistonStatus.Text = "  " .. State.PistonShopLog .. " | สูงสุด: " .. tostring(State.MaxPistonsInBag)
				ecuConsole.Text = "  " .. State.EcuConsoleLog
				emojiLastLbl.Text = "  ผลทายอีโมจิล่าสุด: " .. State.LastEmojiPrompt
				antiAfkPill.Text = State.AntiAFK and "ANTI-AFK: ON" or "ANTI-AFK: OFF"
			end)
		end

		task.wait(loopDelay)
	end
end)

-- ===================== MAP ADAPTIVE (appended) =====================
Loading.step(0.72, "Initializing Map Adaptive")
local __maOk = true
do
local __ctxMA = {
	Players = Players, RunService = RunService, HttpService = HttpService, UserInputService = UserInputService,
	Theme = Theme, State = State, Meta = Meta, player = player,
	createPage = createPage, makeCard = makeCard, makeToggle = makeToggle, makeActionButton = makeActionButton, makeSlider = makeSlider, clickBtn = clickGuiButtonSafe, playerGui = playerGui, guiRootName = guiRootName,
	addCorner = addCorner, addStroke = addStroke, navButtons = navButtons,
	getCharacterParts = getCharacterParts, mainWindow = mainWindow, WorldCache = WorldCache, isBlockedText = isBlockedText,
	firePromptSafe = firePromptSafe, WalkBridge = WalkBridge,
	sendWebhook = sendWebhook, saveConfig = saveConfigToFile,
	autoClick = autoClickGameGuiButtons, moveToPositionSmart = moveToPositionSmart,
}
local __okMA, __errMA = pcall(function()
-- ============================================================================
-- BALL KUN Vv1 : MAP ADAPTIVE MODULE (appended, original code untouched)
-- [v16] fixes: memory path serialization, refresh recovery, change-detector noise, scan quota, re-plan Blocked listener
-- Read-only map analysis. Never calls RemoteEvent / RemoteFunction.
-- Modules: ErrorMonitor, MapDetector, ObjectScanner, MapMemory, PathAnalyzer,
--          AutoSystemCheck, MapAdaptiveUI
-- ============================================================================
local ctx = __ctxMA
local HttpService = ctx.HttpService
local Theme, State, Meta, player = ctx.Theme, ctx.State, ctx.Meta, ctx.player
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local MarketplaceService = game:GetService("MarketplaceService")
local PlayersSvc = game:GetService("Players")


-- Integration contract: JobBot/Farm read nearby objects through the shared WorldCache;
-- MAP ADAPTIVE receives that same cache and exposes walk movement through WalkBridge.
-- PathA remains an advisory planner; it does not directly fire game remotes.
local MA = {
	Version = "1.0",
	Config = {
		MaxInteractables = 3000,
		MaxIgnored = 400, -- [v16] จุด ignore/blocked เก็บได้จำกัด ไม่แย่งโควต้าจุดที่ใช้งานจริง
		MaxLabels = 200,
		MaxSavedEntries = 300,
		YieldEvery = 400,
		MaxRetry = 3,
		PollSeconds = 5,
		DirtyThreshold = 40, -- [v16] นับเฉพาะ Prompt/ClickDetector/ป้าย (ไม่นับชิ้นส่วนรถ/ตัวละคร)
		MinRescanGap = 20,
		PosTolerance = 5,
		AutoRescan = true,
		FilePrefix = "BALL_KUN_MapAdaptive_",
		FileVersion = 2, -- [v13] บังคับสแกนใหม่ ทิ้งหมวดเดิมที่จัดผิด
	},
}

local function stamp() return os.date("%H:%M:%S") end
local function lower(s) return string.lower(tostring(s or "")) end

-- [v13] ตัดข้อความโดยไม่ผ่ากลางตัวอักษร UTF-8 (แก้ภาษาไทยกลายเป็น "�")
local function cut(s, n)
	s = tostring(s or "")
	if #s <= n then return s end
	local i = n
	while i > 0 do
		local b = s:byte(i + 1)
		if not b or b < 0x80 or b >= 0xC0 then break end
		i = i - 1
	end
	return s:sub(1, i)
end

-- [v13] จับคำแบบมีขอบเขต: คำภาษาอังกฤษต้องขึ้นต้นที่ต้นคำ (กัน "fix" ใน "prefix", "gas" ใน "vegas", "ecu" ใน "secure")
local function hasWord(text, w)
	if w:find("[\128-\255]") then return string.find(text, w, 1, true) ~= nil end
	local init = 1
	while true do
		local s = string.find(text, w, init, true)
		if not s then return false end
		local before = (s > 1) and text:sub(s - 1, s - 1) or ""
		if before == "" or not before:find("%w") then return true end
		init = s + 1
	end
end
local function dist3(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- ---------------------------------------------------------------------------
-- 1) ERROR MONITOR : guard, no re-entrancy, limited retry, stop on repeated fail
-- ---------------------------------------------------------------------------
local EM = { log = {}, systems = {}, notifyAt = {}, maxLog = 40 }
MA.ErrorMonitor = EM

local function sysState(name)
	local s = EM.systems[name]
	if not s then
		s = { running = false, fails = 0, stopped = false, reason = "", runs = 0, last = "-" }
		EM.systems[name] = s
	end
	return s
end

function EM.record(name, err)
	local message = tostring(err)
	table.insert(EM.log, 1, "[" .. stamp() .. "] " .. tostring(name) .. ": " .. message)
	while #EM.log > EM.maxLog do table.remove(EM.log) end
	local now = os.clock()
	if now - (EM.notifyAt[name] or 0) >= 10 then
		EM.notifyAt[name] = now
		pcall(__notify, "MAP ADAPTIVE Error: " .. tostring(name), message:sub(1, 160))
	end
end

function EM.guard(name, fn, ...)
	local s = sysState(name)
	if s.stopped then return false, "หยุด: " .. tostring(s.reason) end
	if s.running then return false, "busy" end
	s.running = true
	s.runs = s.runs + 1
	local ok, res = xpcall(fn, function(e) return tostring(e) end, ...)
	s.running = false
	if ok then
		s.fails = 0
		s.last = "OK " .. stamp()
		return true, res
	end
	s.fails = s.fails + 1
	s.last = "ล้มเหลว " .. stamp()
	EM.record(name, res)
	if s.fails >= MA.Config.MaxRetry then
		s.stopped = true
		s.reason = tostring(res)
		EM.record(name, "หยุดหลังล้มเหลว " .. s.fails .. " ครั้งติดต่อกัน")
		-- [v10] แจ้งผู้ใช้ชัดเจนว่าโมดูลถูกพัก (ไม่ใช่ค้าง) และบอกวิธีกู้คืน
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "BALL KUN: โมดูลถูกพักชั่วคราว",
				Text = tostring(name) .. " ล้มเหลวติดต่อกัน กด REFRESH MAP เพื่อกู้คืน",
				Duration = 8,
			})
		end)
	end
	return false, res
end

-- limited retry (bounded attempts, growing delay)
function EM.retry(name, fn, attempts, delay, ...)
	attempts = attempts or MA.Config.MaxRetry
	local lastErr = "unknown"
	for i = 1, attempts do
		local ok, res = pcall(fn, ...)
		if ok and res ~= false then return true, res end
		lastErr = tostring(res)
		EM.record(name, "retry " .. i .. "/" .. attempts .. " : " .. lastErr)
		if i < attempts then task.wait((delay or 0.5) * i) end
	end
	return false, lastErr
end

function EM.resetSystem(name)
	if name then EM.systems[name] = nil else EM.systems = {} end
end

function EM.stoppedList()
	local out = {}
	for n, s in pairs(EM.systems) do
		if s.stopped then out[#out + 1] = n .. " (" .. cut(s.reason, 60) .. ")" end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Pure helpers (testable without Roblox)
-- ---------------------------------------------------------------------------
local KEYWORDS = {
	{ cat = "ignore", words = { "hall of fame", "หอเกียรติยศ", "leaderboard", "podium", "อันดับ" } }, -- [v13] ป้ายอันดับ ไม่ใช่จุดใช้งาน
	{ cat = "uniform", words = { "uniform", "locker", "ชุดไรเดอร์", "ใส่ชุด", "เปลี่ยนชุด", "ล็อกเกอร์", "ชุดพนักงาน" } },
	{ cat = "order", words = { "รับงาน", "รับออเดอร์", "ออเดอร์", "order", "accept", "pickup", "pick up", "take job" } },
	{ cat = "deliver", words = { "ส่งมอบ", "ส่งของ", "ส่งอาหาร", "deliver", "customer", "ลูกค้า", "dropoff", "drop off" } },
	{ cat = "job", words = { "job", "deliver", "rider", "order", "pickup", "dropoff", "ส่ง", "งาน", "ไรเดอร์", "ออเดอร์" } },
	{ cat = "piston", words = { "ใส่ลูก", "ลูกสูบ", "piston" } },
	{ cat = "vehicle", words = { "drive", "ride", "ขับ", "ขึ้นรถ", "เรียกรถ", "spawn" } },
	{ cat = "fuel", words = { "fuel", "gas", "petrol", "refuel", "น้ำมัน", "ปั๊ม" } }, -- [v13] เอา "เติม" ออก (ชนกับ "เติมเงิน")
	{ cat = "repair", words = { "repair", "mechanic", "garage", "fix", "ซ่อม", "อู่", "อะไหล่" } },
	{ cat = "tuner", words = { "tune", "tuner", "ecu", "dyno", "จูน" } },
	{ cat = "shop", words = { "shop", "buy", "store", "dealer", "purchase", "ร้าน", "ซื้อ" } },
}

-- returns category, matchedKeyword, matchedField  (or "unknown")
function MA.classify(fields)
	for _, f in ipairs(fields) do
		local text = lower(f.text)
		if text ~= "" then
			-- [v12] ข้อความที่ห้ามโต้ตอบ: จัดเป็น "blocked" ไม่ถูกเลือกเป็นเป้าหมาย
			local blocked, bw = ctx.isBlockedText(text)
			if blocked then return "blocked", bw, f.src end
			for _, k in ipairs(KEYWORDS) do
				for _, w in ipairs(k.words) do
					if hasWord(text, w) then return k.cat, w, f.src end
				end
			end
		end
	end
	return "unknown", nil, nil
end

-- [v14] จัดหมวดจากเส้นทางจริงของแมพ MAHANAKHON (ได้จาก MAP DUMP) -- ชนะการเดาจากคำ
function MA.classifyPath(names)
	local p = lower(table.concat(names, "/"))
	if p:find("joblockers/", 1, true) then
		-- ตู้เปลี่ยนชุดมีหลายอาชีพ (Courier/Mechanic/Builder/CarWash) ไรเดอร์ส่งอาหารใช้เฉพาะ Locker_Delivery
		return p:find("locker_delivery", 1, true) and "uniform" or "ignore"
	end
	if p:find("tuneshops/", 1, true) then return "tuner" end
	if p:find("repairshop/", 1, true) then return "repair" end
	if p:find("spawnedvehicles/", 1, true) then
		if p:find("refuelprompt", 1, true) then return "fuel" end
		if p:find("pistonpoint", 1, true) or p:find("pistonfit", 1, true) then return "piston" end
		if p:find("mountprompt", 1, true) or p:find("rideprompt", 1, true) then return "vehicle" end
		return nil
	end
	for _, w in ipairs({ "clothing", "housevillage", "passshowcase", "construction", "builderyard", "leaderboards",
		"draglobby", "groupreward", "carwash", "stations/" }) do
		if p:find(w, 1, true) then return "ignore" end
	end
	return nil
end

local function djb2(s)
	local h = 5381
	for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
	return string.format("%08x", h)
end

-- order-independent signature of top-level structure
function MA.signature(names)
	local counts, keys = {}, {}
	for _, n in ipairs(names) do
		n = tostring(n)
		if not counts[n] then counts[n] = 0; keys[#keys + 1] = n end
		counts[n] = counts[n] + 1
	end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. counts[k] end
	return djb2(table.concat(parts, "|")), #names
end

-- ---------------------------------------------------------------------------
-- 2) MAP DETECTOR
-- ---------------------------------------------------------------------------
local Detector = { info = nil, changeReason = "-", lastPlaceId = nil, added = 0, removed = 0, dirty = false }
MA.Detector = Detector

local function topLevelNames()
	local names = {}
	for _, c in ipairs(Workspace:GetChildren()) do
		if not PlayersSvc:GetPlayerFromCharacter(c) then names[#names + 1] = c.Name end
	end
	return names
end

function Detector.snapshot()
	local names = topLevelNames()
	local sig, n = MA.signature(names)
	local folders, models = 0, 0
	for _, c in ipairs(Workspace:GetChildren()) do
		if c:IsA("Folder") then folders = folders + 1 elseif c:IsA("Model") then models = models + 1 end
	end
	local info = {
		placeId = game.PlaceId,
		gameId = game.GameId,
		name = Detector.info and Detector.info.name or tostring(game.Name),
		topCount = n,
		folders = folders,
		models = models,
		signature = sig,
		legacyMatch = (game.PlaceId == Meta.PlaceId),
		time = stamp(),
	}
	return info
end

function Detector.fetchName()
	task.spawn(function()
		local ok, pinfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
		if ok and type(pinfo) == "table" and pinfo.Name and Detector.info then
			Detector.info.name = tostring(pinfo.Name)
		end
	end)
end

-- returns true if the map changed since the last snapshot
function Detector.check()
	local new = Detector.snapshot()
	local old = Detector.info
	Detector.info = new
	if not old then
		Detector.lastPlaceId = new.placeId
		Detector.changeReason = "initial"
		return true
	end
	new.name = old.name
	if old.placeId ~= new.placeId then
		Detector.changeReason = "PlaceId " .. tostring(old.placeId) .. " -> " .. tostring(new.placeId)
		return true
	end
	if old.signature ~= new.signature then
		Detector.changeReason = "โครงสร้าง Workspace เปลี่ยน (" .. old.topCount .. " -> " .. new.topCount .. ")"
		return true
	end
	if Detector.dirty then
		Detector.changeReason = "วัตถุเพิ่ม/ลดจำนวนมาก (" .. Detector.added .. "+/" .. Detector.removed .. "-)"
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- 3) OBJECT SCANNER
-- ---------------------------------------------------------------------------
local Scanner = {
	token = 0, scanning = false, result = nil, lastScan = 0,
	entries = {}, labels = {}, counts = {}, truncated = false, duration = 0,
}
MA.Scanner = Scanner

local function getPosition(inst)
	local cur = inst
	for _ = 1, 5 do
		if not cur then break end
		local ok, p = pcall(function()
			if cur:IsA("BasePart") then return cur.Position end
			if cur:IsA("Attachment") then return cur.WorldPosition end
			if cur:IsA("Model") then return cur:GetPivot().Position end
			return nil
		end)
		if ok and p then return { x = p.X, y = p.Y, z = p.Z } end
		cur = cur.Parent
	end
	return nil
end
MA.getPosition = getPosition

local function pathOf(inst)
	local names, cur = {}, inst
	while cur and cur ~= Workspace and cur ~= game do
		table.insert(names, 1, cur.Name)
		cur = cur.Parent
	end
	return names
end

local function resolvePath(names)
	local cur = Workspace
	for _, n in ipairs(names) do
		cur = cur and cur:FindFirstChild(n)
		if not cur then return nil end
	end
	return cur
end
MA.resolvePath = resolvePath

local function ancestorNames(inst, depth)
	local out, cur = {}, inst and inst.Parent
	for _ = 1, depth do
		if not cur or cur == Workspace then break end
		out[#out + 1] = cur.Name
		cur = cur.Parent
	end
	return out
end

-- verification: still in Workspace, same class, position readable & close
function Scanner.verify(e)
	local inst = e.inst
	if not inst then return false end
	local ok, res = pcall(function()
		if not inst:IsDescendantOf(Workspace) then return false end
		if inst.ClassName ~= e.class then return false end
		local p = getPosition(inst)
		if not p then return false end
		return dist3(p, e.pos) <= MA.Config.PosTolerance
	end)
	return ok and res == true
end

function Scanner.scan()
	-- [v1.28] ถ้าสแกนก่อนหน้าค้างเกิน 60 วินาที ให้ปล่อยให้สแกนใหม่แทนที่ (ตัวเก่าจะหยุดเองจาก token)
	if Scanner.scanning and (os.clock() - (Scanner.startedAt or 0)) < 60 then return false, "busy" end
	Scanner.scanning = true
	Scanner.startedAt = os.clock()
	Scanner.token = Scanner.token + 1
	local myToken = Scanner.token
	local t0 = os.clock()
	local entries, labels = {}, {}
	local counts = { Part = 0, Model = 0, Folder = 0, ProximityPrompt = 0, ClickDetector = 0, Label = 0, Total = 0 }
	local truncated = false
	local cfg = MA.Config
	local ignoredCount = 0

	local function processItem(d)
		counts.Total = counts.Total + 1
		if d:IsA("ProximityPrompt") then
			counts.ProximityPrompt = counts.ProximityPrompt + 1
			if #entries >= cfg.MaxInteractables then truncated = true return end
			local pos = getPosition(d)
			if not pos then return end
			local anc = ancestorNames(d, 3)
			local fields = {
				{ src = "ActionText", text = d.ActionText },
				{ src = "ObjectText", text = d.ObjectText },
				{ src = "Name", text = d.Name },
			}
			for i, n in ipairs(anc) do fields[#fields + 1] = { src = "Parent" .. i, text = n } end
			local cat, kw, src = MA.classify(fields)
			if cat ~= "blocked" then
				local pc = MA.classifyPath(pathOf(d))
				if pc then cat, kw, src = pc, "path", "Path" end
			end
			if cat == "ignore" or cat == "blocked" then
				ignoredCount = ignoredCount + 1
				if ignoredCount > cfg.MaxIgnored then return end
			end
			entries[#entries + 1] = {
				inst = d, class = "ProximityPrompt", name = d.Name, path = pathOf(d), pos = pos,
				kind = cat, matched = kw, source = src,
				action = tostring(d.ActionText or ""), object = tostring(d.ObjectText or ""),
				hold = d.HoldDuration, enabled = d.Enabled, verified = false,
			}
		elseif d:IsA("ClickDetector") then
			counts.ClickDetector = counts.ClickDetector + 1
			if #entries >= cfg.MaxInteractables then truncated = true return end
			local pos = getPosition(d)
			if not pos then return end
			local fields = { { src = "Name", text = d.Name } }
			for i, n in ipairs(ancestorNames(d, 3)) do fields[#fields + 1] = { src = "Parent" .. i, text = n } end
			local cat, kw, src = MA.classify(fields)
			if cat ~= "blocked" then
				local pc = MA.classifyPath(pathOf(d))
				if pc then cat, kw, src = pc, "path", "Path" end
			end
			entries[#entries + 1] = {
				inst = d, class = "ClickDetector", name = d.Name, path = pathOf(d), pos = pos,
				kind = cat, matched = kw, source = src, action = "", object = "", hold = 0,
				enabled = true, verified = false,
			}
		elseif d:IsA("TextLabel") or d:IsA("TextButton") then
			local txt = tostring(d.Text or "")
			if txt ~= "" and (d:FindFirstAncestorOfClass("BillboardGui") or d:FindFirstAncestorOfClass("SurfaceGui")) then
				local model = d:FindFirstAncestorOfClass("Model")
				if not (model and PlayersSvc:GetPlayerFromCharacter(model)) then
					counts.Label = counts.Label + 1
					if #labels < cfg.MaxLabels then
						labels[#labels + 1] = { text = cut(txt, 60), pos = getPosition(d) }
					end
				end
			end
		elseif d:IsA("BasePart") then
			counts.Part = counts.Part + 1
		elseif d:IsA("Model") then
			counts.Model = counts.Model + 1
		elseif d:IsA("Folder") then
			counts.Folder = counts.Folder + 1
		end
	end

	local okAll, errAll = pcall(function()
		local list = Workspace:GetDescendants()
		for i = 1, #list do
			if Scanner.token ~= myToken then error("ถูกแทนที่ด้วยการสแกนใหม่") end
			local ok, err = pcall(processItem, list[i])
			if not ok then EM.record("ObjectScanner", err) end
			if i % cfg.YieldEvery == 0 then task.wait() end
		end
	end)

	if Scanner.token == myToken then Scanner.scanning = false end
	if not okAll then error(errAll) end

	-- [v13] สแกนเมนู GUI: ในแมพนี้ ECU / อะไหล่ / ร้านค้า เป็นหน้าต่าง GUI ไม่ใช่จุดโต้ตอบในโลก
	local guiHits = {}
	pcall(function()
		local pg = player:FindFirstChild("PlayerGui")
		if not pg then return end
		local ours = ctx.guiRootName
		local k = 0
		for _, g in ipairs(pg:GetDescendants()) do
			k = k + 1
			if k % cfg.YieldEvery == 0 then task.wait() end
			if (g:IsA("TextButton") or g:IsA("TextLabel")) and #g.Text > 0 and #g.Text <= 40
				and not (ours and g:FindFirstAncestor(ours)) then
				local cat = MA.classify({ { src = "Gui", text = g.Text } })
				if cat ~= "unknown" and cat ~= "blocked" and cat ~= "ignore" then
					local h = guiHits[cat]
					if not h then h = { n = 0, sample = cut(g.Text, 20) } guiHits[cat] = h end
					h.n = h.n + 1
				end
			end
		end
	end)
	Scanner.guiHits = guiHits

	local verifiedCount = 0
	for _, e in ipairs(entries) do
		e.verified = Scanner.verify(e)
		if e.verified then verifiedCount = verifiedCount + 1 end
	end
	Scanner.entries, Scanner.labels, Scanner.counts = entries, labels, counts
	Scanner.truncated = truncated
	Scanner.duration = os.clock() - t0
	Scanner.lastScan = os.clock()
	Scanner.verifiedCount = verifiedCount
	return true, #entries
end

-- [v1.37] ล้างรายการที่ Instance ถูกลบไปแล้ว (ไม่ถือ reference วัตถุที่หายไปนานระหว่างรอสแกนรอบถัดไป)
function Scanner.prune()
	local list = Scanner.entries
	if type(list) ~= "table" or #list == 0 or Scanner.scanning then return 0 end
	local keep, dropped = {}, 0
	for k = 1, #list do
		local e = list[k]
		local alive = true
		if type(e) == "table" and e.inst ~= nil then
			local ok, d = pcall(function() return e.inst:IsDescendantOf(Workspace) end)
			alive = ok and d == true
		end
		if alive then keep[#keep + 1] = e else dropped = dropped + 1 end
	end
	if dropped > 0 and Scanner.entries == list then Scanner.entries = keep end
	return dropped
end

-- onlyUseful=true: ใช้เลือกเป้าหมายเดิน/วิเคราะห์ ตัดจุดที่ปิดอยู่ (disabled) และหมวด unknown/blocked/ignore ออก
function Scanner.sortedByDistance(origin, onlyUseful)
	local list = {}
	for _, e in ipairs(Scanner.entries) do
		local useful = true
		if onlyUseful then
			if e.kind == "unknown" or e.kind == "blocked" or e.kind == "ignore" then useful = false end
			if useful and e.class == "ProximityPrompt" then
				local okE, en = pcall(function() return e.inst.Enabled end)
				if not okE or en == false then useful = false end
			end
		end
		if e.verified and useful then
			list[#list + 1] = { e = e, d = origin and dist3(e.pos, origin) or 0 }
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	return list
end

-- ---------------------------------------------------------------------------
-- 4) MAP MEMORY : only verified data is stored; revalidated on load
-- ---------------------------------------------------------------------------
local Memory = { loaded = 0, stale = 0, savedCount = 0, status = "empty", entries = {},
	lastSaveAt = 0, lastSerialized = nil, saveCooldown = 15 }

MA.Memory = Memory

function Memory.fileName()
	return MA.Config.FilePrefix .. tostring(game.PlaceId) .. ".json"
end

function Memory.serialize(entries)
	local out = {}
	for _, e in ipairs(entries) do
		local p = e.pos
		-- [v10] บันทึกเฉพาะค่าที่ JSON รองรับ (สตริง/ตัวเลข) และมีตำแหน่งครบ กัน Instance/nil หลุดเข้าไฟล์
		local pathArr = {}
		if type(e.path) == "table" then
			for _, n in ipairs(e.path) do pathArr[#pathArr + 1] = cut(tostring(n), 80) end
		end
		if e.verified and #out < MA.Config.MaxSavedEntries and type(p) == "table" and #pathArr > 0 and #pathArr <= 40
			and tonumber(p.x) and tonumber(p.y) and tonumber(p.z) then
			out[#out + 1] = {
				path = pathArr, class = tostring(e.class or ""), kind = tostring(e.kind or ""),
				name = cut(e.name, 100), action = cut(e.action, 100),
				object = type(e.object) == "string" and cut(e.object, 100) or nil,
				pos = { x = tonumber(p.x), y = tonumber(p.y), z = tonumber(p.z) },
			}
		end
	end
	return { version = MA.Config.FileVersion, placeId = game.PlaceId, saved = os.time(), entries = out }
end

function Memory.save(entries, force)
	if type(writefile) ~= "function" then Memory.status = "ไม่รองรับ writefile (ไม่บันทึก)" return false end
	local doc = Memory.serialize(entries)
	local ok, enc = pcall(function() return HttpService:JSONEncode(doc) end)
	if not ok then return false, enc end
	local now = os.clock()
	-- Avoid disk writes on every map refresh: skip identical data and throttle changed data.
	if enc == Memory.lastSerialized then
		Memory.status = "ข้อมูลเหมือนเดิม (ข้ามการบันทึก)"
		return true, "unchanged"
	end
	if not force and Memory.lastSaveAt > 0 and now - Memory.lastSaveAt < (Memory.saveCooldown or 15) then
		Memory.status = "ข้อมูลเปลี่ยน รอบันทึกตามคูลดาวน์"
		return true, "throttled"
	end
	local okW, errW = pcall(writefile, Memory.fileName(), enc)
	if okW then
		Memory.lastSaveAt, Memory.lastSerialized = now, enc
		Memory.savedCount = #doc.entries
		Memory.status = "saved " .. #doc.entries .. " @ " .. stamp()
	else
		Memory.status = "บันทึกไม่สำเร็จ"
	end
	return okW, errW
end

-- validate one stored entry against the live workspace
local function resolveByPosition(names, idx, cur, rec, budget)
	if idx > #names then
		if cur.ClassName ~= rec.class then return nil end
		local pp = getPosition(cur)
		if pp and dist3(pp, rec.pos) <= MA.Config.PosTolerance then return cur, pp end
		return nil
	end
	for _, c in ipairs(cur:GetChildren()) do
		if c.Name == names[idx] then
			budget.n = budget.n - 1
			if budget.n < 0 then return nil end
			local r, rp = resolveByPosition(names, idx + 1, c, rec, budget)
			if r then return r, rp end
		end
	end
	return nil
end

function Memory.validateEntry(rec)
	if type(rec) ~= "table" or type(rec.path) ~= "table" or type(rec.pos) ~= "table" then return nil end
	if not (tonumber(rec.pos.x) and tonumber(rec.pos.y) and tonumber(rec.pos.z)) then return nil end
	-- [v16] ชื่อพี่น้องซ้ำกันได้ จึงลองทุกตัวที่ชื่อตรง แล้วเลือกตัวที่ class และตำแหน่งตรงกับที่บันทึกไว้
	local inst, p = resolveByPosition(rec.path, 1, Workspace, rec, { n = 400 })
	if not inst then return nil end
	return {
		inst = inst, class = rec.class, name = rec.name, path = rec.path, pos = p, kind = rec.kind,
		matched = "memory", source = "Memory", fromMemory = true,
		action = rec.action or "", object = rec.object or "", hold = 0, enabled = true, verified = true,
	}
end

function Memory.load()
	Memory.loaded, Memory.stale, Memory.entries = 0, 0, {}
	if type(isfile) ~= "function" or type(readfile) ~= "function" then Memory.status = "no readfile" return 0 end
	local okF, exists = pcall(isfile, Memory.fileName())
	if not okF or not exists then Memory.status = "ไม่มีข้อมูลที่บันทึกของแมพนี้" return 0 end
	local okR, raw = pcall(readfile, Memory.fileName())
	if not okR then Memory.status = "อ่านไฟล์ไม่สำเร็จ" return 0 end
	local okD, doc = pcall(function() return HttpService:JSONDecode(raw) end)
	if not okD or type(doc) ~= "table" or doc.version ~= MA.Config.FileVersion
		or doc.placeId ~= game.PlaceId or type(doc.entries) ~= "table" then
		Memory.status = "ปฏิเสธข้อมูลที่บันทึก (แมพ/เวอร์ชันไม่ตรง)"
		return 0
	end
	for _, rec in ipairs(doc.entries) do
		local e = Memory.validateEntry(rec)
		if e then
			Memory.entries[#Memory.entries + 1] = e
			Memory.loaded = Memory.loaded + 1
		else
			Memory.stale = Memory.stale + 1
		end
	end
	Memory.status = "loaded " .. Memory.loaded .. " valid / " .. Memory.stale .. " ทิ้งข้อมูลเก่า"
	return Memory.loaded
end

function Memory.reset()
	Memory.entries, Memory.loaded, Memory.stale, Memory.savedCount = {}, 0, 0, 0
	Scanner.entries, Scanner.labels, Scanner.counts = {}, {}, {}
	Scanner.verifiedCount = 0
	if type(delfile) == "function" and type(isfile) == "function" then
		pcall(function() if isfile(Memory.fileName()) then delfile(Memory.fileName()) end end)
	elseif type(writefile) == "function" then
		pcall(writefile, Memory.fileName(), HttpService:JSONEncode({ version = MA.Config.FileVersion, placeId = game.PlaceId, entries = {} }))
	end
	Memory.status = "reset " .. stamp()
end

-- ---------------------------------------------------------------------------
-- 5) PATH ANALYZER (PathfindingService, walking only, mobile friendly)
-- ---------------------------------------------------------------------------
local PathA = { token = 0, walking = false, status = "idle", last = nil, target = nil, targetIndex = 0 }
MA.Path = PathA

local AGENTS = {
	{ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 },
	{ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 },
	{ AgentRadius = 3, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 4 },
}

local function pathLength(wps)
	local total, prev = 0, nil
	for _, w in ipairs(wps) do
		if prev then total = total + (w.Position - prev).Magnitude end
		prev = w.Position
	end
	return total
end

function PathA.analyze(targetPos)
	local char, hrp = ctx.getCharacterParts()
	if not hrp then return { success = false, reason = "ไม่พบตัวละคร" } end
	local from = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z }
	local direct = dist3(from, targetPos)
	if direct > 3000 then return { success = false, reason = "ไกลเกินไป (" .. math.floor(direct) .. " studs)" } end
	local dest = Vector3.new(targetPos.x, targetPos.y, targetPos.z)
	local lastReason = "no path"
	for i = 1, math.min(MA.Config.MaxRetry, #AGENTS) do
		local path = PathfindingService:CreatePath(AGENTS[i])
		local ok, err = pcall(function() path:ComputeAsync(hrp.Position, dest) end)
		if ok and path.Status == Enum.PathStatus.Success then
			local wps = path:GetWaypoints()
			return {
				success = true, path = path, waypoints = wps, count = #wps,
				length = pathLength(wps), direct = direct, attempt = i, dest = dest,
			}
		end
		lastReason = ok and ("status " .. tostring(path.Status)) or tostring(err)
	end
	return { success = false, reason = lastReason, direct = direct }
end

function PathA.stop(reason)
	PathA.token = PathA.token + 1
	PathA.walking = false
	PathA.status = reason or "stopped"
	local char, hrp, hum = ctx.getCharacterParts()
	if hum and hrp then pcall(function() hum:MoveTo(hrp.Position) end) end
end

local function legacyAutomationActive()
	return State.AutoRiderDelivery or State.AutoBuilder or State.AutoMechanic
		or State.AutoRefuel or State.AutoRepair or State.AutoTuneECU
end

local runWalk
function PathA.walk(result)
	if not result or not result.success then PathA.status = "ไม่พบเส้นทางที่ใช้ได้" return false end
	if PathA.walking then return false, "กำลังเดินอยู่แล้ว" end
	local char, hrp, hum = ctx.getCharacterParts()
	if not (char and hrp and hum) then PathA.status = "ไม่พบตัวละคร" return false end
	if hum.SeatPart then PathA.status = "ปฏิเสธ: นั่งอยู่บนยานพาหนะ (รองรับเฉพาะการเดิน)" return false end
	if legacyAutomationActive() then PathA.status = "ปฏิเสธ: โปรดปิดระบบออโต้เดิมก่อน" return false end
	return runWalk(result)
end

-- shared walking core (no safety refusals; callers decide)
runWalk = function(result)
	if not result or not result.success then PathA.status = "ไม่พบเส้นทางที่ใช้ได้" return false, "ไม่พบเส้นทางที่ใช้ได้" end
	if PathA.walking then return false, "กำลังเดินอยู่แล้ว" end
	local char, hrp, hum = ctx.getCharacterParts()
	if not (char and hrp and hum) then PathA.status = "ไม่พบตัวละคร" return false, "ไม่พบตัวละคร" end
	PathA.token = PathA.token + 1
	local myToken = PathA.token
	PathA.walking = true
	local recomputes = 0
	local wps = result.waypoints
	local i = 2
	local blockedAt = nil
	local conn = nil
	pcall(function()
		conn = result.path.Blocked:Connect(function(idx) blockedAt = idx end)
	end)
	local failMsg = nil
	while i <= #wps do
		if PathA.token ~= myToken then failMsg = "stopped" break end
		if not hum.Parent or hum.Health <= 0 then failMsg = "ไม่พบตัวละคร" break end
		if blockedAt and blockedAt >= i then
			recomputes = recomputes + 1
			if recomputes > MA.Config.MaxRetry then failMsg = "ทางถูกปิด และลองซ้ำครบจำนวนแล้ว" break end
			local re = PathA.analyze({ x = result.dest.X, y = result.dest.Y, z = result.dest.Z })
			if not re.success then failMsg = "ทางตัน ไม่มีทางอื่น: " .. tostring(re.reason) break end
			wps, i, blockedAt = re.waypoints, 2, nil
			if conn then pcall(function() conn:Disconnect() end) end
			pcall(function() conn = re.path.Blocked:Connect(function(idx) blockedAt = idx end) end)
			PathA.status = "คำนวณเส้นทางใหม่ (" .. recomputes .. ")"
		end
		local wp = wps[i]
		if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
		local reached = false
		hum:MoveTo(wp.Position)
		-- arrival by distance (not MoveToFinished, which stalls/jerks); small nudge when not moving
		local tol = (i == #wps) and 2.5 or 4.5
		local t0, lt = os.clock(), os.clock()
		local _, hr0 = ctx.getCharacterParts()
		local lp = hr0 and hr0.Position
		while os.clock() - t0 < 5 and PathA.token == myToken do
			local _, hr2 = ctx.getCharacterParts()
			if not hr2 then break end
			if (hr2.Position - wp.Position).Magnitude <= tol then reached = true break end
			if os.clock() - lt >= 1.5 then
				if lp and (hr2.Position - lp).Magnitude < 1.5 then
					hum.Jump = true
					hum:MoveTo(wp.Position + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2)))
				end
				lp, lt = hr2.Position, os.clock()
			end
			task.wait(0.1)
		end
		if PathA.token ~= myToken then failMsg = "stopped" break end
		if not reached then
			recomputes = recomputes + 1
			if recomputes > MA.Config.MaxRetry then failMsg = "ติดขัด และลองซ้ำครบจำนวนแล้ว" break end
			local re = PathA.analyze({ x = result.dest.X, y = result.dest.Y, z = result.dest.Z })
			if not re.success then failMsg = "ติดขัด ไม่มีทางอื่น: " .. tostring(re.reason) break end
			wps, i, blockedAt = re.waypoints, 2, nil
			if conn then pcall(function() conn:Disconnect() end) end
			pcall(function() conn = re.path.Blocked:Connect(function(idx) blockedAt = idx end) end)
		else
			i = i + 1
		end
		PathA.status = "กำลังเดิน " .. math.min(i, #wps) .. "/" .. #wps
	end
	if conn then pcall(function() conn:Disconnect() end) end
	PathA.walking = false
	if failMsg then
		PathA.status = "หยุด: " .. failMsg
		if failMsg ~= "stopped" then EM.record("PathAnalyzer", failMsg) end
		return false, failMsg
	end
	PathA.status = "ถึงแล้ว"
	return true
end

-- ---------------------------------------------------------------------------
-- 6) AUTO SYSTEM CHECK (report only, never triggers anything)
-- ---------------------------------------------------------------------------
local SYSTEMS = {
	{ id = "job", label = "จุดรับงาน / ส่งของ" },
	{ id = "fuel", label = "จุดเติมน้ำมัน" },
	{ id = "repair", label = "จุดซ่อม / ช่างยนต์" },
	{ id = "tuner", label = "จุดจูน ECU" },
	{ id = "shop", label = "จุดร้านค้า / ซื้อของ" },
	{ id = "uniform", label = "จุดรับชุดไรเดอร์" },
	{ id = "order", label = "จุดรับออเดอร์" },
	{ id = "deliver", label = "จุดส่งของ" },
	{ id = "vehicle", label = "จุดขึ้นรถ / ขับ" },
	{ id = "piston", label = "จุดใส่ลูกสูบ" },
}

-- entries: list of {kind=, class=, verified=}; labels: list of {text=}
function MA.systemCheck(entries, labels, guiHits)
	local out = {}
	for _, s in ipairs(SYSTEMS) do
		local interactables, labelHits = 0, 0
		for _, e in ipairs(entries) do
			if e.kind == s.id and e.verified then interactables = interactables + 1 end
		end
		for _, l in ipairs(labels or {}) do
			local cat = MA.classify({ { src = "Label", text = l.text } })
			if cat == s.id then labelHits = labelHits + 1 end
		end
		local status
		local guiN = (guiHits and guiHits[s.id] and guiHits[s.id].n) or 0
		if interactables > 0 then status = "พร้อมใช้งาน"
		elseif guiN > 0 then status = "พบเมนู GUI x" .. guiN .. " (ใช้ผ่านหน้าต่างในเกม)"
		elseif labelHits > 0 then status = "พบแค่ป้ายข้อความ (ไม่มีจุดโต้ตอบ)"
		else status = "ไม่รองรับ / ไม่พบ" end
		out[#out + 1] = { id = s.id, label = s.label, status = status, points = interactables, labels = labelHits }
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Orchestration
-- ---------------------------------------------------------------------------
MA.lastRescan = 0
MA.rescanCount = 0

function MA.refreshMap(reason)
	-- [v16] กดรีเฟรชเอง = ปลดโมดูลที่ถูกพักเพราะล้มเหลวซ้ำ (ตรงกับข้อความแจ้งเตือน "กด REFRESH MAP เพื่อกู้คืน")
	if reason == "manual" or reason == "หลังรีเซ็ต" then EM.resetSystem("ObjectScanner") end
	local okG, res = EM.guard("ObjectScanner", function()
		Detector.check()
		Detector.dirty, Detector.added, Detector.removed = false, 0, 0
		local ok, n = Scanner.scan()
		if not ok then error(n) end
		Memory.save(Scanner.entries)
		MA.lastRescan = os.clock()
		MA.rescanCount = MA.rescanCount + 1
		return n
	end)
	if not okG then EM.record("RefreshMap", tostring(res)) end
	return okG, res
end

function MA.resetData()
	PathA.stop("reset")
	Memory.reset()
	Detector.info = nil
	Detector.dirty, Detector.added, Detector.removed = false, 0, 0
	EM.resetSystem()
	Detector.check()
	Detector.fetchName()
end

function MA.start()
	if State.WalkMode == nil then State.WalkMode = true end
	Detector.check()
	Detector.fetchName()
	EM.guard("MapMemory", function() Memory.load() end)
	-- [v16] ใช้ข้อมูลเก่าที่ผ่านการตรวจสอบกับแมพปัจจุบันแล้วเท่านั้น เป็นเป้าหมายชั่วคราวระหว่างรอสแกนเต็มรอบแรก
	if #Memory.entries > 0 and #Scanner.entries == 0 then
		Scanner.entries = Memory.entries
		Scanner.verifiedCount = #Memory.entries
	end
	pcall(function()
		local function relevantInst(inst)
			return inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui")
		end
		__bkTrack(Workspace.DescendantAdded:Connect(function(inst)
			if not relevantInst(inst) then return end
			Detector.added = Detector.added + 1
			if Detector.added + Detector.removed >= MA.Config.DirtyThreshold then Detector.dirty = true end
		end))
		__bkTrack(Workspace.DescendantRemoving:Connect(function(inst)
			if not relevantInst(inst) then return end
			Detector.removed = Detector.removed + 1
			if Detector.added + Detector.removed >= MA.Config.DirtyThreshold then Detector.dirty = true end
		end))
	end)
	task.spawn(function()
		task.wait(2)
		MA.refreshMap("startup")
		while ctx.mainWindow and ctx.mainWindow.Parent do
			task.wait(MA.Config.PollSeconds)
			-- [v1.37] ล้างเป้าหมายที่หายไปทุก ~30 วินาที
			if os.clock() - (MA.lastPrune or 0) >= 30 then
				MA.lastPrune = os.clock()
				pcall(Scanner.prune)
			end
			-- [v1.37] ถ้า ObjectScanner ถูกพักจาก error ซ้ำ ให้กู้คืนเอง (เดิมต้องกด REFRESH MAP) เว้นอย่างน้อย 2 นาที
			local sysS = EM.systems.ObjectScanner
			if sysS and sysS.stopped and os.clock() - (MA.autoRecoverAt or 0) > 120 then
				MA.autoRecoverAt = os.clock()
				pcall(EM.resetSystem, "ObjectScanner")
				pcall(MA.refreshMap, "auto-recover")
			end
			local okC, changed = pcall(Detector.check)
			if okC and changed and MA.Config.AutoRescan
				and (os.clock() - MA.lastRescan) >= ((MA.Farm and MA.Farm.on) and math.max(MA.Config.MinRescanGap, 45) or MA.Config.MinRescanGap) then
				if Detector.lastPlaceId ~= game.PlaceId then
					Memory.reset()
					Detector.lastPlaceId = game.PlaceId
				end
				MA.refreshMap(Detector.changeReason)
			elseif not okC then
				EM.record("MapDetector", changed)
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- 8) RIDER FARM: walk to uniform -> spawn bike (GUI) -> accept order (GUI, no walking) -> deliver -> repeat
--    Uses only ProximityPrompt / ClickDetector found by the scanner. No remotes.
-- ---------------------------------------------------------------------------
local Farm = { on = false, token = 0, state = "idle", status = "off", uniforms = 0, orders = 0,
	deliveries = 0, noTarget = 0, noOrder = 0, lastScan = 0,
	spawnKeywords = { "spawn", "เรียกรถ", "เสกรถ", "เสก" },
	orderKeywords = { "รับงาน", "รับออเดอร์", "accept", "เปิดรับงาน" },
	foodKeywords = { "อาหาร", "food" },
	passengerKeywords = { "ผู้โดยสาร", "โดยสาร", "passenger", "taxi", "แท็กซี่", "รับคน" },
	lastAction = "none", lastActionAt = 0, lastJump = "none", jumps = 0,
	useMarker = true, markerText = "", markerMiss = 0,
	drive = true, mode = "both", pending = 0, batchDone = 0, recover = 0, restarts = 0,
	boost = false, speed = 32, origSpeed = nil, walk = nil, char = nil,
	used = setmetatable({}, { __mode = "k" }) }
MA.Farm = Farm

-- [v1.36] ตัวช่วยกลางของ Farm: Webhook แจ้งเตือน + จำว่า "ผู้ใช้ต้องการให้ฟาร์มทำงาน" (ใช้ตอน Rejoin/Auto Resume)
Farm.startedAt, Farm.rejoins, Farm.wdRestarts, Farm.wdLastDone, Farm.wdTotal = os.clock(), 0, 0, 0, 0
local __notifyLast = {}
function Farm.notify(kind, text, force)
	local now = os.clock()
	if not force and now - (__notifyLast[kind] or -999) < 15 then return end
	__notifyLast[kind] = now
	if type(ctx.sendWebhook) ~= "function" then return end
	local desc = string.format("%s\nผู้เล่น: %s\nส่งสำเร็จ: %d | Watchdog รีสตาร์ท: %d | Rejoin: %d | ออนไลน์: %d นาที",
		tostring(text or ""), tostring(ctx.player and ctx.player.Name), Farm.deliveries or 0, Farm.wdTotal or 0,
		Farm.rejoins or 0, math.floor((now - Farm.startedAt) / 60))
	task.spawn(function() pcall(ctx.sendWebhook, "Farm " .. tostring(kind) .. " | " .. tostring(ctx.Meta.ScriptName), desc) end)
end
function Farm.setWanted(v)
	if State.FarmWanted == v then return end
	State.FarmWanted = v
	if type(ctx.saveConfig) == "function" then pcall(ctx.saveConfig) end
end
-- [v1.38] โหมดตามหมุดสีเหลือง: ไม่เดินไปหาจุดสแกนที่อยู่ไกลเอง กรองเหลือเฉพาะจุดที่อยู่ใกล้ตัวอยู่แล้ว
function Farm.nearOnly(list, maxD)
	if not Farm.useMarker then return list end
	local out = {}
	for _, t in ipairs(list) do
		if t.d <= maxD then out[#out + 1] = t end
	end
	return out
end

local function hdist(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

local function liveTargets(kind, origin)
	local out = {}
	for _, e in ipairs(Scanner.entries) do
		if e.kind == kind then
			local alive = pcall(function()
				if not e.inst:IsDescendantOf(Workspace) then error("gone") end
				if e.class == "ProximityPrompt" and e.inst.Enabled == false then error("disabled") end
			end)
			if alive then
				local p = getPosition(e.inst) or e.pos
				e.pos = p
				out[#out + 1] = { e = e, d = origin and dist3(p, origin) or 0 }
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

local function activate(e)
	if e.class == "ProximityPrompt" then return ctx.firePromptSafe(e.inst) end
	local fcd = rawget(_G, "fireclickdetector")
	if type(fcd) ~= "function" then
		local okG, genv = pcall(function() return getgenv and getgenv() end)
		if okG and type(genv) == "table" then fcd = genv.fireclickdetector end
	end
	if type(fcd) == "function" then pcall(fcd, e.inst) return true end
	return false
end

-- get off the vehicle by jumping (never teleports)
local function dismount(isCancelled)
	for _ = 1, 4 do
		local _, _, h = ctx.getCharacterParts()
		if not h or not h.SeatPart then return true end
		pcall(function() h.Sit = false end)
		h.Jump = true
		task.wait(0.6)
		if isCancelled and isCancelled() then return false end
	end
	local _, _, h = ctx.getCharacterParts()
	return not (h and h.SeatPart)
end

-- fallback when PathfindingService finds nothing: still WALK (MoveTo toward target), never teleport
local function directWalk(pos, radius, isCancelled)
	local goal = Vector3.new(pos.x, pos.y, pos.z)
	local t0, lastPos, stuckSince = os.clock(), nil, os.clock()
	while not isCancelled() and os.clock() - t0 < 120 do
		local _, hrp, hum = ctx.getCharacterParts()
		if not (hrp and hum) or hum.Health <= 0 then return false, "ไม่พบตัวละคร" end
		local cur = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z }
		if hdist(cur, pos) <= radius or dist3(cur, pos) <= radius + 2 then return true end
		hum:MoveTo(goal)
		task.wait(0.25)
		if lastPos and (hrp.Position - lastPos).Magnitude > 0.6 then stuckSince = os.clock() end
		lastPos = hrp.Position
		if os.clock() - stuckSince > 1.2 then hum.Jump = true end
		if os.clock() - stuckSince > 6 then return false, "เดินตรงแล้วติดขัด" end
	end
	return false, "เดินตรงหมดเวลา"
end

-- blocking walk to within `radius` studs; tries 3 approach points around the target
local function walkToPos(pos, radius, isCancelled)
	local last = "no path"
	local offsets = { { 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } }
	for attempt = 1, MA.Config.MaxRetry do
		if isCancelled() then return false, "cancelled" end
		local char, hrp, hum = ctx.getCharacterParts()
		if not (hrp and hum) then return false, "ไม่พบตัวละคร" end
		if hum.SeatPart then dismount(isCancelled) end
		local cur = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z }
		if hdist(cur, pos) <= radius or dist3(cur, pos) <= radius + 2 then return true end
		local off = offsets[((attempt - 1) % #offsets) + 1]
		local goal = { x = pos.x + off[1], y = pos.y, z = pos.z + off[2] }
		local res = PathA.analyze(goal)
		if res.success then
			Farm.walk = { t0 = os.clock(), len = res.length, speed = hum.WalkSpeed }
			local ok, why = runWalk(res)
			if isCancelled() then return false, "cancelled" end
			if not ok then last = tostring(why) end
			local _, h2 = ctx.getCharacterParts()
			if h2 then
				local c2 = { x = h2.Position.X, y = h2.Position.Y, z = h2.Position.Z }
				if hdist(c2, pos) <= radius or dist3(c2, pos) <= radius + 2 then return true end
			end
		else
			last = tostring(res.reason)
			task.wait(0.5)
		end
	end
	if isCancelled() then return false, "cancelled" end
	local okD, whyD = directWalk(pos, radius, isCancelled)
	if okD then return true end
	return false, tostring(last) .. " / " .. tostring(whyD)
end

local function farmLabel(e)
	return cut((e.action ~= "" and e.action) or e.object ~= "" and e.object or e.name, 24)
end

local function driveTo(pos, isCancelled)
	local t0 = os.clock()
	local v = Vector3.new(pos.x, pos.y, pos.z)
	while not isCancelled() and os.clock() - t0 < 90 do
		if ctx.moveToPositionSmart(v, State.MaxSpeedKmh) then return true end
		task.wait(0.3)
	end
	return false, "ขับหมดเวลา"
end

-- GUI click used only by the rider farm: skips respawn/teleport/reset-like buttons and records what was pressed
local BAD_BTN = { "respawn", "teleport", "วาป", "เทเลพอร์ต", "reset", "รีเซ็ต", "leave", "rejoin", "ออกจากเกม" }
local function farmClick(keywords, tag)
	local pg = ctx.playerGui
	if not pg then return false end
	local clicked = false
	for _, sg in ipairs(pg:GetChildren()) do
		if sg:IsA("ScreenGui") and sg.Name ~= ctx.guiRootName and sg.Enabled then
			for _, btn in ipairs(sg:GetDescendants()) do
				if btn:IsA("TextButton") and btn.Visible then
					local low = (btn.Text .. " " .. btn.Name):lower()
					local hit = false
					for _, kw in ipairs(keywords) do
						if low:find(kw, 1, true) then hit = true break end
					end
					if hit then
						local bad = false
						for _, b in ipairs(BAD_BTN) do
							if low:find(b, 1, true) then bad = true break end
						end
						if not bad and ctx.clickBtn(btn) then
							clicked = true
							Farm.lastAction = tag .. ": '" .. cut(btn.Text, 24) .. "' (" .. cut(btn.Name, 20) .. ")"
							Farm.lastActionAt = os.clock()
						end
					end
				end
			end
		end
	end
	return clicked
end

-- ============================================================================
-- VEHICLE: board -> engine -> handbrake -> DRIVE to the delivery point (real driving, never CFrame/teleport)
-- Everything marked TUNE depends on the real map's buttons / value names.
-- ============================================================================
local Veh = {
	-- TUNE: text/name of the game's buttons or prompts (lower-case, substring match)
	engineKeywords = { "สตาร์ท", "start", "engine", "ติดเครื่อง", "ignition" },
	handbrakeKeywords = { "เบรคมือ", "handbrake", "hand brake", "parking", "ปลดเบรค" },
	enterKeywords = { "drive", "enter", "sit", "ขึ้นรถ", "ขับ" },
	-- TUNE: names of Bool/String/Number values or Attributes that hold the state (if the map has them)
	engineValueNames = { "engine", "ignition", "motor", "started", "running", "เครื่อง" },
	handbrakeValueNames = { "handbrake", "parkingbrake", "parking", "pbrake", "เบรคมือ" },
	maxSpeed = 70,       -- TUNE: studs/s cap while driving
	useKeys = false,     -- true = press W/A/S/D through VirtualInputManager (for custom car controllers)
	seat = nil, vim = nil, keyDown = {},
}
pcall(function() Veh.vim = game:GetService("VirtualInputManager") end)

local function hasAny(str, list)
	for _, kw in ipairs(list) do
		if str:find(kw, 1, true) then return true end
	end
	return false
end

local function truthy(v)
	if type(v) == "boolean" then return v end
	if type(v) == "number" then return v ~= 0 end
	if type(v) == "string" then
		local l = v:lower()
		if l == "" or l == "false" or l == "0" or l:find("off", 1, true) or l:find("release", 1, true)
			or l:find("stop", 1, true) or l:find("unlock", 1, true) then
			return false
		end
		return true
	end
	return nil
end

-- find a readable state (Attribute or *Value) whose name matches; returns a getter or nil
local function findState(model, seat, names)
	for _, r in ipairs({ model, seat }) do
		if r then
			local okA, attrs = pcall(function() return r:GetAttributes() end)
			if okA then
				for k, v in pairs(attrs) do
					if hasAny(tostring(k):lower(), names) and truthy(v) ~= nil then
						return function() return r:GetAttribute(k) end
					end
				end
			end
		end
	end
	if model then
		for _, d in ipairs(model:GetDescendants()) do
			if (d:IsA("BoolValue") or d:IsA("StringValue") or d:IsA("IntValue") or d:IsA("NumberValue"))
				and hasAny(d.Name:lower(), names) then
				return function() return d.Value end
			end
		end
	end
	return nil
end

local function ownedByMe(model)
	if not model then return false end
	local me = ctx.player
	if model.Name:lower():find(me.Name:lower(), 1, true) then return true end
	for _, k in ipairs({ "Owner", "owner", "OwnerName", "OwnerId", "Player", "PlayerName", "UserId" }) do
		local v = model:GetAttribute(k)
		if v ~= nil and (tostring(v) == me.Name or tostring(v) == tostring(me.UserId)) then return true end
		local ch = model:FindFirstChild(k)
		if ch and ch:IsA("ValueBase") then
			local val = ch.Value
			if val == me or tostring(val) == me.Name or tostring(val) == tostring(me.UserId) then return true end
		end
	end
	return false
end

-- TUNE: how "my vehicle" is found. Default: free VehicleSeat within 150 studs, own-named/owned model first, else nearest.
function Veh.findSeat(hrp)
	local best, bestScore
	-- [v9] ใช้แคชที่นั่งยานพาหนะแทนการสแกนทั้ง Workspace (ถ้าไม่มีแคชจะถอยกลับไปสแกนเต็ม)
	local seatList = (ctx.WorldCache and ctx.WorldCache.list("seat")) or Workspace:GetDescendants()
	for _, d in ipairs(seatList) do
		if d.Parent and d:IsA("VehicleSeat") and d.Occupant == nil then
			-- [v1.38] ใช้เฉพาะรถของเราเท่านั้น (เดิมเลือกที่นั่งว่างที่ใกล้ที่สุดของใครก็ได้ ทำให้ขึ้นรถผิดคันเมื่อยังไม่ได้เสกรถ)
			if ownedByMe(d:FindFirstAncestorOfClass("Model")) then
				local dist = (d.Position - hrp.Position).Magnitude
				if not bestScore or dist < bestScore then best, bestScore = d, dist end
			end
		end
	end
	return best
end

-- [v1.38] โมเดลรถของเราใน Workspace.SpawnedVehicles (nil = ยังไม่ได้เสกรถ)
function Veh.myModel()
	local sv = Workspace:FindFirstChild("SpawnedVehicles")
	if not sv then return nil end
	for _, m in ipairs(sv:GetChildren()) do
		if ownedByMe(m) then return m end
	end
	return nil
end

local KEYCODE = { W = Enum.KeyCode.W, A = Enum.KeyCode.A, S = Enum.KeyCode.S, D = Enum.KeyCode.D, R = Enum.KeyCode.R, K = Enum.KeyCode.K }
local function setKey(name, down)
	if not Veh.vim then return end
	if (Veh.keyDown[name] or false) == down then return end
	Veh.keyDown[name] = down
	pcall(function() Veh.vim:SendKeyEvent(down, KEYCODE[name], false, game) end)
end

-- throttle: -1..1 (negative = reverse/brake), steer: -1..1 (positive = right)
function Veh.control(throttle, steer)
	local seat = Veh.seat
	if seat and seat.Parent and seat:IsA("VehicleSeat") then
		pcall(function() seat.Throttle = throttle seat.Steer = steer end)
	end
	if Veh.useKeys then
		setKey("W", throttle > 0.1)
		setKey("S", throttle < -0.1)
		setKey("D", steer > 0.25)
		setKey("A", steer < -0.25)
	end
end

function Veh.release()
	Veh.control(0, 0)
	for k in pairs(KEYCODE) do setKey(k, false) end
end

-- 1) SIT: walk next to the vehicle if needed, then sit (enter prompt, else Seat:Sit)
function Veh.sit(isCancelled)
	local _, hrp, hum = ctx.getCharacterParts()
	if not (hrp and hum) then return false, "ไม่พบตัวละคร" end
	if hum.SeatPart then
		local sp = hum.SeatPart
		if sp:IsA("VehicleSeat") and ownedByMe(sp:FindFirstAncestorOfClass("Model")) then Veh.seat = sp return true end
		-- [v1.38] นั่งอยู่ที่นั่งอื่นที่ไม่ใช่รถของเรา: ลงก่อน แล้วค่อยไปหารถของเรา
		if not Veh.myModel() then return false, "ไม่พบยานพาหนะของคุณใกล้ตัว" end
		dismount(isCancelled)
		_, hrp, hum = ctx.getCharacterParts()
		if not (hrp and hum) then return false, "ไม่พบตัวละคร" end
	end
	local seat = Veh.findSeat(hrp)
	if not seat then
		if Veh.myModel() then return false, "รถของคุณมีอยู่แต่ไม่พบที่นั่งคนขับที่ว่าง" end
		return false, "ไม่พบยานพาหนะของคุณใกล้ตัว"
	end
	Veh.seat = seat
	Farm.status = "กำลังขึ้นยานพาหนะ"
	if (hrp.Position - seat.Position).Magnitude > 7 then
		local ok, why = walkToPos({ x = seat.Position.X, y = seat.Position.Y, z = seat.Position.Z }, 5, isCancelled)
		Farm.walk = nil
		if not ok then return false, "ไปที่ยานพาหนะไม่ได้: " .. tostring(why) end
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	if model then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled and hasAny((d.ActionText .. " " .. d.ObjectText):lower(), Veh.enterKeywords) then
				Farm.lastAction, Farm.lastActionAt = "กดปุ่มขึ้นรถ: " .. cut(d.ActionText, 20), os.clock()
				ctx.firePromptSafe(d)
				task.wait(1)
				if hum.SeatPart then return true end
			end
		end
	end
	for _ = 1, 3 do
		if isCancelled() then return false, "cancelled" end
		Farm.lastAction, Farm.lastActionAt = "Seat:Sit", os.clock()
		pcall(function() seat:Sit(hum) end)
		task.wait(0.8)
		if hum.SeatPart then return true end
		hum:MoveTo(seat.Position)
		task.wait(0.8)
	end
	return hum.SeatPart ~= nil, "นั่งบนยานพาหนะไม่สำเร็จ"
end

-- fire a button (or a vehicle prompt) for engine / handbrake
local function pressVehicleControl(keywords, tag, model)
	if farmClick(keywords, tag) then return true end
	if model then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled and hasAny((d.ActionText .. " " .. d.ObjectText):lower(), keywords) then
				Farm.lastAction, Farm.lastActionAt = tag .. " prompt: " .. cut(d.ActionText, 20), os.clock()
				ctx.firePromptSafe(d)
				return true
			end
		end
	end
	return false
end

-- 2) ENGINE: only presses when a readable state says it is OFF (unknown state = never toggle blindly)
function Veh.ensureEngine(isCancelled)
	local seat = Veh.seat
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	local get = findState(model, seat, Veh.engineValueNames)
	if not get then Farm.status = "เครื่องยนต์: ไม่ทราบสถานะ" return end
	for n = 1, 3 do
		if isCancelled() then return end
		if truthy(get()) == true then return end
		Farm.status = "กำลังสตาร์ทเครื่อง (" .. n .. "/3)"
		pressVehicleControl(Veh.engineKeywords, "engine", model)
		task.wait(1.2)
	end
end

-- 3) HANDBRAKE: release only when a readable state says it is ON
function Veh.ensureHandbrake(isCancelled)
	local seat = Veh.seat
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	local get = findState(model, seat, Veh.handbrakeValueNames)
	if not get then Farm.status = "เบรกมือ: ไม่ทราบสถานะ" return end
	for n = 1, 3 do
		if isCancelled() then return end
		if truthy(get()) ~= true then return end
		Farm.status = "กำลังปลดเบรกมือ (" .. n .. "/3)"
		pressVehicleControl(Veh.handbrakeKeywords, "handbrake", model)
		task.wait(1)
	end
end

-- [v1.38] กดปุ่มคีย์หนึ่งครั้ง (R = สตาร์ทเครื่อง, K = เก็บขาตั้ง/ปลดเบรกมือ ตามที่ระบบขับอีกตัวในสคริปต์ใช้อยู่แล้ว)
function Veh.tap(name, hold)
	if not Veh.vim then return false end
	setKey(name, true)
	task.wait(hold or 0.15)
	setKey(name, false)
	return true
end

-- ทดสอบว่ารถ "พร้อมเคลื่อนที่" จริง: ให้คันเร่ง/W สั้นๆ แล้ววัดว่าขยับ (กดสตาร์ท/ขาตั้งซ้ำโดยไม่ดูผลไม่ได้ เพราะเป็นปุ่มสลับ)
function Veh.probe(isCancelled, secs)
	local seat = Veh.seat
	if not (seat and seat.Parent) then return false end
	local p0, t0 = seat.Position, os.clock()
	local moved = false
	while os.clock() - t0 < secs do
		if isCancelled() then break end
		Veh.control(1, 0)
		setKey("W", true)
		task.wait(0.1)
		if (seat.Position - p0).Magnitude > 1.2 or seat.AssemblyLinearVelocity.Magnitude > 1.5 then moved = true break end
	end
	setKey("W", false)
	Veh.control(0, 0)
	return moved
end

-- ลำดับก่อนขับ: นั่งที่นั่งคนขับจริง -> (อ่านสถานะได้ก็ใช้) -> ลองให้คันเร่ง -> ถ้าไม่ขยับ: R(สตาร์ท) -> K(เก็บขาตั้ง) -> R แล้ววัดผลทุกครั้ง
-- ผ่านแล้วจะจำที่นั่งนี้ไว้ ไม่กดซ้ำทุกเที่ยว (เคลียร์ตอนเริ่มฟาร์มใหม่/เปลี่ยนรถ)
function Veh.prepare(isCancelled)
	local ok, why = Veh.sit(isCancelled)
	if not ok then return false, why end
	local seat = Veh.seat
	local _, _, hum = ctx.getCharacterParts()
	if not (hum and seat and seat.Parent and hum.SeatPart == seat) then return false, "ยังไม่ได้นั่งที่นั่งคนขับ" end
	if Veh.readySeat == seat then return true end
	Farm.status = "ตรวจเครื่องยนต์/เบรกมือก่อนออกรถ"
	Veh.ensureEngine(isCancelled)
	Veh.ensureHandbrake(isCancelled)
	if isCancelled() then return false, "cancelled" end
	if Veh.probe(isCancelled, 1.2) then Veh.readySeat = seat return true end
	local steps = {
		{ "R", "สตาร์ทเครื่องยนต์ (R)" },
		{ "K", "ปลดเบรกมือ/เก็บขาตั้ง (K)" },
		{ "R", "สตาร์ทเครื่องยนต์ซ้ำ (R)" },
	}
	for _, st in ipairs(steps) do
		if isCancelled() then return false, "cancelled" end
		if hum.SeatPart ~= seat then return false, "ลงจากรถระหว่างเตรียมรถ" end
		Farm.status = st[2]
		Farm.lastAction, Farm.lastActionAt = "key " .. st[1], os.clock()
		Veh.tap(st[1], 0.15)
		task.wait(0.8)
		if Veh.probe(isCancelled, 1.2) then Veh.readySeat = seat return true end
	end
	return false, "รถไม่เคลื่อนที่หลังสตาร์ทเครื่อง/ปลดเบรกมือ"
end

local function hd(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- 4) DRIVE to pos {x,y,z}: path waypoints (straight line if no path), steer + throttle, anti-stuck, no CFrame
function Veh.driveTo(pos, radius, isCancelled)
	local seat = Veh.seat
	if not (seat and seat.Parent) then return false, "ไม่พบที่นั่งยานพาหนะ" end
	local goal = Vector3.new(pos.x, pos.y, pos.z)
	local function plan()
		local list = {}
		pcall(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 5, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 12 })
			path:ComputeAsync(seat.Position, goal)
			if path.Status == Enum.PathStatus.Success then
				for _, w in ipairs(path:GetWaypoints()) do list[#list + 1] = w.Position end
			end
		end)
		list[#list + 1] = goal -- always finish at the goal (straight line if no path)
		return list
	end
	local wps, i = plan(), 1
	Farm.walk = { t0 = os.clock(), len = hd(seat.Position, goal), speed = Veh.maxSpeed * 0.6 }
	local t0, lastSample, lastPos = os.clock(), os.clock(), seat.Position
	local stuckSec, episodes, everMoved = 0, 0, false
	while not isCancelled() and os.clock() - t0 < 240 do
		if not seat.Parent then Veh.release() return false, "ยานพาหนะหายไป" end
		local _, _, hum = ctx.getCharacterParts()
		if not hum or hum.SeatPart ~= seat then Veh.release() return false, "ลงจากยานพาหนะแล้ว" end
		local cur = seat.Position
		local distGoal = hd(cur, goal)
		if distGoal <= radius then break end
		local wp = wps[i]
		while i < #wps and hd(cur, wp) < 12 do i = i + 1 wp = wps[i] end
		local lp = seat.CFrame:PointToObjectSpace(wp)
		local angle = math.atan2(lp.X, -lp.Z)
		local steer = math.clamp(angle / 0.5, -1, 1)
		local speed = seat.AssemblyLinearVelocity.Magnitude
		local throttle = 1
		if math.abs(angle) > 1.0 then throttle = 0.35 elseif math.abs(angle) > 0.5 then throttle = 0.6 end
		if distGoal < 30 then throttle = math.min(throttle, 0.4) end
		if speed > Veh.maxSpeed then throttle = 0 end
		if distGoal < 14 and speed > 20 then throttle = -0.3 end
		Veh.control(throttle, steer)
		Farm.status = string.format("กำลังขับไปส่งของ (เหลือ %.0f studs)", distGoal)
		task.wait(0.1)

		-- anti-stuck: sample once per second
		if os.clock() - lastSample >= 1 then
			if (seat.Position - lastPos).Magnitude > 2 then
				stuckSec, everMoved = 0, true
			else
				stuckSec = stuckSec + 1
			end
			lastPos, lastSample = seat.Position, os.clock()
			if stuckSec >= 3 then
				stuckSec, episodes = 0, episodes + 1
				if episodes > 7 then Veh.release() return false, "ยานพาหนะติด" end
				local model = seat:FindFirstAncestorOfClass("Model")
				if not everMoved then
					-- never moved: handbrake / engine / input method, one at a time
					if episodes == 1 then
						Farm.status = "ไม่เคลื่อนที่ - ลองปลดเบรกมือ"
						pressVehicleControl(Veh.handbrakeKeywords, "handbrake", model)
					elseif episodes == 2 then
						Farm.status = "ไม่เคลื่อนที่ - ลองสตาร์ทเครื่อง"
						pressVehicleControl(Veh.engineKeywords, "engine", model)
					elseif episodes == 3 and Veh.vim and not Veh.useKeys then
						Farm.status = "ไม่เคลื่อนที่ - เปลี่ยนไปใช้ปุ่ม W/A/S/D"
						Veh.useKeys = true
					end
					task.wait(1)
				else
					-- moved before but blocked: back up with opposite steer, then re-plan
					Farm.status = "blocked - reversing"
					local t1 = os.clock()
					while os.clock() - t1 < 1.5 and not isCancelled() do
						Veh.control(-0.7, -steer)
						task.wait(0.1)
					end
					wps, i = plan(), 1
				end
			end
		end
	end
	local arrived = (not isCancelled()) and hd(seat.Position, goal) <= radius
	-- brake to a stop (no sliding past the point)
	local t2 = os.clock()
	while arrived and seat.AssemblyLinearVelocity.Magnitude > 3 and os.clock() - t2 < 3 do
		Veh.control(-0.25, 0)
		task.wait(0.1)
	end
	Veh.release()
	Farm.walk = nil
	if isCancelled() then return false, "cancelled" end
	if not arrived then return false, "ขับหมดเวลา" end
	return true
end

-- ============================================================================
-- YELLOW MARKER FOLLOWER: the game's objective marker (yellow pin + distance text like "39 m").
-- Reads the marker from PlayerGui and walks/drives toward it in legs (no teleport).
-- TUNE: the distance-text pattern and the "yellow" test if the map's marker looks different.
-- ============================================================================
local GuiService = game:GetService("GuiService")
local Marker = { k = 2, arriveStuds = 8 } -- k = studs per displayed unit (auto-calibrated while walking)

local function isYellow(c)
	return typeof(c) == "Color3" and c.R > 0.8 and c.G > 0.6 and c.B < 0.4
end

local function shown(obj, root)
	local o = obj
	while o and o ~= root do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if (o:IsA("ScreenGui") or o:IsA("BillboardGui") or o:IsA("SurfaceGui")) and not o.Enabled then return false end
		o = o.Parent
	end
	return true
end

local function yellowNear(lbl)
	local o, score = lbl, 0
	for _ = 1, 3 do
		o = o.Parent
		if not o then break end
		for _, c in ipairs(o:GetChildren()) do
			pcall(function()
				if c:IsA("Frame") and isYellow(c.BackgroundColor3) then score = score + 1 end
				if (c:IsA("ImageLabel") or c:IsA("ImageButton")) and (isYellow(c.ImageColor3) or isYellow(c.BackgroundColor3)) then
					score = score + 1
				end
			end)
		end
	end
	return score
end

-- returns { dist = displayed number, exact = bool, pos = Vector3 (exact) / dir = Vector3 (bearing), score } or nil
function Marker.read()
	local pg = ctx.player:FindFirstChild("PlayerGui")
	local cam = Workspace.CurrentCamera
	local _, hrp = ctx.getCharacterParts()
	if not (pg and cam and hrp) then return nil end
	local best
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") and d.Visible and #d.Text > 0 and #d.Text <= 12 then
			local num = d.Text:gsub("%s+", ""):match("^(%d+%.?%d*)[mM]$")
			if num and shown(d, pg) and not (ctx.guiRootName and d:FindFirstAncestor(ctx.guiRootName)) then
				local mk = { dist = tonumber(num), score = yellowNear(d) }
				local bb = d:FindFirstAncestorWhichIsA("BillboardGui")
				local adornee = bb and (bb.Adornee or (bb.Parent and bb.Parent:IsA("BasePart") and bb.Parent))
				if adornee and adornee:IsA("BasePart") then
					mk.exact, mk.pos = true, adornee.Position + bb.StudsOffset
				else
					local ap, asz = d.AbsolutePosition, d.AbsoluteSize
					local sg = d:FindFirstAncestorWhichIsA("ScreenGui")
					local inset = (sg and sg.IgnoreGuiInset) and Vector2.new(0, 0) or GuiService:GetGuiInset()
					local ray = cam:ViewportPointToRay(ap.X + asz.X / 2 + inset.X, ap.Y + asz.Y / 2 + inset.Y)
					mk.exact, mk.dir = false, ray.Direction
				end
				if not best or mk.score > best.score or (mk.score == best.score and mk.dist < best.dist) then
					best = mk
				end
			end
		end
	end
	return best
end

-- move toward the marker in legs until it is close / disappears. mover(goal{x,y,z}, cancelled) -> ok, why
function Marker.home(mover, cancelled, minStep, maxStep, maxSec)
	local t0, lastD, lastPos, noGain = os.clock(), nil, nil, 0
	for leg = 1, 30 do
		if cancelled() then return false, "cancelled" end
		if os.clock() - t0 > maxSec then return false, "รอเครื่องหมายหมดเวลา" end
		local mk = Marker.read()
		if not mk then return leg > 1, "เครื่องหมายสีเหลืองหายไป" end
		Farm.markerText = tostring(mk.dist) .. " m"
		local _, hrp = ctx.getCharacterParts()
		if not hrp then return false, "ไม่พบตัวละคร" end
		if lastD and lastPos then
			local moved = hd(hrp.Position, lastPos)
			local gain = lastD - mk.dist
			if gain > 0.5 and moved > 4 then
				Marker.k = math.clamp(0.5 * Marker.k + 0.5 * (moved / gain), 0.9, 4)
				noGain = 0
			elseif gain <= 0.2 then
				noGain = noGain + 1
			end
			if noGain >= 3 then return false, "ไม่ได้เข้าใกล้เครื่องหมาย" end
		end
		if mk.dist <= 3 or mk.dist * Marker.k <= Marker.arriveStuds then return true end
		lastD, lastPos = mk.dist, hrp.Position
		local goal
		if mk.exact then
			goal = mk.pos
		else
			local dir = Vector3.new(mk.dir.X, 0, mk.dir.Z)
			if dir.Magnitude < 0.05 then return false, "เครื่องหมายอยู่ตรงบน/ล่าง (โปรดปรับกล้อง)" end
			goal = hrp.Position + dir.Unit * math.clamp(mk.dist * Marker.k * 0.8, minStep, maxStep)
		end
		local ok, why = mover({ x = goal.X, y = goal.Y, z = goal.Z }, cancelled)
		Farm.walk = nil
		if cancelled() then return false, "cancelled" end
		if not ok then
			noGain = noGain + 1
			if noGain >= 3 then return false, tostring(why) end
		end
	end
	return false, "จำนวนช่วงทางมากเกินไป"
end

-- nearest enabled ProximityPrompt (from the scan) within maxD studs of the character
local function nearestPrompt(maxD, kind)
	local _, hrp = ctx.getCharacterParts()
	if not hrp then return nil end
	local me = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z }
	local best, bd, bestK, bdK
	for _, e in ipairs(Scanner.entries) do
		if e.class == "ProximityPrompt" then
			local alive = pcall(function()
				if not e.inst:IsDescendantOf(Workspace) or e.inst.Enabled == false then error("x") end
			end)
			if alive then
				local p = getPosition(e.inst) or e.pos
				if p then
					e.pos = p
					local d = dist3(p, me)
					if d <= maxD and (not bd or d < bd) then best, bd = e, d end
					if kind and e.kind == kind and d <= maxD and (not bdK or d < bdK) then bestK, bdK = e, d end
				end
			end
		end
	end
	if bestK then return bestK, bdK end -- [v1.38] ถ้ามีปุ่มชนิดตรงกับขั้นตอน (เช่น uniform) ให้เลือกก่อน ไม่เลือก NPC/ปุ่มอื่นที่ใกล้กว่า
	return best, bd
end

-- shared "this point is done" bookkeeping
local function finishPoint(kind)
	if kind == "uniform" then
		Farm.uniforms = Farm.uniforms + 1
		Farm.state = "spawn"
	else
		Farm.deliveries = Farm.deliveries + 1
		Farm.recover, Farm.restarts = 0, 0
		Farm.batchDone = Farm.batchDone + 1
		Farm.pending = Farm.pending - 1
		if Farm.pending <= 0 then Farm.state, Farm.batchDone = "order", 0 end
	end
end

local function applySpeed(hum)
	if not hum then return end
	if Farm.boost then
		if not Farm.origSpeed then Farm.origSpeed = hum.WalkSpeed end
		if hum.WalkSpeed ~= Farm.speed then hum.WalkSpeed = Farm.speed end
	elseif Farm.origSpeed then
		hum.WalkSpeed = Farm.origSpeed
		Farm.origSpeed = nil
	end
end

-- [v14] ช่วยจัดการ GUI ตามชื่อจริงของแมพ (จาก MAP DUMP)
local function guiPath(root, ...)
	local cur = root
	for _, n in ipairs({ ... }) do
		cur = cur and cur:FindFirstChild(n)
		if not cur then return nil end
	end
	return cur
end

local function myVehicleExists()
	local sv = Workspace:FindFirstChild("SpawnedVehicles")
	if not sv then return false end
	local me = ctx.player.Name:lower()
	for _, m in ipairs(sv:GetChildren()) do
		if m.Name:lower():find(me, 1, true) then return true end
	end
	return false
end

-- กดวัตถุ GUI: ใช้ปุ่มภายใน (firesignal) ก่อน ไม่ได้ผลค่อยแตะกลางวัตถุด้วย VirtualInputManager
local function tapGui(obj)
	if not obj then return false end
	local btn = obj:IsA("GuiButton") and obj or obj:FindFirstChildWhichIsA("GuiButton", true)
	if btn and ctx.clickBtn(btn) then return true end
	local vim = Veh.vim
	if vim and obj:IsA("GuiObject") then
		local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
		local inset = (sg and sg.IgnoreGuiInset) and Vector2.new(0, 0) or GuiService:GetGuiInset()
		local x = obj.AbsolutePosition.X + obj.AbsoluteSize.X / 2 + inset.X
		local y = obj.AbsolutePosition.Y + obj.AbsoluteSize.Y / 2 + inset.Y
		pcall(function() vim:SendTouchEvent(7732, 0, x, y) end)
		pcall(function() vim:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
		task.wait(0.05)
		pcall(function() vim:SendTouchEvent(7732, 2, x, y) end)
		pcall(function() vim:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
		return true
	end
	return false
end

-- เรียกรถจากหน้าต่าง MY VEHICLES (GameHud/Left/Garage -> GarageWindow/.../Buttons/Spawn)
local function spawnVehicle()
	if myVehicleExists() then return true end
	local pg = ctx.player:FindFirstChild("PlayerGui")
	if not pg then return false end
	local panel = guiPath(pg, "GarageWindow", "GaragePanel")
	local spawn = panel and guiPath(panel, "Body", "Right", "Buttons", "Spawn")
	if not (spawn and shown(spawn, pg)) then
		tapGui(guiPath(pg, "GameHud", "Left", "Garage"))
		task.wait(1)
		panel = guiPath(pg, "GarageWindow", "GaragePanel")
		spawn = panel and guiPath(panel, "Body", "Right", "Buttons", "Spawn")
	end
	if not spawn then return false end
	tapGui(spawn)
	for _ = 1, 10 do
		task.wait(0.4)
		if myVehicleExists() then return true end
	end
	return false
end

-- เปิดแอป QuickRider บนโทรศัพท์ (Phone/Dock/Phone/Screen/Home/Apps/delivery)
local function openRiderApp()
	local pg = ctx.player:FindFirstChild("PlayerGui")
	local scr = pg and guiPath(pg, "Phone", "Dock", "Phone", "Screen")
	if not scr then return false end
	local app = scr:FindFirstChild("App")
	if app and shown(app, pg) then return true end
	tapGui(guiPath(scr, "Home", "Apps", "delivery"))
	task.wait(1)
	return true
end

-- [v13] แมพนี้รับงานด้วยแถบ "Slide to accept..." (ต้องลาก ไม่ใช่กดปุ่ม) และแท็บ Food/Skip เป็นแค่ตัวกรอง
local function findAcceptSlider()
	local pg = ctx.player:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _, d in ipairs(pg:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and #d.Text > 0 and #d.Text <= 60 and d.AbsoluteSize.X > 0 then
			local low = d.Text:lower()
			if (low:find("slide to accept", 1, true) or low:find("^slide to confirm") or low:find("เลื่อนเพื่อรับ", 1, true) or low:find("สไลด์เพื่อรับ", 1, true))
				and shown(d, pg) then
				-- แถบ (pill) = ตัวห่อที่มีพื้นหลังและกว้างพอ ๆ กับข้อความ
				local track, o = d, d
				for _ = 1, 3 do
					o = o.Parent
					if not (o and o:IsA("GuiObject")) then break end
					if o.BackgroundTransparency < 1 and o.AbsoluteSize.X >= d.AbsoluteSize.X * 0.9 then track = o break end
				end
				return track, d
			end
		end
	end
	return nil
end

local function dragSlider(track)
	local vim = Veh.vim
	if not vim then return false, "ไม่มี VirtualInputManager" end
	local sg = track:FindFirstAncestorWhichIsA("ScreenGui")
	local inset = (sg and sg.IgnoreGuiInset) and Vector2.new(0, 0) or GuiService:GetGuiInset()
	local ap, sz = track.AbsolutePosition, track.AbsoluteSize
	local y = ap.Y + sz.Y / 2 + inset.Y
	local x0 = ap.X + math.min(sz.Y * 0.6, sz.X * 0.15) + inset.X
	local x1 = ap.X + sz.X - math.min(sz.Y * 0.3, 12) + inset.X
	local okAny = false
	local okT = pcall(function() vim:SendTouchEvent(7731, 0, x0, y) end)
	local okM = pcall(function() vim:SendMouseButtonEvent(x0, y, 0, true, game, 0) end)
	okAny = okT or okM
	for i = 1, 14 do
		local x = x0 + (x1 - x0) * (i / 14)
		if okT then pcall(function() vim:SendTouchEvent(7731, 1, x, y) end) end
		if okM then pcall(function() vim:SendMouseMoveEvent(x, y, game) end) end
		task.wait(0.03)
	end
	if okT then pcall(function() vim:SendTouchEvent(7731, 2, x1, y) end) end
	if okM then pcall(function() vim:SendMouseButtonEvent(x1, y, 0, false, game, 0) end) end
	if okAny then return true end
	return false, "ส่งอินพุตไม่สำเร็จ"
end

-- คืน true เมื่อรับงานสำเร็จจริง (แถบหาย หรือเครื่องหมายสีเหลือง/ระยะ "xx m" โผล่)
local function acceptJob()
	local track, lbl = findAcceptSlider()
	if not track then return false, "ไม่พบแถบ Slide to accept" end
	local ok, why = dragSlider(track)
	if not ok then
		if lbl:IsA("TextButton") and ctx.clickBtn(lbl) then ok = true else return false, why end
	end
	Farm.lastAction, Farm.lastActionAt = "ลากแถบ Slide to accept", os.clock()
	for _ = 1, 10 do
		task.wait(0.3)
		if not findAcceptSlider() or Marker.read() then return true end
	end
	return false, "ลากแล้วแต่งานไม่ถูกรับ"
end

local function farmStep(token)
	local function cancelled() return (not Farm.on) or Farm.token ~= token end
	if State.AutoRiderDelivery then Farm.status = "หยุดชั่วคราว: AUTO RIDER เดิมกำลังทำงาน" return end
	local char, hrp, hum = ctx.getCharacterParts()
	if not hrp then Farm.status = "รอตัวละคร" return end
	if Farm.char ~= char then
		if Farm.char ~= nil then
			-- respawned: uniform/vehicle are gone, start the cycle again
			Farm.state, Farm.pending, Farm.batchDone, Farm.noTarget, Farm.origSpeed = "uniform", 0, 0, 0, nil
		end
		Farm.char = char
	end
	applySpeed(hum)
	local kind = Farm.state
	local origin = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z }

	-- SPAWN: summon the bike through the game's own GUI button (no walking)
	if kind == "spawn" then
		local sp = hum and hum.SeatPart
		local onMine = sp and sp:IsA("VehicleSeat") and ownedByMe(sp:FindFirstAncestorOfClass("Model"))
		if not Farm.drive then
			Farm.status = "โหมดเดิน: ไม่เสกรถ"
		elseif onMine then
			Farm.status = "อยู่บนยานพาหนะของเราแล้ว"
			Farm.spawnFail = 0
		else
			Farm.status = "กำลังเรียกยานพาหนะ (ปุ่มใน GUI)"
			local okc = spawnVehicle()
			if not okc then
				-- [v1.38] ยังไม่มีรถ = ไม่ไปรับงาน/ไม่เดินต่อ: ลองเสกใหม่ และหยุดอย่างปลอดภัยถ้าเสกไม่ได้ซ้ำๆ
				Farm.spawnFail = (Farm.spawnFail or 0) + 1
				Farm.status = "เสกรถไม่สำเร็จ (" .. Farm.spawnFail .. "/4) - ลองใหม่"
				if Farm.spawnFail >= 4 then
					Farm.notify("ERROR", "เสกรถไม่สำเร็จ 4 ครั้งติด - หยุดฟาร์ม", true)
					Farm.stop("เสกรถไม่สำเร็จ (ไม่พบปุ่มเรียกรถ/รถไม่โผล่)")
				end
				task.wait(2)
				return
			end
			Farm.spawnFail = 0
			Farm.status = "เสกรถแล้ว"
			task.wait(3)
		end
		Farm.state = (Farm.pending > 0) and "deliver" or "order"
		return
	end

	-- [v21] sync with the game's real state (from job log): DeliveryState / DeliveryJob / DeliveryArrived.
	-- Rider jobs have NO ProximityPrompt: pick-up and drop-off are confirmed with the phone slider.
	-- Shop/home coordinates are random per job and are read from the DeliveryJob attribute (JSON).
	if kind == "order" or kind == "deliver" then
		local pl = ctx.player
		local st = pl:GetAttribute("DeliveryState")
		if st == "ToShop" or st == "ToHome" then
			Farm.state, Farm.pending, Farm.lastLeg = "deliver", 1, st
			if pl:GetAttribute("DeliveryArrived") == true then
				Farm.status = "ถึงจุดแล้ว - ปัดยืนยัน (" .. st .. ")"
				openRiderApp()
				for _ = 1, 6 do
					if cancelled() or pl:GetAttribute("DeliveryArrived") ~= true then break end
					local trk = findAcceptSlider()
					if trk then dragSlider(trk) end
					task.wait(0.7)
				end
				return
			end
			local okJ, job = pcall(function()
				return game:GetService("HttpService"):JSONDecode(pl:GetAttribute("DeliveryJob"))
			end)
			local tgt = okJ and type(job) == "table" and ((st == "ToShop") and job.shop or job.home)
			if not (type(tgt) == "table" and tonumber(tgt.x) and tonumber(tgt.z)) then
				Farm.status = "อ่านพิกัดจาก DeliveryJob ไม่ได้"
				task.wait(1)
				return
			end
			pcall(function() BKPin.set("rider", tgt.x, tgt.z, (st == "ToShop" and "รับลูกค้า: " or "ส่งลูกค้า: ") .. tostring(tgt.name)) end)
			local gy = (Veh.seat and Veh.seat.Parent) and Veh.seat.Position.Y or hrp.Position.Y
			local goal = { x = tgt.x, y = gy, z = tgt.z }
			local function stopNow()
				return cancelled() or pl:GetAttribute("DeliveryArrived") == true or pl:GetAttribute("DeliveryState") ~= st
			end
			local okM, whyM
			if Farm.drive then
				okM, whyM = Veh.prepare(cancelled)
				if not okM and whyM == "ไม่พบยานพาหนะของคุณใกล้ตัว" then
					Farm.state = "spawn"
					Farm.status = "ไม่พบยานพาหนะ - เรียกใหม่อีกครั้ง"
					return
				end
				if okM then
					Farm.status = (st == "ToShop" and "ขับไปรับลูกค้า: " or "ขับไปส่งลูกค้า: ") .. tostring(tgt.name)
					okM, whyM = Veh.driveTo(goal, 10, stopNow)
				end
			else
				Farm.status = "กำลังเดินไป " .. tostring(tgt.name)
				okM, whyM = walkToPos(goal, 6, stopNow)
			end
			Farm.walk = nil
			if cancelled() then return end
			if not okM and not stopNow() then error("เคลื่อนที่ไป " .. tostring(st) .. " ล้มเหลว: " .. tostring(whyM)) end
			return
		end
		pcall(function() BKPin.clear("rider") end)
		-- not on a leg any more: a finished ToHome leg means one completed job
		if Farm.lastLeg == "ToHome" then
			Farm.deliveries = Farm.deliveries + 1
			Farm.recover, Farm.restarts = 0, 0
		end
		Farm.lastLeg = nil
		if kind == "deliver" then Farm.state, Farm.pending = "order", 0 return end
		if st == "Searching" then
			Farm.status = "กำลังค้นหางาน..."
			task.wait(0.5)
			return
		end
	end

	-- ORDER: accept right where we are (GUI buttons). mode: food / passenger / both (held at the same time)
	if kind == "order" then
		Farm.status = "กำลังรับออเดอร์ (" .. Farm.mode .. ")"
		local n = 0
		-- [v13] แท็บ Food/Passenger เป็นแค่ตัวกรอง: กดแล้วไม่นับเป็นออเดอร์ (เดิมนับผิดทำให้ไปขั้น "ส่ง" ทั้งที่ยังไม่ได้รับงาน)
		local tab = Farm.mode
		if tab == "both" then Farm.altTab = not Farm.altTab tab = Farm.altTab and "food" or "passenger" end
		if tab == "food" then farmClick(Farm.foodKeywords, "tab-food") else farmClick(Farm.passengerKeywords, "tab-passenger") end
		task.wait(0.6)
		if cancelled() then return end
		openRiderApp()
		local okA, whyA = acceptJob()
		if okA then
			n = 1
		else
			Farm.status = "รับงานไม่สำเร็จ: " .. tostring(whyA) .. " (ลากแถบ Slide to accept เองได้ ระบบจะทำต่อ)"
			if not findAcceptSlider() and farmClick(Farm.orderKeywords, "order") then n = 1 end
			if n == 0 and Marker.read() then n = 1 end -- ผู้เล่นรับงานเองแล้ว (มีเครื่องหมายระยะ)
		end
		if n == 0 then
			for _, t in ipairs(Farm.nearOnly(liveTargets("order", origin), 12)) do
				if t.d > 12 then
					Farm.status = "เดินกลับไปจุดรับออเดอร์: " .. farmLabel(t.e)
					local okW = walkToPos(t.e.pos, 5, cancelled)
					Farm.walk = nil
					if cancelled() then return end
					if not okW then break end
				end
				Farm.lastAction, Farm.lastActionAt = "กดปุ่มรับออเดอร์: " .. farmLabel(t.e), os.clock()
				if activate(t.e) then n = 1 break end
			end
		end
		if n > 0 then
			Farm.noOrder = 0
			Farm.orders = Farm.orders + n
			Farm.pending, Farm.batchDone = n, 0
			Farm.state = "deliver"
			task.wait(1 + math.random() * 0.8)
			-- destinations usually appear after accepting: rescan (throttled)
			if os.clock() - Farm.lastScan >= 4 then
				Farm.lastScan = os.clock()
				MA.refreshMap("ฟาร์ม: ออเดอร์ใหม่")
			end
		else
			Farm.noOrder = Farm.noOrder + 1
			Farm.status = "รอปุ่มรับออเดอร์ (" .. Farm.noOrder .. "/8)"
			if Farm.noOrder >= 8 then
				Farm.recover = Farm.recover + 1
				if Farm.recover >= 3 then
					Farm.stop("ไม่พบปุ่มรับออเดอร์ (โปรดแจ้งข้อความบนปุ่ม)")
					return
				end
				Farm.noOrder, Farm.state = 0, "uniform"
				Farm.status = "ไม่พบปุ่มออเดอร์ - ทำขั้นตอนชุด/เรียกรถใหม่"
			end
			task.wait(1.5)
		end
		return
	end

	-- UNIFORM / DELIVER: first follow the game's yellow objective marker when it is on screen
	if Farm.useMarker and (kind == "uniform" or kind == "deliver") then
		local mk0 = Marker.read()
		if mk0 then
			local useDrive = (kind == "deliver" and Farm.drive)
			local mover
			if useDrive then
				local okP, whyP = Veh.prepare(cancelled)
				if not okP then
					if whyP == "ไม่พบยานพาหนะของคุณใกล้ตัว" then
						Farm.state = "spawn"
						Farm.status = "ไม่พบยานพาหนะ - เรียกใหม่อีกครั้ง"
						return
					end
					error("vehicle: " .. tostring(whyP))
				end
				mover = function(g, c) return Veh.driveTo(g, 8, c) end
			else
				mover = function(g, c) return walkToPos(g, 3, c) end
			end
			Farm.status = "กำลังเดินตามเครื่องหมายสีเหลือง (" .. tostring(mk0.dist) .. " m) -> " .. kind
			local okH, whyH = Marker.home(mover, cancelled, useDrive and 15 or 8, useDrive and 60 or 35, 150)
			Farm.walk = nil
			if cancelled() then return end
			if okH then
				Farm.markerWait = 0
				if os.clock() - Farm.lastScan >= 3 then
					Farm.lastScan = os.clock()
					MA.refreshMap("ฟาร์ม: ถึงเครื่องหมายแล้ว")
				end
				local pe, pd = nearestPrompt(16, kind)
				if pe then
					if pd > 6 and not useDrive then
						walkToPos(pe.pos, 4, cancelled)
						Farm.walk = nil
						if cancelled() then return end
					end
					Farm.lastAction, Farm.lastActionAt = kind .. " prompt (marker): " .. farmLabel(pe), os.clock()
					activate(pe)
					if kind == "deliver" then Farm.used[pe.inst] = os.clock() end
					Farm.markerMiss = 0
					task.wait(1 + math.random() * 0.8)
					finishPoint(kind)
				else
					Farm.markerMiss = Farm.markerMiss + 1
					Farm.status = "ถึงเครื่องหมายแต่ไม่มีปุ่มโต้ตอบในระยะ (" .. Farm.markerMiss .. "/3)"
					if Farm.markerMiss >= 3 then
						Farm.markerMiss = 0
						finishPoint(kind)
					end
					task.wait(1)
				end
				return
			end
			Farm.status = "เครื่องหมายล้มเหลว (" .. tostring(whyH) .. ") - รอตรวจเป้าหมายใหม่ (ไม่เดินสุ่มหา NPC)"
			Farm.markerWait = (Farm.markerWait or 0) + 1
			if Farm.markerWait >= 5 then
				Farm.markerWait = 0
				if kind == "uniform" then Farm.state = "spawn" else Farm.state, Farm.pending = "order", 0 end
			end
			pcall(function() BKPin.clear("rider") end)
			task.wait(1.5)
			return
		else
			-- [v1.38] ไม่พบหมุดสีเหลือง: ห้ามเดินสุ่มไปหาจุดที่สแกนได้ ให้รอแล้วตรวจใหม่ และแจ้งสถานะบน UI
			Farm.markerWait = (Farm.markerWait or 0) + 1
			Farm.status = "ไม่พบหมุดสีเหลือง - รอตรวจเป้าหมายใหม่ (" .. Farm.markerWait .. "/8)"
			pcall(function() BKPin.clear("rider") end)
			if Farm.markerWait >= 8 then
				Farm.markerWait = 0
				if kind == "uniform" then
					Farm.state = "spawn"
					Farm.status = "ไม่พบหมุดสีเหลือง - ข้ามขั้นตอนชุด (อาจใส่ชุดแล้ว)"
				else
					Farm.state, Farm.pending = "order", 0
				end
			end
			task.wait(1)
			return
		end
	end

	-- UNIFORM / DELIVER: need a located point
	Farm.status = "กำลังค้นหา " .. kind .. " point"
	local list = liveTargets(kind, origin)
	if kind == "deliver" then
		local now, f = os.clock(), {}
		for _, t in ipairs(list) do
			local u = Farm.used[t.e.inst]
			if not (u and now - u < 25) then f[#f + 1] = t end
		end
		list = f
	end
	if #list == 0 then
		Farm.noTarget = Farm.noTarget + 1
		if os.clock() - Farm.lastScan >= 5 then
			Farm.lastScan = os.clock()
			MA.refreshMap("farm: no " .. kind .. " point")
		end
		if Farm.noTarget >= 6 then
			Farm.noTarget = 0
			if kind == "uniform" then
				Farm.state = "spawn"
				Farm.status = "ไม่พบจุดรับชุด - ข้ามขั้นตอนชุด"
			elseif Farm.batchDone > 0 then
				Farm.state, Farm.pending, Farm.batchDone = "order", 0, 0
				Farm.status = "ไม่มีจุดส่งของเหลือ - ไปออเดอร์ถัดไป"
			else
				Farm.recover = Farm.recover + 1
				if Farm.recover >= 3 then
					Farm.stop("ไม่พบจุดส่งของ (ดูรายการใน OBJECT SCANNER)")
					return
				end
				Farm.state, Farm.pending = "order", 0
				Farm.status = "ไม่มีจุดส่งของ - ลองรับออเดอร์ใหม่"
			end
		end
		return
	end
	Farm.noTarget = 0
	local e = list[1].e
	local md = 10
	if e.class == "ProximityPrompt" then
		local okM, v = pcall(function() return e.inst.MaxActivationDistance end)
		if okM and type(v) == "number" then md = v end
	end
	local radius = math.max(3, math.min(7, md - 2))
	local ok, why
	if kind == "deliver" and Farm.drive then
		-- sit -> engine -> handbrake -> drive (re-checked every delivery, so leaving the car or respawning is fine)
		ok, why = Veh.prepare(cancelled)
		if ok then
			local dr = math.max(5, math.min(10, md - 2))
			Farm.status = "กำลังขับไปส่งของ: " .. farmLabel(e)
			ok, why = Veh.driveTo(e.pos, dr, cancelled)
		end
		if not ok and why == "ไม่พบยานพาหนะของคุณใกล้ตัว" then
			Farm.state = "spawn"
			Farm.status = "ไม่พบยานพาหนะ - เรียกใหม่อีกครั้ง"
			return
		end
	else
		Farm.status = "กำลังเดินไป " .. kind .. ": " .. farmLabel(e)
		ok, why = walkToPos(e.pos, radius, cancelled)
	end
	Farm.walk = nil
	if cancelled() then return end
	if not ok then
		if kind == "deliver" then Farm.used[e.inst] = os.clock() end
		error("เคลื่อนที่ไป " .. kind .. " failed: " .. tostring(why))
	end
	Farm.status = "activating " .. kind
	task.wait(0.4 + math.random() * 0.6)
	Farm.lastAction, Farm.lastActionAt = kind .. " prompt: " .. farmLabel(e) .. " [" .. tostring(e.class) .. "]", os.clock()
	activate(e)
	if kind == "deliver" then Farm.used[e.inst] = os.clock() end
	task.wait(1 + math.random() * 0.8)
	finishPoint(kind)
end

function Farm.stop(reason)
	local wasOn, keep = Farm.on, Farm.keepWanted
	Farm.keepWanted = false
	pcall(function() BKPin.clear("rider") end)
	Farm.on = false
	if not keep then
		Farm.setWanted(false)
		if wasOn then Farm.notify("STOP", "เหตุผล: " .. tostring(reason or "user"), true) end
	end
	Farm.token = Farm.token + 1
	Farm.state = "idle"
	Farm.status = "หยุด: " .. tostring(reason or "user")
	Farm.walk = nil
	Veh.release()
	local _, _, h = ctx.getCharacterParts()
	if h and Farm.origSpeed then pcall(function() h.WalkSpeed = Farm.origSpeed end) end
	Farm.origSpeed = nil
	PathA.stop("ฟาร์มหยุดทำงาน")
end

-- [v1.31] STOP ALL ต้องหยุด Farm ด้วย (เดิมไม่ได้ลงทะเบียนฮุก ทำให้ Farm วิ่งต่อ)
EmergencyStopHooks[#EmergencyStopHooks + 1] = function(reason)
	Farm.emergencyAt = os.clock()
	Farm.setWanted(false)
	if Farm.on then Farm.stop("STOP ALL: " .. tostring(reason)) end
end

function Farm.start(initial)
	if Farm.on then return true end
	-- Farm and JobBot share movement/interaction resources; never run both together.
	if stopActiveJobBot then stopActiveJobBot("สลับไปใช้ Farm") end
	if State.AutoRiderDelivery then Farm.status = "ปฏิเสธ: โปรดปิด AUTO RIDER เดิมก่อน" return false end
	if State.AutoBuilder or State.AutoMechanic or State.AutoRefuel or State.AutoRepair or State.AutoTuneECU then
		Farm.status = "ปฏิเสธ: โปรดปิดระบบออโต้เดิมอื่นก่อน"
		return false
	end
	EM.resetSystem("RiderFarm")
	Farm.on = true
	Farm.token = Farm.token + 1
	local my = Farm.token
	Farm.setWanted(true)
	if initial ~= "spawn" then
		Farm.wdRestarts, Farm.wdLastDone = 0, Farm.deliveries
		Farm.notify("START", "เริ่มฟาร์ม (" .. tostring(initial or "uniform") .. ")", true)
	end
	Farm.state, Farm.noTarget, Farm.noOrder = initial or "uniform", 0, 0
	Farm.pending, Farm.batchDone, Farm.recover, Farm.restarts = 0, 0, 0, 0
	Farm.char, Farm.origSpeed, Farm.walk = nil, nil, nil
	Farm.used = setmetatable({}, { __mode = "k" })
	Farm.status = "starting"
	Veh.readySeat, Farm.spawnFail, Farm.markerWait = nil, 0, 0
	pcall(function()
		local I = (getgenv and getgenv() or _G).__BK_INSTANCE
		-- [v1.31] ใช้ฮุกแทนการเขียนทับ I.onStop (เดิมทับฮุกล้างเส้นทางของหน้านำทาง)
		if not Farm.stopHooked then
			Farm.stopHooked = true
			I.hooks[#I.hooks + 1] = function(reason) State.AutoRiderDelivery = false Farm.keepWanted = not tostring(reason):find("window closed", 1, true) Farm.stop(reason) end
		end
		if ctx.mainWindow and not Farm.winConn then
			Farm.winConn = ctx.mainWindow.AncestryChanged:Connect(function(_, parent)
				if not parent then I.stop("window closed") end
			end)
			I.conns[#I.conns + 1] = Farm.winConn
		end
	end)
	Farm.lastAction, Farm.lastActionAt, Farm.lastJump, Farm.jumps = "start", os.clock(), "none", 0
	task.spawn(function()
		-- teleport detector: reports a sudden position jump and the last thing the farm pressed
		local lastP, lastT
		while Farm.on and Farm.token == my do
			local _, hrp, hum = ctx.getCharacterParts()
			if hrp then
				local p, t = hrp.Position, os.clock()
				if lastP and t - lastT < 0.6 then
					local d = (p - lastP).Magnitude
					if d > ((hum and hum.SeatPart) and 60 or 25) then
						Farm.jumps = Farm.jumps + 1
						Farm.lastJump = string.format("%.0f studs | state=%s | after [%s] %.1fs ago",
							d, Farm.state, Farm.lastAction, t - Farm.lastActionAt)
					end
				end
				lastP, lastT = p, t
			end
			task.wait(0.1)
		end
	end)
	-- [v1.28] WATCHDOG: ถ้าไม่มีความคืบหน้านานเกินกำหนด (สถานะ/ตำแหน่ง/สถานะงานในเกมไม่เปลี่ยน) ให้ล้างงานค้างในสคริปต์แล้วเริ่มวงจรใหม่
	-- ไม่กดยกเลิกงานในเกม (เสียเรตติ้ง) แค่ทิ้งสถานะเก่าของฟาร์มแล้วซิงก์กับสถานะจริงของเกมใหม่
	task.spawn(function()
		local sig, sigAt = nil, os.clock()
		while Farm.on and Farm.token == my do
			task.wait(2)
			local _, hrp = ctx.getCharacterParts()
			local pl = ctx.player
			local ds = pl:GetAttribute("DeliveryState")
			local cell = hrp and (math.floor(hrp.Position.X / 8) .. ":" .. math.floor(hrp.Position.Z / 8)) or "-"
			local cur = table.concat({ tostring(Farm.state), tostring(ds), tostring(pl:GetAttribute("DeliveryArrived")),
				tostring(pl:GetAttribute("DeliveryProgress")), tostring(pl:GetAttribute("DeliveryJobs")), cell }, "|")
			local now = os.clock()
			if cur ~= sig then
				sig, sigAt = cur, now
			else
				local limit = (ds == "Searching" or ds == "Off" or ds == nil) and 240 or 120
				if now - sigAt > limit then
					if Farm.deliveries > (Farm.wdLastDone or 0) then Farm.wdRestarts, Farm.wdLastDone = 0, Farm.deliveries end
					Farm.wdRestarts = (Farm.wdRestarts or 0) + 1
					Farm.wdTotal = (Farm.wdTotal or 0) + 1
					if Farm.wdRestarts > 3 then
						Farm.notify("ERROR", "Watchdog: ค้างซ้ำเกิน 3 รอบ (" .. tostring(Farm.state) .. "/" .. tostring(ds) .. ") - หยุดฟาร์ม", true)
						Farm.stop("watchdog: ค้างซ้ำ 3 รอบ (" .. tostring(Farm.state) .. "/" .. tostring(ds) .. ")")
						return
					end
					local keepDeliveries = Farm.deliveries
					Farm.keepWanted = true
					Farm.notify("WATCHDOG", "ไม่มีความคืบหน้า " .. math.floor(now - sigAt) .. " วินาที (" .. tostring(Farm.state) .. "/" .. tostring(ds) .. ") - เริ่มวงจรใหม่")
					local wdT0 = os.clock()
					Farm.stop("watchdog: ไม่มีความคืบหน้า " .. math.floor(now - sigAt) .. " วินาที - เริ่มวงจรใหม่")
					task.wait(1)
					-- [v1.31] ถ้ามี STOP ALL / ปิดสคริปต์ระหว่างรอ ห้ามเริ่มฟาร์มกลับมา
					if (Farm.emergencyAt or 0) >= wdT0 or not __bkAlive() then return end
					Farm.start("spawn")
					Farm.deliveries = keepDeliveries
					return
				end
			end
		end
	end)
	task.spawn(function()
		-- runs until the user turns it off; recovers from errors a few times in a row
		while Farm.on and Farm.token == my and ctx.mainWindow and ctx.mainWindow.Parent do
			local ok = EM.guard("RiderFarm", farmStep, my)
			if not ok then pcall(Veh.release) end -- [v1.37] ไม่ปล่อยปุ่ม/คันเร่งค้างเมื่อ error กลางทาง
			local s = EM.systems.RiderFarm
			if s and s.stopped then
				Farm.restarts = Farm.restarts + 1
				if Farm.restarts > 5 then
					Farm.notify("ERROR", "หยุดหลัง error ซ้ำ: " .. cut(s.reason, 150), true)
					Farm.stop("errors: " .. cut(s.reason, 80))
					break
				end
				Farm.status = "error, retrying (" .. Farm.restarts .. "/5): " .. cut(s.reason, 60)
				Farm.notify("ERROR", "ลองใหม่ " .. Farm.restarts .. "/5: " .. cut(s.reason, 150))
				EM.resetSystem("RiderFarm")
				PathA.stop("ฟาร์ม: ลองใหม่")
				task.wait(3)
			end
			task.wait(ok and 0.4 or 1.5)
		end
	end)
	return true
end

-- ---------------------------------------------------------------------------
-- [v1.36] SUPERVISOR: ตรวจหลุด/ถูกเตะ -> Rejoin อัตโนมัติ + ทำฟาร์มต่อ (Auto Resume) + Heartbeat
-- Rejoin ทำงานเฉพาะตอน "ผู้ใช้ต้องการให้ฟาร์มทำงาน" (FarmWanted) เท่านั้น: STOP ALL / กดปิดเอง / เจอทีมงาน = ไม่ Rejoin
-- ข้อจำกัด: ถ้าแอปปิดทั้งตัว (ไม่มีหน้า Error ให้สคริปต์เห็น) ต้องใช้ Auto Execute ของตัวรันช่วยเปิดสคริปต์ใหม่
-- ---------------------------------------------------------------------------
do
	local GuiService = game:GetService("GuiService")
	local TeleportService = game:GetService("TeleportService")
	local Sup = { busy = false, times = {}, queued = false }
	Farm.Sup = Sup
	local MAX_PER_HOUR = 8

	local function queueSelf()
		local q = (type(queue_on_teleport) == "function" and queue_on_teleport)
			or (type(queueonteleport) == "function" and queueonteleport)
			or (type(syn) == "table" and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
			or (type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)
		if not q then return false, "ตัวรันไม่มี queue_on_teleport" end
		local have = false
		pcall(function() have = type(isfile) == "function" and isfile("BallKun_v1_35_src.lua") end)
		if not have then return false, "ไม่พบไฟล์ BallKun_v1_35_src.lua (ต้องรันผ่าน Loader อย่างน้อย 1 ครั้ง)" end
		local ok = pcall(q, 'pcall(function() loadstring(readfile("BallKun_v1_35_src.lua"))() end)')
		return ok, ok and "queued" or "queue ล้มเหลว"
	end

	-- ข้อความที่ "ไม่ควร" Rejoin เอง: แบน / ถูกเตะโดยเกม / เปิดบัญชีซ้อนจากเครื่องอื่น (วนซ้ำจะยิ่งเสี่ยง)
	local function isFatal(msg)
		local low = tostring(msg):lower()
		if low:find("ban", 1, true) or low:find("kick", 1, true) then return true end
		for _, code in ipairs({ "256", "267", "268", "273" }) do
			if low:find("error code: " .. code, 1, true) or low:find("code " .. code, 1, true) then return true end
		end
		return false
	end

	local function rejoin(reason)
		if Sup.busy or not __bkAlive() then return end
		if not State.AutoRejoin or not State.FarmWanted then return end
		if isFatal(reason) then
			Farm.setWanted(false)
			Farm.notify("ERROR", "ไม่ Rejoin (แบน/ถูกเตะ/บัญชีซ้อน): " .. tostring(reason), true)
			return
		end
		local now = os.time()
		local fresh = {}
		for _, t in ipairs(Sup.times) do if now - t < 3600 then fresh[#fresh + 1] = t end end
		Sup.times = fresh
		if #fresh >= MAX_PER_HOUR then
			Farm.setWanted(false)
			Farm.notify("ERROR", "Rejoin ถี่เกิน " .. MAX_PER_HOUR .. " ครั้ง/ชั่วโมง - หยุดเพื่อความปลอดภัย: " .. tostring(reason), true)
			return
		end
		Sup.times[#Sup.times + 1] = now
		Sup.busy = true
		Farm.rejoins = Farm.rejoins + 1
		local qok, qmsg = true, "queued แล้ว"
		if not Sup.queued then
			qok, qmsg = queueSelf()
			if qok then Sup.queued = true end
		end
		Farm.notify("REJOIN", "สาเหตุ: " .. tostring(reason) .. "\nรันสคริปต์ซ้ำหลังเข้า: " .. tostring(qmsg), true)
		if type(ctx.saveConfig) == "function" then pcall(ctx.saveConfig) end
		task.wait(1.5) -- ให้ Webhook ส่งออกก่อน
		local placeId = ctx.Meta.PlaceId or game.PlaceId
		local ok, err = pcall(function() TeleportService:Teleport(placeId, ctx.player) end)
		if not ok then Farm.notify("ERROR", "Teleport ล้มเหลว: " .. tostring(err), true) end
		-- ถ้า Teleport สำเร็จ สคริปต์นี้จะหายไปพร้อมเซสชัน; ถ้ายังอยู่แปลว่าไม่สำเร็จ -> ลองใหม่แบบเว้นช่วงนานขึ้น
		task.delay(math.min(180, 30 * #Sup.times), function()
			Sup.busy = false
			if __bkAlive() then rejoin("ลองใหม่: Teleport ไม่สำเร็จ (" .. tostring(reason) .. ")") end
		end)
	end

	local function readError()
		local msg = ""
		pcall(function() msg = GuiService:GetErrorMessage() end)
		return msg
	end
	__bkTrack(GuiService.ErrorMessageChanged:Connect(function()
		local m = readError()
		if m ~= "" then task.spawn(rejoin, "ErrorMessage: " .. m) end
	end))
	task.spawn(function()
		local ok, overlay = pcall(function()
			return game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 20):WaitForChild("promptOverlay", 20)
		end)
		if ok and overlay then
			__bkTrack(overlay.ChildAdded:Connect(function(c)
				if c.Name ~= "ErrorPrompt" then return end
				task.wait(0.5)
				local m = readError()
				if m == "" then pcall(function() m = c.MessageArea.ErrorFrame.ErrorMessage.Text end) end
				rejoin("ErrorPrompt: " .. tostring(m))
			end))
		end
	end)
	__bkTrack(TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
		Farm.notify("ERROR", "TeleportInitFailed: " .. tostring(result) .. " " .. tostring(msg))
	end))

	-- AUTO RESUME: เข้าเกมใหม่แล้วถ้าครั้งก่อนฟาร์มกำลังทำงานอยู่ ให้เริ่มต่อเอง
	task.spawn(function()
		if not (State.AutoResumeFarm and State.FarmWanted) or Farm.on then return end
		if game.PlaceId ~= ctx.Meta.PlaceId then return end
		local t0 = os.clock()
		while __bkAlive() and os.clock() - t0 < 120 do
			local _, hrp = ctx.getCharacterParts()
			if hrp and game:IsLoaded() then break end
			task.wait(1)
		end
		task.wait(6) -- ให้ Scanner / WorldCache พร้อมก่อน
		for attempt = 1, 4 do
			if not __bkAlive() or Farm.on or not State.FarmWanted then return end
			if Farm.start() then
				Farm.notify("RESUME", "ทำฟาร์มต่อหลังเข้าเกมใหม่ (ครั้งที่ " .. attempt .. ")", true)
				return
			end
			task.wait(10)
		end
		Farm.notify("ERROR", "Auto Resume ไม่สำเร็จ: " .. tostring(Farm.status), true)
	end)

	-- HEARTBEAT ทุก 30 นาทีขณะฟาร์มทำงาน (ถ้าเงียบไป = แอปค้าง/ปิด) พร้อมค่า Memory ไว้ดูแนวโน้มรั่ว
	task.spawn(function()
		local last = os.clock()
		while __bkAlive() do
			task.wait(60)
			if Farm.on and os.clock() - last >= 1800 then
				last = os.clock()
				local mem = 0
				pcall(function() mem = math.floor(collectgarbage("count") / 1024) end)
				local nScan = 0
				pcall(function() nScan = #Scanner.entries end)
				Farm.notify("HEARTBEAT", "ยังทำงานอยู่ | state=" .. tostring(Farm.state) .. " | Lua memory ~" .. mem .. " MB | Scanner=" .. nScan, true)
			end
		end
	end)
end

-- bridge for the ORIGINAL auto systems: walk instead of teleport (non-blocking)
local Bridge = { thread = false, target = nil, id = 0 }
if ctx.WalkBridge then
	ctx.WalkBridge.stop = function(reason)
		Bridge.id = Bridge.id + 1
		Bridge.thread, Bridge.target = false, nil
		PathA.stop(reason or "ยกเลิกโดยตัวจัดการงาน")
	end
	ctx.WalkBridge.walkTo = function(pos)
		local _, hrp = ctx.getCharacterParts()
		if not hrp then return false end
		local cur = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z }
		local tp = { x = pos.X, y = pos.Y, z = pos.Z }
		if dist3(cur, tp) <= 11 or hdist(cur, tp) <= 9 then return true end
		if Bridge.thread and Bridge.target and dist3(Bridge.target, tp) < 8 then return false end
		PathA.stop("เปลี่ยนเป้าหมายสะพานเดิน")
		Bridge.id = Bridge.id + 1
		local myId = Bridge.id
		Bridge.thread, Bridge.target = true, tp
		task.spawn(function()
			local okG, err = EM.guard("WalkBridge", function()
				walkToPos(tp, 8, function() return Bridge.id ~= myId end)
			end)
			if Bridge.id == myId then Bridge.thread = false end
		end)
		return false
	end
end

-- ---------------------------------------------------------------------------
-- 7) UI  (page "5. MAP ADAPTIVE", same theme/helpers as the original UI)
-- ---------------------------------------------------------------------------
local function buildUI()
	local page = ctx.createPage("MapAdaptive", "5. MAP ADAPTIVE")

	-- 5 nav buttons must fit the sidebar: compact height only when needed
	local n = 0
	for _ in pairs(ctx.navButtons) do n = n + 1 end
	if n > 4 then
		for _, b in pairs(ctx.navButtons) do
			b.btn.Size = UDim2.new(1, 0, 0, 36)
		end
	end

	local function infoLabel(card, y, h)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -20, 0, h)
		lbl.Position = UDim2.fromOffset(10, y)
		lbl.BackgroundColor3 = Theme.BgInput
		lbl.BorderSizePixel = 0
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 11
		lbl.TextColor3 = Theme.TextMain
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.TextWrapped = true
		lbl.Text = "..."
		lbl.Parent = card
		ctx.addCorner(lbl, 7)
		return lbl
	end

	local function scrollText(card, y, h)
		local sc = Instance.new("ScrollingFrame")
		sc.Size = UDim2.new(1, -20, 0, h)
		sc.Position = UDim2.fromOffset(10, y)
		sc.BackgroundColor3 = Theme.BgInput
		sc.BorderSizePixel = 0
		sc.ScrollBarThickness = 4
		sc.ScrollBarImageColor3 = Theme.GreenPrimary
		sc.CanvasSize = UDim2.new(0, 0, 0, 0)
		sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sc.Parent = card
		ctx.addCorner(sc, 7)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -8, 0, 0)
		lbl.Position = UDim2.fromOffset(4, 2)
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 11
		lbl.TextColor3 = Theme.TextMain
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.TextWrapped = true
		lbl.Text = "..."
		lbl.Parent = sc
		return lbl
	end

	-- RIDER FARM (walk)
	local cFarm = ctx.makeCard(page, "AUTO RIDER: รับชุด > เรียกรถ > รับออเดอร์ > ขับ/เดินส่ง > ทำซ้ำ", 572, 0)
	ctx.makeToggle(cFarm, "AUTO RIDER (วนซ้ำ)", 32,
		function() return Farm.on end,
		function(v) if v then Farm.start() else Farm.stop("user") end end)
	ctx.makeToggle(cFarm, "ระบบออโต้เดิม: เดินแทนการวาป", 68,
		function() return State.WalkMode == true end,
		function(v) State.WalkMode = v end)
	local modeBtns = {}
	local function addMode(txt, x, mode)
		modeBtns[mode] = ctx.makeActionButton(cFarm, txt, x, 1 / 3, 104, 28, function() Farm.mode = mode end)
	end
	addMode("FOOD", 0, "food")
	addMode("PASSENGER", 1 / 3, "passenger")
	addMode("BOTH (พร้อมกัน)", 2 / 3, "both")
	ctx.makeToggle(cFarm, "ส่งของโดยขับรถ (ปิด = เดิน)", 138,
		function() return Farm.drive end,
		function(v) Farm.drive = v end)
	ctx.makeToggle(cFarm, "เดินตามเครื่องหมายสีเหลือง", 174,
		function() return Farm.useMarker end,
		function(v) Farm.useMarker = v end)
	ctx.makeToggle(cFarm, "ล็อกไม่ยิง Remote (บังคับเปิดตลอด)", 210,
		function() return true end,
		function(v) State.BlockRemotes = true end)
	ctx.makeToggle(cFarm, "เพิ่มความเร็วเดิน (เสี่ยงถูกตรวจจับ)", 246,
		function() return Farm.boost end,
		function(v) Farm.boost = v end)
	ctx.makeSlider(cFarm, "ความเร็วเดิน (เมื่อเปิดเพิ่มความเร็ว)", 282, 16, 80, "studs/s",
		function() return Farm.speed end,
		function(v) Farm.speed = v end)
	ctx.makeToggle(cFarm, "Auto Rejoin เมื่อหลุด/ถูกเตะ", 332,
		function() return State.AutoRejoin == true end,
		function(v) State.AutoRejoin = v if State.AutoSaveConfig and ctx.saveConfig then pcall(ctx.saveConfig) end end)
	ctx.makeToggle(cFarm, "Auto Resume ฟาร์มหลังเข้าเกมใหม่", 368,
		function() return State.AutoResumeFarm == true end,
		function(v) State.AutoResumeFarm = v if State.AutoSaveConfig and ctx.saveConfig then pcall(ctx.saveConfig) end end)
	local farmLbl = infoLabel(cFarm, 408, 148)

	-- MAP DETECTOR
	local cDet = ctx.makeCard(page, "MAP DETECTOR", 132, 1)
	local detLbl = infoLabel(cDet, 32, 92)

	-- OBJECT SCANNER
	local cScan = ctx.makeCard(page, "OBJECT SCANNER", 210, 2)
	local scanSummary = infoLabel(cScan, 32, 44)
	local scanList = scrollText(cScan, 82, 120)

	-- PATH ANALYZER
	local cPath = ctx.makeCard(page, "PATH ANALYZER", 150, 3)
	local pathLbl = infoLabel(cPath, 32, 64)
	local targets = {}
	local function currentTarget()
		return targets[PathA.targetIndex]
	end
	local function rebuildTargets()
		local _, hrp = ctx.getCharacterParts()
		local origin = hrp and { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z } or nil
		targets = Scanner.sortedByDistance(origin, true)
		if PathA.targetIndex < 1 or PathA.targetIndex > #targets then PathA.targetIndex = (#targets > 0) and 1 or 0 end
	end
	ctx.makeActionButton(cPath, "NEXT TARGET", 0, 0.25, 102, 36, function()
		rebuildTargets()
		if #targets == 0 then PathA.status = "ไม่มีเป้าหมายที่ยืนยันแล้ว" return end
		PathA.targetIndex = (PathA.targetIndex % #targets) + 1
		PathA.last = nil
	end)
	ctx.makeActionButton(cPath, "ANALYZE", 0.25, 0.25, 102, 36, function()
		task.spawn(function()
			local ok, res = EM.guard("PathAnalyzer", function()
				rebuildTargets()
				local t = currentTarget()
				if not t then PathA.status = "ไม่มีเป้าหมายที่ยืนยันแล้ว (กด REFRESH MAP)" return end
				PathA.status = "analyzing..."
				PathA.last = PathA.analyze(t.e.pos)
				PathA.status = PathA.last.success and "เส้นทางใช้ได้" or ("no path: " .. tostring(PathA.last.reason))
			end)
			if not ok then PathA.status = "error: " .. tostring(res) end
		end)
	end)
	ctx.makeActionButton(cPath, "WALK", 0.5, 0.25, 102, 36, function()
		task.spawn(function()
			local ok, res = EM.guard("PathWalk", function()
				if not (PathA.last and PathA.last.success) then PathA.status = "โปรดกด ANALYZE ก่อน" return end
				PathA.walk(PathA.last)
			end)
			if not ok then PathA.status = "error: " .. tostring(res) end
		end)
	end)
	ctx.makeActionButton(cPath, "STOP", 0.75, 0.25, 102, 36, function()
		PathA.stop("ผู้ใช้สั่งหยุด")
	end)

	-- AUTO SYSTEM CHECK
	local cSys = ctx.makeCard(page, "AUTO SYSTEM CHECK", 150, 4)
	local sysLbl = scrollText(cSys, 32, 110)

	-- MAP INFORMATION
	local cInfo = ctx.makeCard(page, "MAP INFORMATION", 112, 5)
	local infoLbl = infoLabel(cInfo, 32, 72)

	-- ERROR MONITOR
	local cErr = ctx.makeCard(page, "ERROR MONITOR", 160, 6)
	local errSummary = infoLabel(cErr, 32, 34)
	local errLog = scrollText(cErr, 72, 80)

	-- CONTROLS
	local cCtl = ctx.makeCard(page, "CONTROLS", 120, 7)
	ctx.makeToggle(cCtl, "รีเฟรชอัตโนมัติเมื่อแมพเปลี่ยน", 32,
		function() return MA.Config.AutoRescan end,
		function(v) MA.Config.AutoRescan = v end)
	ctx.makeActionButton(cCtl, "REFRESH MAP", 0, 0.5, 74, 36, function()
		task.spawn(function() MA.refreshMap("manual") end)
	end)
	ctx.makeActionButton(cCtl, "RESET DATA", 0.5, 0.5, 74, 36, function()
		MA.resetData()
		task.spawn(function() MA.refreshMap("หลังรีเซ็ต") end)
	end)

	local function fmtPath(r)
		if not r then return "ยังไม่ได้วิเคราะห์" end
		if not r.success then return "ล้มเหลว: " .. tostring(r.reason) end
		return string.format("สำเร็จ  จุดทาง=%d  ความยาว=%.0f studs  ตรง=%.0f  ตัวแทน#%d",
			r.count, r.length, r.direct, r.attempt)
	end

	local function refreshUI()
		for m, b in pairs(modeBtns) do
			local sel = Farm.mode == m
			b.BackgroundColor3 = sel and Theme.GreenPrimary or Theme.BgInput
			b.TextColor3 = sel and Theme.BgMain or Theme.TextMain
		end
		local eta = ""
		if Farm.walk then
			local rem = math.max(0, Farm.walk.len / math.max(Farm.walk.speed, 1) - (os.clock() - Farm.walk.t0))
			eta = string.format("\n เส้นทาง %.0f studs | เหลือ ~%d วินาที", Farm.walk.len, math.ceil(rem))
		end
		farmLbl.Text = string.format(" สถานะ: %s | โหมด: %s | ถือของ: %d\n %s%s\n ชุด %d | ออเดอร์ %d | ส่งแล้ว %d\n กดล่าสุด: %s\n ก้าวข้ามจุดติด: %d | %s",
			Farm.state, Farm.mode, Farm.pending, Farm.status, eta, Farm.uniforms, Farm.orders, Farm.deliveries,
			Farm.lastAction, Farm.jumps, Farm.lastJump)
		local d = Detector.info
		if d then
			detLbl.Text = string.format(
				" ชื่อ: %s\n PlaceId: %s   GameId: %s\n ระดับบนของ Workspace: %d (Folder %d / Model %d)\n ลายเซ็นโครงสร้าง: %s\n ฟีเจอร์เดิมของมหานคร: %s\n เปลี่ยนล่าสุด: %s",
				tostring(d.name), tostring(d.placeId), tostring(d.gameId), d.topCount, d.folders, d.models,
				d.signature, d.legacyMatch and "แมพตรงกัน" or "ต่างแมพ (โหมดอ่านอย่างเดียว)", Detector.changeReason)
		end

		local c = Scanner.counts
		if c and c.Total then
			scanSummary.Text = string.format(
				" รวม %d | Part %d | Model %d | Folder %d\n Prompt %d | Click %d | ป้ายข้อความ %d | สแกน %.1f วินาที%s%s",
				c.Total, c.Part, c.Model, c.Folder, c.ProximityPrompt, c.ClickDetector, c.Label,
				Scanner.duration or 0, Scanner.truncated and " | ตัดผลบางส่วน" or "",
				Scanner.scanning and " | กำลังสแกน" or "")
		else
			scanSummary.Text = Scanner.scanning and " กำลังสแกน..." or " ยังไม่ได้สแกน"
		end
		local _, hrp = ctx.getCharacterParts()
		local origin = hrp and { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z } or nil
		local sorted = Scanner.sortedByDistance(origin)
		local lines = {}
		for i = 1, math.min(#sorted, 40) do
			local e = sorted[i].e
			lines[#lines + 1] = string.format("%s %-6s %-7s %s  %.0fst%s",
				(i == PathA.targetIndex) and ">" or " ", e.class == "ProximityPrompt" and "ปุ่มโต้ตอบ" or "คลิก",
				e.kind, cut(e.action ~= "" and e.action or e.name, 22), sorted[i].d,
				e.enabled == false and " (disabled)" or "")
		end
		scanList.Text = (#lines > 0) and table.concat(lines, "\n") or " (ไม่พบจุดโต้ตอบ)"

		local t = currentTarget()
		pathLbl.Text = string.format(" Target: %s\n %s\n Status: %s",
			t and (t.e.name .. " [" .. t.e.kind .. "]") or "-", fmtPath(PathA.last), PathA.status)

		local checks = MA.systemCheck(Scanner.entries, Scanner.labels, Scanner.guiHits)
		local sl = {}
		for _, s in ipairs(checks) do
			sl[#sl + 1] = string.format(" %-26s %s (%d)", s.label, s.status, s.points)
		end
		sl[#sl + 1] = " Remote: โมดูลนี้ไม่เรียกเด็ดขาด"
		sysLbl.Text = table.concat(sl, "\n")

		infoLbl.Text = string.format(
			" หน่วยความจำ: %s\n ไฟล์: %s\n จุดที่ยืนยันแล้ว: %d | สแกนซ้ำ: %d | รีเฟรชอัตโนมัติ: %s",
			Memory.status, Memory.fileName(), Scanner.verifiedCount or 0, MA.rescanCount,
			MA.Config.AutoRescan and "เปิด" or "ปิด")

		local stopped = EM.stoppedList()
		errSummary.Text = (#stopped == 0) and " ทุกโมดูลทำงานปกติ" or (" หยุดทำงาน: " .. table.concat(stopped, "; "))
		errLog.Text = (#EM.log > 0) and table.concat(EM.log, "\n") or " (ไม่มีข้อผิดพลาด)"
	end
	MA.refreshUI = refreshUI

	task.spawn(function()
		while ctx.mainWindow and ctx.mainWindow.Parent do
			if page.Visible then
				local ok, err = pcall(refreshUI)
				if not ok then EM.record("UI", err) end
			end
			task.wait(1)
		end
	end)
	return page
end


-- ============================================================================
-- [v1.28] 13) MAP NATIVE STATUS + MAP NAVIGATION : Registry, MapPlaces, Waypoint, Vehicle
-- รายการระบบที่ "ตรวจพบจริง" จากข้อมูลแมพ (MAP DUMP) สถานะคำนวณจากการมีอยู่ของ Dependency จริงในเกมตอนนี้
-- ปุ่มสั่งงานมีเฉพาะระบบที่สคริปต์เชื่อมต่อจริง ระบบอื่นแสดงสถานะอย่างเดียว ไม่มีปุ่มหลอก
-- ============================================================================
local Registry = { list = {}, byId = {}, selected = nil }
MA.Registry = Registry

local function depCheck(d)
	if d.t == "gui" then
		local pg = player:FindFirstChild("PlayerGui")
		return (pg and pg:FindFirstChild(d.n, true)) and "ok" or "missing"
	end
	if d.t == "station" then
		local root = Workspace
		for part in string.gmatch(d.root, "[^/]+") do root = root and root:FindFirstChild(part) end
		if not root then
			if Workspace.StreamingEnabled then return "unstreamed" end
			return "missing"
		end
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:GetAttribute("Job") == d.job and obj:GetAttribute("StationId") == d.station then
				return "ok"
			end
		end
		if Workspace.StreamingEnabled then return "unstreamed" end
		return "missing"
	end
	local cur = (d.t == "rs") and game:GetService("ReplicatedStorage") or Workspace
	for part in string.gmatch(d.n, "[^/]+") do cur = cur and cur:FindFirstChild(part) end
	if cur then return "ok" end
	-- ห้ามสมมติว่าของที่ยังไม่ Stream ไม่มีอยู่จริง
	if d.t == "ws" and Workspace.StreamingEnabled then return "unstreamed" end
	return "missing"
end

local function G(n) return { t = "gui", n = n } end
local function R(n) return { t = "rs", n = n } end
local function W(n) return { t = "ws", n = n } end
local function A(root, job, station) return { t = "station", root = root, job = job, station = station, n = root .. " [Job=" .. job .. ", StationId=" .. station .. "]" } end

local SYS = {
	{ id = "rider", name = "ไรเดอร์ส่งอาหาร (QuickRider)", cat = "อาชีพ", act = "rider",
		deps = { G("Phone"), R("GameRemotes/Delivery"), R("DeliveryShared"), W("Map/JobLockers/Locker_Delivery") },
		running = function() return Farm.on end },
	{ id = "mechanic", name = "ช่างซ่อมรถ (MAP NATIVE)", cat = "อาชีพ",
		note = "ใช้จุดจริงใน Workspace/Map: LockerPrompt เริ่มงาน, WorkPrompt ที่ Board และ Bay3; การทำงานให้กด ProximityPrompt ของเกมเอง",
		deps = { W("Map/JobLockers/Locker_Mechanic/Cabinet/LockerPrompt"), A("Map/Landmarks/RepairShop/Workshop", "Mechanic", "Board"), A("Map/Landmarks/RepairShop/Workshop", "Mechanic", "Bay3") } },
	{ id = "builder", name = "ช่างก่อสร้าง (MAP NATIVE)", cat = "อาชีพ",
		note = "ตรวจ WorkPrompt ที่ Board, Pile, Mixer, Bricks และ Paint รวมถึง LockerPrompt; ใช้ปุ่ม E/ProximityPrompt ปกติของเกม",
		deps = { W("Map/JobLockers/Locker_Builder/Cabinet/LockerPrompt"), A("Map/Landmarks/Construction/BuilderYard", "Builder", "Board"), A("Map/Landmarks/Construction/BuilderYard", "Builder", "Pile"), A("Map/Landmarks/Construction/BuilderYard", "Builder", "Mixer"), A("Map/Landmarks/Construction/BuilderYard", "Builder", "Bricks"), A("Map/Landmarks/Construction/BuilderYard", "Builder", "Paint") } },
	{ id = "courier", name = "พนักงานส่งพัสดุ (Courier)", cat = "อาชีพ",
		note = "ปักหมุดและเดินตาม Pathfinding ไปยัง Locker_Delivery ที่ rider hub, AUTOWORKS yard ได้; จุดรับ/ส่งพัสดุหลังเริ่มงานยังไม่ยืนยัน",
		deps = { W("Map/JobLockers/Locker_Delivery/Cabinet/LockerPrompt") } },
	{ id = "carwash", name = "พนักงานล้างรถ (MAP NATIVE)", cat = "อาชีพ",
		note = "ตรวจ LockerPrompt เริ่มงาน และ ProximityPrompt ตู้ MachineG/H สาขา 4S กับ MachineE/F สาขา 4N; กดใช้งานผ่าน Prompt ของเกมเอง",
		deps = { W("Map/JobLockers/Locker_CarWash3/Cabinet/LockerPrompt"), W("Map/CarWashLot4S/Machines/MachineG/CoinMachine/Cabinet/PromptAt/CarWashPrompt"), W("Map/CarWashLot4S/Machines/MachineH/CoinMachine/Cabinet/PromptAt/CarWashPrompt"), W("Map/CarWashLot4N/Machines/MachineE/CoinMachine/Cabinet/PromptAt/CarWashPrompt"), W("Map/CarWashLot4N/Machines/MachineF/CoinMachine/Cabinet/PromptAt/CarWashPrompt") } },
	{ id = "cargo", name = "งานขนส่ง (Cargo)", cat = "อาชีพ",
		deps = { G("CargoMenu"), R("GameRemotes/PickupCargo"), W("VehicleCargo") } },
	{ id = "garage", name = "โรงรถ / เรียกรถ (MY VEHICLES)", cat = "ระบบรถ", act = "garage",
		deps = { G("GarageWindow"), G("GameHud"), R("GameRemotes/Garage"), W("SpawnedVehicles") } },
	{ id = "care", name = "ดูแลรถ / เติมน้ำมัน", cat = "ระบบรถ",
		deps = { G("VehicleCare"), R("GameRemotes/Care"), R("CareShared") } },
	{ id = "ecu", name = "จูน ECU", cat = "จูนรถ",
		deps = { G("TuneShop"), R("GameRemotes/Ecu"), R("EcuShared"), W("Map/TuneShops/MahanakhonTuning") } },
	{ id = "tuneup", name = "ร้านจูน / อัปเกรด", cat = "จูนรถ",
		deps = { G("TuneShop"), R("GameRemotes/TuneShop"), R("GameRemotes/TuneUpgrade") } },
	{ id = "piston", name = "ลูกสูบ (PistonShop)", cat = "จูนรถ",
		deps = { G("PistonShop"), R("GameRemotes/Piston"), R("PistonShared") } },
	{ id = "dyno", name = "Dyno / RPM สด", cat = "จูนรถ",
		deps = { W("DynoTunerSet"), R("LiveRpm"), R("DynoScreenKit") } },
	{ id = "custom", name = "แต่งรถ (สติกเกอร์ / หมวก / อะไหล่)", cat = "แต่งรถ",
		deps = { G("StickerEditor"), G("HelmetRoom"), R("GameRemotes/Sticker"), R("GameRemotes/Helmet"), R("PartsShared") } },
	{ id = "dashcam", name = "กล้องหน้ารถ (Dashcam)", cat = "แต่งรถ",
		deps = { G("DashcamShop"), R("GameRemotes/Dashcam"), R("DashcamShared") } },
	{ id = "race", name = "แข่งรถ / Duel", cat = "กิจกรรม", note = "ตรวจ GUI/Remote/ModuleScript เท่านั้น ไม่เรียก Remote และไม่ยืนยันว่าร่วมแข่งได้",
		deps = { G("DuelRace"), R("GameRemotes/Race"), R("GameRemotes/Duel"), R("RaceShared") } },
	{ id = "quest", name = "ภารกิจ (Quest)", cat = "กิจกรรม", note = "ตรวจ GUI/Remote/ModuleScript เท่านั้น ไม่เรียก Remote และไม่ยืนยันว่ารับหรือส่งภารกิจได้",
		deps = { G("Phone"), R("GameRemotes/Quest"), R("QuestShared") } },
	{ id = "clan", name = "แคลน", cat = "สังคม",
		deps = { G("ClanWindow"), R("GameRemotes/Clan"), R("ClanShared") } },
	{ id = "reward", name = "รางวัลเข้ากลุ่ม", cat = "สังคม", note = "ไม่เชื่อมต่อการรับรางวัลอัตโนมัติ (กันธุรกรรมที่ไม่ได้รับอนุญาต)",
		deps = { G("GroupReward"), R("GameRemotes/GroupReward"), R("GroupRewardShared") } },
	{ id = "shop", name = "ร้านค้า / ไอเทม", cat = "ร้านค้า", note = "ไม่เชื่อมต่อการซื้อ (ต้องซื้อผ่านหน้าร้านของเกมเอง)",
		deps = { G("StoreWindow"), R("GameRemotes/Store"), R("GameRemotes/Shop"), R("ShopShared") } },
	{ id = "map", name = "แผนที่ / นำทาง", cat = "การเดินทาง",
		deps = { G("Minimap"), R("MapPlaces"), R("MapConfig"), R("RoadGraph") } },
	{ id = "warp", name = "เวลา / สภาพอากาศ / วาร์ป", cat = "การเดินทาง",
		deps = { G("WarpWindow") } },
	{ id = "security", name = "ระบบตรวจสอบของเกม (FarmCheck / UiGuard / NetSeal)", cat = "ความปลอดภัย",
		note = "ตรวจพบเท่านั้น ไม่เชื่อมต่อ และไม่พยายามข้ามระบบนี้",
		deps = { G("FarmCheck"), R("GameRemotes/FarmCheck"), R("UiGuardShared"), R("NetSeal") } },
	{ id = "mapadaptive", name = "MAP ADAPTIVE (ของสคริปต์)", cat = "สคริปต์", act = "ma", deps = {},
		running = function() return Scanner.scanning end,
		disabled = function() return MA.Config.AutoRescan == false end },
}
for _, s in ipairs(SYS) do Registry.list[#Registry.list + 1] = s Registry.byId[s.id] = s end

local function evaluate(s)
	local missing, unstreamed, lines = {}, {}, {}
	for _, d in ipairs(s.deps) do
		local st = depCheck(d)
		local tag = (d.t == "gui" and "GUI " or d.t == "rs" and "ReplicatedStorage/" or "Workspace/") .. d.n
		if st == "ok" then lines[#lines + 1] = "  [FOUND] " .. tag
		elseif st == "unstreamed" then unstreamed[#unstreamed + 1] = d.n lines[#lines + 1] = "  [NOT VERIFIED] " .. tag .. " (ยังไม่ Stream เข้ามา)"
		else missing[#missing + 1] = d.n lines[#lines + 1] = "  [NOT FOUND] " .. tag end
	end
	local status, why
	if s.err then status, why = "ERROR", s.err
	elseif #missing > 0 then status, why = "UNSUPPORTED", "ไม่พบ Dependency: " .. table.concat(missing, ", ")
	elseif #unstreamed > 0 then status, why = "NOT VERIFIED", "ยังไม่ได้ Stream เข้ามา: " .. table.concat(unstreamed, ", ")
	elseif s.running and s.running() then status, why = "RUNNING", "กำลังทำงาน"
	elseif s.disabled and s.disabled() then status, why = "DISABLED", "ปิดใช้งานอยู่"
	elseif s.act then status, why = "READY", "พร้อมใช้งาน (มีปุ่มสั่งงานที่เชื่อมจริง)"
	else status, why = "NOT VERIFIED", "พบจุดในแมพแล้ว; ให้ใช้ ProximityPrompt/GUI ปกติของเกมเพื่อเริ่มและทำงาน (ตัวช่วยนี้ไม่สั่งงานแทนเกม)" end
	s.status, s.why, s.depLines = status, why, lines
end

local function statusColor(st)
	if st == "RUNNING" then return Theme.GreenBright end
	if st == "READY" then return Theme.GreenPrimary end
	if st == "ERROR" then return Theme.Danger end
	if st == "NOT VERIFIED" then return Color3.fromRGB(255, 205, 90) end
	return Theme.TextMuted
end

local function buildStatusUI()
	local page = ctx.createPage("MapSystemStatus", "7. MAP NATIVE STATUS + COURIER WAYPOINT")
	for _, b in pairs(ctx.navButtons) do b.btn.Size = UDim2.new(1, 0, 0, 36) end

	local cSum = ctx.makeCard(page, "MAP NATIVE STATUS", 70, 0)
	local sumLbl = Instance.new("TextLabel")
	sumLbl.Size = UDim2.new(1, -20, 0, 34)
	sumLbl.Position = UDim2.fromOffset(10, 30)
	sumLbl.BackgroundTransparency = 1
	sumLbl.Font = Enum.Font.Code
	sumLbl.TextSize = 11
	sumLbl.TextWrapped = true
	sumLbl.TextXAlignment = Enum.TextXAlignment.Left
	sumLbl.TextYAlignment = Enum.TextYAlignment.Top
	sumLbl.TextColor3 = Theme.TextMain
	sumLbl.Parent = cSum

	local cList = ctx.makeCard(page, "ระบบจริงในแมพ (กดเพื่อดูจุดทำงาน)", 250, 1)
	local listSc = Instance.new("ScrollingFrame")
	listSc.Size = UDim2.new(1, -20, 0, 208)
	listSc.Position = UDim2.fromOffset(10, 32)
	listSc.BackgroundColor3 = Theme.BgInput
	listSc.BorderSizePixel = 0
	listSc.ScrollBarThickness = 4
	listSc.ScrollBarImageColor3 = Theme.GreenPrimary
	listSc.CanvasSize = UDim2.new()
	listSc.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listSc.Parent = cList
	ctx.addCorner(listSc, 7)
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 3)
	ll.Parent = listSc

	local cDet = ctx.makeCard(page, "รายละเอียดจุดทำงานจริง", 262, 2)
	local detLbl = Instance.new("TextLabel")
	detLbl.Size = UDim2.new(1, -20, 0, 176)
	detLbl.Position = UDim2.fromOffset(10, 32)
	detLbl.BackgroundColor3 = Theme.BgInput
	detLbl.BorderSizePixel = 0
	detLbl.Font = Enum.Font.Code
	detLbl.TextSize = 11
	detLbl.TextWrapped = true
	detLbl.TextXAlignment = Enum.TextXAlignment.Left
	detLbl.TextYAlignment = Enum.TextYAlignment.Top
	detLbl.TextColor3 = Theme.TextMain
	detLbl.Text = "เลือกระบบจากรายการด้านบน"
	detLbl.Parent = cDet
	ctx.addCorner(detLbl, 7)

	local rows = {}
	local function actionLabel(s)
		if s.id == "courier" then return PathA.walking and "STOP WALK" or "WALK TO COURIER" end
		if s.act == "rider" then return Farm.on and "STOP AUTO RIDER" or "START AUTO RIDER" end
		if s.act == "garage" then return "SPAWN VEHICLE" end
		if s.act == "ma" then return "REFRESH MAP" end
		return nil
	end

	local actBtn
	local pinBtn
	local function refreshDetail()
		local s = Registry.selected and Registry.byId[Registry.selected]
		if not s then return end
		local t = {
			" " .. s.name, " หมวด: " .. s.cat .. "   สถานะ: " .. tostring(s.status), " " .. tostring(s.why), "",
			" Dependency ที่ตรวจ:",
		}
		for _, l in ipairs(s.depLines or {}) do t[#t + 1] = l end
		if #(s.depLines or {}) == 0 then t[#t + 1] = "  (ไม่มี)" end
		if s.note then t[#t + 1] = "" t[#t + 1] = " หมายเหตุ: " .. s.note end
		if s.last then t[#t + 1] = "" t[#t + 1] = " ผลล่าสุด: " .. s.last end
		detLbl.Text = table.concat(t, "\n")
		local al = actionLabel(s)
		actBtn.Visible = al ~= nil
		if al then actBtn.Text = al end
		if pinBtn then
			pinBtn.Text = (s.id == "courier") and "PIN COURIER" or "RE-CHECK"
		end
	end

	local function refreshAll()
		local cnt = {}
		for _, s in ipairs(Registry.list) do
			evaluate(s)
			cnt[s.status] = (cnt[s.status] or 0) + 1
			local r = rows[s.id]
			if r then
				r.Text = "  [" .. s.status .. "]  " .. s.name
				r.TextColor3 = statusColor(s.status)
			end
		end
		local parts = {}
		for _, k in ipairs({ "RUNNING", "READY", "NOT VERIFIED", "DISABLED", "UNSUPPORTED", "ERROR" }) do
			if cnt[k] then parts[#parts + 1] = k .. " " .. cnt[k] end
		end
		sumLbl.Text = " ระบบที่ตรวจพบ " .. #Registry.list .. " รายการ\n " .. table.concat(parts, " | ")
		refreshDetail()
	end

	for i, s in ipairs(Registry.list) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -6, 0, 28)
		b.BackgroundColor3 = Theme.BgCard
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 11
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextTruncate = Enum.TextTruncate.AtEnd
		b.Text = ""
		b.LayoutOrder = i
		b.Parent = listSc
		ctx.addCorner(b, 6)
		rows[s.id] = b
		b.MouseButton1Click:Connect(function()
			Registry.selected = s.id
			refreshDetail()
		end)
	end

	-- Courier waypoint: ใช้ตำแหน่ง LockerPrompt ที่พบจริงในแมพเท่านั้น
	local courierMarker, courierTargetPart
	local function findCourierTarget()
		local node = Workspace
		for _, part in ipairs({"Map", "JobLockers", "Locker_Delivery", "Cabinet", "LockerPrompt"}) do
			node = node and node:FindFirstChild(part)
		end
		if not node or not node:IsA("ProximityPrompt") then return nil, "ยังไม่พบ LockerPrompt (อาจยังไม่ Stream เข้ามา)" end
		local parent = node.Parent
		while parent and parent ~= Workspace do
			if parent:IsA("BasePart") then return parent, nil end
			local found = parent:FindFirstChildWhichIsA("BasePart", true)
			if found then return found, nil end
			parent = parent.Parent
		end
		return nil, "พบ Prompt แต่หา Part สำหรับปักหมุดไม่เจอ"
	end
	local function pinCourier()
		local part, why = findCourierTarget()
		if not part then Registry.byId.courier.last = why return false end
		courierTargetPart = part
		if courierMarker then pcall(function() courierMarker:Destroy() end) courierMarker = nil end
		local marker = Instance.new("BillboardGui")
		marker.Name = "BallKun_CourierWaypoint"
		marker.Adornee = part
		marker.Size = UDim2.fromOffset(170, 42)
		marker.StudsOffset = Vector3.new(0, 4, 0)
		marker.AlwaysOnTop = true
		marker.Parent = screenGui.Parent or player:WaitForChild("PlayerGui")
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Theme.BgCard
		label.BackgroundTransparency = 0.12
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = Theme.GreenBright
		label.Text = "📍 COURIER / รับงานส่งพัสดุ"
		label.Parent = marker
		ctx.addCorner(label, 7)
		courierMarker = marker
		Registry.byId.courier.last = "ปักหมุดแล้ว: Locker_Delivery / rider hub, AUTOWORKS yard"
		return true
	end

	-- ปุ่มสั่งงาน (เฉพาะระบบที่เชื่อมจริง) + ปุ่มปักหมุด
	actBtn = ctx.makeActionButton(cDet, "ACTION", 0, 0.6, 216, 34, function()
		local s = Registry.selected and Registry.byId[Registry.selected]
		if not s then return end
		task.spawn(function()
			s.err = nil
			local ok, res
			if s.id == "courier" then
				if PathA.walking then
					PathA.stop("หยุดเดินตามหมุด Courier")
					s.last = "หยุดเดินแล้ว " .. stamp()
					ok = true
				else
					if not courierTargetPart or not courierTargetPart.Parent then
						local pinned = pinCourier()
						if not pinned then s.err = s.last end
					end
					if courierTargetPart and courierTargetPart.Parent then
						local pos = courierTargetPart.Position + Vector3.new(0, 2, 0)
						local result = PathA.analyze({ x = pos.X, y = pos.Y, z = pos.Z })
						if result.success then
							ok = PathA.walk(result)
							s.last = ok and "เดินถึงหมุด Courier แล้ว " .. stamp() or ("เดินไม่สำเร็จ: " .. tostring(PathA.status))
						else
							ok = false s.last = "คำนวณทางไม่สำเร็จ: " .. tostring(result.reason)
						end
					end
				end
			elseif s.act == "rider" then
				if Farm.on then
					Farm.stop("user")
					s.last = "หยุด AUTO RIDER แล้ว " .. stamp()
					ok = true
				else
					ok = Farm.start()
					s.last = ok and ("เริ่ม AUTO RIDER แล้ว " .. stamp()) or ("เริ่มไม่ได้: " .. tostring(Farm.status))
					if not ok then s.err = tostring(Farm.status) end
				end
			elseif s.act == "garage" then
				local okG, r = pcall(spawnVehicle)
				ok = okG and r == true
				s.last = ok and ("รถอยู่ในแมพแล้ว " .. stamp()) or ("เรียกรถไม่สำเร็จ " .. stamp() .. (okG and "" or (": " .. tostring(r))))
				if not ok then s.err = s.last end
			elseif s.act == "ma" then
				local okR, r = MA.refreshMap("MAP NATIVE STATUS")
				ok = okR
				s.last = okR and ("สแกนแล้ว " .. tostring(r) .. " จุด " .. stamp()) or ("สแกนไม่สำเร็จ: " .. tostring(r))
				if not okR then s.err = s.last end
			end
			refreshAll()
		end)
	end)
	pinBtn = ctx.makeActionButton(cDet, "RE-CHECK", 0.6, 0.4, 216, 34, function()
		local s = Registry.selected and Registry.byId[Registry.selected]
		if s and s.id == "courier" then
			local okPin = pinCourier()
			if not okPin then s.err = s.last end
		else
			for _, item in ipairs(Registry.list) do item.err = nil end
		end
		refreshAll()
	end)
	actBtn.Visible = false

	Registry.selected = Registry.selected or "rider"
	refreshAll()
	task.spawn(function()
		while ctx.mainWindow and ctx.mainWindow.Parent do
			if page.Visible then
				local ok, err = pcall(refreshAll)
				if not ok then EM.record("MapSystemStatus", err) end
			end
			task.wait(2)
		end
	end)
	return page
end

MA.buildUI = buildUI
-- [v1.28] แถบสถานะสั้น (แสดงเมื่อมีระบบทำงาน/ติดขัด แม้หน้าต่างหลักถูกพับ) ไม่รับการกด ไม่ยิง Remote
local function buildMiniStatus()
	local bar = Instance.new("TextLabel")
	bar.Name = "MiniStatus"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 6)
	bar.Size = UDim2.fromOffset(300, 22)
	bar.BackgroundColor3 = Theme.BgCard
	bar.BackgroundTransparency = 0.15
	bar.BorderSizePixel = 0
	bar.Font = Enum.Font.GothamMedium
	bar.TextSize = 11
	bar.TextColor3 = Theme.TextMain
	bar.TextTruncate = Enum.TextTruncate.AtEnd
	bar.Active = false
	bar.Visible = false
	bar.ZIndex = 50
	bar.Parent = screenGui
	ctx.addCorner(bar, 6)
	ctx.addStroke(bar, Theme.GreenPrimary, 1, 0.5)
	task.spawn(function()
		while bar.Parent do
			local txt, warn
			if Farm.on then
				txt = "ไรเดอร์: " .. tostring(Farm.status)
				warn = tostring(Farm.status):find("ไม่เคลื่อนที่", 1, true) or tostring(Farm.status):find("blocked", 1, true)
			elseif PathA.walking then
				txt = "เดิน: " .. tostring(PathA.status)
			else
				local stopped = EM.stoppedList()
				if #stopped > 0 then txt = "หยุดทำงาน: " .. table.concat(stopped, ", ") warn = true end
			end
			bar.Visible = txt ~= nil
			if txt then
				bar.Text = " " .. txt
				bar.TextColor3 = warn and Color3.fromRGB(255, 205, 90) or Theme.TextMain
			end
			task.wait(1)
		end
	end)
end
local okMS, errMS = EM.guard("MiniStatus", buildMiniStatus)
if not okMS then EM.record("MiniStatus", errMS) end

local okUI, errUI = EM.guard("UI", buildUI)
if not okUI then EM.record("UI", errUI) end
local okSS, errSS = EM.guard("MapSystemStatus", buildStatusUI)
if not okSS then EM.record("MapSystemStatus", errSS) end

-- ============================================================================
-- [v1.28] MAP NAVIGATION : อ่านสถานที่จาก ReplicatedStorage/MapPlaces จริง
-- ใช้ PathfindingService สำหรับเส้นทางนำทาง (ไม่อ้างว่าเป็น RoadGraph route:
-- dump ของแมพแสดง RoadGraph.edges แต่ไม่พบพิกัด nodes)
-- เรียกรถผ่าน Garage GUI ปกติ และควบคุม VehicleSeat เฉพาะเมื่อผู้เล่นนั่งเอง
-- ============================================================================
local function buildMapNavigationUI()
	local page = ctx.createPage("MapNavigation", "8. MAP NAVIGATION / VEHICLE")
	local mapNav = { places = {}, selected = nil, target = nil, marker = nil,
		routeParts = {}, driveToken = 0, driving = false, status = "ยังไม่ได้เลือกจุดหมาย" }
	MA.MapNavigation = mapNav

	local function clearRoute()
		for _, p in ipairs(mapNav.routeParts) do pcall(function() p:Destroy() end) end
		table.clear(mapNav.routeParts)
	end
	local function clearMarker()
		if mapNav.marker then pcall(function() mapNav.marker:Destroy() end) end
		mapNav.marker = nil
	end
	local statusLbl
	local function setStatus(t)
		mapNav.status = tostring(t)
		if statusLbl then statusLbl.Text = "สถานะ: " .. mapNav.status end
	end

	local mapModule = ReplicatedStorage:FindFirstChild("MapPlaces")
	local mapData
	if mapModule and mapModule:IsA("ModuleScript") then
		local ok, result = pcall(require, mapModule)
		if ok and type(result) == "table" then mapData = result end
	end
	if type(mapData) == "table" then
		for k, v in pairs(mapData) do
			if type(v) == "table" and type(v.x) == "number" and type(v.z) == "number" then
				mapNav.places[#mapNav.places + 1] = {
					key = tostring(k), name = tostring(v.th or v.name or ("Place " .. tostring(k))),
					icon = tostring(v.icon or "📍"), x = v.x, z = v.z, go = tostring(v.go or "")
				}
			end
		end
	end
	table.sort(mapNav.places, function(a,b) return a.name < b.name end)

	local top = ctx.makeCard(page, "MAPPLACES • จุดหมายจากแมพจริง", 84, 0)
	statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(1, -18, 0, 38)
	statusLbl.Position = UDim2.fromOffset(9, 34)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.Code
	statusLbl.TextSize = 11
	statusLbl.TextWrapped = true
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.TextYAlignment = Enum.TextYAlignment.Top
	statusLbl.TextColor3 = Theme.TextMain
	statusLbl.Text = "สถานะ: โหลดจุดหมาย..."
	statusLbl.Parent = top

	local searchCard = ctx.makeCard(page, "ค้นหาสถานที่ / เลือกจุดหมาย", 286, 1)
	local search = Instance.new("TextBox")
	search.Size = UDim2.new(1, -18, 0, 30)
	search.Position = UDim2.fromOffset(9, 32)
	search.BackgroundColor3 = Theme.BgInput
	search.BorderSizePixel = 0
	search.Font = Enum.Font.Gotham
	search.TextSize = 12
	search.TextColor3 = Theme.TextMain
	search.PlaceholderColor3 = Theme.TextMuted
	search.PlaceholderText = "พิมพ์ชื่อสถานที่..."
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Parent = searchCard
	ctx.addCorner(search, 6)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -18, 0, 206)
	list.Position = UDim2.fromOffset(9, 68)
	list.BackgroundColor3 = Theme.BgInput
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = searchCard
	ctx.addCorner(list, 6)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.Parent = list

	local actionCard = ctx.makeCard(page, "นำทาง / รถยนต์ / มอเตอร์ไซค์", 238, 2)
	local detail = Instance.new("TextLabel")
	detail.Size = UDim2.new(1, -18, 0, 44)
	detail.Position = UDim2.fromOffset(9, 30)
	detail.BackgroundColor3 = Theme.BgInput
	detail.BorderSizePixel = 0
	detail.Font = Enum.Font.Code
	detail.TextSize = 11
	detail.TextWrapped = true
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Center
	detail.TextColor3 = Theme.TextMain
	detail.Text = "เลือกสถานที่จากรายการด้านบน"
	detail.Parent = actionCard
	ctx.addCorner(detail, 6)

	local function targetPosition(x, z)
		local _, hrp = ctx.getCharacterParts()
		if not hrp then return nil end
		local origin = Vector3.new(x, math.max(hrp.Position.Y + 250, 250), z)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		local hit = Workspace:Raycast(origin, Vector3.new(0, -800, 0), params)
		return Vector3.new(x, hit and (hit.Position.Y + 3) or hrp.Position.Y, z)
	end

	local function drawMarker(pos, titleText)
		clearMarker()
		local p = Instance.new("Part")
		p.Name = "BallKun_MapWaypoint"
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(0, 229, 255) -- [v1.33] สีฟ้า (Cyan)
		p.Size = Vector3.new(0.25, 5, 5)
		p.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = Workspace
		mapNav.marker = p
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(220, 44)
		bb.StudsOffset = Vector3.new(0, 5, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = p
		bb.Parent = p
		local tx = Instance.new("TextLabel")
		tx.Size = UDim2.fromScale(1,1)
		tx.BackgroundColor3 = Theme.BgCard
		tx.BackgroundTransparency = 0.1
		tx.BorderSizePixel = 0
		tx.Font = Enum.Font.GothamBold
		tx.TextSize = 12
		tx.TextColor3 = Color3.fromRGB(0, 229, 255)
		tx.Text = "📍 " .. tostring(titleText):sub(1, 42)
		tx.Parent = bb
		ctx.addCorner(tx, 7)
	end

	local function buildRoute(pos)
		local result = PathA.analyze({x=pos.X, y=pos.Y, z=pos.Z})
		if not result.success then return nil, result.reason end
		clearRoute()
		local prev
		for _, wp in ipairs(result.waypoints) do
			if prev then
				local delta = wp.Position - prev
				local len = delta.Magnitude
				if len > 0.5 then
					local seg = Instance.new("Part")
					seg.Name = "BallKun_RouteSegment"
					seg.Anchored = true
					seg.CanCollide = false
					seg.CanTouch = false
					seg.CanQuery = false
					seg.Material = Enum.Material.Neon
					seg.Color = Color3.fromRGB(0, 229, 255) -- [v1.33] เส้นนำทางสีฟ้า (Cyan)
					seg.Transparency = 0.18
					seg.Size = Vector3.new(0.35, 0.35, len)
					seg.CFrame = CFrame.lookAt((prev + wp.Position)/2, wp.Position)
					seg.Parent = Workspace
					mapNav.routeParts[#mapNav.routeParts + 1] = seg
				end
			end
			prev = wp.Position
		end
		return result
	end

	local function pinSelected()
		if not mapNav.target then setStatus("ยังไม่ได้เลือกสถานที่") return false end
		local pos = targetPosition(mapNav.target.x, mapNav.target.z)
		if not pos then setStatus("ไม่พบตัวละคร") return false end
		local result, why = buildRoute(pos)
		if not result then
			-- [v1.33] หมุดจากระบบอื่น: ถึงคำนวณเส้นไม่ได้ (เช่น ไกลเกิน 3000 stud) ก็ยังปักหมุดให้เห็นปลายทาง
			if mapNav.target.source then drawMarker(pos, mapNav.target.icon .. " " .. mapNav.target.name) end
			setStatus("คำนวณเส้นทางไม่ได้: " .. tostring(why))
			return false
		end
		drawMarker(pos, mapNav.target.icon .. " " .. mapNav.target.name)
		mapNav.route = result
		-- [v1.33] หมุดที่ผู้ใช้ปักเองก็อยู่ในหมุดกลางด้วย (ไม่แจ้งผู้ฟัง เพื่อไม่ให้วนซ้ำ)
		if not mapNav.target.source then
			BKPin.cur = { source = "user", x = mapNav.target.x, z = mapNav.target.z, label = mapNav.target.name, at = os.clock() }
		end
		setStatus("ปักหมุดแล้ว • " .. mapNav.target.name .. " • " .. result.count .. " จุดนำทาง")
		return true
	end

	-- [v1.34 BEGIN pinNavDecision]
	local PIN_NAV_MODES = { "off", "route", "walk", "drive", "auto" }
	local PIN_NAV_LABEL = { off = "ปิด", route = "เส้นอย่างเดียว", walk = "เดิน", drive = "ขับ", auto = "อัตโนมัติ" }
	-- ตัดสินว่าหมุดที่เข้ามาควร "เริ่มนำทาง" หรือไม่ (ฟังก์ชันล้วน ทดสอบได้)
	-- seat: "driver" | "other" | "free"   คืนค่า action ("none"|"walk"|"drive"), เหตุผลที่ไม่เริ่ม
	local function decidePinNav(mode, source, seat, busy)
		if mode ~= "walk" and mode ~= "drive" and mode ~= "auto" then return "none", "" end
		source = tostring(source or "")
		if source == "user" then return "none", "" end
		if BKPin.selfNav[source] then return "none", "ระบบ " .. source .. " นำทางเองอยู่แล้ว" end
		if busy then return "none", "กำลังเดิน/ขับ/ทำงานอัตโนมัติอยู่" end
		if mode == "walk" then
			if seat == "free" then return "walk", "" end
			return "none", "อยู่บนรถ: โหมดเดินใช้ไม่ได้"
		elseif mode == "drive" then
			if seat == "driver" then return "drive", "" end
			return "none", "ต้องนั่งตำแหน่งคนขับก่อน"
		end
		if seat == "driver" then return "drive", "" end
		if seat == "free" then return "walk", "" end
		return "none", "นั่งอยู่บนรถแต่ไม่ใช่คนขับ"
	end
	-- [v1.34 END pinNavDecision]

	-- [v1.34 BEGIN navVerify]
	-- สถานะ TEST -> ใช้งานจริง: เลื่อนเองหลังขับตามหมุดถึงจุดหมายจริง NAV_VERIFY_RUNS รอบติดต่อกันในเกม
	-- (ถ้ารถติดจนหยุดฉุกเฉิน จะนับใหม่จาก 0) ค่าถูกเก็บในไฟล์ตั้งค่า
	local NAV_VERIFY_RUNS = 2
	local NAV_ARRIVE_STUDS = 25
	local function navLabel(runs)
		local n = tonumber(runs) or 0
		if n >= NAV_VERIFY_RUNS then return "AUTO DRIVE" end
		return string.format("DRIVE TEST %d/%d", n, NAV_VERIFY_RUNS)
	end
	local function navRecord(runs, event)
		local n = tonumber(runs) or 0
		if event == "arrived" then return math.min(n + 1, NAV_VERIFY_RUNS) end
		if event == "stuck" then return 0 end
		return n
	end
	-- [v1.34 END navVerify]

	local autoDriveBtn
	local function recordNav(event)
		State.NavVerifiedRuns = navRecord(State.NavVerifiedRuns, event)
		if autoDriveBtn then autoDriveBtn.Text = navLabel(State.NavVerifiedRuns) end
		if State.AutoSaveConfig then pcall(saveConfigToFile) end
	end
	if PIN_NAV_LABEL[State.PinNavMode] == nil then State.PinNavMode = "auto" end

	local function stopDrive(reason)
		mapNav.driveToken = mapNav.driveToken + 1
		mapNav.driving = false
		local _, _, seat = getPlayerVehicle()
		if seat and seat:IsA("VehicleSeat") then
			pcall(function() seat.Throttle = 0; seat.Steer = 0 end)
		end
		setStatus(reason or "หยุดระบบขับตามหมุดแล้ว")
	end

	local function startDrive()
		if not mapNav.target then setStatus("เลือกจุดหมายก่อน") return false end
		local char, hrp, hum = ctx.getCharacterParts()
		if not (char and hrp and hum) then setStatus("ไม่พบตัวละคร") return false end
		local vehicle, root, seat = getPlayerVehicle()
		if not (vehicle and seat and seat:IsA("VehicleSeat") and seat.Occupant == hum) then
			setStatus("ต้องเรียกรถจาก Garage และขึ้นนั่งตำแหน่งคนขับก่อน")
			return false
		end
		local pos = targetPosition(mapNav.target.x, mapNav.target.z)
		if not pos then setStatus("อ่านพิกัดจุดหมายไม่ได้") return false end
		local result, why = buildRoute(pos)
		if not result then setStatus("สร้างเส้นทางไม่ได้: " .. tostring(why)) return false end
		drawMarker(pos, mapNav.target.icon .. " " .. mapNav.target.name)
		mapNav.route = result
		mapNav.driveToken = mapNav.driveToken + 1
		local token = mapNav.driveToken
		mapNav.driving = true
		if (tonumber(State.NavVerifiedRuns) or 0) >= NAV_VERIFY_RUNS then
			setStatus("ขับตาม Waypoints • เฝ้าดูรถตลอดเวลา")
		else
			setStatus("ทดลองขับตาม Waypoints (" .. navLabel(State.NavVerifiedRuns) .. ") • โปรดเฝ้าดูรถตลอดเวลา")
		end
		task.spawn(function()
			local wps = result.waypoints
			local idx = 2
			local lastPos = root.Position
			local lastMove = os.clock()
			while mapNav.driving and mapNav.driveToken == token and idx <= #wps do
				local c, r, s = getPlayerVehicle()
				if not (c == vehicle and r and s == seat and s.Occupant == hum) then
					stopDrive("หยุด: หลุดจากรถหรือเปลี่ยนรถ")
					break
				end
				local delta = wps[idx].Position - r.Position
				local flat = Vector3.new(delta.X, 0, delta.Z)
				local distance = flat.Magnitude
				if distance <= 11 then
					idx = idx + 1
				else
					local dir = flat.Unit
					local look = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
					if look.Magnitude < 0.05 then look = Vector3.new(0,0,-1) end
					look = look.Unit
					local cross = look:Cross(dir).Y
					local dot = math.clamp(look:Dot(dir), -1, 1)
					local angle = math.deg(math.acos(dot))
					local steer = math.clamp(-cross * 2.2, -1, 1)
					local throttle = (angle > 105) and -0.25 or (distance < 18 and 0.25 or 0.65)
					pcall(function()
						s.Steer = steer
						s.Throttle = throttle
					end)
				end
				if (r.Position - lastPos).Magnitude > 2 then
					lastPos, lastMove = r.Position, os.clock()
				elseif os.clock() - lastMove > 7 then
					recordNav("stuck")
					stopDrive("หยุดฉุกเฉิน: รถไม่เคลื่อนที่ / ติดสิ่งกีดขวาง")
					break
				end
				PathA.status = "รถกำลังไป " .. math.min(idx, #wps) .. "/" .. #wps
				task.wait(0.12)
			end
			if mapNav.driving and mapNav.driveToken == token then
				-- [v1.34] นับว่าผ่านก็ต่อเมื่อรถอยู่ใกล้จุดหมายจริง (ไม่ใช่แค่ไล่ Waypoint ครบ)
				local _, rEnd = getPlayerVehicle()
				local arrived = rEnd and (Vector3.new(rEnd.Position.X, 0, rEnd.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude <= NAV_ARRIVE_STUDS
				if arrived then
					recordNav("arrived")
					stopDrive("ถึงจุดหมายตาม Waypoints แล้ว • " .. navLabel(State.NavVerifiedRuns))
				else
					stopDrive("จบเส้นทางแต่ยังห่างจากจุดหมาย • ไม่นับเป็นรอบที่ผ่านการทดสอบ")
				end
			end
		end)
		return true
	end

	local function addButton(text, x, y, w, callback)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(w, 30)
		b.Position = UDim2.fromOffset(x, y)
		b.BackgroundColor3 = Theme.BgInput
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.TextColor3 = Theme.TextMain
		b.Text = text
		b.Parent = actionCard
		ctx.addCorner(b, 6)
		b.MouseButton1Click:Connect(callback)
		return b
	end
	addButton("PIN + ROUTE", 9, 84, 104, function() pinSelected() end)
	addButton("WALK", 119, 84, 64, function()
		if not mapNav.target then setStatus("เลือกจุดหมายก่อน") return end
		local pos = targetPosition(mapNav.target.x, mapNav.target.z)
		if not pos then setStatus("ไม่พบตัวละคร") return end
		local result, why = buildRoute(pos)
		if result then
			drawMarker(pos, mapNav.target.name)
			local ok, err = PathA.walk(result)
			setStatus(ok and "เดินถึงจุดหมายแล้ว" or ("เดินไม่สำเร็จ: " .. tostring(err or PathA.status)))
		else setStatus("ไม่มีเส้นทางเดิน: " .. tostring(why)) end
	end)
	addButton("SPAWN VEHICLE", 189, 84, 118, function()
		setStatus("เปิด Garage • เลือกรถยนต์หรือมอเตอร์ไซค์ในเกม แล้วกด Spawn")
		task.spawn(function()
			local ok, result = pcall(spawnVehicle)
			setStatus(ok and result and "เรียกรถผ่านปุ่ม Garage แล้ว • กรุณาขึ้นนั่งคนขับ" or "เรียกรถไม่สำเร็จ • ใช้ Garage ของเกมเอง")
		end)
	end)
	autoDriveBtn = addButton(navLabel(State.NavVerifiedRuns), 9, 121, 104, function()
		if mapNav.driving then stopDrive("หยุดขับตามหมุดแล้ว") else startDrive() end
	end)
	addButton("STOP ALL", 119, 121, 88, function()
		stopDrive("หยุดการขับแล้ว")
		PathA.stop("หยุดการเดินแล้ว")
		clearRoute()
	end)
	addButton("CLEAR PIN", 213, 121, 94, function()
		stopDrive("ยกเลิกหมุดแล้ว")
		clearRoute()
		clearMarker()
		mapNav.target, mapNav.route = nil, nil
		detail.Text = "เลือกสถานที่จากรายการด้านบน"
		setStatus("ล้างหมุดแล้ว")
	end)

	-- [v1.34] ตั้งค่าการเริ่มนำทางอัตโนมัติเมื่อมีหมุดเข้ามา (วนโหมด: ปิด / เส้นอย่างเดียว / เดิน / ขับ / อัตโนมัติ)
	local pinNavBtn
	local function pinNavText() return "PIN NAV: " .. (PIN_NAV_LABEL[State.PinNavMode] or "?") end
	pinNavBtn = addButton(pinNavText(), 155, 158, 152, function()
		local cur = 1
		for i, m in ipairs(PIN_NAV_MODES) do if m == State.PinNavMode then cur = i end end
		State.PinNavMode = PIN_NAV_MODES[(cur % #PIN_NAV_MODES) + 1]
		pinNavBtn.Text = pinNavText()
		setStatus("หมุดนำทาง: " .. PIN_NAV_LABEL[State.PinNavMode] .. " (หมุดของ Rider/JobBot/Care นำทางเองอยู่แล้ว)")
		if State.AutoSaveConfig then pcall(saveConfigToFile) end
	end)

	local function refreshList()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		local q = string.lower(search.Text or "")
		local shownCount = 0
		for _, place in ipairs(mapNav.places) do
			if q == "" or string.find(string.lower(place.name), q, 1, true) then
				shownCount = shownCount + 1
				local b = Instance.new("TextButton")
				b.Size = UDim2.new(1, -6, 0, 27)
				b.BackgroundColor3 = (mapNav.target == place) and Theme.BgCard or Theme.BgInput
				b.BorderSizePixel = 0
				b.Font = Enum.Font.Gotham
				b.TextSize = 11
				b.TextXAlignment = Enum.TextXAlignment.Left
				b.TextColor3 = Theme.TextMain
				b.Text = string.format(" %s  %s", place.icon, place.name)
				b.Parent = list
				ctx.addCorner(b, 5)
				b.MouseButton1Click:Connect(function()
					mapNav.target = place
					detail.Text = string.format("%s %s\nX: %.1f  Z: %.1f  | MapPlaces #%s",
						place.icon, place.name, place.x, place.z, place.key)
					setStatus("เลือกจุดหมายแล้ว • กด PIN + ROUTE")
					refreshList()
				end)
			end
		end
		if shownCount == 0 then
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -6, 0, 28)
			lbl.BackgroundTransparency = 1
			lbl.TextColor3 = Theme.TextMuted
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 11
			lbl.Text = "ไม่พบสถานที่ใน MapPlaces"
			lbl.Parent = list
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(refreshList)

	-- อ่านจุดหมาย Courier จาก Marker ของเกมจริง เฉพาะกรณีที่อ่านตำแหน่ง 3 มิติได้
	addButton("COURIER TARGET", 9, 158, 140, function()
		local mk = Marker.read()
		if not (mk and mk.exact and mk.pos) then
			setStatus("ยังอ่านพิกัด 3 มิติจากตัวชี้งาน Courier ไม่ได้ • รับงานและเปิด Marker ในเกมก่อน")
			return
		end
		mapNav.target = {name="Courier • จุดหมายงานปัจจุบัน", icon="📦", x=mk.pos.X, z=mk.pos.Z}
		detail.Text = string.format("📦 Courier • จุดหมายงานปัจจุบัน\nX: %.1f  Y: %.1f  Z: %.1f", mk.pos.X, mk.pos.Y, mk.pos.Z)
		local result, why = buildRoute(mk.pos)
		if result then
			drawMarker(mk.pos, "Courier • จุดหมายงานปัจจุบัน")
			mapNav.route = result
			setStatus("อ่านจุดหมาย Courier จาก Marker จริงแล้ว • " .. result.count .. " จุด")
		else
			setStatus("อ่านจุดหมายได้ แต่คำนวณเส้นทางไม่ได้: " .. tostring(why))
		end
	end)

	if #mapNav.places == 0 then
		setStatus("ไม่พบ ReplicatedStorage/MapPlaces หรือโหลด Module ไม่สำเร็จ")
	else
		setStatus("โหลดสถานที่จาก MapPlaces แล้ว " .. #mapNav.places .. " จุด")
	end
	refreshList()

	-- [v1.33] รับหมุดจากหมุดกลาง (Rider / JobBot / Care ฯลฯ) แล้ววาดหมุด + เส้นนำทางสีฟ้า
	BKPin.subscribe(function(ev, pin)
		if mapNav.driving then return end -- กำลังขับตามหมุดที่ผู้ใช้สั่งเอง ไม่ทับ
		if ev == "set" and PathA.walking then return end -- กำลังเดินอยู่ ไม่ทับ
		if ev == "set" then
			mapNav.target = { name = pin.label, icon = "📍", x = pin.x, z = pin.z, source = pin.source }
			task.spawn(function()
				local okPin, drawn = pcall(pinSelected)
				if not (okPin and drawn) then return end
				-- [v1.34] เริ่มนำทางตามการตั้งค่า PIN NAV (เดิน = Pathfinding+MoveTo, ขับ = คันเร่ง/เลี้ยวของรถจริง ไม่วาป)
				local _, _, hum = ctx.getCharacterParts()
				local vehicle, _, seatObj = getPlayerVehicle()
				local seat = "free"
				if vehicle and seatObj and seatObj:IsA("VehicleSeat") and hum and seatObj.Occupant == hum then
					seat = "driver"
				elseif hum and hum.SeatPart ~= nil then
					seat = "other"
				end
				local busy = mapNav.driving or PathA.walking or Farm.on or legacyAutomationActive() or BKPin.selfNavActive()
				if BKPin.selfNav[tostring(pin.source)] then busy = false end -- เหตุผลจะแจ้งจาก decidePinNav
				local action, why = decidePinNav(State.PinNavMode, pin.source, seat, busy)
				if action == "drive" then
					setStatus("หมุดจาก " .. tostring(pin.source) .. ": เริ่มขับตามหมุด")
					startDrive()
				elseif action == "walk" then
					setStatus("หมุดจาก " .. tostring(pin.source) .. ": เริ่มเดินตามหมุด")
					local okW, errW = PathA.walk(mapNav.route)
					setStatus(okW and "เดินถึงจุดหมายแล้ว" or ("เดินไม่สำเร็จ: " .. tostring(errW or PathA.status)))
				elseif why ~= "" and (State.PinNavMode == "walk" or State.PinNavMode == "drive" or State.PinNavMode == "auto") then
					setStatus("หมุดจาก " .. tostring(pin.source) .. ": แสดงเส้นอย่างเดียว • " .. why)
				end
			end)
		else
			if mapNav.target and mapNav.target.source == pin.source then
				clearRoute() clearMarker()
				mapNav.target, mapNav.route = nil, nil
				setStatus("หมุดจาก " .. tostring(pin.source) .. " เสร็จสิ้น/ถูกล้างแล้ว")
			end
		end
	end)
	-- [v1.33] ตัวเฝ้าเส้นนำทาง: ถึงจุดหมายแล้วล้างเส้น / ออกนอกเส้นทาง (>45 stud) คำนวณใหม่ / หยุดนิ่งนานแจ้งสถานะ
	task.spawn(function()
		local lastP, lastMoveAt, lastRebuild = nil, os.clock(), 0
		local function segDist(a, b, p)
			local ax, az, bx, bz = a.X, a.Z, b.X, b.Z
			local dx, dz = bx - ax, bz - az
			local l2 = dx * dx + dz * dz
			local t = l2 > 0 and math.clamp(((p.X - ax) * dx + (p.Z - az) * dz) / l2, 0, 1) or 0
			local cx, cz = ax + dx * t, az + dz * t
			return math.sqrt((p.X - cx) ^ 2 + (p.Z - cz) ^ 2)
		end
		while __bkAlive() and ctx.mainWindow and ctx.mainWindow.Parent do
			task.wait(1)
			local route, tgt = mapNav.route, mapNav.target
			local _, hrp = ctx.getCharacterParts()
			if route and tgt and hrp and not mapNav.driving then
				local p = hrp.Position
				if lastP and (p - lastP).Magnitude > 3 then lastMoveAt = os.clock() end
				lastP = p
				local dToTarget = math.sqrt((p.X - tgt.x) ^ 2 + (p.Z - tgt.z) ^ 2)
				if dToTarget < 10 then
					clearRoute() clearMarker()
					mapNav.route = nil
					if tgt.source then BKPin.clear(tgt.source) end
					setStatus("ถึงจุดหมายแล้ว: " .. tostring(tgt.name))
				else
					local wps, best = route.waypoints, math.huge
					for k = 1, #wps - 1 do
						local d = segDist(wps[k].Position, wps[k + 1].Position, p)
						if d < best then best = d end
					end
					if best > 45 and os.clock() - lastRebuild > 6 then
						lastRebuild = os.clock()
						local pos = targetPosition(tgt.x, tgt.z)
						if pos then
							local r2 = buildRoute(pos)
							if r2 then
								mapNav.route = r2
								setStatus("ออกนอกเส้นทาง: คำนวณเส้นทางใหม่แล้ว")
							end
						end
					elseif os.clock() - lastMoveAt > 8 then
						setStatus("หยุดนิ่งนานแล้ว: ตรวจดูว่ารถ/ตัวละครติดหรือไม่ (เส้นนำทางยังอยู่)")
					end
				end
			else
				lastP, lastMoveAt = nil, os.clock()
			end
		end
	end)

	-- [v1.34] STOP ALL (triggerEmergencyStop) ต้องหยุดการขับ/เดินที่เริ่มจากหมุดด้วย
	EmergencyStopHooks[#EmergencyStopHooks + 1] = function(reason)
		pcall(stopDrive, "STOP ALL: หยุดการขับ")
		pcall(PathA.stop, "STOP ALL: หยุดการเดิน")
	end
	-- หยุดรถ/ล้างเส้นทางเมื่อปิดสคริปต์หรือหน้า UI ถูกทำลาย
	local instStore = nil
	pcall(function() instStore = (getgenv and getgenv()) or _G end)
	if type(instStore) == "table" and type(instStore.__BK_INSTANCE) == "table" then
		local inst = instStore.__BK_INSTANCE
		local prev = inst.onStop
		inst.onStop = function(reason)
			pcall(stopDrive, "หยุดเมื่อปิดสคริปต์")
			pcall(clearRoute)
			pcall(clearMarker)
			if prev then pcall(prev, reason) end
		end
	end
	return page
end
local okNav, errNav = EM.guard("MapNavigation", buildMapNavigationUI)
if not okNav then EM.record("MapNavigation", errNav) end
-- ===================== [v1.38] AUTO MAP SCANNER + BKPin HUB =====================
do
-- [v1.38 BEGIN AutoMapScanner]
-- AUTO MAP SCANNER: สแกนข้อมูลแมพจากสิ่งที่ Client เข้าถึงได้ (read-only: ไม่เรียก Remote, ไม่แก้ค่าเกม)
--  * ทุกจุดมาจากวัตถุ/ข้อมูลจริงเท่านั้น (ไม่สร้างพิกัดปลอม) สถานะเริ่มต้น = "found" (ยังไม่ยืนยัน)
--  * "verified" ได้ก็ต่อเมื่อวัตถุยังอยู่ในฉาก + Pathfinding จากตัวละครสำเร็จจริง
--  * รองรับ StreamingEnabled: วัตถุที่หลุดฉากเปลี่ยนเป็น "unstreamed" (เก็บพิกัดล่าสุดที่เคยเห็นจริงไว้ แต่ไม่ถือว่าใช้งานได้)
--  * สแกนซ้ำได้โดยไม่เกิดข้อมูลซ้ำ (คีย์ตามวัตถุ/พาธ+ตำแหน่ง) และ Event เชื่อมครั้งเดียว
local function __buildAutoMap(env)
	local Workspace = env.Workspace
	local ReplicatedStorage = env.ReplicatedStorage
	local Meta, BKPin = env.Meta, env.BKPin
	local clock = env.clock or os.clock
	local wait = env.wait or task.wait
	local spawn = env.spawn or task.spawn
	local alive = env.alive or function() return true end
	local MAX_POINTS = env.maxPoints or 3000
	local MAX_QUEUE = 4000
	local VERIFY_TTL = 180 -- วินาที: ผล verified เก่ากว่านี้ถือว่าหมดอายุ

	local AM = {
		version = "1.38",
		status = "idle", -- idle | checking | waiting | scanning | done | partial | failed | wrongplace | stopped
		detail = "ยังไม่เริ่มสแกน",
		placeOk = nil, placeId = tostring(env.placeId), mapName = tostring(Meta.MapName or "-"),
		points = {}, list = {}, n = 0, dropped = 0,
		byInst = setmetatable({}, { __mode = "k" }),
		instRef = setmetatable({}, { __mode = "v" }),
		roadSet = setmetatable({}, { __mode = "k" }),
		roadGraph = nil, mapPlaces = 0, scanned = 0, totalToScan = 0,
		lastScanClock = nil, lastScanTime = nil, scans = 0, retries = 0,
		scanning = false, stopped = false, token = 0,
		queue = {}, qHead = 1, qTail = 0, qDropped = 0,
		conns = {}, liveOn = false, liveGen = 0, notes = {}, missing = nil, missingAt = 0,
	}

	-- ---------- ตัวช่วย ----------
	local function finite(v) return type(v) == "number" and v == v and v > -1e6 and v < 1e6 end

	-- แยกชื่อเป็นคำ (รองรับ CamelCase / _ / ตัวเลขท้าย) เพื่อไม่ให้เจอคำซ้อน เช่น "plane" ไม่ใช่ "lane"
	local function tokens(name)
		local s = tostring(name or "")
		s = s:gsub("(%l)(%u)", "%1 %2"):lower()
		local out = {}
		for w in s:gmatch("[%w\224-\244\128-\191]+") do
			out[#out + 1] = (w:gsub("%d+$", ""))
		end
		return out
	end
	local function setOf(arr) local t = {} for _, w in ipairs(arr) do t[w] = true end return t end
	local K = {
		road = setOf({ "road", "roads", "street", "streets", "highway", "asphalt", "expressway", "avenue", "ถนน" }),
		building = setOf({ "building", "buildings", "tower", "house", "condo", "mall", "hotel", "hospital", "office", "apartment", "landmark", "landmarks" }),
		shop = setOf({ "shop", "shops", "store", "mart", "market", "tune", "tuning", "tuneshop", "dealership", "showroom", "cafe", "restaurant", "fuel", "petrol", "ร้าน" }),
		garage = setOf({ "garage", "garages", "carport", "parking", "อู่", "โรงรถ" }),
		quest = setOf({ "quest", "quests", "mission", "missions", "ภารกิจ" }),
		race = setOf({ "race", "races", "racing", "duel", "startline", "finish", "แข่ง" }),
		delivery = setOf({ "delivery", "deliver", "courier", "dropoff", "parcel", "ส่งของ" }),
	}
	local function hasKind(toks, kind)
		local set = K[kind]
		for _, w in ipairs(toks) do if set[w] then return true end end
		return false
	end
	-- ลำดับความสำคัญเมื่อชื่อตรงหลายหมวด
	local ORDER = { "quest", "race", "garage", "delivery", "shop", "building" }
	local function kindFromTokens(toks)
		for _, k in ipairs(ORDER) do
			if hasKind(toks, k) then return k end
		end
		return nil
	end
	AM.tokens, AM.kindFromTokens = tokens, kindFromTokens

	local function ancestorAttr(inst, key)
		local o, depth = inst, 0
		while o and o ~= Workspace and depth < 10 do
			local v = o:GetAttribute(key)
			if v ~= nil then return v end
			o = o.Parent
			depth = depth + 1
		end
		return nil
	end
	AM.ancestorAttr = ancestorAttr

	local function ancestorTokens(inst, levels)
		local toks, o, d = {}, inst, 0
		while o and o ~= Workspace and d < levels do
			for _, w in ipairs(tokens(o.Name)) do toks[#toks + 1] = w end
			o = o.Parent
			d = d + 1
		end
		return toks
	end

	local function posOf(inst)
		local part
		if inst:IsA("ProximityPrompt") then
			local par = inst.Parent
			if par and par:IsA("BasePart") then part = par
			elseif par and par:IsA("Attachment") then part = par.Parent
			elseif par then part = par:FindFirstAncestorWhichIsA("BasePart") end
		elseif inst:IsA("BasePart") then
			part = inst
		elseif inst:IsA("Model") then
			local ok, cf = pcall(function() return inst:GetPivot() end)
			if ok and cf and cf.Position then
				local p = cf.Position
				if finite(p.X) and finite(p.Y) and finite(p.Z) then return p end
			end
			return nil
		end
		if not part then return nil end
		local p = part.Position
		if p and finite(p.X) and finite(p.Y) and finite(p.Z) then return p end
		return nil
	end

	local function note(msg)
		for _, m in ipairs(AM.notes) do if m == msg then return end end
		AM.notes[#AM.notes + 1] = msg
		if #AM.notes > 8 then table.remove(AM.notes, 1) end
	end

	local function setStatus(st, detail)
		AM.status, AM.detail = st, detail or AM.detail
	end

	-- ---------- ฐานข้อมูลจุด (ไม่ซ้ำ) ----------
	local function newPoint(id, kind, src)
		if AM.n >= MAX_POINTS then AM.dropped = AM.dropped + 1 return nil end
		local pt = { id = id, kind = kind, src = src, state = "found", seenAt = clock() }
		AM.points[id] = pt
		AM.list[#AM.list + 1] = id
		AM.n = AM.n + 1
		return pt
	end

	-- upsert จากวัตถุจริง: คืน point หรือ nil
	function AM.upsertInst(inst, kind, info)
		local pos = posOf(inst)
		if not pos then return nil, "no position" end
		local id = AM.byInst[inst]
		local pt = id and AM.points[id]
		if not pt then
			local path = inst:GetFullName()
			id = kind .. ":" .. path .. "@" .. math.floor(pos.X + 0.5) .. "," .. math.floor(pos.Z + 0.5)
			pt = AM.points[id]
			if not pt then
				pt = newPoint(id, kind, "inst")
				if not pt then return nil, "cap" end
				pt.path = path
			end
			AM.byInst[inst] = id
		end
		local moved = pt.x and ((pt.x - pos.X) ^ 2 + (pt.z - pos.Z) ^ 2) > 4
		pt.x, pt.y, pt.z = pos.X, pos.Y, pos.Z
		pt.kind = kind
		pt.seenAt = clock()
		if info then
			pt.name, pt.job, pt.station, pt.sub = info.name or pt.name, info.job, info.station, info.sub
		end
		AM.instRef[id] = inst
		if pt.state == "unstreamed" or moved then
			pt.state, pt.verifiedAt = "found", nil
		end
		return pt
	end

	-- จุดจากข้อมูลโมดูลเกม (MapPlaces): มีเฉพาะ x,z ที่เกมให้ ไม่เดา y
	function AM.upsertPlace(key, name, kind, x, z)
		if not (finite(x) and finite(z)) then return nil end
		local id = "mp:" .. tostring(key)
		local pt = AM.points[id] or newPoint(id, kind, "mapplaces")
		if not pt then return nil end
		pt.x, pt.z, pt.y, pt.name, pt.kind, pt.seenAt = x, z, nil, name, kind, clock()
		return pt
	end

	function AM.markGone(inst)
		local id = AM.byInst[inst]
		if id then
			local pt = AM.points[id]
			if pt then pt.state, pt.verifiedAt = "unstreamed", nil end
			AM.instRef[id] = nil
			AM.byInst[inst] = nil
		end
		AM.roadSet[inst] = nil
	end

	-- ---------- จัดประเภทวัตถุ ----------
	local function considerPrompt(p)
		local job = ancestorAttr(p, "Job")
		local station = ancestorAttr(p, "StationId")
		local kind
		if job ~= nil then
			kind = "work"
		else
			local toks = tokens(p.Name)
			for _, w in ipairs(ancestorTokens(p, 6)) do toks[#toks + 1] = w end
			kind = kindFromTokens(toks) or "prompt"
		end
		local label = (job and (tostring(job) .. (station and ("/" .. tostring(station)) or "")) or p.Name)
		return AM.upsertInst(p, kind, { name = label .. " (" .. p.Name .. ")", job = job, station = station, sub = p.Name })
	end

	local function considerContainer(c)
		local kind = kindFromTokens(tokens(c.Name))
		if not kind then return nil end
		if kind == "garage" or kind == "shop" or kind == "building" then
			return AM.upsertInst(c, kind, { name = c.Name })
		end
		return nil
	end

	local function considerPart(part)
		if hasKind(tokens(part.Name), "road") or (part.Parent and hasKind(tokens(part.Parent.Name), "road")) then
			AM.roadSet[part] = true
			return true
		end
		return nil
	end

	function AM.consider(inst)
		local cls = inst.ClassName
		if cls == "ProximityPrompt" then return considerPrompt(inst)
		elseif cls == "Model" or cls == "Folder" then return considerContainer(inst)
		elseif inst:IsA("BasePart") then return considerPart(inst) end
		return nil
	end

	-- ---------- ตรวจสอบ/ยืนยันจุด ----------
	function AM.verify(id)
		local pt = AM.points[id]
		if not pt then return false, "ไม่พบจุดในฐานข้อมูล" end
		local pos
		if pt.src == "inst" then
			local inst = AM.instRef[id]
			if not inst or not inst.Parent then
				pt.state, pt.verifiedAt = "unstreamed", nil
				return false, "วัตถุไม่อยู่ในฉากที่โหลด (StreamingEnabled) ยังยืนยันไม่ได้"
			end
			if inst:IsA("ProximityPrompt") and inst.Enabled == false then
				return false, "Prompt ถูกปิดอยู่"
			end
			local p = posOf(inst)
			if not p then return false, "อ่านตำแหน่งวัตถุไม่ได้" end
			pt.x, pt.y, pt.z = p.X, p.Y, p.Z
			pos = p
		else
			-- จุดจาก MapPlaces ไม่มี y: ต้องหาพื้นจริงด้วย Raycast (ถ้าฉากยังไม่โหลดจะไม่เดา)
			pos = env.groundAt and env.groundAt(pt.x, pt.z)
			if not pos then return false, "ยังโหลดพื้นที่บริเวณจุดนี้ไม่ได้ (ไม่เดาความสูง)" end
		end
		local res = env.analyze and env.analyze({ x = pos.X, y = pos.Y, z = pos.Z })
		if res and res.success then
			pt.state, pt.verifiedAt, pt.pathCount, pt.pathLen = "verified", clock(), res.count, res.length
			return true, "ok"
		end
		pt.state = "unreachable"
		pt.why = res and tostring(res.reason) or "ไม่มีตัววิเคราะห์เส้นทาง"
		return false, "ไม่มีเส้นทางจริง: " .. pt.why
	end

	local function isFresh(pt)
		return pt.state == "verified" and pt.verifiedAt and (clock() - pt.verifiedAt) < VERIFY_TTL
	end

	-- ---------- ค้นหา / ปักหมุดกลาง ----------
	local function dist2(pt, hrp)
		if not hrp then return 0 end
		local p = hrp.Position
		return (pt.x - p.X) ^ 2 + (pt.z - p.Z) ^ 2
	end

	-- opts: kind, job, station, sub, name(substring), state, needY
	function AM.find(opts)
		opts = opts or {}
		local _, hrp = nil, nil
		if env.getCharacterParts then _, hrp = env.getCharacterParts() end
		local best, bestD
		local nameLow = opts.name and tostring(opts.name):lower()
		for _, id in ipairs(AM.list) do
			local pt = AM.points[id]
			if pt and (not opts.kind or pt.kind == opts.kind)
				and (opts.job == nil or pt.job == opts.job)
				and (opts.station == nil or pt.station == opts.station)
				and (opts.sub == nil or pt.sub == opts.sub)
				and (not opts.state or pt.state == opts.state)
				and (not opts.needY or pt.y)
				and (not nameLow or (pt.name and pt.name:lower():find(nameLow, 1, true))) then
				local d = dist2(pt, hrp)
				if not bestD or d < bestD then best, bestD = pt, d end
			end
		end
		return best
	end

	-- จุดที่เคยเห็นจริงล่าสุด (รวมที่หลุดฉากไปแล้ว) ใช้เดินเข้าหาเพื่อให้ฉากโหลด
	function AM.lastKnown(opts)
		opts = opts or {}
		opts.needY = true
		return AM.find(opts)
	end

	-- ปักหมุด: ต้องยืนยันจุดก่อน ไม่ผ่าน = ไม่ปัก
	function AM.pin(id, source, label)
		local pt = AM.points[id]
		if not pt then return false, "ไม่พบจุด" end
		if not isFresh(pt) then
			local ok, why = AM.verify(id)
			if not ok then return false, why end
		end
		local okSet = BKPin.set(source or "scan", pt.x, pt.z, label or ((pt.name or pt.kind) .. " ✓"))
		return okSet and true or false, okSet and "ok" or "ปักหมุดไม่สำเร็จ"
	end

	-- หาจุดที่ใกล้ที่สุดของหมวดที่ยืนยันผ่าน (ลองทีละจุดใกล้→ไกล สูงสุด 4 จุด)
	function AM.pinNearest(kind, source, opts)
		opts = opts or {}
		local cands = {}
		local _, hrp = nil, nil
		if env.getCharacterParts then _, hrp = env.getCharacterParts() end
		for _, id in ipairs(AM.list) do
			local pt = AM.points[id]
			if pt and pt.kind == kind and (opts.job == nil or pt.job == opts.job) then
				cands[#cands + 1] = { id = id, d = dist2(pt, hrp) }
			end
		end
		if #cands == 0 then return false, "ยังไม่พบจุดหมวด " .. tostring(kind) .. " ในฐานข้อมูล" end
		table.sort(cands, function(a, b) return a.d < b.d end)
		local lastWhy = "-"
		for i = 1, math.min(4, #cands) do
			local ok, why = AM.pin(cands[i].id, source, opts.label)
			if ok then return true, AM.points[cands[i].id] end
			lastWhy = why
		end
		return false, lastWhy
	end

	-- ตรวจว่ามีเส้นทางเดินจริงไปยังตำแหน่ง (ใช้ก่อนเดินเข้าหาจุดที่เคยสแกน)
	function AM.pathExists(pos)
		local res = env.analyze and env.analyze({ x = pos.X, y = pos.Y, z = pos.Z })
		if res and res.success then return true, res.count end
		return false, res and res.reason or "no analyzer"
	end

	-- ---------- สถิติ ----------
	function AM.counts()
		local c = { total = AM.n, verified = 0, found = 0, unstreamed = 0, unreachable = 0, byKind = {} }
		for _, id in ipairs(AM.list) do
			local pt = AM.points[id]
			if pt then
				c[pt.state] = (c[pt.state] or 0) + 1
				c.byKind[pt.kind] = (c.byKind[pt.kind] or 0) + 1
			end
		end
		local roads = 0
		for _ in pairs(AM.roadSet) do roads = roads + 1 end
		c.roads = roads
		c.work = c.byKind.work or 0
		return c
	end

	-- นับจุดที่ "ยังไม่พบ" จากรายการที่ระบบเดิมรู้ว่าต้องมี (Registry deps ชนิด Workspace/Station)
	function AM.refreshMissing()
		if not env.missingCounter then return end
		local ok, m = pcall(env.missingCounter)
		if ok and type(m) == "table" then AM.missing, AM.missingAt = m, clock() end
	end

	-- ---------- อ่านข้อมูลจากโมดูลเกม ----------
	local function readMapPlaces(tok)
		local mod = ReplicatedStorage:FindFirstChild("MapPlaces")
		if not mod then note("ไม่พบ ReplicatedStorage/MapPlaces") return 0 end
		if not mod:IsA("ModuleScript") then note("MapPlaces ไม่ใช่ ModuleScript") return 0 end
		local ok, data = pcall(env.require, mod)
		if not ok or type(data) ~= "table" then note("อ่าน MapPlaces ไม่สำเร็จ: " .. tostring(data)) return 0 end
		local n = 0
		for k, v in pairs(data) do
			if type(v) == "table" and type(v.x) == "number" and type(v.z) == "number" then
				local nm = tostring(v.th or v.name or ("Place " .. tostring(k)))
				local toks = tokens(nm .. " " .. tostring(v.go or "") .. " " .. tostring(v.icon or ""))
				local kind = kindFromTokens(toks) or "place"
				if AM.upsertPlace(k, nm, kind, v.x, v.z) then n = n + 1 end
			end
		end
		AM.mapPlaces = n
		return n
	end

	local function readRoadGraph()
		local mod = ReplicatedStorage:FindFirstChild("RoadGraph")
		if not mod then AM.roadGraph = nil note("ไม่พบ ReplicatedStorage/RoadGraph") return end
		if not mod:IsA("ModuleScript") then return end
		local ok, data = pcall(env.require, mod)
		if not ok or type(data) ~= "table" then note("อ่าน RoadGraph ไม่สำเร็จ") return end
		local nodes = data.nodes or data.Nodes
		local edges = data.edges or data.Edges
		local nn, ne = 0, 0
		if type(nodes) == "table" then
			for _, nd in pairs(nodes) do
				if type(nd) == "table" and finite(nd.x or nd.X) and finite(nd.z or nd.Z) then nn = nn + 1 end
			end
		end
		if type(edges) == "table" then for _ in pairs(edges) do ne = ne + 1 end end
		if nn == 0 and ne == 0 then
			note("RoadGraph มีโครงสร้างที่ไม่รู้จัก (ไม่นับโหนด)")
			AM.roadGraph = { nodes = 0, edges = 0, known = false }
		else
			AM.roadGraph = { nodes = nn, edges = ne, known = true }
		end
	end

	-- ---------- ตัวสแกนหลัก ----------
	local function runScan(tok, reason)
		local function live() return tok == AM.token and alive() and not AM.stopped end
		setStatus("checking", "ตรวจ PlaceId...")
		AM.notes = {}
		-- 1) ตรวจแมพเป้าหมาย
		if env.placeId ~= Meta.PlaceId then
			AM.placeOk = false
			setStatus("wrongplace", "PlaceId " .. tostring(env.placeId) .. " ไม่ตรงแมพเป้าหมาย " .. tostring(Meta.PlaceId) .. " (" .. tostring(Meta.MapName) .. ") ไม่สแกน")
			return
		end
		AM.placeOk = true
		-- 2) รอแมพโหลด (จำกัดเวลา ไม่วนไม่สิ้นสุด)
		local t0 = clock()
		local root = Workspace:FindFirstChild("Map")
		while not root and live() and clock() - t0 < (env.mapWaitSec or 25) do
			setStatus("waiting", string.format("รอ Workspace.Map โหลด... %ds", math.floor(clock() - t0)))
			wait(0.5)
			root = Workspace:FindFirstChild("Map")
		end
		if not live() then return end
		local partialWhy
		if not root then
			partialWhy = Workspace.StreamingEnabled and "ไม่พบ Workspace.Map (StreamingEnabled: ฉากอาจยังไม่ Stream มาถึงตำแหน่งผู้เล่น)" or "ไม่พบ Workspace.Map"
		end
		-- 3) ข้อมูลโมดูลเกม
		setStatus("scanning", "อ่าน MapPlaces / RoadGraph...")
		readMapPlaces(tok)
		readRoadGraph()
		-- 4) สแกน Workspace เป็นช่วง ๆ (ไม่ค้างเฟรม)
		local okD, desc = pcall(function() return Workspace:GetDescendants() end)
		if not okD then
			setStatus("failed", "อ่าน Workspace ไม่สำเร็จ: " .. tostring(desc))
			return
		end
		AM.totalToScan, AM.scanned = #desc, 0
		for i = 1, #desc do
			if not live() then return end
			local inst = desc[i]
			if inst and inst.Parent then pcall(AM.consider, inst) end
			AM.scanned = i
			if i % 400 == 0 then
				setStatus("scanning", string.format("สแกน Workspace %d/%d", i, #desc))
				wait()
			end
		end
		-- จุดที่ไม่ได้ผูกวัตถุในฉากตอนนี้ = unstreamed (เก็บพิกัดเดิมไว้ ไม่ถือว่าใช้งานได้)
		for _, id in ipairs(AM.list) do
			local pt = AM.points[id]
			if pt and pt.src == "inst" and not AM.instRef[id] then pt.state, pt.verifiedAt = "unstreamed", nil end
		end
		AM.refreshMissing()
		AM.scans = AM.scans + 1
		AM.lastScanClock, AM.lastScanTime = clock(), os.date("%H:%M:%S")
		local c = AM.counts()
		if c.total == 0 and AM.mapPlaces == 0 then
			setStatus("failed", (partialWhy or "สแกนจบแต่ไม่พบจุดใด ๆ") .. " — ไม่พบข้อมูลจุดหมายเลย")
		elseif partialWhy then
			setStatus("partial", partialWhy .. " (ได้ " .. c.total .. " จุด)")
		else
			setStatus("done", string.format("สแกนเสร็จ (%s): %d จุด / %d ถนน", tostring(reason or "manual"), c.total, c.roads))
		end
		AM.partialWhy = partialWhy
	end

	-- สแกน (กันซ้อน) คืน true ถ้าเริ่มได้
	function AM.scan(reason)
		if AM.stopped then return false, "ถูกหยุดด้วย STOP ALL — กด 'เริ่ม/สแกนใหม่' เพื่อเริ่มอีกครั้ง" end
		if AM.scanning then return false, "กำลังสแกนอยู่" end
		AM.scanning = true
		AM.token = AM.token + 1
		local tok = AM.token
		spawn(function()
			local ok, err = pcall(runScan, tok, reason)
			if not ok then setStatus("failed", "สแกนผิดพลาด: " .. tostring(err):sub(1, 120)) end
			if tok == AM.token then AM.scanning = false end
		end)
		return true
	end

	-- ---------- ตรวจจับวัตถุที่โหลดเพิ่ม (Live) ----------
	local function roadHint(name)
		local l = name:lower()
		return l:find("road", 1, true) or l:find("street", 1, true) or l:find("highway", 1, true) or l:find("asphalt", 1, true) or l:find("ถนน", 1, true)
	end

	local function enqueue(inst)
		if AM.qTail - AM.qHead + 1 >= MAX_QUEUE then
			AM.queue[AM.qHead] = nil
			AM.qHead = AM.qHead + 1
			AM.qDropped = AM.qDropped + 1
		end
		AM.qTail = AM.qTail + 1
		AM.queue[AM.qTail] = inst
	end

	local function onAdded(inst)
		local cls = inst.ClassName
		if cls == "ProximityPrompt" or cls == "Model" or cls == "Folder" then
			enqueue(inst)
		elseif roadHint(inst.Name) and inst:IsA("BasePart") then
			enqueue(inst)
		end
	end

	local function onRemoving(inst)
		if AM.byInst[inst] or AM.roadSet[inst] then AM.markGone(inst) end
	end

	function AM.pump(maxItems)
		local n = 0
		while AM.qHead <= AM.qTail and n < (maxItems or 150) do
			local inst = AM.queue[AM.qHead]
			AM.queue[AM.qHead] = nil
			AM.qHead = AM.qHead + 1
			n = n + 1
			if inst and inst.Parent then pcall(AM.consider, inst) end
		end
		if AM.qHead > AM.qTail then AM.qHead, AM.qTail = 1, 0 end
		return n
	end

	function AM.startLive()
		if AM.liveOn then return false end -- เชื่อมครั้งเดียว ไม่ซ้ำ
		AM.liveOn = true
		local function track(c)
			AM.conns[#AM.conns + 1] = c
			if env.track then env.track(c) end
		end
		track(Workspace.DescendantAdded:Connect(onAdded))
		track(Workspace.DescendantRemoving:Connect(onRemoving))
		AM.liveGen = AM.liveGen + 1
		local myGen = AM.liveGen
		spawn(function()
			local ticks = 0
			while AM.liveOn and AM.liveGen == myGen and alive() and not AM.stopped do
				wait(0.25)
				AM.pump(150)
				ticks = ticks + 1
				if ticks % 120 == 0 then AM.refreshMissing() end -- ทุก ~30 วินาที
			end
		end)
		return true
	end

	function AM.stopLive()
		AM.liveOn = false
		for _, c in ipairs(AM.conns) do pcall(function() c:Disconnect() end) end
		AM.conns = {}
		AM.queue, AM.qHead, AM.qTail = {}, 1, 0
	end

	-- STOP ALL: หยุดสแกนและ Live ทันที (ไม่แตะ Collision เพราะโมดูลนี้ไม่เคยแก้ค่านั้น)
	function AM.stop(reason)
		AM.stopped = true
		AM.token = AM.token + 1
		AM.scanning = false
		AM.stopLive()
		setStatus("stopped", "หยุด: " .. tostring(reason or "STOP ALL"))
	end

	function AM.resume(reason)
		AM.stopped = false
		AM.startLive()
		return AM.scan(reason or "resume")
	end

	-- เริ่มอัตโนมัติเมื่อเข้าเกม: สแกน -> Live -> ลองใหม่แบบจำกัดครั้งถ้ายังได้ไม่ครบ
	function AM.start()
		if env.placeId ~= Meta.PlaceId then
			-- ไม่ใช่แมพเป้าหมาย: แจ้งสาเหตุแล้วจบ ไม่ต่อ Event ไม่วนลูป
			return AM.scan("startup")
		end
		AM.startLive()
		local ok = AM.scan("startup")
		spawn(function()
			local delays = { 15, 30, 60 }
			for i = 1, #delays do
				wait(delays[i])
				if not alive() or AM.stopped then return end
				while AM.scanning and alive() do wait(1) end
				if AM.status == "done" or AM.status == "wrongplace" or AM.status == "stopped" then return end
				AM.retries = i
				AM.scan("retry " .. i)
			end
		end)
		return ok
	end

	-- ล้างทุกอย่างตอนปิดสคริปต์ (กัน Memory Leak)
	function AM.destroy()
		AM.stop("unload")
		AM.points, AM.list, AM.n, AM.notes = {}, {}, 0, {}
		AM.byInst = setmetatable({}, { __mode = "k" })
		AM.instRef = setmetatable({}, { __mode = "v" })
		AM.roadSet = setmetatable({}, { __mode = "k" })
	end

	-- ---------- เสียบเข้า WorldCache และ BKPin กลาง ----------
	if env.WorldCache then
		env.WorldCache.mapPoints = AM.points
		function env.WorldCache.listPoints(kind)
			local out = {}
			for _, id in ipairs(AM.list) do
				local pt = AM.points[id]
				if pt and (not kind or pt.kind == kind) then out[#out + 1] = pt end
			end
			return out
		end
	end
	BKPin.scan = AM
	function BKPin.find(opts) return AM.find(opts) end
	function BKPin.pinPoint(id, source, label) return AM.pin(id, source, label) end
	function BKPin.pinKind(kind, source, opts) return AM.pinNearest(kind, source, opts) end

	return AM
end
-- [v1.38 END AutoMapScanner]

	-- นับจุดที่ระบบเดิมรู้ว่าต้องมี (Registry deps ชนิด Workspace/Station) แต่ยังไม่พบ — แยก "ยังไม่ Stream" ออกจาก "ไม่พบ"
	local function amMissingCounter()
		local total, uns, miss, seen = 0, 0, 0, {}
		for _, s in ipairs(Registry.list) do
			for _, d in ipairs(s.deps or {}) do
				if (d.t == "ws" or d.t == "station") and not seen[d.n] then
					seen[d.n] = true
					total = total + 1
					local st = depCheck(d)
					if st == "unstreamed" then uns = uns + 1 elseif st ~= "ok" then miss = miss + 1 end
				end
			end
		end
		return { total = total, unstreamed = uns, missing = miss }
	end

	local AM = __buildAutoMap({
		Workspace = Workspace, ReplicatedStorage = ReplicatedStorage, Meta = Meta, BKPin = BKPin,
		placeId = game.PlaceId, require = require, WorldCache = WorldCache,
		clock = os.clock, wait = task.wait, spawn = task.spawn, alive = __bkAlive, track = __bkTrack,
		getCharacterParts = ctx.getCharacterParts,
		analyze = function(t) return PathA.analyze(t) end,
		groundAt = function(x, z)
			local _, hrp = ctx.getCharacterParts()
			if not hrp then return nil end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character }
			local hit = Workspace:Raycast(Vector3.new(x, math.max(hrp.Position.Y + 250, 250), z), Vector3.new(0, -800, 0), params)
			if not hit then return nil end -- ฉากบริเวณนั้นยังไม่โหลด: ไม่เดาความสูง
			return Vector3.new(x, hit.Position.Y + 3, z)
		end,
		missingCounter = amMissingCounter,
	})
	MA.AutoMap = AM
	-- STOP ALL: หยุดสแกน/Live ทันที (โมดูลนี้ไม่แก้ Collision จึงไม่มีอะไรต้องคืน; Collision ของ Nav/Ghost คืนผ่าน CollisionKeeper ใน hook เดิม)
	EmergencyStopHooks[#EmergencyStopHooks + 1] = function(reason) pcall(AM.stop, "STOP ALL: " .. tostring(reason)) end
	__bkHook(function() pcall(AM.destroy) end)

	local okAmUI, errAmUI = EM.guard("AutoMapUI", function()
		local page = ctx.createPage("AutoScanner", "9. AUTO MAP SCANNER • v1.38")
		local card = ctx.makeCard(page, "AUTO MAP SCANNER v1.38 • สถานะ (อ่านอย่างเดียว ไม่เรียก Remote)", 262, 0)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -18, 0, 224)
		lbl.Position = UDim2.fromOffset(9, 32)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 11
		lbl.TextWrapped = true
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.TextColor3 = Theme.TextMain
		lbl.Text = "กำลังเตรียมข้อมูล..."
		lbl.Parent = card

		local lastMsg = ""
		local STATUS_TH = { idle = "ยังไม่เริ่ม", checking = "กำลังตรวจแมพ", waiting = "รอโหลดแมพ", scanning = "กำลังสแกน",
			done = "สแกนสำเร็จ", partial = "สแกนได้บางส่วน", failed = "สแกนไม่สำเร็จ", wrongplace = "ไม่ใช่แมพเป้าหมาย", stopped = "หยุดแล้ว" }
		local function statusText()
			local c = AM.counts()
			local mn = MA.MapNavigation
			local det = MA.Detector and MA.Detector.info
			local wps = (mn and mn.route and mn.route.waypoints) and #mn.route.waypoints or 0
			local marks = (mn and mn.marker) and 1 or 0
			local m = AM.missing
			local rg = AM.roadGraph
			local L = {}
			L[#L + 1] = "Auto Map Scanner v" .. tostring(AM.version) .. " | Status: " .. (STATUS_TH[AM.status] or tostring(AM.status))
			L[#L + 1] = "  " .. tostring(AM.detail)
			L[#L + 1] = string.format("Map: %s | PlaceId: %s (%s)", tostring(det and det.name or Meta.MapName), AM.placeId,
				AM.placeOk == nil and "ยังไม่ตรวจ" or (AM.placeOk and "ตรงเป้าหมาย" or "ไม่ตรงเป้าหมาย"))
			L[#L + 1] = string.format("จุดที่ตรวจพบ: %d (ยืนยันแล้ว %d / ยังไม่ยืนยัน %d / นอกฉาก %d / ไปไม่ได้ %d)",
				c.total, c.verified, c.found, c.unstreamed, c.unreachable)
			L[#L + 1] = string.format("ถนน: %d ชิ้น%s | จุดทำงาน: %d", c.roads,
				rg and rg.known and string.format(" (RoadGraph %d โหนด/%d เส้น)", rg.nodes, rg.edges) or "", c.work)
			L[#L + 1] = string.format("Marker: %d (หมุดกลาง %d) | Waypoints: %d", marks, BKPin.cur and 1 or 0, wps)
			if m then
				L[#L + 1] = string.format("จุดที่ยังไม่พบ: %d จาก %d (ยังไม่ Stream %d / ไม่พบ %d)", m.unstreamed + m.missing, m.total, m.unstreamed, m.missing)
			else
				L[#L + 1] = "จุดที่ยังไม่พบ: (ยังไม่คำนวณ)"
			end
			if AM.lastScanTime then
				L[#L + 1] = string.format("สแกนล่าสุด: %s (%d วิที่แล้ว) | ครั้งที่ %d", AM.lastScanTime, math.floor(os.clock() - AM.lastScanClock), AM.scans)
			else
				L[#L + 1] = "สแกนล่าสุด: -"
			end
			if AM.dropped > 0 then L[#L + 1] = "ข้อมูลเต็มเพดาน: ข้าม " .. AM.dropped .. " จุด" end
			for i = 1, math.min(2, #AM.notes) do L[#L + 1] = "หมายเหตุ: " .. AM.notes[i] end
			if lastMsg ~= "" then L[#L + 1] = "ล่าสุด: " .. lastMsg end
			return table.concat(L, "\n")
		end

		local ctl = ctx.makeCard(page, "ควบคุม / ปักหมุดจากฐานข้อมูล (ปักได้เมื่อยืนยันจุดผ่านแล้วเท่านั้น)", 184, 1)
		local function pinKind(kind, source, title)
			task.spawn(function()
				lastMsg = "กำลังยืนยันจุด " .. title .. "..."
				local ok, res = AM.pinNearest(kind, source, { label = title })
				if ok then
					lastMsg = "ปักหมุด " .. title .. ": " .. tostring(res.name or res.id)
				else
					lastMsg = "ปัก " .. title .. " ไม่ได้: " .. tostring(res)
				end
			end)
		end
		ctx.makeActionButton(ctl, "สแกนแมพใหม่", 0, 0.5, 34, 28, function()
			local ok, why = AM.scan("manual")
			lastMsg = ok and "เริ่มสแกนใหม่" or tostring(why)
		end)
		ctx.makeActionButton(ctl, "เริ่ม/ต่อ หลัง STOP ALL", 0.5, 0.5, 34, 28, function()
			local ok, why = AM.resume("manual")
			lastMsg = ok and "เริ่มระบบสแกนอีกครั้ง" or tostring(why)
		end)
		ctx.makeActionButton(ctl, "ปักหมุด Quest", 0, 0.5, 68, 28, function() pinKind("quest", "quest", "Quest") end)
		ctx.makeActionButton(ctl, "ปักหมุด Race", 0.5, 0.5, 68, 28, function() pinKind("race", "race", "Race") end)
		ctx.makeActionButton(ctl, "ปักหมุด Garage", 0, 0.5, 102, 28, function() pinKind("garage", "garage", "Garage") end)
		ctx.makeActionButton(ctl, "ปักหมุด ร้านค้า", 0.5, 0.5, 102, 28, function() pinKind("shop", "shop", "ร้านค้า") end)
		ctx.makeActionButton(ctl, "ปักหมุด จุดส่งของ", 0, 0.5, 136, 28, function() pinKind("delivery", "delivery", "จุดส่งของ") end)
		ctx.makeActionButton(ctl, "ล้างหมุดทั้งหมด", 0.5, 0.5, 136, 28, function()
			BKPin.clear()
			lastMsg = "ล้างหมุดแล้ว"
		end)

		task.spawn(function()
			while __bkAlive() and ctx.mainWindow and ctx.mainWindow.Parent do
				if page.Visible then pcall(function() lbl.Text = statusText() end) end
				task.wait(1)
			end
		end)
		pcall(function() lbl.Text = statusText() end)
	end)
	if not okAmUI then EM.record("AutoMapUI", errAmUI) end
	EM.guard("AutoMapStart", AM.start)
end
-- ===================== [v1.35 END] =====================
EM.guard("MapAdaptiveStart", MA.start)
if ctx.Export then ctx.Export.MA = MA end

end)
if not __okMA then
	__maOk = false
	warn("[BALL KUN Vv1] MAP ADAPTIVE: " .. tostring(__errMA))
end
end
-- ===================== END MAP ADAPTIVE =====================

-- ===================== BALL KUN Vv1 : 2030 SMART SUITE (v1.34) =====================
-- ระบบใหม่ทั้งหมดทำงานผ่าน "UI / Prompt / ปุ่มจริงของเกม" และขับรถจริงด้วยปุ่ม W/A/S/D
-- ไม่เรียก Remote ตรง ไม่วาป ไม่ยุ่งกับระบบตรวจจับของเกม (UiGuard)
do
local __okBK, __errBK = pcall(function()
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local BK = { alive = true, log = {}, status = {}, tel = {}, refreshers = {}, pages = {}, tabs = {} }
BK.cfg = {
	targetKmh = 70,
	avoid = true,
	ghost = false,
	pistonAlert = true,
	pistonAuto = false,
	pistonMin = 53,
	pistonMax = 90,
	pistonMaxPrice = 200000,
	pistonMaxBuy = 3,
	uiScale = 1,
	alerts = { lowFuel = true, repair = true, refuelDone = true, stuck = true, piston = true, shop = true },
}
BK.fwdSign = 1
BK.conns = {}
-- ทุก Event Connection ของโมดูลนี้ต้องลงทะเบียนผ่าน track() เพื่อให้ cleanup() ยกเลิกได้ครบจุดเดียว
local function track(conn)
	BK.conns[#BK.conns + 1] = conn
	return conn
end
local function disconnectAll()
	local n = 0
	for _, cn in ipairs(BK.conns) do
		pcall(function() cn:Disconnect() end)
		n = n + 1
	end
	BK.conns = {}
	return n
end
-- กันรันซ้ำ: ถ้ามีอินสแตนซ์เก่าของโมดูลนี้ค้างอยู่ ให้เก็บกวาดก่อน (ไม่ให้ Connection/ลูปซ้อนกัน)
do
	local okG, g = pcall(function() return getgenv() end)
	BK.genv = okG and type(g) == "table" and g or nil
	if BK.genv and type(BK.genv.__BK_PREMIUM_CLEANUP) == "function" then
		pcall(BK.genv.__BK_PREMIUM_CLEANUP)
	end
end
BK.bought = 0
BK.file = "BALL_KUN_2030_" .. tostring(player and player.UserId or 0) .. ".json"

-- ---------- helpers ----------
local function pg() return player:FindFirstChild("PlayerGui") end
local function log(msg)
	table.insert(BK.log, 1, os.date("%H:%M:%S") .. "  " .. tostring(msg))
	if #BK.log > 40 then table.remove(BK.log) end
end
local function setStatus(sys, txt) BK.status[sys] = tostring(txt) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function posOf(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, cf = pcall(function() return inst:GetPivot() end)
		if ok and cf then return cf.Position end
	end
	local p = inst:FindFirstChildWhichIsA("BasePart", true)
	return p and p.Position or nil
end

local function saveCfg()
	if type(writefile) ~= "function" then return end
	pcall(function()
		local c = BK.cfg
		writefile(BK.file, HttpService:JSONEncode({
			targetKmh = c.targetKmh, avoid = c.avoid, ghost = c.ghost,
			pistonAlert = c.pistonAlert, pistonAuto = c.pistonAuto, pistonMin = c.pistonMin, pistonMax = c.pistonMax,
			pistonMaxPrice = c.pistonMaxPrice, pistonMaxBuy = c.pistonMaxBuy, uiScale = c.uiScale, alerts = c.alerts,
		}))
	end)
end
local function loadCfg()
	if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
	pcall(function()
		if not isfile(BK.file) then return end
		local d = HttpService:JSONDecode(readfile(BK.file))
		if type(d) ~= "table" then return end
		for k, v in pairs(d) do
			if k == "alerts" and type(v) == "table" then
				for ak, av in pairs(v) do if BK.cfg.alerts[ak] ~= nil and type(av) == "boolean" then BK.cfg.alerts[ak] = av end end
			elseif BK.cfg[k] ~= nil and type(v) == type(BK.cfg[k]) then
				BK.cfg[k] = v
			end
		end
		BK.cfg.pistonAuto = false -- ปิดซื้ออัตโนมัติทุกครั้งที่เปิดสคริปต์ (กันใช้เงินโดยไม่ตั้งใจ)
	end)
end
loadCfg()

local lastAlert = {}
local function alert(key, title, desc, cooldown)
	if BK.cfg.alerts[key] == false then return end
	local t = os.clock()
	if lastAlert[key] and t - lastAlert[key] < (cooldown or 120) then return end
	lastAlert[key] = t
	log(title)
	task.spawn(function() pcall(sendWebhook, title, desc or "") end)
end

-- ---------- telemetry (อ่านจาก HUD ของเกม) ----------
local function readGauge(name)
	local gui = pg() and pg():FindFirstChild("VehicleCareTop")
	if not gui then return nil end
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text == name and d.Parent then
			for _, s in ipairs(d.Parent:GetChildren()) do
				if s:IsA("TextLabel") and s ~= d then
					local n = s.Text:match("^%s*(%d+%.?%d*)%s*%%")
					if n then return tonumber(n) end
				end
			end
		end
	end
	return nil
end

local function myVehicle()
	local sv = Workspace:FindFirstChild("SpawnedVehicles")
	if not sv then return nil end
	local tag = "_" .. player.Name .. "_"
	local _, _, hum = getCharacterParts()
	local seatModel = hum and hum.SeatPart and hum.SeatPart:FindFirstAncestorOfClass("Model")
	local found = nil
	for _, m in ipairs(sv:GetChildren()) do
		if m:IsA("Model") and m.Name:find(tag, 1, true) then
			if m == seatModel or (seatModel and seatModel:IsDescendantOf(m)) then return m end
			found = found or m
		end
	end
	return found
end
local function vehRoot(m)
	if not m then return nil end
	if m.PrimaryPart then return m.PrimaryPart end
	local c = m:FindFirstChild("Chassis", true)
	if c and c:IsA("BasePart") then return c end
	return m:FindFirstChildWhichIsA("BasePart", true)
end
local function seated()
	local _, _, hum = getCharacterParts()
	return hum and hum.SeatPart ~= nil
end
local function rootPos()
	local _, hrp = getCharacterParts()
	return hrp and hrp.Position or nil
end

-- ---------- keys ----------
local KC = {
	W = Enum.KeyCode.W, A = Enum.KeyCode.A, S = Enum.KeyCode.S, D = Enum.KeyCode.D,
	R = Enum.KeyCode.R, K = Enum.KeyCode.K, F = Enum.KeyCode.F, G = Enum.KeyCode.G,
}
local keyDown = {}
local function setKey(n, down)
	if not VIM then return end
	if (keyDown[n] or false) == down then return end
	keyDown[n] = down
	pcall(function() VIM:SendKeyEvent(down, KC[n], false, game) end)
end
local function tapKey(n, hold)
	setKey(n, true)
	task.wait(hold or 0.08)
	setKey(n, false)
end
local function releaseAll() for k in pairs(KC) do setKey(k, false) end end

-- ---------- destinations ----------
local function nearestOf(list, from)
	local best, bd = nil, math.huge
	for _, p in ipairs(list) do
		local d = (flat(p) - flat(from)).Magnitude
		if d < bd then best, bd = p, d end
	end
	return best, bd
end
local DEST = {}
function DEST.fuel(from)
	local list = {}
	local lm = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks")
	if lm then
		for _, st in ipairs(lm:GetChildren()) do
			if st.Name:lower():find("fuel", 1, true) then
				local disp = st:FindFirstChild("Dispensers")
				if disp then
					for _, d in ipairs(disp:GetChildren()) do
						local p = posOf(d)
						if p then list[#list + 1] = p end
					end
				end
				if #list == 0 then local p = posOf(st) if p then list[#list + 1] = p end end
			end
		end
	end
	if #list == 0 then list = { Vector3.new(245, 3, -87) } end -- พิกัดสำรองจาก dump
	return nearestOf(list, from)
end
function DEST.tune(from)
	local list = {}
	local ts = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("TuneShops")
	if ts then
		for _, s in ipairs(ts:GetChildren()) do
			local p = posOf(s)
			if p and p.Magnitude > 5 then list[#list + 1] = p end
		end
	end
	if #list == 0 then list = { Vector3.new(-430, 3, -150) } end
	return nearestOf(list, from)
end
function DEST.piston(from)
	local ps = Workspace:FindFirstChild("PistonShop")
	local seller = ps and (ps:FindFirstChild("Seller") or ps)
	local p = posOf(seller)
	if p and p.Magnitude > 5 then return p, (flat(p) - flat(from)).Magnitude end
	return nil
end
function DEST.repair(from)
	local lm = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks")
	local rs = lm and lm:FindFirstChild("RepairShop")
	local p = posOf(rs) or Vector3.new(812, 3, 77)
	return p, (flat(p) - flat(from)).Magnitude
end

-- ---------- walking (ตัวละคร) ----------
local Nav = { token = 0 }
local function walkBlocking(target, stopDist, token)
	local t0 = os.clock()
	local _, hrp, hum = getCharacterParts()
	if not (hrp and hum) then return false, "ไม่พบตัวละคร" end
	local wps = nil
	pcall(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		path:ComputeAsync(hrp.Position, target)
		if path.Status == Enum.PathStatus.Success then
			wps = {}
			for _, w in ipairs(path:GetWaypoints()) do wps[#wps + 1] = w.Position end
		end
	end)
	wps = wps or { target }
	for _, wp in ipairs(wps) do
		local lastMove, lastPos = os.clock(), hrp.Position
		while Nav.token == token and os.clock() - t0 < 120 do
			_, hrp, hum = getCharacterParts()
			if not (hrp and hum) or hum.Health <= 0 then return false, "ตัวละครไม่พร้อม" end
			if (flat(hrp.Position) - flat(target)).Magnitude <= stopDist then return true end
			if (flat(hrp.Position) - flat(wp)).Magnitude < 4 then break end
			hum:MoveTo(wp)
			task.wait(0.2)
			if (hrp.Position - lastPos).Magnitude > 0.5 then lastMove, lastPos = os.clock(), hrp.Position end
			if os.clock() - lastMove > 1.5 then hum.Jump = true end
			if os.clock() - lastMove > 6 then return false, "เดินติดขัด" end
		end
		if Nav.token ~= token then return false, "ยกเลิก" end
	end
	return (flat(hrp.Position) - flat(target)).Magnitude <= stopDist + 3
end

-- ---------- driving (ขับจริงด้วยปุ่ม) ----------
local Drive = { active = false, status = "ว่าง", dest = "-", stuckCount = 0 }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
pcall(function() rayParams.RespectCanCollide = true end)

local function avoidVector(root, model, desired)
	rayParams.FilterDescendantsInstances = { model, player.Character }
	local origin = root.Position + Vector3.new(0, 2, 0)
	local function cast(dir)
		local r = Workspace:Raycast(origin, dir * 28, rayParams)
		return r and r.Distance or 28
	end
	local fwd = cast(desired)
	if fwd >= 22 then return desired, false end
	local best, bestD = desired, fwd
	for _, a in ipairs({ 25, -25, 50, -50, 80, -80 }) do
		local d = CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(desired)
		local dist = cast(d)
		if dist > bestD + 2 then best, bestD = d, dist end
	end
	return best, true
end

local function planDrivePath(from, to)
	local wps = nil
	pcall(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 5, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 18 })
		path:ComputeAsync(from, to)
		if path.Status == Enum.PathStatus.Success then
			wps = {}
			for _, w in ipairs(path:GetWaypoints()) do wps[#wps + 1] = w.Position end
		end
	end)
	return wps
end

-- คืนค่า ok, เหตุผล
local function driveBlocking(target, stopDist, token, label)
	if not VIM then return false, "ตัวรันไม่รองรับ VirtualInputManager (ขับอัตโนมัติไม่ได้)" end
	local model = myVehicle()
	local root = vehRoot(model)
	if not (model and root and seated()) then return false, "ยังไม่ได้นั่งรถ" end
	Drive.active, Drive.dest, Drive.status = true, label or "-", "วางเส้นทาง"
	pcall(function() BKPin.set("care", target.X, target.Z, label or "จุดหมาย") end)
	local wps = planDrivePath(root.Position, target) or { target }
	local offSince = nil
	local idx, t0 = 1, os.clock()
	local lastProgress, lastPos, wHeldSince = os.clock(), root.Position, nil
	local prepared, calibrated = false, false
	local result, why = false, "หยุด"
	while Drive.token == token and BK.alive do
		if not seated() then why = "ตกจากรถ/ลงจากรถ" break end
		model = myVehicle() or model
		root = vehRoot(model) or root
		local pos = root.Position
		local dest = (flat(target) - flat(pos)).Magnitude
		if dest <= stopDist then result, why = true, "ถึงจุดหมาย" break end
		if os.clock() - t0 > 240 then why = "ขับหมดเวลา" break end

		local wp = wps[idx]
		while wp and idx < #wps and (flat(pos) - flat(wp)).Magnitude < 14 do idx = idx + 1 wp = wps[idx] end
		-- [v1.33] ออกนอกเส้นทาง: ห่างจากจุดนำทางใกล้เคียงทุกจุดเกิน 55 stud นานเกิน 3 วินาที -> วางเส้นทางใหม่
		do
			local best = math.huge
			for k = math.max(1, idx - 3), math.min(#wps, idx + 4) do
				local d = (flat(pos) - flat(wps[k])).Magnitude
				if d < best then best = d end
			end
			if best > 55 then
				offSince = offSince or os.clock()
				if os.clock() - offSince > 3 then
					Drive.status = "ออกนอกเส้นทาง: วางเส้นทางใหม่"
					wps = planDrivePath(pos, target) or { target }
					idx, offSince = 1, nil
					wp = wps[idx]
				end
			else
				offSince = nil
			end
		end
		local vel = root.AssemblyLinearVelocity
		local spd = vel.Magnitude * 1.008
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
		-- เรียนรู้ทิศหน้ารถ (บางโมเดลหันกลับด้าน)
		if keyDown.W and spd > 8 and not calibrated and wHeldSince and os.clock() - wHeldSince > 0.8 then
			local dot = flat(vel).Unit:Dot(look.Unit)
			BK.fwdSign = dot >= 0 and 1 or -1
			calibrated = true
		end
		local hd
		if flat(vel).Magnitude > 5 and keyDown.W then hd = flat(vel).Unit else hd = look.Unit * BK.fwdSign end
		local toWp = flat(wp) - flat(pos)
		local desired = toWp.Magnitude > 0.5 and toWp.Unit or hd
		local avoiding = false
		if BK.cfg.avoid then desired, avoiding = avoidVector(root, model, desired) end
		local cross = hd:Cross(desired).Y
		local ang = math.deg(math.acos(math.clamp(hd:Dot(desired), -1, 1)))
		local maxK = BK.cfg.targetKmh
		if ang > 60 then maxK = math.min(maxK, 22) elseif ang > 30 then maxK = math.min(maxK, 40) end
		if avoiding then maxK = math.min(maxK, 35) end
		if dest < 60 then maxK = math.min(maxK, math.max(12, dest * 0.6)) end

		-- เตรียมรถครั้งแรก: ถ้ากด W แล้วไม่ขยับ ให้สตาร์ท (R) และเก็บขาตั้ง (K) หนึ่งครั้ง
		if not prepared and wHeldSince and os.clock() - wHeldSince > 1.6 and spd < 1.5 then
			prepared = true
			Drive.status = "สตาร์ทเครื่อง/เก็บขาตั้ง"
			releaseAll()
			tapKey("R", 0.15) task.wait(0.8) tapKey("K", 0.15) task.wait(0.6)
			wHeldSince = nil
		end

		if spd < maxK then
			setKey("S", false) setKey("W", true)
			if not wHeldSince then wHeldSince = os.clock() end
		else
			setKey("W", false)
			wHeldSince = nil
			setKey("S", spd > maxK + 12)
		end
		setKey("A", cross > 0.1)
		setKey("D", cross < -0.1)
		Drive.status = string.format("ขับ %s • %d km/h • เหลือ %d m%s", label or "-", math.floor(spd), math.floor(dest), avoiding and " • หลบสิ่งกีดขวาง" or "")

		-- ตรวจรถติด
		if (pos - lastPos).Magnitude > 1.2 then lastProgress, lastPos = os.clock(), pos end
		if wHeldSince and os.clock() - wHeldSince > 2.5 then
			if os.clock() - lastProgress > (State.StuckStopSeconds or 4) then
				Drive.stuckCount = Drive.stuckCount + 1
				alert("stuck", "รถติดค้าง", "ตำแหน่ง " .. math.floor(pos.X) .. "," .. math.floor(pos.Z) .. " (ครั้งที่ " .. Drive.stuckCount .. ")", 90)
				Drive.status = "รถติด: ถอยหลังแก้ไข"
				releaseAll()
				if cross > 0 then setKey("D", true) else setKey("A", true) end
				setKey("S", true)
				task.wait(1.3)
				releaseAll()
				lastProgress, lastPos = os.clock(), root.Position
				wps = planDrivePath(root.Position, target) or { target } -- [v1.33] วางเส้นทางใหม่หลังแก้รถติด
				idx = 1
				if Drive.stuckCount > 5 then why = "ติดค้างหลายครั้ง" break end
			end
		end
		task.wait(0.07)
	end
	releaseAll()
	Drive.active = false
	pcall(function() BKPin.clear("care") end)
	Drive.status = result and "ถึงจุดหมายแล้ว" or ("หยุด: " .. why)
	return result, why
end

function Drive.stopAll(reason)
	Drive.token = (Drive.token or 0) + 1
	Nav.token = Nav.token + 1
	Drive.active = false
	releaseAll()
	pcall(function() BKPin.clear("care") end)
	Drive.status = reason or "หยุด"
end
Drive.token = 0

-- ---------- ghost traffic (ไร้แรงชนกับรถ/ผู้เล่นอื่น เฉพาะฝั่งเรา) ----------
local Ghost = { saved = setmetatable({}, { __mode = "k" }), seen = setmetatable({}, { __mode = "k" }) }
local function ghostModel(m)
	local t = os.clock()
	if Ghost.seen[m] and t - Ghost.seen[m] < 4 then return end
	Ghost.seen[m] = t
	for _, d in ipairs(m:GetDescendants()) do
		-- [v1.34] จดค่าเดิมผ่าน CollisionKeeper (ชิ้นที่ nav จองอยู่แล้วก็ลงชื่อเจ้าของ ghost เพิ่มด้วย)
		if d:IsA("BasePart") and (d.CanCollide or CollisionKeeper.has(d)) then
			CollisionKeeper.disable(d, "ghost")
		end
	end
end
function Ghost.tick()
	local mine = myVehicle()
	local sv = Workspace:FindFirstChild("SpawnedVehicles")
	if sv then
		for _, m in ipairs(sv:GetChildren()) do
			if m ~= mine and m:IsA("Model") then ghostModel(m) end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then ghostModel(p.Character) end
	end
end
function Ghost.restore()
	-- [v1.34] คืนค่าเดิมผ่าน CollisionKeeper (ไม่บังคับ true ให้ทุกชิ้นเหมือนเดิม)
	CollisionKeeper.release("ghost")
	Ghost.seen = setmetatable({}, { __mode = "k" })
end

-- ---------- garage (เลือกรถผ่านหน้าต่าง MY VEHICLES ของเกม) ----------
local Garage = { selected = nil, status = "ว่าง" }
local function garageGui() return pg() and pg():FindFirstChild("GarageWindow") end
function Garage.list()
	local g = garageGui()
	local out = {}
	local list = g and g:FindFirstChild("List", true)
	if not list then return out end
	for _, item in ipairs(list:GetChildren()) do
		local card = item:FindFirstChild("Card")
		if card then
			local title = card:FindFirstChild("Title", true)
			local sub = card:FindFirstChild("Sub", true)
			local kind = card:FindFirstChild("Kind", true)
			local subT = sub and sub.Text or ""
			out[#out + 1] = {
				key = item.Name, card = card,
				title = title and title.Text or item.Name,
				kind = kind and kind.Text or "",
				owned = not subT:find("฿", 1, true),
			}
		end
	end
	return out
end
function Garage.ensureOpen()
	local g = garageGui()
	if not g then return false end
	local panel = g:FindFirstChild("GaragePanel")
	local function isOpen()
		return g.Enabled and panel and panel.Visible and panel.AbsoluteSize.X > 10
	end
	if isOpen() then return true end
	tapKey("G", 0.1)
	for _ = 1, 8 do
		task.wait(0.25)
		if isOpen() then return true end
	end
	return isOpen()
end
function Garage.spawn(key)
	if not Garage.ensureOpen() then Garage.status = "เปิดหน้าต่างโรงรถไม่ได้ (กด G ในเกมแล้วลองใหม่)" return false end
	for _, e in ipairs(Garage.list()) do
		if e.key == key then
			clickGuiButtonSafe(e.card)
			task.wait(0.5)
			local g = garageGui()
			for _, b in ipairs(g:GetDescendants()) do
				if b:IsA("TextButton") and b.Visible and b ~= e.card then
					local nm = (b.Name .. " " .. b.Text):lower()
					if nm:find("spawn", 1, true) or nm:find("เรียก", 1, true) then
						clickGuiButtonSafe(b)
						Garage.status = "เรียกรถ: " .. e.title
						log("เรียกรถ " .. e.title)
						task.wait(1.2)
						local close = g:FindFirstChild("Close", true)
						if close then clickGuiButtonSafe(close) end
						return true
					end
				end
			end
			Garage.status = "ไม่พบปุ่ม Spawn (เลือกรถแล้ว กดเองได้)"
			return false
		end
	end
	Garage.status = "ไม่พบรถ " .. tostring(key) .. " ในโรงรถ"
	return false
end

-- ---------- boarding ----------
local function boardVehicle(token)
	if seated() then return true end
	local m = myVehicle()
	if not m then
		if Garage.selected then
			Garage.spawn(Garage.selected)
			task.wait(1.5)
			m = myVehicle()
		end
		if not m then return false, "ไม่มีรถของคุณในแมพ (เลือกรถในแท็บโรงรถก่อน)" end
	end
	local root = vehRoot(m)
	local hp = rootPos()
	if root and hp and (hp - root.Position).Magnitude > 7 then
		local ok = walkBlocking(root.Position, 5, token)
		if not ok then return false, "เดินไปที่รถไม่ได้" end
	end
	for _ = 1, 3 do
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled then
				local t = ((d.ActionText or "") .. " " .. (d.ObjectText or "")):lower()
				if (t:find("drive", 1, true) or t:find("ขับ", 1, true)) and not t:find("ride", 1, true) then
					firePromptSafe(d)
					task.wait(1)
					if seated() then return true end
				end
			end
		end
		task.wait(0.5)
	end
	return seated(), "ขึ้นรถไม่สำเร็จ"
end

-- ---------- care: fuel / repair ----------
local Care = { busy = false, lastRefuel = 0, lastRepair = 0, repairMsg = "-" }
local function runTask(name, fn)
	Drive.token = Drive.token + 1
	Nav.token = Nav.token + 1
	local token = Drive.token
	Care.busy = true
	task.spawn(function()
		local ok, err = pcall(fn, token)
		if not ok then log(name .. " error: " .. tostring(err)) setStatus(name, "Error: " .. tostring(err):sub(1, 60)) end
		releaseAll()
		Care.busy = false
	end)
end

local function refuelFlow(token)
	setStatus("fuel", "เตรียมรถ")
	local ok, why = boardVehicle(token)
	if not ok then setStatus("fuel", "หยุด: " .. tostring(why)) return end
	local from = rootPos() or Vector3.zero
	local st = DEST.fuel(from)
	setStatus("fuel", "ขับไปปั๊มน้ำมัน")
	local okD, whyD = driveBlocking(st, 7, token, "ปั๊มน้ำมัน")
	if not okD then setStatus("fuel", "หยุด: " .. tostring(whyD)) return end
	task.wait(0.8)
	local m = myVehicle()
	local pr = m and m:FindFirstChild("RefuelPrompt", true)
	local startFuel = readGauge("FUEL") or 0
	for i = 1, 10 do
		if Drive.token ~= token then return end
		local f = readGauge("FUEL")
		if f and f >= 97 then break end
		setStatus("fuel", "เติมน้ำมัน " .. tostring(f or "?") .. "%")
		if pr and pr.Enabled then firePromptSafe(pr) end
		task.wait(1.0)
		local f2 = readGauge("FUEL")
		if f2 == f and i >= 2 then tapKey("F", 0.7) task.wait(0.8) end
	end
	local endFuel = readGauge("FUEL") or 0
	setStatus("fuel", "เสร็จ: " .. tostring(endFuel) .. "%")
	if endFuel > startFuel then
		alert("refuelDone", "เติมน้ำมันเสร็จ", "น้ำมัน " .. startFuel .. "% → " .. endFuel .. "%", 60)
	else
		setStatus("fuel", "เติมไม่ขึ้น: ตรวจว่าจอดชิดหัวจ่าย/เงินพอ")
		log("เติมน้ำมันไม่เพิ่ม: RefuelPrompt " .. ((pr and pr.Enabled) and "พร้อม" or "ยังไม่เปิด"))
	end
end
function Care.refuelNow() if not Care.busy then runTask("fuel", refuelFlow) end end

function Care.tryRepair()
	local gui = pg() and pg():FindFirstChild("VehicleCareTop")
	local btn = gui and gui:FindFirstChild("Repair", true)
	if btn and btn:IsA("GuiButton") and btn.Visible then
		local ok = clickGuiButtonSafe(btn)
		Care.repairMsg = ok and "กดซ่อมแล้ว" or "ตัวรันไม่รองรับ firesignal"
		log(Care.repairMsg)
		return ok
	end
	Care.repairMsg = "ปุ่มซ่อมยังไม่ขึ้น (ต้องมีกล่องซ่อม/รถเสียหาย)"
	return false
end

-- ---------- go to destination ----------
local function goFlow(which)
	return function(token)
		local ok, why = boardVehicle(token)
		if not ok then Drive.status = "หยุด: " .. tostring(why) return end
		local from = rootPos() or Vector3.zero
		local p = DEST[which](from)
		if not p then Drive.status = "ไม่พบปลายทาง (ร้านยังไม่โหลด/ยังไม่เปิด)" return end
		local label = ({ fuel = "ปั๊มน้ำมัน", tune = "ร้านจูน", piston = "ร้านลูกสูบ", repair = "อู่ซ่อม" })[which]
		driveBlocking(p, 10, token, label)
	end
end
function Care.go(which) if not Care.busy then runTask("drive", goFlow(which)) end end

-- ---------- piston shop (อ่านหน้าต่างร้านจริงของเกม) ----------
local Piston = { rows = {}, open = false, shopSeen = nil, closesIn = nil, inStock = {}, status = "ยังไม่พบร้าน" }
local function digits(s) local d = tostring(s or ""):gsub("[^%d]", "") return tonumber(d) end
function Piston.read()
	local sg = pg() and pg():FindFirstChild("PistonShop")
	local win = sg and sg:FindFirstChild("PistonShopWindow")
	local sf = win and win:FindFirstChild("ScrollingFrame", true)
	Piston.rows = {}
	Piston.open = win and win.Visible and win.AbsoluteSize.X > 10 or false
	if not sf then return end
	for _, fr in ipairs(sf:GetChildren()) do
		if fr:IsA("GuiObject") then
			local btn = fr:FindFirstChild("Button")
			if btn and btn:IsA("GuiButton") then
				local size, sold, caption = nil, false, ""
				for _, d in ipairs(fr:GetDescendants()) do
					if d:IsA("TextLabel") then
						local t = d.Text
						if not size and t:match("^%s*%d+%s*$") then size = tonumber(t) end
						if t:find("หมด", 1, true) then sold = true end
						if d.Name == "Caption" then caption = t end
					end
				end
				if size then
					Piston.rows[#Piston.rows + 1] = { size = size, price = digits(caption), sold = sold, btn = btn, caption = caption }
				end
			end
		end
	end
end
function Piston.tick()
	local ps = Workspace:FindFirstChild("PistonShop")
	local spot = ps and ps:GetAttribute("Spot")
	local closes = ps and ps:GetAttribute("ClosesAt")
	if ps then
		if Piston.shopSeen ~= tostring(spot) then
			Piston.shopSeen = tostring(spot)
			local p = posOf(ps:FindFirstChild("Seller") or ps)
			alert("shop", "ร้านลูกสูบเปิดแล้ว", "จุด " .. tostring(spot) .. (p and (" พิกัด " .. math.floor(p.X) .. "," .. math.floor(p.Z)) or ""), 60)
		end
		Piston.closesIn = type(closes) == "number" and math.max(0, math.floor(closes - os.time())) or nil
		Piston.status = "ร้านเปิดอยู่" .. (Piston.closesIn and (" • ปิดใน " .. math.floor(Piston.closesIn / 60) .. " นาที") or "")
	else
		Piston.shopSeen = nil
		Piston.closesIn = nil
		Piston.status = "ยังไม่พบร้านลูกสูบในแมพ (อาจยังไม่โหลด/ปิดอยู่)"
	end
	Piston.read()
	local c = BK.cfg
	for _, r in ipairs(Piston.rows) do
		if r.size >= c.pistonMin and r.size <= c.pistonMax and not r.sold then
			if not Piston.inStock[r.size] then
				Piston.inStock[r.size] = true
				if c.pistonAlert then
					alert("piston", "ลูกสูบ " .. r.size .. " มม. มีของ", "ราคา ฿" .. tostring(r.price or "?") .. " • " .. Piston.status, 20)
				end
			end
		else
			Piston.inStock[r.size] = nil
		end
	end
	-- ซื้ออัตโนมัติ (ต้องเปิดหน้าต่างร้านค้างไว้เอง / ตั้งเพดานราคาและจำนวน)
	if c.pistonAuto and Piston.open and BK.bought < c.pistonMaxBuy then
		for _, r in ipairs(Piston.rows) do
			if r.size >= c.pistonMin and r.size <= c.pistonMax and not r.sold and r.price and r.price <= c.pistonMaxPrice and BK.bought < c.pistonMaxBuy then
				if clickGuiButtonSafe(r.btn) then
					BK.bought = BK.bought + 1
					log("กดซื้อลูกสูบ " .. r.size .. " มม. ฿" .. tostring(r.price))
					alert("piston", "กดซื้อลูกสูบ " .. r.size .. " มม.", "ราคา ฿" .. tostring(r.price) .. " (ครั้งที่ " .. BK.bought .. "/" .. c.pistonMaxBuy .. ")", 5)
					task.wait(1.5)
					break
				end
			end
		end
	end
end
function Piston.goShop()
	if Care.busy then return end
	runTask("piston", function(token)
		local p = DEST.piston(rootPos() or Vector3.zero)
		if not p then Piston.status = "ไม่พบร้านลูกสูบ" return end
		if seated() then
			driveBlocking(p, 12, token, "ร้านลูกสูบ")
			local _, _, hum = getCharacterParts()
			if hum then hum.Jump = true task.wait(0.8) end
		end
		walkBlocking(p, 6, token)
		local ps = Workspace:FindFirstChild("PistonShop")
		if ps then
			for _, d in ipairs(ps:GetDescendants()) do
				if d:IsA("ProximityPrompt") and d.Enabled then firePromptSafe(d) break end
			end
		end
	end)
end

-- ---------- main loop ----------
local function stopEverything(reason)
	Drive.stopAll(reason or "STOP ALL")
	Care.busy = false
	State.AutoRefuel = false
	State.AutoRepair = false
	BK.cfg.pistonAuto = false
	if BK.cfg.ghost then BK.cfg.ghost = false Ghost.restore() end
	log("STOP ALL: " .. tostring(reason or ""))
end
EmergencyStopHooks[#EmergencyStopHooks + 1] = function(reason) stopEverything(reason) end

task.spawn(function()
	local tPiston, tGhost = 0, 0
	while BK.alive and screenGui.Parent do
		local fuel, engine = readGauge("FUEL"), readGauge("ENGINE")
		BK.tel.fuel, BK.tel.engine = fuel, engine
		local m = myVehicle()
		BK.tel.vehicle = m and m.Name:gsub("_" .. player.Name .. "_%d+$", "") or "ไม่มีรถในแมพ"
		local root = vehRoot(m)
		BK.tel.speed = root and math.floor(root.AssemblyLinearVelocity.Magnitude * 1.008) or 0
		BK.tel.seated = seated()
		local hp = rootPos()
		if hp then
			local sp, sd = DEST.fuel(hp)
			BK.tel.fuelDist = sd and math.floor(sd) or nil
		end

		if fuel and fuel < State.RefuelBelowPercent then
			alert("lowFuel", "น้ำมันเหลือน้อย", "เหลือ " .. fuel .. "% (ต่ำกว่า " .. State.RefuelBelowPercent .. "%)", 300)
			if State.AutoRefuel and not Care.busy and os.clock() - Care.lastRefuel > 60 then
				Care.lastRefuel = os.clock()
				Care.refuelNow()
			end
		end
		if engine and engine < State.RepairBelowPercent then
			alert("repair", "รถเสียหาย", "สภาพเครื่อง " .. engine .. "% (ต่ำกว่า " .. State.RepairBelowPercent .. "%)", 300)
			if State.AutoRepair and os.clock() - Care.lastRepair > 12 then
				Care.lastRepair = os.clock()
				Care.tryRepair()
			end
		end
		if not fuel then setStatus("fuel", State.AutoRefuel and "รอ HUD น้ำมัน (ขึ้นรถก่อน)" or (BK.status.fuel or "ปิดอยู่")) end

		local t = os.clock()
		if BK.cfg.ghost and t - tGhost > 1 then tGhost = t pcall(Ghost.tick) end
		if t - tPiston > 3 then tPiston = t pcall(Piston.tick) end
		task.wait(0.5)
	end
	releaseAll()
	pcall(Ghost.restore)
end)

-- ======================= UI PREMIUM (Graphite + Neon Lime) =======================
-- Main Window เดียว: Header / Sidebar / Content / Footer  (ไม่มีหน้าต่างแยก ไม่มี ScreenGui ซ้ำ)
local C = {
	bg = Color3.fromRGB(12, 14, 16), panel = Color3.fromRGB(19, 22, 25), card = Color3.fromRGB(25, 29, 32),
	line = Color3.fromRGB(42, 48, 51), text = Color3.fromRGB(235, 239, 240), mute = Color3.fromRGB(135, 145, 149),
	cyan = Color3.fromRGB(166, 255, 35), violet = Color3.fromRGB(95, 173, 23), good = Color3.fromRGB(166, 255, 35),
	warn = Color3.fromRGB(255, 190, 70), bad = Color3.fromRGB(255, 90, 90), active = Color3.fromRGB(37, 46, 30),
}
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o) end
local function stroke(o, col, th, tr)
	return mk("UIStroke", { Color = col, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function grad(o, c1, c2, rot)
	return mk("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 0 }, o)
end
local function pad(o, p)
	return mk("UIPadding", { PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p), PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p) }, o)
end
local function list(o, gap)
	return mk("UIListLayout", { Padding = UDim.new(0, gap or 8), SortOrder = Enum.SortOrder.LayoutOrder }, o)
end
local function refresher(fn) BK.refreshers[#BK.refreshers + 1] = fn fn() end

local old = uiParent:FindFirstChild("BALL_KUN_VV1_PREMIUM")
if old then old:Destroy() end
local gui = mk("ScreenGui", { Name = "BALL_KUN_VV1_PREMIUM", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 1000000 }, uiParent)
local function cleanup()
	BK.alive = false
	releaseAll()
	pcall(Ghost.restore)
	disconnectAll()
	pcall(function() gui:Destroy() end)
	if BK.genv and BK.genv.__BK_PREMIUM_CLEANUP == BK.cleanup then BK.genv.__BK_PREMIUM_CLEANUP = nil end
end
BK.cleanup = cleanup
__bkHook(function() pcall(cleanup) end)
if BK.genv then BK.genv.__BK_PREMIUM_CLEANUP = cleanup end
track(screenGui.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end))

local BASE_W, BASE_H = 680, 440
local W, H = BASE_W, BASE_H
local touch = UserInputService.TouchEnabled
local BTN = touch and 44 or 38 -- พื้นที่สัมผัสขั้นต่ำบนมือถือ
local win = mk("Frame", { Name = "Main", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2), BackgroundColor3 = C.bg, ClipsDescendants = true }, gui)
corner(win, 14)
stroke(win, C.line, 1.2, 0)
local uiscale = mk("UIScale", {}, win)
BK.compact = false
BK.userCompact = false
local setCompact = nil
local minimized = false
-- ปรับขนาดหน้าต่างให้พอดีจอ: สเกลตัวอักษรไม่ต่ำกว่า 0.7 แล้วหดความกว้าง/สูงของหน้าต่างให้ไม่ล้นขอบ
local function applyScale()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min(vp.X / 560, vp.Y / 380, 1.15), 0.7, 1.3) * BK.cfg.uiScale
	s = math.clamp(s, 0.5, 1.6)
	uiscale.Scale = s
	W = math.clamp(math.floor(vp.X / s) - 16, 340, BASE_W)
	H = math.clamp(math.floor(vp.Y / s) - 16, 250, BASE_H)
	win.Size = UDim2.fromOffset(W, minimized and 52 or H)
	win.Position = UDim2.new(0.5, -W / 2, 0.5, -(minimized and 52 or H) / 2)
	if setCompact then setCompact(W < 600 or BK.userCompact == true) end
end
if Workspace.CurrentCamera then
	track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale))
end

-- ตัวจัดการลาก (Drag) กลาง: ใช้ Connection เดียวสำหรับทั้งหน้าต่างและสไลเดอร์ทุกตัว
local activeDrag = nil
track(UserInputService.InputChanged:Connect(function(i)
	if activeDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		activeDrag(i.Position)
	end
end))
local function beginDrag(input, fn, onEnd)
	activeDrag = fn
	input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			if activeDrag == fn then activeDrag = nil end
			if onEnd then pcall(onEnd) end
		end
	end)
end

-- ---------- Header ----------
local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.panel }, win)
corner(header, 14)
mk("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, header)
local logo = mk("TextLabel", {
	Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(12, 8), BackgroundColor3 = C.cyan, Text = "BK", Font = Enum.Font.GothamBold,
	TextSize = 15, TextColor3 = C.bg,
}, header)
corner(logo, 10)
mk("TextLabel", {
	Size = UDim2.new(1, -250, 0, 22), Position = UDim2.fromOffset(56, 6), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.cyan, Text = "BALL KUN VV1",
}, header)
mk("TextLabel", {
	Size = UDim2.new(1, -250, 0, 14), Position = UDim2.fromOffset(56, 28), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.mute, Text = "PREMIUM CONTROL • MAHANAKHON RACING • v1.38",
}, header)
local statusPill = mk("TextLabel", {
	Size = UDim2.fromOffset(96, 24), Position = UDim2.new(1, -258, 0, 14), BackgroundColor3 = C.card, Font = Enum.Font.GothamBold, TextSize = 10,
	TextColor3 = C.good, Text = "● ONLINE",
}, header)
corner(statusPill, 12)
local function headerBtn(txt, x)
	local b = mk("TextButton", {
		Size = UDim2.fromOffset(touch and 40 or 34, touch and 36 or 30), Position = UDim2.new(1, x - (touch and 6 or 0), 0, touch and 8 or 11), BackgroundColor3 = C.card, Text = txt, Font = Enum.Font.GothamBold,
		TextSize = 16, TextColor3 = C.text, AutoButtonColor = false,
	}, header)
	corner(b, 8)
	stroke(b, C.line, 1, 0)
	return b
end
local minBtn = headerBtn("—", touch and -132 or -108)
local compactBtn = headerBtn("◧", touch and -88 or -72)
local closeBtn = headerBtn("✕", touch and -44 or -36)
header.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		local startIn, startPos = i.Position, win.Position
		beginDrag(i, function(pos)
			local d = pos - startIn
			local s = uiscale.Scale
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / s, startPos.Y.Scale, startPos.Y.Offset + d.Y / s)
		end)
	end
end)

-- ---------- Footer ----------
local footer = mk("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), BackgroundColor3 = C.panel }, win)
local footL = mk("TextLabel", {
	Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.mute, Text = "BALL KUN • VV1 • v1.38",
}, footer)
local footR = mk("TextLabel", {
	Size = UDim2.new(0.5, -12, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.cyan, Text = "พร้อมใช้งาน", TextTruncate = Enum.TextTruncate.AtEnd,
}, footer)

-- ---------- Sidebar + Content ----------
local sidebar = mk("ScrollingFrame", {
	Size = UDim2.new(0, 160, 1, -52 - 24 - 16), Position = UDim2.fromOffset(8, 60), BackgroundColor3 = C.panel, BorderSizePixel = 0,
	ScrollBarThickness = 2, ScrollBarImageColor3 = C.cyan, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, win)
corner(sidebar, 10)
stroke(sidebar, C.line, 1, 0)
pad(sidebar, 6)
list(sidebar, 4)
local content = mk("Frame", {
	Size = UDim2.new(1, -184, 1, -52 - 24 - 16), Position = UDim2.fromOffset(176, 60), BackgroundColor3 = C.panel, ClipsDescendants = true,
}, win)
corner(content, 10)
stroke(content, C.line, 1, 0)

setCompact = function(v)
	BK.compact = v
	local sw = v and 54 or 160
	sidebar.Size = UDim2.new(0, sw, 1, -92)
	content.Position = UDim2.fromOffset(sw + 16, 60)
	content.Size = UDim2.new(1, -(sw + 24), 1, -92)
	for _, t in ipairs(BK.tabs) do
		t.name.Visible, t.desc.Visible = not v, not v
	end
end

local function newPage(id, icon, label, desc)
	local page = mk("ScrollingFrame", {
		Name = id, Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.cyan, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false,
	}, content)
	list(page, 8)
	mk("UIPadding", { PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 6) }, page)
	local tab = mk("TextButton", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.card, Text = "", AutoButtonColor = false, LayoutOrder = #BK.tabs + 1 }, sidebar)
	corner(tab, 8)
	local accent = mk("Frame", { Size = UDim2.fromOffset(3, 24), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = C.cyan, Visible = false }, tab)
	corner(accent, 2)
	local ic = mk("TextLabel", { Size = UDim2.fromOffset(34, 44), BackgroundTransparency = 1, Text = icon, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.mute }, tab)
	local nm = mk("TextLabel", {
		Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(36, 6), BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamBold, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, TextTruncate = Enum.TextTruncate.AtEnd,
	}, tab)
	local ds = mk("TextLabel", {
		Size = UDim2.new(1, -40, 0, 14), Position = UDim2.fromOffset(36, 24), BackgroundTransparency = 1, Text = desc, Font = Enum.Font.Gotham, TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.mute, TextTruncate = Enum.TextTruncate.AtEnd,
	}, tab)
	local entry = { id = id, btn = tab, accent = accent, icon = ic, name = nm, desc = ds }
	BK.pages[id], BK.tabs[#BK.tabs + 1] = page, entry
	tab.Activated:Connect(function() BK.switchPage(id) end)
	return page
end
function BK.switchPage(id)
	for _, t in ipairs(BK.tabs) do
		local on = t.id == id
		BK.pages[t.id].Visible = on
		t.btn.BackgroundColor3 = on and C.active or C.card
		t.accent.Visible = on
		t.icon.TextColor3 = on and C.cyan or C.mute
		t.name.TextColor3 = on and C.cyan or C.text
	end
	BK.activePage = id
end

local function card(parent, titleText)
	local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.card }, parent)
	corner(f, 8)
	stroke(f, C.line, 1, 0)
	pad(f, 10)
	list(f, 7)
	if titleText then
		mk("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.cyan, Text = titleText, LayoutOrder = 0,
		}, f)
	end
	return f
end
local function text(parent, textOrFn, col, size)
	local l = mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.Gotham,
		TextSize = size or 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = col or C.text, Text = "",
	}, parent)
	if type(textOrFn) == "function" then
		refresher(function() local ok, v = pcall(textOrFn) l.Text = ok and tostring(v) or "—" end)
	else
		l.Text = tostring(textOrFn)
	end
	return l
end
local function button(parent, label, cb, col)
	local b = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, BTN), BackgroundColor3 = col or C.card, Text = label, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = col and Color3.new(1, 1, 1) or C.text, AutoButtonColor = false,
	}, parent)
	corner(b, 8)
	stroke(b, col or C.cyan, 1, col and 0.3 or 0.65)
	b.MouseEnter:Connect(function() b.BackgroundColor3 = col and col or Color3.fromRGB(34, 39, 42) end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = col or C.card end)
	b.Activated:Connect(function() pcall(cb) end)
	return b
end
local function toggle(parent, label, get, set, hint)
	local row = mk("TextButton", { Size = UDim2.new(1, 0, 0, hint and 52 or math.max(BTN, 38)), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, parent)
	mk("TextLabel", {
		Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(0, hint and 4 or 9), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, Text = label,
	}, row)
	if hint then
		mk("TextLabel", {
			Size = UDim2.new(1, -60, 0, 24), Position = UDim2.fromOffset(0, 24), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.mute, Text = hint,
		}, row)
	end
	local pill = mk("Frame", { Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -40, 0.5, -11), BackgroundColor3 = Color3.fromRGB(55, 60, 63) }, row)
	corner(pill, 11)
	local knob = mk("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(235, 235, 235) }, pill)
	corner(knob, 8)
	local function sync()
		local on = get() and true or false
		pill.BackgroundColor3 = on and C.violet or Color3.fromRGB(55, 60, 63)
		knob.BackgroundColor3 = on and C.cyan or Color3.fromRGB(235, 235, 235)
		knob.Position = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
	end
	refresher(sync)
	row.Activated:Connect(function() pcall(function() set(not get()) end) sync() saveCfg() end)
end
local function slider(parent, label, minV, maxV, unit, get, set, step)
	step = step or 1
	local row = mk("Frame", { Size = UDim2.new(1, 0, 0, touch and 54 or 46), BackgroundTransparency = 1 }, parent)
	local lbl = mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, Text = label,
	}, row)
	local track = mk("TextButton", { Size = UDim2.new(1, 0, 0, touch and 10 or 6), Position = UDim2.fromOffset(0, touch and 32 or 29), BackgroundColor3 = Color3.fromRGB(53, 59, 62), Text = "", AutoButtonColor = false }, row)
	corner(track, 3)
	local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.cyan }, track)
	corner(fill, 3)
	local knob = mk("Frame", { Size = UDim2.fromOffset(touch and 22 or 14, touch and 22 or 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = C.cyan }, track)
	corner(knob, 11)
	local function sync()
		local v = get()
		local r = math.clamp((v - minV) / (maxV - minV), 0, 1)
		fill.Size = UDim2.fromScale(r, 1)
		knob.Position = UDim2.fromScale(r, 0.5)
		lbl.Text = label .. "   " .. tostring(v) .. " " .. (unit or "")
	end
	refresher(sync)
	local function apply(x)
		local r = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = minV + (maxV - minV) * r
		v = math.floor(v / step + 0.5) * step
		v = math.floor(v * 1000 + 0.5) / 1000
		pcall(set, math.clamp(v, minV, maxV))
		sync()
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			apply(i.Position.X)
			beginDrag(i, function(pos) apply(pos.X) end, saveCfg)
		end
	end)
end
local function bar(parent, label, get, col)
	local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, parent)
	local lbl = mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, Text = label,
	}, row)
	local track = mk("Frame", { Size = UDim2.new(1, 0, 0, 7), Position = UDim2.fromOffset(0, 19), BackgroundColor3 = Color3.fromRGB(53, 59, 62) }, row)
	corner(track, 4)
	local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = col or C.good }, track)
	corner(fill, 4)
	refresher(function()
		local v = get()
		fill.Size = UDim2.fromScale(math.clamp((v or 0) / 100, 0, 1), 1)
		fill.BackgroundColor3 = (v and v < 25) and C.bad or ((v and v < 50) and C.warn or (col or C.good))
		lbl.Text = label .. "   " .. (v and (tostring(v) .. "%") or "— (ขึ้นรถเพื่อดูค่า)")
	end)
end
local function stat(parent, title, fn, desc)
	local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C.card }, parent)
	corner(f, 8)
	stroke(f, C.line, 1, 0)
	mk("TextLabel", { Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 5), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.mute, Text = title }, f)
	local v = mk("TextLabel", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 19), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.cyan, Text = "—", TextTruncate = Enum.TextTruncate.AtEnd }, f)
	if desc then mk("TextLabel", { Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 43), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.mute, Text = desc }, f) end
	refresher(function() local ok, r = pcall(fn) v.Text = ok and tostring(r) or "—" end)
	return f
end
local function section(parent, t, hint)
	local w = mk("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, parent)
	mk("TextLabel", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.cyan, Text = t }, w)
	mk("TextLabel", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 19), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.mute, Text = hint or "" }, w)
end
local function dropdown(parent, label, options, get, set)
	local b = button(parent, "", function() end)
	local function sync() b.Text = label .. "  ›  " .. tostring(get()) end
	b.Activated:Connect(function()
		local cur, idx = get(), 1
		for i, o in ipairs(options) do if o == cur then idx = i end end
		set(options[(idx % #options) + 1])
		sync()
		saveCfg()
	end)
	refresher(sync)
	return b
end

-- ---------- ข้อมูลจาก HUD ----------
local function readCash()
	local hud = pg() and pg():FindFirstChild("GameHud")
	local money = hud and hud:FindFirstChild("Money", true)
	if not money then return nil end
	for _, d in ipairs(money:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text:match("%d") then return d.Text end
	end
	return nil
end
local function fmtTime(s)
	s = math.floor(s)
	return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end
local startedAt = os.clock()

-- ---------- Pages (10 หมวด) ----------
local p01 = newPage("p01", "⌂", "01 ภาพรวม", "สรุปผู้เล่นและสถานะ")
local p02 = newPage("p02", "▣", "02 ศูนย์งาน", "อาชีพและประวัติงาน")
local p03 = newPage("p03", "➤", "03 ศูนย์ไรเดอร์", "ส่งอาหาร / ส่งคน")
local p04 = newPage("p04", "◆", "04 รถและดูแลรถ", "น้ำมัน ซ่อม ขับ โรงรถ")
local p05 = newPage("p05", "⚙", "05 เครื่องยนต์/ECU", "ลูกสูบ ร้านจูน ECU")
local p06 = newPage("p06", "฿", "06 เงินและกระเป๋า", "ยอดเงินและไอเทม")
local p07 = newPage("p07", "◉", "07 มอนิเตอร์", "สถานะระบบ")
local p08 = newPage("p08", "☰", "08 ตั้งค่า", "UI แจ้งเตือน บันทึก")
local p09 = newPage("p09", "⌘", "09 คอนโซล", "Log และข้อผิดพลาด")
local p10 = newPage("p10", "★", "10 เกี่ยวกับ", "ผู้พัฒนาและเวอร์ชัน")

-- 01 ภาพรวม
do
	section(p01, "ภาพรวมระบบ", "สรุปข้อมูลผู้เล่นและสถานะทั้งหมด")
	local pc = mk("Frame", { Size = UDim2.new(1, 0, 0, 86), BackgroundColor3 = C.card }, p01)
	corner(pc, 9)
	stroke(pc, C.line, 1, 0)
	local av = mk("ImageLabel", { Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(12, 14), BackgroundColor3 = C.bg, Image = "" }, pc)
	corner(av, 29)
	stroke(av, C.cyan, 1, 0)
	local avText = mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "BK", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.cyan }, av)
	task.spawn(function()
		local ok, img = pcall(function() return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
		if ok and img and av.Parent then av.Image = img avText.Visible = false end
	end)
	mk("TextLabel", { Size = UDim2.new(1, -94, 0, 22), Position = UDim2.fromOffset(82, 13), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, Text = player.DisplayName, TextTruncate = Enum.TextTruncate.AtEnd }, pc)
	mk("TextLabel", { Size = UDim2.new(1, -94, 0, 17), Position = UDim2.fromOffset(82, 36), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.mute, Text = "@" .. player.Name, TextTruncate = Enum.TextTruncate.AtEnd }, pc)
	mk("TextLabel", { Size = UDim2.new(1, -94, 0, 15), Position = UDim2.fromOffset(82, 56), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.cyan, Text = "USER ID  ·  " .. tostring(player.UserId) }, pc)
	stat(p01, "สถานะผู้เล่น", function() return BK.tel.seated and "กำลังขับรถ" or "ยืนอยู่" end, "จากตัวละครในเกม")
	stat(p01, "เงินสด", function() return readCash() or "—" end, "อ่านจาก HUD เงินของเกม")
	stat(p01, "รถที่ใช้งาน", function() return tostring(BK.tel.vehicle or "—") end, "รถของคุณใน SpawnedVehicles")
	stat(p01, "อาชีพปัจจุบัน", function() return tostring(State.CurrentJob) end, "จากระบบงานเดิม")
	stat(p01, "งานที่ทำสำเร็จ", function() return tostring(State.CompletedJobs) end, "จำนวนรอบงาน")
	local c = card(p01, "สถานะระบบแบบเรียลไทม์")
	text(c, function() return "เติมน้ำมัน: " .. (State.AutoRefuel and "เปิด" or "ปิด") .. " • " .. tostring(BK.status.fuel or "พร้อม") end)
	text(c, function() return "ซ่อมรถ: " .. (State.AutoRepair and "เปิด" or "ปิด") .. " • " .. tostring(Care.repairMsg) end)
	text(c, function() return "ขับ/นำทาง: " .. tostring(Drive.status) end)
	text(c, function() return "ลูกสูบ: " .. tostring(Piston.status) end)
	button(c, "STOP ALL — หยุดทุกระบบ", function() triggerEmergencyStop("กดจาก UI") end, C.bad)
end

-- 02 ศูนย์งาน
do
	section(p02, "ศูนย์งาน", "ข้อมูลอาชีพและสถานะงาน (เชื่อมกับระบบงานเดิม v1.28)")
	stat(p02, "อาชีพปัจจุบัน", function() return tostring(State.CurrentJob) end)
	stat(p02, "จำนวนงานสำเร็จ", function() return tostring(State.CompletedJobs) end)
	stat(p02, "สถานะงาน", function() return tostring(State.WorkStatus) end, "ว่าง / กำลังทำงาน")
	local c = card(p02, "ควบคุมงานอาชีพ")
	toggle(c, "งานช่างก่อสร้าง", function() return State.AutoBuilder end, function(v) State.AutoBuilder = v end, "ใช้ระบบเดินรับงานเดิมของสคริปต์")
	toggle(c, "งานช่างซ่อมรถ", function() return State.AutoMechanic end, function(v) State.AutoMechanic = v end, "ใช้ระบบเดินรับงานเดิมของสคริปต์")
	text(p02, "ประวัติงานละเอียดต่อรายการ: ยังเป็น Placeholder (ระบบเดิมเก็บเฉพาะตัวเลขรวม)", C.warn, 11)
end

-- 03 ศูนย์ไรเดอร์
do
	section(p03, "ศูนย์ไรเดอร์", "ส่งอาหารและส่งผู้โดยสาร (เชื่อมกับระบบ Rider เดิม)")
	stat(p03, "สถานะไรเดอร์", function() return tostring(State.RiderStatus) end)
	stat(p03, "จำนวนงานที่ส่งสำเร็จ", function() return tostring(State.CompletedJobs) end)
	local c = card(p03, "ควบคุมไรเดอร์")
	dropdown(c, "ประเภทงาน", RiderModesList, function() return State.RiderMode end, function(v) State.RiderMode = v end)
	toggle(c, "เปิด Rider Delivery", function() return State.AutoRiderDelivery end, function(v) State.AutoRiderDelivery = v end, "รับงาน → ขับส่งตามระบบเดิม")
	text(p03, "ประวัติการส่งรายรอบ / สถานะคำสั่งซื้อ: Placeholder (ยังไม่มีข้อมูลรายรอบจากระบบเดิม)", C.warn, 11)
end

-- 04 รถและดูแลรถ
do
	section(p04, "รถและดูแลรถ", "ตรวจสภาพรถ เติมน้ำมัน ซ่อม ขับนำทาง เลือกรถ")
	local c0 = card(p04, "สถานะรถ")
	text(c0, function() return "รถ: " .. tostring(BK.tel.vehicle or "—") .. "  •  " .. (BK.tel.seated and "กำลังขับ" or "ไม่ได้นั่ง") .. "  •  " .. tostring(BK.tel.speed or 0) .. " km/h" end, C.text, 12)
	bar(c0, "น้ำมัน", function() return BK.tel.fuel end, C.cyan)
	bar(c0, "ความทนทาน (เครื่อง)", function() return BK.tel.engine end, C.good)

	local c1 = card(p04, "ออโต้เติมน้ำมัน")
	toggle(c1, "เปิดออโต้เติมน้ำมัน", function() return State.AutoRefuel end, function(v) State.AutoRefuel = v end, "ขับไปปั๊ม จอด แล้วกดเติมให้เอง")
	slider(c1, "เติมเมื่อต่ำกว่า", 5, 85, "%", function() return State.RefuelBelowPercent end, function(v) State.RefuelBelowPercent = v end, 5)
	button(c1, "เติมน้ำมันตอนนี้", function() Care.refuelNow() end)
	text(c1, function() return "สถานะ: " .. tostring(BK.status.fuel or "พร้อม") .. (BK.tel.fuelDist and ("  •  ปั๊มใกล้สุด ~" .. BK.tel.fuelDist .. " m") or "") end, C.mute, 11)

	local c2 = card(p04, "ออโต้ซ่อมรถ")
	toggle(c2, "เปิดออโต้ซ่อม", function() return State.AutoRepair end, function(v) State.AutoRepair = v end, "กดปุ่ม REPAIR ของเกมเมื่อรถเสียหาย")
	slider(c2, "ซ่อมเมื่อต่ำกว่า", 5, 90, "%", function() return State.RepairBelowPercent end, function(v) State.RepairBelowPercent = v end, 5)
	button(c2, "ซ่อมตอนนี้", function() Care.tryRepair() end)
	text(c2, function() return "สถานะ: " .. tostring(Care.repairMsg) end, C.mute, 11)

	local c3 = card(p04, "ขับอัตโนมัติ + นำทางอัจฉริยะ")
	button(c3, "ไปปั๊มน้ำมัน", function() Care.go("fuel") end)
	button(c3, "ไปร้านจูน", function() Care.go("tune") end)
	button(c3, "ไปร้านลูกสูบ", function() Care.go("piston") end)
	button(c3, "ไปอู่ซ่อม", function() Care.go("repair") end)
	button(c3, "หยุดขับ", function() Drive.stopAll("หยุดโดยผู้ใช้") Care.busy = false end, C.bad)
	text(c3, function() return Drive.status end, C.cyan, 11)
	toggle(c3, "นำทางอัจฉริยะ", function() return BK.cfg.avoid end, function(v) BK.cfg.avoid = v end, "วางเส้นทาง หลบสิ่งกีดขวาง แก้รถติด")
	toggle(c3, "โหมดไร้แรงชน", function() return BK.cfg.ghost end, function(v) BK.cfg.ghost = v if not v then Ghost.restore() end end, "ทะลุรถ/ผู้เล่นอื่น เฉพาะฝั่งเรา")
	slider(c3, "ความเร็วเป้าหมาย", 20, 140, "km/h", function() return BK.cfg.targetKmh end, function(v) BK.cfg.targetKmh = v end, 5)
	slider(c3, "รถนิ่งนานก่อนถอยแก้ติด", 1, 12, "วินาที", function() return State.StuckStopSeconds end, function(v) State.StuckStopSeconds = v end, 1)

	local c4 = card(p04, "โรงรถ — เลือกรถ")
	local holder = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, c4)
	list(holder, 5)
	local sig = ""
	local function rebuild()
		local items = Garage.list()
		local s = tostring(#items) .. "|" .. tostring(Garage.selected)
		for _, e in ipairs(items) do s = s .. e.key .. (e.owned and "1" or "0") end
		if s == sig then return end
		sig = s
		for _, ch in ipairs(holder:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
		if #items == 0 then text(holder, "ยังไม่พบรายการ: กด 'เปิดโรงรถ / รีเฟรช' ด้านล่าง", C.mute, 11) end
		for _, e in ipairs(items) do
			if e.owned then
				local sel = Garage.selected == e.key
				local b = mk("TextButton", {
					Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = sel and C.active or C.panel, Text = (sel and "✔ " or "") .. e.title .. "   [" .. e.kind .. "]",
					Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = sel and C.cyan or C.text, AutoButtonColor = false,
				}, holder)
				corner(b, 7)
				stroke(b, sel and C.cyan or C.line, 1, sel and 0.3 or 0)
				b.Activated:Connect(function() Garage.selected = e.key sig = "" rebuild() end)
			end
		end
	end
	refresher(function() pcall(rebuild) end)
	button(c4, "เปิดโรงรถ / รีเฟรชรายการ", function() Garage.ensureOpen() sig = "" rebuild() end)
	button(c4, "เรียกรถที่เลือกออกมา", function()
		if not Garage.selected then Garage.status = "ยังไม่ได้เลือกรถ" return end
		task.spawn(Garage.spawn, Garage.selected)
	end)
	text(c4, function() return "เลือกไว้: " .. tostring(Garage.selected or "—") .. "  •  " .. tostring(Garage.status) end, C.cyan, 11)
end

-- 05 เครื่องยนต์ / ECU
do
	section(p05, "เครื่องยนต์ / ลูกสูบ / ECU", "ติดตามร้านลูกสูบ ซื้อ และแจ้งเตือน")
	local c1 = card(p05, "ร้านลูกสูบ")
	text(c1, function() return Piston.status .. (Piston.open and "  •  หน้าต่างร้านเปิดอยู่" or "") end, C.cyan, 12)
	slider(c1, "ขนาดต่ำสุดที่สนใจ", 53, 90, "มม.", function() return BK.cfg.pistonMin end, function(v) BK.cfg.pistonMin = math.min(v, BK.cfg.pistonMax) end, 1)
	slider(c1, "ขนาดสูงสุดที่สนใจ", 53, 90, "มม.", function() return BK.cfg.pistonMax end, function(v) BK.cfg.pistonMax = math.max(v, BK.cfg.pistonMin) end, 1)
	toggle(c1, "แจ้งเตือนมือถือเมื่อมีลูกสูบในช่วงนี้", function() return BK.cfg.pistonAlert end, function(v) BK.cfg.pistonAlert = v end)
	button(c1, "ไปที่ร้านลูกสูบ (ขับ + เดิน + เปิดร้าน)", function() Piston.goShop() end)
	local rowsHolder = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, c1)
	list(rowsHolder, 3)
	local sig = ""
	refresher(function()
		local s = ""
		for _, r in ipairs(Piston.rows) do s = s .. r.size .. (r.sold and "x" or "o") .. tostring(r.price) end
		if s == sig then return end
		sig = s
		for _, ch in ipairs(rowsHolder:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
		if #Piston.rows == 0 then text(rowsHolder, "ยังอ่านรายการจากร้านไม่ได้ (เปิดหน้าต่างร้านครั้งแรกก่อน)", C.mute, 11) end
		for _, r in ipairs(Piston.rows) do
			text(rowsHolder, string.format("%d มม.    ฿%s    %s", r.size, tostring(r.price or "?"), r.sold and "หมดแล้ว" or "มีของ"), r.sold and C.mute or C.good, 12)
		end
	end)
	local c2 = card(p05, "ซื้อลูกสูบอัตโนมัติ (ใช้เงินจริงในเกม)")
	toggle(c2, "เปิดซื้ออัตโนมัติ", function() return BK.cfg.pistonAuto end, function(v) BK.cfg.pistonAuto = v if v then BK.bought = 0 end end, "ต้องเปิดหน้าต่างร้านค้างไว้เอง • ปิดเองทุกครั้งที่เปิดสคริปต์")
	slider(c2, "ราคาสูงสุดต่อลูก", 3000, 200000, "฿", function() return BK.cfg.pistonMaxPrice end, function(v) BK.cfg.pistonMaxPrice = v end, 1000)
	slider(c2, "ซื้อได้สูงสุดต่อรอบ", 1, 10, "ลูก", function() return BK.cfg.pistonMaxBuy end, function(v) BK.cfg.pistonMaxBuy = v end, 1)
	text(c2, function() return "ซื้อไปแล้วรอบนี้: " .. BK.bought .. " / " .. BK.cfg.pistonMaxBuy end, C.mute, 11)
	local c3 = card(p05, "ECU 8 ตาราง / ออโต้จูน")
	text(c3, "Placeholder: ยังไม่เปิดใช้ เพราะ dump ที่มียังไม่มีหน้าจอ ECU/จูน/ไดโนตอนเปิดอยู่ (หน้าต่างพวกนี้สร้างตอนเปิดเท่านั้น) ส่ง dump ที่ถ่ายตอนเปิดหน้า ECU แล้วจะต่อระบบเลือกตาราง ECU และออโต้จูนให้", C.warn, 11)
	button(c3, "ขับไปร้านจูน (ใช้ได้แล้ว)", function() Care.go("tune") end)
end

-- 06 เงินและกระเป๋า
do
	section(p06, "เงินและกระเป๋า", "ยอดเงินและไอเทมของผู้เล่น")
	stat(p06, "เงินสด", function() return readCash() or "—" end, "อ่านจาก HUD เงินของเกม")
	stat(p06, "เงินธนาคาร", function() return "—" end, "Placeholder: ยังไม่พบข้อมูลใน dump")
	stat(p06, "จำนวนไอเทม", function() return "—" end, "Placeholder: ยังไม่พบข้อมูลใน dump")
	text(p06, "รายการไอเทม ค้นหา เรียงลำดับ: Placeholder (ต้องรู้ตำแหน่งข้อมูลกระเป๋าในเกม)", C.warn, 11)
end

-- 07 มอนิเตอร์
do
	section(p07, "มอนิเตอร์ระบบ", "ตรวจสอบประสิทธิภาพและความสามารถของ executor")
	stat(p07, "เวลาเปิดใช้งาน", function() return fmtTime(os.clock() - startedAt) end)
	stat(p07, "อุปกรณ์", function() return UserInputService.TouchEnabled and "TOUCH (มือถือ/แท็บเล็ต)" or "DESKTOP" end)
	local c = card(p07, "ความสามารถของ executor")
	local function cap(n, ok) return n .. ": " .. (ok and "พร้อม" or "ไม่รองรับ") end
	text(c, function() return cap("ขับรถด้วยปุ่ม (VirtualInputManager)", VIM ~= nil) end)
	text(c, function() return cap("กดปุ่ม GUI (firesignal)", type(firesignal) == "function") end)
	text(c, function() return cap("กด Prompt (fireproximityprompt)", type(fireproximityprompt) == "function") end)
	text(c, function() return cap("บันทึกไฟล์ (writefile)", type(writefile) == "function") end)
	text(c, function() return cap("ส่ง Webhook (HTTP request)", getHttpRequestFunc() ~= nil) end)
	text(c, function() return "ผู้เล่นในเซิร์ฟเวอร์: " .. #Players:GetPlayers() end)
	text(c, function() return "Event Connections ที่ลงทะเบียน: " .. #BK.conns end)
end

-- 08 ตั้งค่า (+ แจ้งเตือนมือถือ)
do
	section(p08, "ตั้งค่า", "หน้าตา การแจ้งเตือนมือถือ และการบันทึก")
	local c1 = card(p08, "หน้าตา")
	dropdown(c1, "ภาษา", { "ไทย" }, function() return "ไทย" end, function() end)
	slider(c1, "ขนาด UI", 0.6, 1.4, "x", function() return BK.cfg.uiScale end, function(v) BK.cfg.uiScale = v applyScale() end, 0.1)
	slider(c1, "ความโปร่งใส", 0, 0.6, "", function() return math.floor(win.BackgroundTransparency * 10 + 0.5) / 10 end, function(v) win.BackgroundTransparency = v end, 0.1)
	toggle(c1, "Compact Mode (แถบเมนูแบบไอคอน)", function() return BK.compact end, function(v) BK.userCompact = v setCompact(v or W < 600) end)
	toggle(c1, "แสดง UI คลาสสิก (หน้าต่างเก่า v1.28)", function() return BK.classic == true end, function(v)
		BK.classic = v
		pcall(function() State.UIOpen = v mainWindow.Visible = v end)
		pcall(function() if floatingBtn then floatingBtn.Visible = v end end)
	end)
	text(c1, "ปุ่มลัด: " .. State.ToggleKey.Name .. "  •  ปุ่มลอย BK = เปิด/ซ่อนบนมือถือ", C.mute, 11)

	local c2 = card(p08, "แจ้งเตือนเข้ามือถือ (Discord Webhook)")
	text(c2, "1) สร้างเซิร์ฟเวอร์ Discord → ตั้งค่าช่อง → Integrations → Webhooks → Copy URL\n2) วางลิงก์ด้านล่าง แล้วกดทดสอบ\n3) ติดตั้ง Discord บนมือถือและเปิดแจ้งเตือน", C.mute, 11)
	local box = mk("TextBox", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.bg, TextColor3 = C.text, PlaceholderText = "วาง Webhook URL ที่นี่", PlaceholderColor3 = C.mute,
		Font = Enum.Font.Code, TextSize = 12, ClearTextOnFocus = false, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	}, c2)
	corner(box, 8)
	stroke(box, C.line, 1, 0)
	local MASK = "••••••••"
	local function shown() return (State.WebhookUrl or "") ~= "" and (MASK .. " (ตั้งค่าแล้ว)") or "" end
	box.Text = shown()
	box.Focused:Connect(function() box.Text = State.WebhookUrl or "" end)
	box.FocusLost:Connect(function()
		local t = (box.Text or ""):match("^%s*(.-)%s*$")
		if t == "" then State.WebhookUrl = "" elseif not t:find(MASK, 1, true) then State.WebhookUrl = t end
		pcall(saveConfigToFile)
		box.Text = shown()
	end)
	button(c2, "ทดสอบส่งแจ้งเตือน", function()
		local ok, msg = sendWebhook("ทดสอบแจ้งเตือน | BALL KUN VV1", "ถ้าเห็นข้อความนี้บนมือถือ แปลว่าใช้งานได้")
		log("ทดสอบ Webhook: " .. tostring(msg))
	end)
	local names = {
		{ "lowFuel", "น้ำมันเหลือน้อย" }, { "repair", "รถเสียหาย" }, { "refuelDone", "เติมน้ำมันเสร็จ" },
		{ "stuck", "รถติดค้าง" }, { "piston", "ลูกสูบมีของ / ซื้อลูกสูบ" }, { "shop", "ร้านลูกสูบเปิด" },
	}
	for _, n in ipairs(names) do
		toggle(c2, "แจ้งเตือน: " .. n[2], function() return BK.cfg.alerts[n[1]] end, function(v) BK.cfg.alerts[n[1]] = v end)
	end

	local c3 = card(p08, "บันทึก / โหลด")
	button(c3, "บันทึกการตั้งค่า", function() saveCfg() pcall(saveConfigToFile) log("บันทึกการตั้งค่าแล้ว") end)
	button(c3, "โหลดการตั้งค่า", function() loadCfg() pcall(loadConfigFromFile) applyScale() for _, f in ipairs(BK.refreshers) do pcall(f) end log("โหลดการตั้งค่าแล้ว") end)
	button(c3, "รีเซ็ตค่าเริ่มต้น", function()
		BK.cfg.targetKmh, BK.cfg.avoid, BK.cfg.ghost, BK.cfg.uiScale = 70, true, false, 1
		BK.cfg.pistonMin, BK.cfg.pistonMax, BK.cfg.pistonMaxPrice, BK.cfg.pistonMaxBuy = 53, 90, 200000, 3
		Ghost.restore() applyScale() saveCfg()
		for _, f in ipairs(BK.refreshers) do pcall(f) end
		log("รีเซ็ตค่าเริ่มต้นแล้ว")
	end, C.bad)
end

-- 09 คอนโซล
do
	section(p09, "คอนโซลนักพัฒนา", "Log ล่าสุด แยกประเภท พร้อมเวลา")
	local c = card(p09, "Log")
	local lbl = text(c, function()
		if #BK.log == 0 then return "ยังไม่มีเหตุการณ์" end
		local out = {}
		for i = 1, math.min(25, #BK.log) do
			local line = BK.log[i]
			local low = line:lower()
			local lv = (low:find("error", 1, true) and "[ERROR] ") or ((line:find("หยุด", 1, true) or line:find("ติด", 1, true)) and "[WARN] ") or "[INFO] "
			out[#out + 1] = lv .. line
		end
		return table.concat(out, "\n")
	end, C.cyan, 10)
	lbl.Font = Enum.Font.Code
	button(c, "ล้าง Log", function() BK.log = {} end)
	button(c, "Copy Log", function()
		local fn = rawget(_G, "setclipboard") or (getgenv and getgenv().setclipboard) or setclipboard
		if type(fn) == "function" then pcall(fn, table.concat(BK.log, "\n")) log("คัดลอก Log แล้ว") else log("ตัวรันไม่รองรับ setclipboard") end
	end)
end

-- 10 เกี่ยวกับ
do
	section(p10, "เกี่ยวกับโปรแกรม", "รายละเอียดผู้พัฒนาและเวอร์ชัน")
	local c = card(p10, "BALL KUN VV1")
	text(c, "ผู้พัฒนา: บอลคุง ไงหนู\nเวอร์ชัน: v1.38 (Auto Map Scanner + Premium Suite บนแกน v1.28)\nแมพ: MAHANAKHON RACING", C.text, 12)
	text(c, "ระบบหลัก: เติมน้ำมัน • ซ่อมรถ • ขับนำทาง • ไร้แรงชน • โรงรถ • ร้านลูกสูบ • แจ้งเตือนมือถือ • ระบบงาน/ไรเดอร์เดิม", C.mute, 11)
	button(c, "ปุ่มคอมมูนิตี้", function() log("คอมมูนิตี้: ยังไม่ได้ตั้งลิงก์") end)
end

-- ---------- ปุ่มลอย / ย่อ / ปิด ----------
local floating = mk("TextButton", {
	Name = "FloatingButton", Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0, 16, 0.5, -25), BackgroundColor3 = C.bg, Text = "BK",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.cyan, AutoButtonColor = false, Visible = true,
}, gui)
corner(floating, 25)
stroke(floating, C.cyan, 1.5, 0)
local function setMinimized(v)
	minimized = v
	win.Size = UDim2.fromOffset(W, v and 52 or H)
	sidebar.Visible, content.Visible, footer.Visible = not v, not v, not v
end
floating.Activated:Connect(function() win.Visible = not win.Visible end)
minBtn.Activated:Connect(function() setMinimized(not minimized) end)
compactBtn.Activated:Connect(function() BK.userCompact = not BK.compact setCompact(BK.userCompact or W < 600) end)
closeBtn.Activated:Connect(function() win.Visible = false end)
track(UserInputService.InputBegan:Connect(function(inp, gp)
	if not gp and inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == State.ToggleKey then
		win.Visible = not win.Visible
		task.defer(function()
			if not BK.classic then pcall(function() mainWindow.Visible = false State.UIOpen = false end) end
		end)
	end
end))

-- ซ่อน UI เดิมเป็นค่าเริ่มต้น (เปิดกลับได้ที่ ตั้งค่า > UI คลาสสิก)
pcall(function() State.UIOpen = false mainWindow.Visible = false end)
pcall(function() if floatingBtn then floatingBtn.Visible = false end end)

applyScale()
BK.switchPage("p01")

-- ---------- Loading overlay ----------
do
	local ov = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, ZIndex = 50 }, gui)
	mk("TextLabel", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0.42, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = C.cyan, Text = "BALL KUN VV1", ZIndex = 51 }, ov)
	mk("TextLabel", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.48, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.mute, Text = "รอก่อนไอหนู", ZIndex = 51 }, ov)
	local track = mk("Frame", { Size = UDim2.fromOffset(190, 4), Position = UDim2.new(0.5, -95, 0.55, 0), BackgroundColor3 = C.card, ZIndex = 51 }, ov)
	corner(track, 2)
	local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.cyan, ZIndex = 52 }, track)
	corner(fill, 2)
	TweenService:Create(fill, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
	task.delay(1, function() if ov.Parent then ov:Destroy() end end)
end

task.spawn(function()
	while BK.alive and gui.Parent do
		for _, f in ipairs(BK.refreshers) do pcall(f) end
		local busy = Drive.active or Care.busy
		statusPill.Text = busy and "● WORKING" or "● ONLINE"
		statusPill.TextColor3 = busy and C.warn or C.good
		footR.Text = busy and tostring(Drive.status) or tostring(BK.status.fuel or "พร้อมใช้งาน")
		task.wait(0.6)
	end
end)

log("BALL KUN VV1 Premium พร้อมใช้งาน")
end)
if not __okBK then
	warn("[BALL KUN VV1] Premium Suite: " .. tostring(__errBK))
	pcall(function() __notify("BALL KUN: Premium Suite error", __errBK) end)
	pcall(function() mainWindow.Visible = true State.UIOpen = true if floatingBtn then floatingBtn.Visible = true end end)
end
end
-- ===================== END PREMIUM SUITE =====================

Loading.step(0.9, "Checking Components")
do
	local checks = {
		["Main UI"] = (mainWindow ~= nil and mainWindow.Parent ~= nil),
		["Screen GUI"] = (screenGui ~= nil and screenGui.Parent ~= nil),
		["Config"] = (type(State) == "table"),
		["Map Adaptive"] = __maOk,
	}
	Loading.finish(checks)
end

__notify("BALL KUN VV1 v1.38", "โหลดสคริปต์สำเร็จ (+ตามหมุด/สตาร์ท R/ขาตั้ง K)")
end, function(e) return tostring(e) end)

if not __ok then
	if __Loading then pcall(__Loading.fail, tostring(__err)) end
	warn("[BALL KUN Vv1] สคริปต์พัง: " .. tostring(__err))
	__notify("BALL KUN: สคริปต์พัง", __err)
end
