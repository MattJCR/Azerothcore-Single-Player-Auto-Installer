-- Controles integrados para mod-party-here, mod-dungeon-clear y la barra.
-- Los botones maestros continuan la seccion Right de la estructura original.

local tMultiBar = MultiBot.frames["MultiBar"]
if(tMultiBar == nil) then return end
local tRight = tMultiBar.frames["Right"]
if(tRight == nil) then return end

local function Run(command)
	SendChatMessage(command, "SAY")
end

MultiBot.tips.extensions = {
	master = "Extensiones del servidor\n|cffffffffControles adicionales para Party Here, Dungeon Clear y la barra de MultiBot.|r\n\n|cffff0000Clic izquierdo para mostrar u ocultar las categorías|r",
	move = "Mover MultiBot\n|cffffffffEste tirador solamente sirve para mover la barra.|r\n\n|cffff0000Mantén pulsado el botón izquierdo y arrastra|r",
	partyMaster = "Party Here\n|cffffffffAbre las opciones de grupos de bots de mod-party-here.|r\n\n|cffff0000Clic izquierdo para mostrar las opciones|r",
	group = "Grupo aquí\n|cffffffffForma o completa un grupo equilibrado de cinco miembros con bots de tu nivel.|r\n\n|cffff0000Clic izquierdo: .grupo|r",
	dungeon = "Grupo de mazmorra\n|cffffffffForma un grupo equilibrado para entrar andando a una mazmorra.|r\n\n|cffff0000Clic izquierdo: .grupo mazmorra|r",
	raid10 = "Banda de 10\n|cffffffffCompleta una banda de diez miembros.|r\n\n|cffff0000Clic izquierdo: .grupo banda 10|r",
	raid25 = "Banda de 25\n|cffffffffCompleta una banda de veinticinco miembros.|r\n\n|cffff0000Clic izquierdo: .grupo banda 25|r",
	raid40 = "Banda de 40\n|cffffffffCompleta una banda de cuarenta miembros.|r\n\n|cffff0000Clic izquierdo: .grupo banda 40|r",
	status = "Estado del grupo\n|cffffffffMuestra los compañeros proporcionados por mod-party-here.|r\n\n|cffff0000Clic izquierdo: .grupo estado|r",
	dismiss = "Despedir compañeros\n|cffffffffRetira los bots proporcionados por mod-party-here.|r\n\n|cffff0000Clic izquierdo: .grupo fuera|r",
	dcMaster = "Dungeon Clear\n|cffffffffAbre los controles de mod-dungeon-clear para el grupo actual.|r\n\n|cffff0000Clic izquierdo para mostrar las opciones|r",
	dcOn = "Activar Dungeon Clear\n|cffffffffActiva mod-dungeon-clear para el grupo actual.|r\n\n|cffff0000Clic izquierdo: .dc on|r",
	dcOff = "Desactivar Dungeon Clear\n|cffffffffDesactiva mod-dungeon-clear para el grupo actual.|r\n\n|cffff0000Clic izquierdo: .dc off|r",
	dcPullAggressive = "Ritmo: agresivo (Leeroy)\n|cffffffffEl tanque entra directo a cada grupo de bichos y pelea donde caiga. El más rápido, también el más arriesgado.|r\n\n|cffff0000Clic izquierdo: .dc pull off|r",
	dcPullDynamic = "Ritmo: dinámico (recomendado)\n|cffffffffDecide por grupo de bichos: entra directo si es manejable, tira hacia el campamento si no. Punto medio de velocidad y riesgo.|r\n\n|cffff0000Clic izquierdo: .dc pull dynamic|r",
	dcPullCareful = "Ritmo: cauto (Advanced)\n|cffffffffEl tanque tira cada grupo hacia un punto de espera antes de pelear. El más lento, también el más seguro.|r\n\n|cffff0000Clic izquierdo: .dc pull on|r",
	barMaster = "Configuración de la barra\n|cffffffffAbre las opciones de tamaño y posición de MultiBot.|r\n\n|cffff0000Clic izquierdo para mostrar las opciones|r",
	smaller = "Reducir barra\n|cffffffffReduce la escala un 10%.|r",
	reset = "Tamaño original\n|cffffffffRestablece la escala al 100%.|r",
	larger = "Aumentar barra\n|cffffffffAumenta la escala un 10%.|r",
	lock = "Fijar posición\n|cffffffffBloquea o desbloquea el tirador de la barra.|r"
}

