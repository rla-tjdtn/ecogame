--!strict
-- 최소 UI: 작은 조준점, 음파 재사용 대기 막대, 스테이지 이름, 상호작용 안내, 사망/탈출/클리어 화면.
-- 흰색·회색만. 미니맵이나 괴물 위치 표시는 없다.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local UI = {}
local player = Players.LocalPlayer

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SonarUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local function label(parent: Instance, text: string, size: number, pos: UDim2, anchor: Vector2, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = if bold then FONT_BOLD else FONT
	l.TextColor3 = Color3.fromRGB(220, 220, 220)
	l.Size = UDim2.fromOffset(600, size + 8)
	l.Position = pos
	l.AnchorPoint = anchor
	l.Parent = parent
	return l
end

-- 조준점
local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(3, 3)
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
dot.BackgroundTransparency = 0.35
dot.BorderSizePixel = 0
dot.Parent = gui

-- 음파 대기 막대(조준점 아래, 아주 얇게)
local barBack = Instance.new("Frame")
barBack.Size = UDim2.fromOffset(36, 2)
barBack.AnchorPoint = Vector2.new(0.5, 0)
barBack.Position = UDim2.new(0.5, 0, 0.5, 14)
barBack.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
barBack.BackgroundTransparency = 0.75
barBack.BorderSizePixel = 0
barBack.Parent = gui
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
barFill.BackgroundTransparency = 0.5
barFill.BorderSizePixel = 0
barFill.Parent = barBack

-- 스테이지 이름(왼쪽 위, 흐리게)
local stageLabel = label(gui, "", 14, UDim2.fromOffset(18, 14), Vector2.zero)
stageLabel.TextXAlignment = Enum.TextXAlignment.Left
stageLabel.TextTransparency = 0.45

-- 가운데 큰 제목(스테이지 시작 시 잠깐)
local title = label(gui, "", 26, UDim2.fromScale(0.5, 0.36), Vector2.new(0.5, 0.5), true)
title.TextTransparency = 1
title.Size = UDim2.fromOffset(900, 40)

-- 짧은 안내(가운데 아래)
local hint = label(gui, "", 15, UDim2.new(0.5, 0, 0.5, 46), Vector2.new(0.5, 0))
hint.TextTransparency = 1

-- 상호작용 안내
local prompt = label(gui, "", 15, UDim2.new(0.5, 0, 0.5, 26), Vector2.new(0.5, 0))
prompt.TextTransparency = 0.2
prompt.Visible = false

-- 결과 화면
local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.ZIndex = 10
overlay.Parent = gui
local ovTitle = label(overlay, "", 40, UDim2.fromScale(0.5, 0.44), Vector2.new(0.5, 0.5), true)
ovTitle.Size = UDim2.fromOffset(900, 56)
ovTitle.ZIndex = 11
ovTitle.TextTransparency = 1
local ovSub = label(overlay, "", 16, UDim2.fromScale(0.5, 0.53), Vector2.new(0.5, 0.5))
ovSub.Size = UDim2.fromOffset(900, 24)
ovSub.ZIndex = 11
ovSub.TextColor3 = Color3.fromRGB(160, 160, 160)
ovSub.TextTransparency = 1

-- 관전 안내(아래쪽)
local spectate = label(gui, "", 14, UDim2.new(0.5, 0, 1, -40), Vector2.new(0.5, 0.5))
spectate.TextColor3 = Color3.fromRGB(170, 170, 170)
spectate.Visible = false

local function tween(obj: Instance, t: number, props: { [string]: any })
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Sine), props):Play()
end

function UI.setCooldown(frac: number)
	barFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	barFill.BackgroundTransparency = if frac >= 1 then 0.6 else 0.35
end

function UI.setStage(name: string)
	stageLabel.Text = name
	title.Text = name
	tween(title, 1.2, { TextTransparency = 0.1 })
	task.delay(3.5, function()
		if title.Text == name then
			tween(title, 1.5, { TextTransparency = 1 })
		end
	end)
end

function UI.hint(text: string, seconds: number)
	hint.Text = text
	tween(hint, 0.6, { TextTransparency = 0.25 })
	task.delay(seconds, function()
		if hint.Text == text then
			tween(hint, 1.2, { TextTransparency = 1 })
		end
	end)
end

-- 안내 문구는 두 곳에서 온다: 문·숨는 곳(가까이 가면) / 서랍·상자(조준하면). 조준한 것이 먼저 보이고,
-- 한쪽이 지워도 다른 쪽 문구는 남는다(서랍에서 눈을 떼도 옆 사물함의 '숨기'가 사라지지 않게)
local nearText: string? = nil
local lookText: string? = nil
local function showPrompt()
	local text = lookText or nearText
	prompt.Visible = text ~= nil
	prompt.Text = text or ""
end

function UI.setPrompt(text: string?)
	nearText = text
	showPrompt()
end

function UI.setLookPrompt(text: string?)
	lookText = text
	showPrompt()
end

-- 결과 화면. black: 화면을 검게 덮는다(아니면 글자만)
function UI.overlay(t: string, sub: string, black: boolean)
	ovTitle.Text = t
	ovSub.Text = sub
	tween(overlay, 0.9, { BackgroundTransparency = if black then 0 else 1 })
	tween(ovTitle, 0.9, { TextTransparency = 0 })
	tween(ovSub, 1.2, { TextTransparency = 0 })
	dot.Visible = false
	barBack.Visible = false
end

function UI.hideOverlay(fast: boolean?)
	local t = if fast then 0.2 else 0.8
	tween(overlay, t, { BackgroundTransparency = 1 })
	tween(ovTitle, t, { TextTransparency = 1 })
	tween(ovSub, t, { TextTransparency = 1 })
	dot.Visible = true
	barBack.Visible = true
end

-- 오버레이 글자만 남기고 배경을 걷는다(관전으로 넘어갈 때)
function UI.liftOverlay()
	tween(overlay, 1.2, { BackgroundTransparency = 1 })
	tween(ovTitle, 1.2, { TextTransparency = 1 })
	tween(ovSub, 1.2, { TextTransparency = 1 })
end

function UI.setSpectate(text: string?)
	spectate.Visible = text ~= nil
	spectate.Text = text or ""
	if text then
		dot.Visible = false
		barBack.Visible = false
	end
end

function UI.state()
	return {
		overlayTitle = ovTitle.Text,
		overlayShown = ovTitle.TextTransparency < 0.5,
		stage = stageLabel.Text,
		spectate = if spectate.Visible then spectate.Text else nil,
		prompt = if prompt.Visible then prompt.Text else nil,
	}
end

return UI