MultiBot.barLocked = false

-- Borde derecho máximo de la barra para que el engranaje de ajustes (el botón más a la derecha) y su panel, que cuelga justo
-- encima, quepan en la pantalla. La posición por defecto (-262) es anterior a los botones de Party Here, Dungeon Clear y
-- ajustes: con ella el engranaje quedaba medio fuera de la pantalla y el panel con el candado, entero fuera.
MultiBot.ClampBarRight = function(pRight)
	local tGear = tRight.buttons["BarOptions"]
	local tGearRight, tBarRight = tGear and tGear:GetRight(), tMultiBar:GetRight()
	if(pRight == nil or tGearRight == nil or tBarRight == nil) then return pRight end
	return math.min(pRight, GetScreenWidth() - 4 - (tGearRight - tBarRight) * tMultiBar:GetScale())
end

MultiBot.SaveBarPosition = function()
	local x, y = MultiBot.toPoint(tMultiBar)
	MultiBotSave["MultiBarPoint"] = x .. ", " .. y
end

local function SetScale(scale)
	scale = math.max(0.6, math.min(1.5, scale))
	scale = math.floor(scale * 10 + 0.5) / 10

	-- SetPoint reinterpreta el mismo xOfs/yOfs con la escala nueva: sin
	-- recalcular el offset aquí, cambiar la escala con +/- desplaza la barra
	-- de sitio (aunque nadie la haya arrastrado). Capturamos la posición
	-- absoluta ANTES de escalar y reanclamos (con corrección empírica de
	-- MultiBot.setAbsolutePoint) para que se quede donde estaba.
	local tRight, tBottom = tMultiBar:GetRight(), tMultiBar:GetBottom()

	tMultiBar:SetScale(scale)

	if(tRight ~= nil and tBottom ~= nil) then
		MultiBot.setAbsolutePoint(tMultiBar, tRight, tBottom)
	end

	MultiBotSave["MultiBarScale"] = tostring(scale)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00MultiBot:|r escala de la barra " .. math.floor(scale * 100 + 0.5) .. "%.")
	MultiBot.SaveBarPosition()
end

-- Tirador independiente. Al no ser un boton de opciones, el arrastre nunca
-- compite con acciones de clic derecho de MultiBot.
local moveHandle = CreateFrame("Button", nil, tMultiBar)
moveHandle:SetPoint("TOP", tMultiBar, "BOTTOM", -100, -2)
moveHandle:SetSize(64, 14)
moveHandle:SetFrameLevel(tMultiBar:GetFrameLevel() + 6)
moveHandle:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 8, edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
moveHandle:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
moveHandle:SetBackdropBorderColor(1, 0.75, 0, 0.9)
moveHandle:EnableMouse(true)
moveHandle:RegisterForDrag("LeftButton")
moveHandle:Show()

local moveText = moveHandle:CreateFontString(nil, "ARTWORK")
moveText:SetFont("Fonts\\ARIALN.ttf", 8, "OUTLINE")
moveText:SetPoint("CENTER", 0, 0)
moveText:SetText("MOVER")

-- Marcador de depuración de posición: fix provisional, oculto (ver nota
-- junto a los botones de escala, más abajo). El código queda por si hace
-- falta reactivarlo para seguir investigando el desplazamiento con escala.
local coordText = tMultiBar:CreateFontString(nil, "OVERLAY")
coordText:SetFont("Fonts\\ARIALN.ttf", 8, "OUTLINE")
coordText:SetPoint("TOP", moveHandle, "BOTTOM", 0, -16)
coordText:SetJustifyH("CENTER")
coordText:SetTextColor(0.4, 1, 0.4)
coordText:Hide()

moveHandle:SetScript("OnEnter", function()
	GameTooltip:SetOwner(moveHandle, "ANCHOR_BOTTOM", 0, -2)
	GameTooltip:SetText(MultiBot.tips.extensions.move)
	GameTooltip:Show()
end)
moveHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)
moveHandle:SetScript("OnDragStart", function()
	if(not MultiBot.barLocked) then
		GameTooltip:Hide()
		tMultiBar:StartMoving()
	end
end)
moveHandle:SetScript("OnDragStop", function()
	tMultiBar:StopMovingOrSizing()
	MultiBot.SaveBarPosition()
end)

-- PARTY HERE ---------------------------------------------------------------

local partyButton = tRight.addButton("PartyHere", 136, 0, "achievement_dungeon_gloryoftheraider", MultiBot.tips.extensions.partyMaster)
partyButton.doLeft = function(button)
	MultiBot.ShowHideSwitch(button.parent.frames["PartyHere"])
end

local party = tRight.addFrame("PartyHere", 138, 32)
party:SetFrameLevel(tRight:GetFrameLevel() + 2)
party:Hide()

local partyEntries = {
	{"PartyGroup", 0, "Interface\\AddOns\\MultiBot\\Icons\\invite_party_5.blp", MultiBot.tips.extensions.group, ".grupo"},
	{"PartyDungeon", 34, "achievement_dungeon_heroic_gloryoftheraider", MultiBot.tips.extensions.dungeon, ".grupo mazmorra"},
	{"PartyRaid10", 68, "Interface\\AddOns\\MultiBot\\Icons\\invite_raid_10.blp", MultiBot.tips.extensions.raid10, ".grupo banda 10"},
	{"PartyRaid25", 102, "Interface\\AddOns\\MultiBot\\Icons\\invite_raid_25.blp", MultiBot.tips.extensions.raid25, ".grupo banda 25"},
	{"PartyRaid40", 136, "Interface\\AddOns\\MultiBot\\Icons\\invite_raid_40.blp", MultiBot.tips.extensions.raid40, ".grupo banda 40"},
	{"PartyStatus", 170, "inv_scroll_03", MultiBot.tips.extensions.status, ".grupo estado"},
	{"PartyDismiss", 204, "spell_shadow_sacrificialshield", MultiBot.tips.extensions.dismiss, ".grupo fuera"}
}

for _, entry in ipairs(partyEntries) do
	local button = party.addButton(entry[1], 0, entry[2], entry[3], entry[4])
	button.command = entry[5]
	button.doLeft = function(self) Run(self.command) end
end

-- DUNGEON CLEAR ------------------------------------------------------------

local dungeonButton = tRight.addButton("DungeonClear", 170, 0, "achievement_boss_anubarak", MultiBot.tips.extensions.dcMaster)
dungeonButton.doLeft = function(button)
	MultiBot.ShowHideSwitch(button.parent.frames["DungeonClear"])
end

local dungeonClear = tRight.addFrame("DungeonClear", 172, 32)
dungeonClear:SetFrameLevel(tRight:GetFrameLevel() + 2)
dungeonClear:Hide()

local dcOn = dungeonClear.addButton("DungeonClearOn", 0, 0, "spell_holy_devotionaura", MultiBot.tips.extensions.dcOn)
dcOn.doLeft = function() Run(".dc on") end
local dcOff = dungeonClear.addButton("DungeonClearOff", 0, 34, "spell_shadow_antishadow", MultiBot.tips.extensions.dcOff)
dcOff.doLeft = function() Run(".dc off") end

-- Ritmo de tirones (mod-dungeon-clear "advanced pull"): agresivo = Leeroy
-- (entra directo, .dc pull off), dinámico = decide por grupo (.dc pull
-- dynamic), cauto = siempre tira al campamento antes de pelear (.dc pull on).
local dcPullAggressive = dungeonClear.addButton("DungeonClearPullAggressive", 0, 68, "ability_warrior_charge", MultiBot.tips.extensions.dcPullAggressive)
dcPullAggressive.doLeft = function() Run(".dc pull off") end
local dcPullDynamic = dungeonClear.addButton("DungeonClearPullDynamic", 0, 102, "spell_nature_farsight", MultiBot.tips.extensions.dcPullDynamic)
dcPullDynamic.doLeft = function() Run(".dc pull dynamic") end
local dcPullCareful = dungeonClear.addButton("DungeonClearPullCareful", 0, 136, "ability_defend", MultiBot.tips.extensions.dcPullCareful)
dcPullCareful.doLeft = function() Run(".dc pull on") end

-- OPCIONES DE BARRA --------------------------------------------------------

local barButton = tRight.addButton("BarOptions", 204, 0, "inv_misc_gear_01", MultiBot.tips.extensions.barMaster)
barButton.doLeft = function(button)
	MultiBot.ShowHideSwitch(button.parent.frames["BarOptions"])
end

local barOptions = tRight.addFrame("BarOptions", 206, 32)
barOptions:SetFrameLevel(tRight:GetFrameLevel() + 2)
barOptions:Hide()

local function AddScaleButton(name, y, label, tip, action)
	local button = barOptions.addButton(name, 0, y, "Interface\\AddOns\\MultiBot\\Textures\\Black.blp", tip)
	button.label = button:CreateFontString(nil, "OVERLAY")
	button.label:SetFont("Fonts\\ARIALN.ttf", label == "100%" and 10 or 22, "OUTLINE")
	button.label:SetPoint("CENTER", 0, 0)
	button.label:SetText(label)
	button.label:SetTextColor(1, 0.82, 0)
	button.doLeft = action
	return button
end

-- Fix provisional: la escala distinta de 100% desplaza la barra al
-- guardar/restaurar la posición (ver CHANGELOG 08/09/2026) y no se ha
-- encontrado todavía la fórmula correcta. Se ocultan los botones de escala
-- y se fuerza 100% siempre hasta resolverlo.
AddScaleButton("Smaller", 0, "-", MultiBot.tips.extensions.smaller, function()
	SetScale(tMultiBar:GetScale() - 0.1)
end):Hide()
AddScaleButton("ResetScale", 34, "100%", MultiBot.tips.extensions.reset, function()
	SetScale(1)
end):Hide()
AddScaleButton("Larger", 68, "+", MultiBot.tips.extensions.larger, function()
	SetScale(tMultiBar:GetScale() + 0.1)
end):Hide()

local lockButton = barOptions.addButton("Lock", 0, 0, "inv_misc_key_14", MultiBot.tips.extensions.lock)

local function SetLocked(locked)
	MultiBot.barLocked = locked and true or false
	tMultiBar:SetMovable(not MultiBot.barLocked)
	MultiBotSave["MultiBarLocked"] = MultiBot.IF(MultiBot.barLocked, "true", "false")
	if(MultiBot.barLocked) then
		-- Guardar aquí y no esperar al próximo PLAYER_LOGOUT: así la posición
		-- queda fijada en el momento de bloquear, no en un reload posterior.
		MultiBot.SaveBarPosition()
		lockButton.setEnable()
		moveHandle:Hide()
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00MultiBot:|r posición de la barra fijada.")
	else
		lockButton.setDisable()
		moveHandle:Show()
		moveText:SetTextColor(1, 0.82, 0)
		moveHandle:SetBackdropBorderColor(1, 0.75, 0, 0.9)
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00MultiBot:|r barra desbloqueada; arrastra el recuadro MOVER con el botón izquierdo.")
	end
end

lockButton.setDisable()
lockButton.doLeft = function() SetLocked(not MultiBot.barLocked) end

MultiBot.ApplyBarSettings = function(scale, locked)
	-- Fix provisional: forzamos siempre 100% (ver nota junto a los botones
	-- de escala ocultos, más abajo), sea cual sea el valor guardado.
	tMultiBar:SetScale(1)
	MultiBot.barLocked = locked and true or false
	tMultiBar:SetMovable(not MultiBot.barLocked)
	if(MultiBot.barLocked) then
		lockButton.setEnable()
		moveHandle:Hide()
	else
		lockButton.setDisable()
		moveHandle:Show()
		moveText:SetTextColor(1, 0.82, 0)
		moveHandle:SetBackdropBorderColor(1, 0.75, 0, 0.9)
	end
end
