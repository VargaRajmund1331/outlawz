-- ==========================================================
-- Projekt: outlawz | Tuning Kliens (sourceC.lua)
-- MÓDOSÍTVA: Töltőképernyő, Hangok, Emerald HUD implementáció
-- ==========================================================

local screenX, screenY = guiGetScreenSize()
local activeTuningMarker = nil

-- Töltőképernyő (Progress Bar) adatai
local tuningProcess = {
    active = false,
    startTick = 0,
    itemData = nil,
    itemCategory = nil,
    itemLevel = nil,
    readyToBuy = false
}
-- ==========================================
-- PAINTJOB RENDSZER (SULTAN)
-- ==========================================
local myPaintjobShader = false
local myPaintjobTexture = false

local sultanPaintjobs = {
    [1] = { name = "BBS Tuning", file = "sultan_pj/sultan_bbs.dds" },
    [2] = { name = "Devil Edition", file = "sultan_pj/sultan_devil.dds" },
    [3] = { name = "Electro Shock", file = "sultan_pj/sultan_electro.dds" },
    [4] = { name = "Grip Racing", file = "sultan_pj/sultan_grip.dds" },
    [5] = { name = "LSPD Cruiser", file = "sultan_pj/sultan_lspd.dds" },
    [6] = { name = "Alien Madness", file = "sultan_pj/sultan_madness.dds" },
    [7] = { name = "The Punisher", file = "sultan_pj/sultan_punisher.dds" },
    [8] = { name = "Scorpion Drift", file = "sultan_pj/sultan_scorpion.dds" }
}

-- Funkció: Paintjob ráhúzása az autóra
function applyVehicleCustomPaintjob(veh, pjID)
    -- Ha le akarjuk venni a paintjobot (vagy 0/nil az érték)
    if not pjID or pjID == 0 then
        if myPaintjobShader then
            engineRemoveShaderFromWorldTexture(myPaintjobShader, "sultan1body256", veh)
            destroyElement(myPaintjobShader)
            myPaintjobShader = false
        end
        if myPaintjobTexture then
            destroyElement(myPaintjobTexture)
            myPaintjobTexture = false
        end
        return
    end

    -- Ha érvényes Sultan paintjobról van szó (Sultan ID: 560)
    if getElementModel(veh) == 560 and sultanPaintjobs[pjID] then
        -- 1. Gyári paintjob ráadása alapnak
        setVehiclePaintjob(veh, 0) 
        
        -- 2. Töröljük a régit, ha épp cseréljük
        if myPaintjobShader then destroyElement(myPaintjobShader) end
        if myPaintjobTexture then destroyElement(myPaintjobTexture) end
        
        -- 3. Létrehozzuk az újat
        myPaintjobShader = dxCreateShader("paintjob.fx")
        myPaintjobTexture = dxCreateTexture(sultanPaintjobs[pjID].file)
        
        if myPaintjobShader and myPaintjobTexture then
            dxSetShaderValue(myPaintjobShader, "gTexture", myPaintjobTexture)
            engineApplyShaderToWorldTexture(myPaintjobShader, "sultan1body256", veh)
        end
    end
end

responsiveMultiplier = 0.75
stepMultiplier = 0.03571428571429
whileScreenSize = 1024

while whileScreenSize < screenX do
	responsiveMultiplier = responsiveMultiplier + stepMultiplier
	whileScreenSize = whileScreenSize + 128
end

addEventHandler("onClientMarkerHit", root, function(hitElement, matchingDimension)
    if matchingDimension and getElementData(source, "tuningMarkerSettings") then
        if hitElement == localPlayer or (getElementType(hitElement) == "vehicle" and getVehicleController(hitElement) == localPlayer) then
            activeTuningMarker = source
        end
    end
end)

addEventHandler("onClientMarkerLeave", root, function(leaveElement, matchingDimension)
    if matchingDimension and activeTuningMarker == source then
        if leaveElement == localPlayer or (getElementType(leaveElement) == "vehicle" and getVehicleController(leaveElement) == localPlayer) then
            activeTuningMarker = nil
        end
    end
end)

bindKey("e", "down", function()
    if activeTuningMarker and not panelState then
        if getPedOccupiedVehicle(localPlayer) then
            triggerServerEvent("tuning->EnterMarker", localPlayer, localPlayer, activeTuningMarker)
            activeTuningMarker = nil
        end
    end
end)

responsiveMultiplier = 0.75
stepMultiplier = 0.03571428571429
whileScreenSize = 1024

while whileScreenSize < screenX do
	responsiveMultiplier = responsiveMultiplier + stepMultiplier
	whileScreenSize = whileScreenSize + 128
end

local tuningMarkers = {}
local tuningMarkersCount = 0
local markerImageMaxVisibleDistance = 35

local availableTextures = {
	["logo"] = dxCreateTexture("outlawz_tuninglogo.png", "argb", true, "clamp"),
	["marker"] = dxCreateTexture("repair.png", "argb", true, "clamp"),
	["emerald"] = dxCreateTexture("emerald.png", "argb", true, "clamp"),
	["hoveredrow"] = dxCreateTexture("files/images/hoveredrow.png", "argb", true, "clamp"),
	["menunav"] = dxCreateTexture("files/images/menunav.png", "argb", true, "clamp"),
	["mouse"] = dxCreateTexture("files/images/navbar/mouse.png", "argb", true, "clamp"),
}

local availableIcons = {
	["wrench"] = "",
	["long-arrow-up"] = "",
	["long-arrow-down"] = "",
	["info-circle"] = "",
	["check"] = "",
	["exclamation-triangle"] = "",
}

local mouseTable = { ["speed"] = {0, 0}, ["last"] = {0, 0}, ["move"] = {0, 0} }

local panelState = false
local enteredVehicle = false
local availableFonts = nil

local panelWidth, rowHeight = 460 * responsiveMultiplier, 42 * responsiveMultiplier
local panelX, panelY = 32, 32
local logoHeight = 120

local hoveredCategory, selectedCategory, selectedSubCategory = 1, 0, 0
local maxRowsPerPage, currentPage = 9, 1

local compatibleOpticalUpgrades = {}
local equippedTuning = 1

local navbarButtonHeight = 30 * responsiveMultiplier
local navigationBar = {
	{"", {"Enter"}, false},
	{"", {"long-arrow-up", "long-arrow-down"}, true},
	{"", {"Backspace"}, false},
	{getLocalizedText("navbar.camera"), {"mouse"}, "image", 30 * responsiveMultiplier}
}

local noticeData = { ["text"] = false, ["type"] = "info", ["tick"] = 0, ["state"] = "", ["height"] = 0, ["timer"] = nil }
local cameraSettings = {}
local promptDialog = { ["state"] = false, ["itemName"] = "", ["itemPrice"] = 0 }

local availableOffroadAbilities = { ["dirt"] = {0x100000, 2}, ["sand"] = {0x200000, 3} }

local availableWheelSizes = {
	["front"] = { ["verynarrow"] = {0x100, 1}, ["narrow"] = {0x200, 2}, ["wide"] = {0x400, 4}, ["verywide"] = {0x800, 5} },
	["rear"] = { ["verynarrow"] = {0x1000, 1}, ["narrow"] = {0x2000, 2}, ["wide"] = {0x4000, 4}, ["verywide"] = {0x8000, 5} }
}

local savedVehicleColors = {["all"] = false, ["headlight"] = false}
local moneyChangeTable = {["tick"] = 0, ["amount"] = 0}
local vehicleNumberplate = ""

addEvent("tuning->ShowMenu", true)
addEvent("tuning->HideMenu", true)

addEventHandler("onClientResourceStart", resourceRoot, function()
	for _, value in ipairs(getElementsByType("marker", root, true)) do
		if getElementData(value, "tuningMarkerSettings") then
			tuningMarkers[value] = true
			tuningMarkersCount = tuningMarkersCount + 1
		end
	end
	
	for i = 1, 4 do
		table.insert(tuningMenu[getMainCategoryIDByName(getLocalizedText("menu.color"))]["subMenu"], {
			["categoryName"] = getLocalizedText("menu.color") .. " " .. i,
			["tuningPrice"] = 10000,
			["tuningData"] = "color" .. i
		})
	end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
	if panelState and enteredVehicle then
		resetOpticalUpgrade()
		setVehicleColorsToDefault()
		triggerEvent("tuning->HideMenu", localPlayer)
	end
end)

addEventHandler("onClientElementStreamIn", root, function()
	if getElementType(source) == "marker" then
		if getElementData(source, "tuningMarkerSettings") then
			tuningMarkers[source] = true
			tuningMarkersCount = tuningMarkersCount + 1
		end
	end
end)

addEventHandler("onClientElementStreamOut", root, function()
	if getElementType(source) == "marker" then
		if getElementData(source, "tuningMarkerSettings") then
			tuningMarkers[source] = nil
			tuningMarkersCount = tuningMarkersCount - 1
		end
	end
end)

addEventHandler("onClientRender", root, function()
	-- ==========================================
    -- GOLYÓÁLLÓ KERÉK HUD ÉS "BETON" LOGIKA
    -- ==========================================
    local veh = getPedOccupiedVehicle(localPlayer)
    if veh and getElementData(veh, "tuning.bulletProofTires") then
        local now = getRealTime().timestamp
        local state = getElementData(veh, "bp_state") or "ready"
        local endTime = getElementData(veh, "bp_end_time") or 0
        
        if state == "protecting" then
            if now >= endTime then
                -- Csak a sofőr küldi be az állapotváltozást a szervernek, hogy ne akadjon össze utasokkal
                if getVehicleController(veh) == localPlayer then
                    setElementData(veh, "bp_state", "cooldown")
                    setElementData(veh, "bp_end_time", now + 30)
                end
                state = "cooldown"
                endTime = now + 30
            else
                -- BETON KERÉK: Minden képkockán megjavítja! Képtelenség kidurrantani!
                setVehicleWheelStates(veh, 0, 0, 0, 0)
            end
        elseif state == "cooldown" and now >= endTime then
            -- Ha lejárt a cooldown, jöhet az azonnali javítás és a chat üzenet!
            if getVehicleController(veh) == localPlayer then
                setElementData(veh, "bp_state", "ready")
                setVehicleWheelStates(veh, 0, 0, 0, 0) -- Azonnal megjavítja a szétlőtt kerekeket
                outputChatBox("#82e071[Tires] #ffffffYour tires successfully repaired!", 255, 255, 255, true)
            end
            state = "ready"
        end
        
        -- Ikon betöltése okosan (ha hiányzik, szöveget ír)
        if not tireRepairTexture and not tireRepairTextureFailed then 
            if fileExists("tire_repair.png") then tireRepairTexture = dxCreateTexture("tire_repair.png", "argb", true, "clamp")
            elseif fileExists("files/images/tire_repair.png") then tireRepairTexture = dxCreateTexture("files/images/tire_repair.png", "argb", true, "clamp")
            else tireRepairTextureFailed = true end 
        end
        
        -- Ikon mérete (900x512 arányhoz igazítva, jelentősen nagyobbra véve!)
        local iconW = 160 * responsiveMultiplier
        local iconH = 90 * responsiveMultiplier
        local iconX = screenX - iconW - 30 
        local iconY = screenY - 280 
        
        if state == "ready" then
            if tireRepairTexture then 
                dxDrawImage(iconX, iconY, iconW, iconH, tireRepairTexture, 0, 0, 0, tocolor(255, 255, 255, 255))
            else 
                dxDrawText("VÉDELEM\nKÉSZ", iconX, iconY, iconX + iconW, iconY + iconH, tocolor(50, 255, 50, 255), 1.0, "default-bold", "center", "center") 
            end
            
        elseif state == "protecting" then
            local remaining = endTime - now
            if remaining < 0 then remaining = 0 end
            local alpha = 150 + math.sin(getTickCount() / 150) * 105
            
            if tireRepairTexture then 
                dxDrawImage(iconX, iconY, iconW, iconH, tireRepairTexture, 0, 0, 0, tocolor(50, 255, 50, alpha))
                -- Szöveg picit feljebb tolva a nagyobb kép miatt
                dxDrawText(tostring(remaining) .. "s", iconX, iconY - 30, iconX + iconW, iconY, tocolor(50, 255, 50, 255), 1.5, "default-bold", "center", "center")
            else 
                dxDrawText("VÉDVE:\n" .. tostring(remaining) .. "s", iconX, iconY, iconX + iconW, iconY + iconH, tocolor(50, 255, 50, alpha), 1.0, "default-bold", "center", "center") 
            end
            
        elseif state == "cooldown" then
            local remaining = endTime - now
            if remaining < 0 then remaining = 0 end
            
            if tireRepairTexture then
                dxDrawImage(iconX, iconY, iconW, iconH, tireRepairTexture, 0, 0, 0, tocolor(255, 255, 255, 70))
                -- Piros visszaszámláló a nagyobb kép közepén
                dxDrawText(tostring(remaining), iconX, iconY, iconX + iconW, iconY + iconH, tocolor(255, 50, 50, 255), 2.0, "default-bold", "center", "center")
            else 
                dxDrawText("TÖLT:\n" .. tostring(remaining) .. "s", iconX, iconY, iconX + iconW, iconY + iconH, tocolor(255, 50, 50, 255), 1.0, "default-bold", "center", "center") 
            end
        end
    end
	if tuningMarkersCount ~= 0 then
		local cameraX, cameraY, cameraZ = getCameraMatrix()

		for marker, id in pairs(tuningMarkers) do
			if marker and isElement(marker) then
				if getElementAlpha(marker) ~= 0 and getElementDimension(marker) == getElementDimension(localPlayer) then
					local markerX, markerY, markerZ = getElementPosition(marker)
					local markerDistance = getDistanceBetweenPoints3D(cameraX, cameraY, cameraZ, markerX, markerY, markerZ)
					
					if markerDistance <= markerImageMaxVisibleDistance then
					    if isLineOfSightClear(cameraX, cameraY, cameraZ, markerX, markerY, markerZ + 1.5, true, false, false, true, false, false, false) then
    					    local screenX, screenY = getScreenFromWorldPosition(markerX, markerY, markerZ + 2.0, 1)
    
    				        if screenX and screenY then
        				        local floatY = math.sin(getTickCount() / 400) * 10 
        				        local imageScale = 1 - (markerDistance / markerImageMaxVisibleDistance) * 0.5
        				        local alphaScale = 1 - (markerDistance / markerImageMaxVisibleDistance)
        
        				        local imageWidth, imageHeight = 150 * imageScale, 150 * imageScale 
        				        local imageX, imageY = math.floor(screenX - (imageWidth / 2)), math.floor((screenY - (imageHeight / 2)) + floatY)
        
        				        dxDrawImage(imageX, imageY, imageWidth, imageHeight, availableTextures["marker"], 0, 0, 0, tocolor(255, 255, 255, 255 * alphaScale))
    				        end
				        end
					end
				end
			else
				tuningMarkers[marker] = nil
			end
		end
	end
	
	if activeTuningMarker and not panelState then
		local screenX, screenY = guiGetScreenSize()
		local tW, tH = 450, 55
		local tX, tY = math.floor((screenX / 2) - (tW / 2)), math.floor(screenY - 180)
		
		local neonAlpha = 150 + math.sin(getTickCount() / 300) * 105
		local neonColor = tocolor(0, 200, 255, neonAlpha) 
		
		local bSize = 2 
		dxDrawRectangle(tX - bSize, tY - bSize, tW + (bSize*2), bSize, neonColor) 
		dxDrawRectangle(tX - bSize, tY + tH, tW + (bSize*2), bSize, neonColor) 
		dxDrawRectangle(tX - bSize, tY, bSize, tH, neonColor) 
		dxDrawRectangle(tX + tW, tY, bSize, tH, neonColor) 
		
		dxDrawRectangle(tX, tY, tW, tH, tocolor(10, 10, 15, 240))
		
		if not globalPromptFont then globalPromptFont = dxCreateFont("opensans.ttf", 16, false, "cleartype") or "default-bold" end
		
		dxDrawText("Nyomd meg az 'E' gombot a tuningoláshoz!", tX, tY, tX + tW, tY + tH, tocolor(255, 255, 255, 255), 1.0, globalPromptFont, "center", "center")
	end
	
	if panelState and enteredVehicle then
		dxDrawRectangle(math.floor(panelX), math.floor(panelY), math.floor(panelWidth), math.floor(logoHeight * responsiveMultiplier), tocolor(10, 10, 10, 255))
		dxDrawImage(math.floor(panelX + (panelWidth / 2) - ((panelWidth * responsiveMultiplier) / 2)), math.floor(panelY), math.floor(panelWidth * responsiveMultiplier), math.floor(logoHeight * responsiveMultiplier), availableTextures["logo"])

		local hudW, hudH = 180 * responsiveMultiplier, 65 * responsiveMultiplier
		local hudX, hudY = math.floor(screenX - hudW - 30), 50
		
		dxDrawRectangle(hudX, hudY, hudW, hudH, tocolor(15, 15, 15, 160)) 
		
		local fontScale = 1.2 
		local hudFont = (availableFonts and availableFonts["opensans"]) or "default-bold"
		local halfH = hudH / 2
		local iconSize = 24 * responsiveMultiplier 
		local iconY = hudY + halfH + (halfH - iconSize) / 2 
		
		dxDrawText("$", hudX + 17, hudY, hudX + 47, hudY + halfH, tocolor(100, 220, 100, 255), fontScale, hudFont, "left", "center")
		dxDrawText(formatNumber(getPlayerMoney(localPlayer), ","), hudX + 45, hudY, hudX + hudW - 15, hudY + halfH, tocolor(255, 255, 255, 255), fontScale, hudFont, "right", "center")
		
		local emeraldVal = getElementData(localPlayer, "player:emerald") or 0 
		if moneyChangeTable["tick"] >= getTickCount() then
			dxDrawText("-$ " .. formatNumber(moneyChangeTable["amount"], ","), hudX + 15, hudY + halfH, hudX + hudW - 15, hudY + hudH, tocolor(220, 80, 80, 255), fontScale, hudFont, "right", "center")
		else
			if availableTextures["emerald"] then
				dxDrawImage(math.floor(hudX + 15), math.floor(iconY), math.floor(iconSize), math.floor(iconSize), availableTextures["emerald"])
			else
				dxDrawText("E", hudX + 15, hudY + halfH, hudX + 45, hudY + hudH, tocolor(80, 220, 180, 255), fontScale, hudFont, "left", "center")
			end
			dxDrawText(formatNumber(emeraldVal, ","), hudX + 45, hudY + halfH, hudX + hudW - 15, hudY + hudH, tocolor(80, 180, 255, 255), fontScale, hudFont, "right", "center")
		end

		if noticeData["text"] then
			if noticeData["state"] == "showNotice" then
				local animationProgress = (getTickCount() - noticeData["tick"]) / 300
				local animationState = interpolateBetween(0, 0, 0, logoHeight * responsiveMultiplier, 0, 0, animationProgress, "Linear")
				noticeData["height"] = animationState
				if animationProgress > 1 then
					noticeData["state"] = "fixNoticeJumping"
					noticeData["timer"] = setTimer(function() noticeData["tick"] = getTickCount(); noticeData["state"] = "hideNotice" end, string.len(noticeData["text"]) * 50, 1)
				end
			elseif noticeData["state"] == "hideNotice" then
				local animationProgress = (getTickCount() - noticeData["tick"]) / 300
				local animationState = interpolateBetween(logoHeight * responsiveMultiplier, 0, 0, 0, 0, 0, animationProgress, "Linear")
				noticeData["height"] = animationState
				if animationProgress > 1 then noticeData["text"] = false end
			elseif noticeData["state"] == "fixNoticeJumping" then
				noticeData["height"] = (logoHeight * responsiveMultiplier)
			end
			
			dxDrawRectangle(panelX, panelY, panelWidth, noticeData["height"], tocolor(0, 0, 0, 200))
			
			if noticeData["height"] == (logoHeight * responsiveMultiplier) then
				local noticeIcon, iconColor = "", {255, 255, 255}
				if noticeData["type"] == "info" then noticeIcon, iconColor = availableIcons["info-circle"], {85, 178, 243}
				elseif noticeData["type"] == "warning" then noticeIcon, iconColor = availableIcons["exclamation-triangle"], {220, 190, 120}
				elseif noticeData["type"] == "error" then noticeIcon, iconColor = availableIcons["exclamation-triangle"], {200, 80, 80}
				elseif noticeData["type"] == "success" then noticeIcon, iconColor = availableIcons["check"], {130, 220, 115} end
				
				dxDrawText(noticeIcon, panelX + 5, panelY + 5, panelX + 5 + panelWidth - 10, panelY + 5 + noticeData["height"] - 10, tocolor(iconColor[1], iconColor[2], iconColor[3], 255), 1.0, availableFonts["icons"], "left", "top")
				dxDrawText(noticeData["text"], panelX + 10, panelY, panelX + 10 + panelWidth - 20, panelY + noticeData["height"], tocolor(255, 255, 255, 255), 0.5, availableFonts["chalet"], "center", "center", false, true)
			end
		end
		
		loopTable, categoryCount, categoryName = {}, 0, "N/A"
		
		if selectedCategory == 0 then
			loopTable = tuningMenu; categoryName = getLocalizedText("menu.mainMenu")
			navigationBar[1][1] = getLocalizedText("navbar.select"); navigationBar[3][1] = getLocalizedText("navbar.exit")
		elseif selectedCategory ~= 0 and selectedSubCategory == 0 then
			loopTable = tuningMenu[selectedCategory]["subMenu"]; categoryName = tuningMenu[selectedCategory]["categoryName"]
			if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.color")) then navigationBar[1][1] = getLocalizedText("navbar.buy") else navigationBar[1][1] = getLocalizedText("navbar.select") end
			navigationBar[3][1] = getLocalizedText("navbar.back")
		elseif selectedCategory ~= 0 and selectedSubCategory ~= 0 then
			if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.optical")) then
				if isGTAUpgradeSlot(tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["upgradeSlot"]) then
					loopTable = tuningMenu[selectedCategory]["availableUpgrades"]; categoryName = tuningMenu[selectedCategory]["categoryName"]
				else
					loopTable = tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["subMenu"]; categoryName = tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["categoryName"]
				end
			else
				loopTable = tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["subMenu"]; categoryName = tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["categoryName"]
			end
			navigationBar[1][1] = getLocalizedText("navbar.buy"); navigationBar[3][1] = getLocalizedText("navbar.back")
		end
		
		local currentPanelY = panelY + (logoHeight * responsiveMultiplier)
		
		dxDrawRectangle(panelX, currentPanelY, panelWidth, rowHeight, tocolor(0, 0, 0, 255))
		dxDrawText(utf8.upper(categoryName), panelX + 10, currentPanelY, panelX + 10 + panelWidth - 20, currentPanelY + rowHeight, tocolor(255, 255, 255, 255), 0.5, availableFonts["chalet"], "left", "center", false, false, false, true)
		dxDrawText(hoveredCategory .. " / " .. #loopTable, panelX + 10, currentPanelY, panelX + 10 + panelWidth - 20, currentPanelY + rowHeight, tocolor(255, 255, 255, 255), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
	
		currentPanelY = currentPanelY + rowHeight
		
		for id, row in ipairs(loopTable) do
			if id >= currentPage and id <= currentPage + maxRowsPerPage then
				local rowX, rowY, rowWidth, rowH = panelX, currentPanelY + (categoryCount * rowHeight), panelWidth, rowHeight
				
				if selectedCategory == 0 or selectedSubCategory == 0 then equippedUpgrade = -1
				elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.optical")) then
					if isGTAUpgradeSlot(tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["upgradeSlot"]) then
						if row["upgradeID"] == equippedTuning then equippedUpgrade = id end
					else
						if id == equippedTuning then equippedUpgrade = id end
					end
				else
					if id == equippedTuning then equippedUpgrade = id end
				end
				
				if hoveredCategory ~= id then
					if categoryCount %2 == 0 then dxDrawRectangle(rowX, rowY, rowWidth, rowH, tocolor(0, 0, 0, 150)) else dxDrawRectangle(rowX, rowY, rowWidth, rowH, tocolor(0, 0, 0, 200)) end
					dxDrawText(row["categoryName"], rowX + 15, rowY, rowX + 15 + rowWidth - 30, rowY + rowH, tocolor(255, 255, 255, 255), 0.5, availableFonts["chalet"], "left", "center", false, false, false, true)
				
					if equippedUpgrade ~= id then
						if row["tuningPrice"] then
							if row["tuningPrice"] == 0 then
								dxDrawText(getLocalizedText("tuningPrice.free"), rowX + 15, rowY, rowX + 15 + rowWidth - 30, rowY + rowH, tocolor(198, 83, 82, 255), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
							else
                                if row["currency"] == "emerald" then
                                -- A számot jobbra igazítjuk, az ikont pedig még jobbra toljuk
                                dxDrawText(row["tuningPrice"], rowX + 15, rowY, rowX + rowWidth - 55, rowY + rowH, tocolor(80, 180, 255, 255), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
                                dxDrawImage(rowX + rowWidth - 45, rowY + (rowH / 2) - 10, 20, 20, availableTextures["emerald"])
                            else
                                dxDrawText("$ " .. formatNumber(row["tuningPrice"], ","), rowX + 15, rowY, rowX + 15 + rowWidth - 30, rowY + rowH, tocolor(255, 255, 255, 200), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
                            end
							end
						end
					else
						dxDrawText(getLocalizedText("tuning.active"), rowX + 15, rowY, rowX + 15 + rowWidth - 30 - dxGetTextWidth(availableIcons["wrench"], 1.0, availableFonts["icons"]) - 10, rowY + rowH, tocolor(150, 255, 150, 255), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
						dxDrawText(availableIcons["wrench"], rowX + 15, rowY, rowX + 15 + rowWidth - 30, rowY + rowH, tocolor(150, 255, 150, 255), 1.0, availableFonts["icons"], "right", "center", false, false, false, true)
					end
				else
					dxDrawImage(rowX, rowY, rowWidth, rowH, availableTextures["hoveredrow"])
					dxDrawText(row["categoryName"], rowX + 15, rowY, rowX + 15 + rowWidth - 30, rowY + rowH, tocolor(0, 0, 0, 255), 0.5, availableFonts["chalet"], "left", "center", false, false, false, true)
				
					if equippedUpgrade ~= id then
						if row["tuningPrice"] then
							if row["tuningPrice"] == 0 then
								dxDrawText(getLocalizedText("tuningPrice.free"), rowX + 15, rowY, rowX + 15 + rowWidth - 30, rowY + rowH, tocolor(0, 0, 0, 255), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
							else
                                if row["currency"] == "emerald" then
                                -- Kék szám, zöld ikon (a tocolor paramétert kivettem a dxDrawImage-ből, így nem lesz fekete)
                                dxDrawText(row["tuningPrice"], rowX + 15, rowY, rowX + rowWidth - 55, rowY + rowH, tocolor(0, 100, 200, 255), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
                                dxDrawImage(rowX + rowWidth - 45, rowY + (rowH / 2) - 10, 20, 20, availableTextures["emerald"])
                            else
                                dxDrawText("$ " .. formatNumber(row["tuningPrice"], ","), rowX + 15, rowY, rowX + 15 + rowWidth - 30, rowY + rowH, tocolor(0, 0, 0, 200), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
                            end
							end
						end
					else
						dxDrawText(getLocalizedText("tuning.active"), rowX + 15, rowY, rowX + 15 + rowWidth - 30 - dxGetTextWidth(availableIcons["wrench"], 1.0, availableFonts["icons"]) - 10, rowY + rowH, tocolor(0, 0, 0, 255), 0.5, availableFonts["chalet"], "right", "center", false, false, false, true)
						dxDrawText(availableIcons["wrench"], rowX + 15, rowY, rowX + 15 + rowWidth - 30, rowY + rowH, tocolor(0, 0, 0, 255), 1.0, availableFonts["icons"], "right", "center", false, false, false, true)
					end
				end
				
				categoryCount = categoryCount + 1
			end
		end
		
		local navBarY = currentPanelY + (categoryCount * rowHeight)
		dxDrawImage(panelX, navBarY, panelWidth, rowHeight, availableTextures["menunav"])
		
		if categoryCount >= (maxRowsPerPage + 1) and categoryCount ~= #loopTable then
			local rowVisible = math.max(0.05, math.min(1.0, (maxRowsPerPage + 1) / #loopTable))
			local scrollbarHeight = ((maxRowsPerPage + 1) * rowHeight) * rowVisible
			local scrollbarPosition = math.min((currentPage - 1) / #loopTable, 1.0 - rowVisible) * ((maxRowsPerPage + 1) * rowHeight)
			dxDrawRectangle(panelX + panelWidth - 2, currentPanelY + scrollbarPosition, 2, scrollbarHeight, tocolor(255, 255, 255, 255))
		end
		
		local navbarWidth = getNavbarWidth()
		local barOffsetX = 0
		drawRoundedRectangle(screenX - navbarWidth - 32 - 10, screenY - 32 - rowHeight, navbarWidth, rowHeight, 1, tocolor(0, 0, 0, 200))
		
		for _, row in ipairs(navigationBar) do
			local textLength = dxGetTextWidth(row[1], 0.5, availableFonts["chalet"]) + 20
			local navX, navY, navHeight = screenX - navbarWidth - 32 + barOffsetX, screenY - 32 - rowHeight, rowHeight
			local navWidth = 0
			for id, icon in ipairs(row[2]) do
				local buttonWidth = 0
				if type(row[3]) == "string" and row[3] == "image" then buttonWidth = row[4]
				elseif type(row[3]) == "boolean" and row[3] then buttonWidth = dxGetTextWidth(availableIcons[icon], 1.0, availableFonts["icons"]) + (20 * responsiveMultiplier)
				elseif type(row[3]) == "boolean" and not row[3] then buttonWidth = dxGetTextWidth(icon, 0.5, availableFonts["chalet"]) + (10 * responsiveMultiplier) end
				
				local iconX = navX + textLength - (10 * responsiveMultiplier) + ((id - 1) * buttonWidth) + ((id - 1) * 5)
				if type(row[3]) == "boolean" then drawRoundedRectangle(iconX, navY + ((rowHeight / 2) - (navbarButtonHeight / 2)), buttonWidth, navbarButtonHeight, 1, tocolor(255, 255, 255, 255)) end
				
				if type(row[3]) == "string" and row[3] == "image" then dxDrawImage(iconX, navY + ((rowHeight / 2) - (navbarButtonHeight / 2)), buttonWidth, navbarButtonHeight, availableTextures[icon])
				elseif type(row[3]) == "boolean" and row[3] then dxDrawText(availableIcons[icon], iconX, navY + ((rowHeight / 2) - (navbarButtonHeight / 2)), iconX + buttonWidth, navY + ((rowHeight / 2) - (navbarButtonHeight / 2)) + navbarButtonHeight, tocolor(0, 0, 0, 255), 1.0, availableFonts["icons"], "center", "center")
				elseif type(row[3]) == "boolean" and not row[3] then dxDrawText(icon, iconX, navY + ((rowHeight / 2) - (navbarButtonHeight / 2)), iconX + buttonWidth, navY + ((rowHeight / 2) - (navbarButtonHeight / 2)) + navbarButtonHeight, tocolor(0, 0, 0, 255), 0.5, availableFonts["chalet"], "center", "center") end
				
				navWidth = navWidth + buttonWidth + (10 * responsiveMultiplier)
			end
			dxDrawText(row[1], navX, navY, navX + navWidth, navY + navHeight, tocolor(255, 255, 255, 255), 0.5, availableFonts["chalet"], "left", "center")
			barOffsetX = barOffsetX + (navWidth + textLength)
		end
		
		if promptDialog["state"] then
			local promptWidth = dxGetTextWidth(getLocalizedText("prompt.text"), 0.5, availableFonts["chalet"]) + 20
			local promptWidth, promptHeight = promptWidth, 120 * responsiveMultiplier
			local promptX, promptY = (screenX / 2) - (promptWidth / 2), (screenY / 2) - (promptHeight / 2)
			
			drawRoundedRectangle(promptX, promptY, promptWidth, promptHeight, 1, tocolor(0, 0, 0, 200))
			dxDrawText(getLocalizedText("prompt.text"), promptX + 10, promptY + 5, promptX + 10 + promptWidth - 20, promptY + 5 + promptHeight - 10, tocolor(255, 255, 255, 255), 0.5, availableFonts["chalet"], "left", "top")
		
			dxDrawText("#cccccc" .. getLocalizedText("prompt.info.1") ..": #ffffff" .. promptDialog["itemName"], promptX + 15, promptY + 30, promptX + 15 + promptWidth - 30, promptY + 30 + promptHeight - 60, tocolor(255, 255, 255, 255), 0.45, availableFonts["chalet"], "left", "top", false, false, false, true)
            
            -- Smaragd vs Dollár kiírása!
            if promptDialog["currency"] == "emerald" then
                dxDrawText("#cccccc" .. getLocalizedText("prompt.info.2") .. ": #50B4FF" .. formatNumber(promptDialog["itemPrice"], ",") .. " Emerald", promptX + 15, promptY + 30 + dxGetFontHeight(0.45, availableFonts["chalet"]), promptX + 15 + promptWidth - 30, promptY + 30 + dxGetFontHeight(0.45, availableFonts["chalet"]) + promptHeight - 60, tocolor(255, 255, 255, 255), 0.45, availableFonts["chalet"], "left", "top", false, false, false, true)
            else
			    dxDrawText("#cccccc" .. getLocalizedText("prompt.info.2") .. ": #ffffff$ " .. formatNumber(promptDialog["itemPrice"], ","), promptX + 15, promptY + 30 + dxGetFontHeight(0.45, availableFonts["chalet"]), promptX + 15 + promptWidth - 30, promptY + 30 + dxGetFontHeight(0.45, availableFonts["chalet"]) + promptHeight - 60, tocolor(255, 255, 255, 255), 0.45, availableFonts["chalet"], "left", "top", false, false, false, true)
            end
		
			local buttonX, buttonY, buttonWidth, buttonHeight = promptX + 10, promptY + promptHeight - 10 - navbarButtonHeight, (promptWidth / 2) - 20, navbarButtonHeight
		
			drawRoundedRectangle(buttonX, buttonY, buttonWidth, buttonHeight, 1, tocolor(110, 207, 112, 255))
			dxDrawText(getLocalizedText("prompt.button.1"), buttonX, buttonY, buttonX + buttonWidth, buttonY + buttonHeight, tocolor(0, 0, 0, 255), 0.5, availableFonts["chalet"], "center", "center")
			
			drawRoundedRectangle((buttonX + buttonWidth + 20), buttonY, buttonWidth, buttonHeight, 1, tocolor(200, 80, 80, 255))
			dxDrawText(getLocalizedText("prompt.button.2"), (buttonX + buttonWidth + 20), buttonY, (buttonX + buttonWidth + 20) + buttonWidth, buttonY + buttonHeight, tocolor(0, 0, 0, 255), 0.5, availableFonts["chalet"], "center", "center")
		end

		--> Tuning Progress Bar (Töltőcsík)
		if tuningProcess.active then
			local progress = (getTickCount() - tuningProcess.startTick) / 5000
			if progress > 1 then progress = 1 end
			
			local barW, barH = 300 * responsiveMultiplier, 12 * responsiveMultiplier
			local barX, barY = (screenX / 2) - (barW / 2), (screenY / 2) + 120
			
			-- Feketébb, üvegesebb háttér (sötétebb alfa: 220)
			dxDrawRectangle(barX - 20, barY - 40, barW + 40, barH + 60, tocolor(5, 5, 5, 220))
			
			-- Szöveg (Picit feljebb tolva: barY - 25 helyett barY - 35)
			dxDrawText("Tuning beszerelés folyamatban...", barX, barY - 35, barX + barW, barY, tocolor(255, 255, 255, 255), 0.5, availableFonts["chalet"], "center", "center")
			
			-- Sáv háttere
			dxDrawRectangle(barX, barY, barW, barH, tocolor(0, 0, 0, 255))
			
			-- Világoszöld töltőcsík (A sötét glow keret eltávolítva!)
			dxDrawRectangle(barX, barY, barW * progress, barH, tocolor(50, 255, 50, 255)) 
			
			-- HA LETELT AZ 5 MÁSODPERC, OTT HELYBEN MEGVESZI (Nincs szimulált gombnyomás!)
			if progress >= 1 then
				tuningProcess.active = false
                
                -- Ellenőrizzük, hogy az adatok megvannak-e
                if tuningProcess.itemData then
                    -- Kinyerjük az elmentett adatokat a memóriából
                    local cat = tuningProcess.itemCategory
                    local subCat = tuningProcess.itemSubCategory
                    local lvl = tuningProcess.itemLevel
                    local row = tuningProcess.itemData
                    local price = row["tuningPrice"]
                    local currency = row["currency"] or "money"

                    -- Fizetés
                    if currency == "emerald" then 
                        triggerServerEvent("tuning->PayEmerald", localPlayer, price)
                    else 
                        takePlayerMoney(price) 
                    end
                    
                    giveNotification("success", getLocalizedText("notification.success.purchased"))
                    playSoundEffect("moneychange.wav")
                    
                    -- Jármű tuningjának élesítése kategóriától függően
                    if cat == getMainCategoryIDByName(getLocalizedText("menu.performance")) then
                        local tuningName = tuningMenu[cat]["subMenu"][subCat]["upgradeData"]
                        setElementData(enteredVehicle, "tuning." .. tuningName, lvl, true)
                        
                        if tuningName ~= "nitro" then
                            triggerServerEvent("tuning->PerformanceUpgrade", localPlayer, enteredVehicle, row["tuningData"], tuningName, lvl)
                            equippedTuning = lvl
                        else
                            if row["tuningData"] == 0 then 
                                triggerServerEvent("tuning->OpticalUpgrade", localPlayer, enteredVehicle, "remove", 1010)
                            else 
                                triggerServerEvent("tuning->OpticalUpgrade", localPlayer, enteredVehicle, "add", 1010) 
                            end
                            setElementData(enteredVehicle, "tuning.nitroLevel", row["tuningData"])
                            refreshVehicleNitroLevel(enteredVehicle, row["tuningData"])
                        end
                        -- ÚJ SOR: Szólunk a szervernek, hogy mentse az adatbázisba!
                        triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)

                    elseif cat == getMainCategoryIDByName(getLocalizedText("menu.optical")) then
                        if isGTAUpgradeSlot(tuningMenu[cat]["subMenu"][subCat]["upgradeSlot"]) then
                            if row["upgradeID"] == 0 then 
                                triggerServerEvent("tuning->OpticalUpgrade", localPlayer, enteredVehicle, "remove", equippedTuning)
                                equippedTuning = 0
                            else 
                                triggerServerEvent("tuning->OpticalUpgrade", localPlayer, enteredVehicle, "add", row["upgradeID"])
                                equippedTuning = row["upgradeID"] 
                            end
                            -- ÚJ SOR: Szólunk a szervernek, hogy mentse az adatbázisba!
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)

                        elseif subCat == 10 then -- Air-Ride
                            setElementData(enteredVehicle, "tuning.airRide", row["tuningData"], true)
                            if lvl == 1 then removeAirRide(enteredVehicle) end
                            equippedTuning = lvl
                            -- ÚJ SOR: Szólunk a szervernek, hogy mentse az adatbázisba!
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle) 
                            
                        elseif subCat == 11 then -- Lámpa
                            savedVehicleColors["all"] = {getVehicleColor(enteredVehicle, true)}
                            savedVehicleColors["headlight"] = {getVehicleHeadLightColor(enteredVehicle)}
                            triggerServerEvent("tuning->Color", localPlayer, enteredVehicle, savedVehicleColors["all"], savedVehicleColors["headlight"])
                            equippedTuning = -1
                            -- ÚJ SOR: Ráerősítünk a mentésre a lámpaszínnél is!
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)
                            
                        elseif subCat == 12 then -- Neon
                            saveNeon(enteredVehicle, row["tuningData"], true)
                            
                            -- OKOS TRÜKK: Ráerőltetjük a mi "tuning.neon" nevünket is a kocsira
                            setElementData(enteredVehicle, "tuning.neon", row["tuningData"], true)
                            
                            equippedTuning = lvl
                            -- ÚJ SOR: Szólunk a szervernek, hogy mentse az adatbázisba!
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle) 
                        end
                        
                    elseif cat == getMainCategoryIDByName(getLocalizedText("menu.extras")) then
                        if subCat == 1 or subCat == 2 then
                            local vehicleSide = (subCat == 1 and "front") or (subCat == 2 and "rear")
                            triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, vehicleSide, row["tuningData"])
                            equippedTuning = lvl
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)

                        elseif subCat == 3 then
                            triggerServerEvent("tuning->OffroadAbility", localPlayer, enteredVehicle, row["tuningData"])
                            equippedTuning = lvl
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)

                        elseif subCat == 4 or subCat == 7 then
                            triggerServerEvent("tuning->HandlingUpdate", localPlayer, enteredVehicle, tuningMenu[cat]["subMenu"][subCat]["propertyName"], row["tuningData"])
                            equippedTuning = lvl
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)

                        elseif subCat == 5 then
                            setElementData(enteredVehicle, "tuning.bulletProofTires", row["tuningData"], true)
                            equippedTuning = lvl
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)

                        elseif subCat == 6 then
                            setVehicleDoorToLSD(enteredVehicle, row["tuningData"])
                            -- OKOS TRÜKK: Ráerőltetjük a mi "tuning.lsdDoor" nevünket is a kocsira
                            setElementData(enteredVehicle, "tuning.lsdDoor", row["tuningData"], true)
                            equippedTuning = lvl
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)

                        elseif subCat == 8 then
                            if row["tuningData"] == "random" then vehicleNumberplate = generateString(8) end
                            triggerServerEvent("tuning->LicensePlate", localPlayer, enteredVehicle, vehicleNumberplate)
                            equippedTuning = vehicleNumberplate
                            triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)
                        end
                    elseif cat == getMainCategoryIDByName(getLocalizedText("menu.color")) then
                        savedVehicleColors["all"] = {getVehicleColor(enteredVehicle, true)}
                        savedVehicleColors["headlight"] = {getVehicleHeadLightColor(enteredVehicle)}
                        triggerServerEvent("tuning->Color", localPlayer, enteredVehicle, savedVehicleColors["all"], savedVehicleColors["headlight"])
                        equippedTuning = lvl
                        triggerServerEvent("tuning->SaveVehicle", localPlayer, enteredVehicle)
                    end
                else
                    outputDebugString("Hiba: tuningProcess.itemData nil!", 1)
                end
			end
		end
	end
end)

addEventHandler("onClientPreRender", root, function(timeSlice)
	if isCursorShowing() then
		local cursorX, cursorY = getCursorPosition()
		mouseTable["speed"][1] = math.sqrt(math.pow((mouseTable["last"][1] - cursorX) / timeSlice, 2))
		mouseTable["speed"][2] = math.sqrt(math.pow((mouseTable["last"][2] - cursorY) / timeSlice, 2))
		mouseTable["last"][1] = cursorX
		mouseTable["last"][2] = cursorY
	end
	
	if panelState and enteredVehicle then
		local _, _, _, _, _, _, roll, fov = getCameraMatrix()
		local cameraZoomProgress = (getTickCount() - cameraSettings["zoomTick"]) / 500
		local cameraZoomAnimation = interpolateBetween(fov, 0, 0, cameraSettings["zoom"], 0, 0, cameraZoomProgress, "Linear")
		
		if cameraSettings["moveState"] == "moveToElement" then
			local currentCameraX, currentCameraY, currentCameraZ, currentCameraRotX, currentCameraRotY, currentCameraRotZ = getCameraMatrix()
			local cameraProgress = (getTickCount() - cameraSettings["moveTick"]) / 1000
			local cameraX, cameraY, cameraZ, componentX, componentY, componentZ = _getCameraPosition("component")
			local newCameraX, newCameraY, newCameraZ = interpolateBetween(currentCameraX, currentCameraY, currentCameraZ, cameraX, cameraY, cameraZ, cameraProgress, "Linear")
			local newCameraRotX, newCameraRotY, newCameraRotZ = interpolateBetween(currentCameraRotX, currentCameraRotY, currentCameraRotZ, componentX, componentY, componentZ, cameraProgress, "Linear")
			local newCameraZoom = interpolateBetween(fov, 0, 0, 60, 0, 0, cameraProgress, "Linear")
			
			setCameraMatrix(newCameraX, newCameraY, newCameraZ, newCameraRotX, newCameraRotY, newCameraRotZ, roll, newCameraZoom)
			
			if cameraProgress > 0.5 then cameraSettings["moveState"] = "freeMode"; cameraSettings["zoom"] = 60 end
		elseif cameraSettings["moveState"] == "backToVehicle" then
			local currentCameraX, currentCameraY, currentCameraZ, currentCameraRotX, currentCameraRotY, currentCameraRotZ = getCameraMatrix()
			local cameraProgress = (getTickCount() - cameraSettings["moveTick"]) / 1000
			local cameraX, cameraY, cameraZ, vehicleX, vehicleY, vehicleZ = _getCameraPosition("vehicle")
			local newCameraX, newCameraY, newCameraZ = interpolateBetween(currentCameraX, currentCameraY, currentCameraZ, cameraX, cameraY, cameraZ, cameraProgress, "Linear")
			local newCameraRotX, newCameraRotY, newCameraRotZ = interpolateBetween(currentCameraRotX, currentCameraRotY, currentCameraRotZ, vehicleX, vehicleY, vehicleZ, cameraProgress, "Linear")
			local newCameraZoom = interpolateBetween(fov, 0, 0, 60, 0, 0, cameraProgress, "Linear")
			
			setCameraMatrix(newCameraX, newCameraY, newCameraZ, newCameraRotX, newCameraRotY, newCameraRotZ, roll, newCameraZoom)
			
			if cameraProgress > 0.5 then cameraSettings["moveState"] = "freeMode"; cameraSettings["zoom"] = 60 end
		elseif cameraSettings["moveState"] == "freeMode" then
			local cameraX, cameraY, cameraZ, elementX, elementY, elementZ = _getCameraPosition("both")
			setCameraMatrix(cameraX, cameraY, cameraZ, elementX, elementY, elementZ, roll, cameraZoomAnimation)
			
			if getKeyState("mouse1") and not pickingColor and not pickingLuminance and isCursorShowing() and not isMTAWindowActive() and not promptDialog["state"] then
				cameraSettings["freeModeActive"] = true
			else cameraSettings["freeModeActive"] = false end
		end
	end
end)

addEventHandler("onClientCursorMove", root, function(cursorX, cursorY, absoluteX, absoluteY)
	if panelState and enteredVehicle then
		if cameraSettings["freeModeActive"] then
			lastCursorX = mouseTable["move"][1]
			lastCursorY = mouseTable["move"][2]
			mouseTable["move"][1] = cursorX
			mouseTable["move"][2] = cursorY
			
			if cursorX > lastCursorX then cameraSettings["currentX"] = cameraSettings["currentX"] - (mouseTable["speed"][1] * 100)
			elseif cursorX < lastCursorX then cameraSettings["currentX"] = cameraSettings["currentX"] + (mouseTable["speed"][1] * 100) end
			
			if cursorY > lastCursorY then cameraSettings["currentZ"] = cameraSettings["currentZ"] + (mouseTable["speed"][2] * 50)
			elseif cursorY < lastCursorY then cameraSettings["currentZ"] = cameraSettings["currentZ"] - (mouseTable["speed"][2] * 50) end
			
			cameraSettings["currentY"] = cameraSettings["currentX"]
			cameraSettings["currentZ"] = math.max(cameraSettings["minimumZ"], math.min(cameraSettings["maximumZ"], cameraSettings["currentZ"]))
		end
	end
end)

addEventHandler("onClientCharacter", root, function(character)
	if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.extras")) then
		if selectedSubCategory == 8 and hoveredCategory == 2 then
			if #vehicleNumberplate < 8 then
				local supportedCharacters = {
					["q"] = true, ["w"] = true, ["x"] = true, ["4"] = true, ["e"] = true, ["r"] = true, ["c"] = true, ["5"] = true,
					["t"] = true, ["z"] = true, ["v"] = true, ["6"] = true, ["u"] = true, ["i"] = true, ["b"] = true, ["7"] = true,
					["o"] = true, ["p"] = true, ["n"] = true, ["8"] = true, ["a"] = true, ["s"] = true, ["m"] = true, ["9"] = true,
					["d"] = true, ["f"] = true, ["0"] = true, ["-"] = true, ["g"] = true, ["h"] = true, ["1"] = true, [" "] = true,
					["j"] = true, ["k"] = true, ["2"] = true, ["l"] = true, ["y"] = true, ["3"] = true,
				}
				if supportedCharacters[character] then
					vehicleNumberplate = vehicleNumberplate .. utf8.upper(character)
					setVehiclePlateText(enteredVehicle, vehicleNumberplate)
				end
			end
		end
	end
end)

addEventHandler("onClientKey", root, function(key, pressed)
	if panelState and enteredVehicle then
        
        -- *** EZ A LEGFONTOSABB SOR: BLOKKOL MINDENT TÖLTÉS ALATT ***
        if tuningProcess.active then return end 

		if pressed then
			if key == "arrow_d" and not promptDialog["state"] then
				if hoveredCategory > #loopTable or hoveredCategory == #loopTable then hoveredCategory = #loopTable
				else
					if hoveredCategory > maxRowsPerPage then currentPage = currentPage + 1 end
					hoveredCategory = hoveredCategory + 1
					
					if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.optical")) then
						if selectedSubCategory ~= 0 then
							if isGTAUpgradeSlot(tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["upgradeSlot"]) then showNextOpticalUpgrade()
							else if selectedSubCategory == 12 then addNeon(enteredVehicle, loopTable[hoveredCategory]["tuningData"]) end end
						end
					elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.extras")) then
						if selectedSubCategory == 1 then triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, "front", loopTable[hoveredCategory]["tuningData"])
						elseif selectedSubCategory == 2 then triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, "rear", loopTable[hoveredCategory]["tuningData"]) end
					elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.color")) then
						setVehicleColorsToDefault(); setPaletteType(loopTable[hoveredCategory]["tuningData"]); updatePaletteColor(enteredVehicle, loopTable[hoveredCategory]["tuningData"])
					end
					playSoundEffect("menunavigate.mp3")
				end
			elseif key == "arrow_u" and not promptDialog["state"] then
    			if hoveredCategory < 1 or hoveredCategory == 1 then 
        			hoveredCategory = 1
        			if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.optical")) then
            			if selectedSubCategory ~= 0 then if isGTAUpgradeSlot(tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["upgradeSlot"]) then showDefaultOpticalUpgrade() end end
       	 			end
    			else
        			if currentPage - 1 >= 1 then currentPage = currentPage - 1 end
        			hoveredCategory = hoveredCategory - 1
					
					if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.optical")) then
						if selectedSubCategory ~= 0 then
							if isGTAUpgradeSlot(tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["upgradeSlot"]) then
								if hoveredCategory == 1 then removeVehicleUpgrade(enteredVehicle, compatibleOpticalUpgrades[hoveredCategory]) else showNextOpticalUpgrade() end
							else
								if selectedSubCategory == 12 then
									if hoveredCategory == 1 then removeNeon(enteredVehicle, true) else addNeon(enteredVehicle, loopTable[hoveredCategory]["tuningData"]) end
								end
							end
						end
					elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.extras")) then
						if selectedSubCategory == 1 then triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, "front", loopTable[hoveredCategory]["tuningData"])
						elseif selectedSubCategory == 2 then triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, "rear", loopTable[hoveredCategory]["tuningData"])
						elseif selectedSubCategory == 8 then
							if equippedTuning ~= vehicleNumberplate then setVehiclePlateText(enteredVehicle, equippedTuning); vehicleNumberplate = equippedTuning end
						end
					
					elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.color")) then
						setVehicleColorsToDefault(); setPaletteType(loopTable[hoveredCategory]["tuningData"]); updatePaletteColor(enteredVehicle, loopTable[hoveredCategory]["tuningData"])
					end
					playSoundEffect("menunavigate.mp3")
				end
			
			elseif key == "backspace" then
				if promptDialog["state"] then promptDialog["state"] = false
				else
					if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.extras")) and selectedSubCategory == 8 then
						if hoveredCategory == 2 then
							if #vehicleNumberplate - 1 >= 0 then vehicleNumberplate = string.sub(vehicleNumberplate, 1, #vehicleNumberplate - 1); setVehiclePlateText(enteredVehicle, vehicleNumberplate)
							else setVehiclePlateText(enteredVehicle, ""); vehicleNumberplate = "" end
							return
						else
							if equippedTuning ~= vehicleNumberplate then setVehiclePlateText(enteredVehicle, equippedTuning); vehicleNumberplate = equippedTuning end
						end
					end
					
					if selectedCategory == 0 and selectedSubCategory == 0 then triggerEvent("tuning->HideMenu", localPlayer)
					elseif selectedCategory ~= 0 and selectedSubCategory == 0 then
						if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.color")) then destroyColorPicker(); setVehicleColorsToDefault() end
						selectedCategory, hoveredCategory, currentPage = 0, 1, 1
					elseif selectedCategory ~= 0 and selectedSubCategory ~= 0 then
						moveCameraToDefaultPosition()
						if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.optical")) then
							if selectedSubCategory ~= 0 then
								if isGTAUpgradeSlot(tuningMenu[selectedCategory]["subMenu"][selectedSubCategory]["upgradeSlot"]) then
									resetOpticalUpgrade(); tuningMenu[selectedCategory]["availableUpgrades"] = {}; equippedTuning = 1
								else
									if selectedSubCategory == 11 then destroyColorPicker(); setVehicleColorsToDefault(); setVehicleOverrideLights(enteredVehicle, 1)
									elseif selectedSubCategory == 12 then restoreOldNeon(enteredVehicle) end
								end
							end
						elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.extras")) then
							if selectedSubCategory == 1 then
								local defaultWheelSize = (equippedTuning == 1 and "verynarrow") or (equippedTuning == 2 and "narrow") or (equippedTuning == 3 and "default") or (equippedTuning == 4 and "wide") or (equippedTuning == 5 and "verywide")
								triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, "front", defaultWheelSize)
							elseif selectedSubCategory == 2 then
								local defaultWheelSize = (equippedTuning == 1 and "verynarrow") or (equippedTuning == 2 and "narrow") or (equippedTuning == 3 and "default") or (equippedTuning == 4 and "wide") or (equippedTuning == 5 and "verywide")
								triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, "rear", defaultWheelSize)
							elseif selectedSubCategory == 6 then
								setVehicleDoorOpenRatio(enteredVehicle, 2, 0, 500); setVehicleDoorOpenRatio(enteredVehicle, 3, 0, 500)
								setVehicleDoorToLSD(enteredVehicle, ((equippedTuning == 1 and false) or (equippedTuning == 2 and true)))
							end
						end
						selectedSubCategory, hoveredCategory, currentPage = 0, 1, 1
					end
					playSoundEffect("menuback.wav")
					if enteredVehicle then for component in pairs(getVehicleComponents(enteredVehicle)) do setVehicleComponentVisible(enteredVehicle, component, true) end end
				end
			elseif key == "enter" then
				if not promptDialog["state"] and not tuningProcess.readyToBuy then
					if selectedCategory == 0 then
						selectedCategory, currentPage, hoveredCategory = hoveredCategory, 1, 1
						if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.color")) then
							savedVehicleColors["all"] = {getVehicleColor(enteredVehicle, true)}; savedVehicleColors["headlight"] = {getVehicleHeadLightColor(enteredVehicle)}
							createColorPicker(enteredVehicle, panelX + 2, (panelY + (logoHeight * responsiveMultiplier) + rowHeight + (categoryCount * rowHeight) + rowHeight) + 2, panelWidth - 4, (panelWidth / 2) * responsiveMultiplier, "color1")
						end
						playSoundEffect("menuenter.mp3")
					elseif selectedCategory ~= 0 and selectedSubCategory == 0 then
						if selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.performance")) then
							local componentCompatible = false
							if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck", "Quad", "Bike"}) then
								local tuningDataName = loopTable[hoveredCategory]["upgradeData"]
								local equippedTuningID = getElementData(enteredVehicle, "tuning." .. tuningDataName) or 1
								if tuningDataName ~= "nitro" then equippedTuning = equippedTuningID; componentCompatible = true
								else
									if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck"}) then equippedTuning = -1; componentCompatible = true end
								end
							end
							if componentCompatible then setCameraAndComponentVisible(); selectedSubCategory, hoveredCategory, currentPage = hoveredCategory, 1, 1 end
						elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.optical")) then
							if isGTAUpgradeSlot(loopTable[hoveredCategory]["upgradeSlot"]) then
								local upgradeSlot = loopTable[hoveredCategory]["upgradeSlot"]
								local compatibleUpgrades = getVehicleCompatibleUpgrades(enteredVehicle, upgradeSlot)
								if compatibleUpgrades[1] == nil then giveNotification("error", getLocalizedText("notification.error.notCompatible", loopTable[hoveredCategory]["categoryName"]))
								else
									setCameraAndComponentVisible(); compatibleOpticalUpgrades = compatibleUpgrades; equippedTuning = getVehicleUpgradeOnSlot(enteredVehicle, upgradeSlot)
									table.insert(tuningMenu[selectedCategory]["availableUpgrades"], { ["categoryName"] = getLocalizedText("tuningPack.0"), ["tuningPrice"] = 0, ["upgradeID"] = 0 })
									for id, upgrade in pairs(compatibleOpticalUpgrades) do table.insert(tuningMenu[selectedCategory]["availableUpgrades"], { ["categoryName"] = tuningMenu[selectedCategory]["subMenu"][hoveredCategory]["categoryName"] .. " " .. id, ["tuningPrice"] = tuningMenu[selectedCategory]["subMenu"][hoveredCategory]["tuningPrice"], ["upgradeID"] = upgrade }) end
									selectedSubCategory, hoveredCategory, currentPage = hoveredCategory, 1, 1; showDefaultOpticalUpgrade()
								end
							else
								local componentCompatible = false
								if hoveredCategory == 10 then if isComponentCompatible(enteredVehicle, "Automobile") then equippedTuning = (getElementData(enteredVehicle, "tuning.airRide") and 2) or 1; componentCompatible = true end
								elseif hoveredCategory == 11 then
									if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck", "Quad", "Bike"}) then
										equippedTuning = -1; setVehicleOverrideLights(enteredVehicle, 2)
										savedVehicleColors["all"] = {getVehicleColor(enteredVehicle, true)}; savedVehicleColors["headlight"] = {getVehicleHeadLightColor(enteredVehicle)}
										createColorPicker(enteredVehicle, panelX + 2, (panelY + (logoHeight * responsiveMultiplier) + (rowHeight * 2) + rowHeight) + 2, panelWidth - 4, (panelWidth / 2) * responsiveMultiplier, "headlight")
										componentCompatible = true
									end
								elseif hoveredCategory == 12 then
									if isComponentCompatible(enteredVehicle, "Automobile") then
										local currentNeon = getElementData(enteredVehicle, "tuning.neon") or false
										if currentNeon == "white" then currentNeon = 2 elseif currentNeon == "blue" then currentNeon = 3 elseif currentNeon == "green" then currentNeon = 4 elseif currentNeon == "red" then currentNeon = 5 elseif currentNeon == "yellow" then currentNeon = 6 elseif currentNeon == "pink" then currentNeon = 7 elseif currentNeon == "orange" then currentNeon = 8 elseif currentNeon == "lightblue" then currentNeon = 9 elseif currentNeon == "rasta" then currentNeon = 10 elseif currentNeon == "ice" then currentNeon = 11 else currentNeon = 1 end
										equippedTuning = currentNeon; removeNeon(enteredVehicle, true); componentCompatible = true
									end
								end
								if componentCompatible then setCameraAndComponentVisible(); selectedSubCategory, hoveredCategory, currentPage = hoveredCategory, 1, 1 end
							end
						elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.extras")) then
							local componentCompatible = false
							if hoveredCategory == 1 then if isComponentCompatible(enteredVehicle, "Automobile") then equippedTuning = getVehicleWheelSize(enteredVehicle, "front"); triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, "front", loopTable[hoveredCategory]["subMenu"][1]["tuningData"]); componentCompatible = true end
							elseif hoveredCategory == 2 then if isComponentCompatible(enteredVehicle, "Automobile") then equippedTuning = getVehicleWheelSize(enteredVehicle, "rear"); triggerServerEvent("tuning->WheelWidth", localPlayer, enteredVehicle, "rear", loopTable[hoveredCategory]["subMenu"][1]["tuningData"]); componentCompatible = true end
							elseif hoveredCategory == 3 then if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck", "Quad", "Bike"}) then equippedTuning = getVehicleOffroadAbility(enteredVehicle); componentCompatible = true end
							elseif hoveredCategory == 4 then if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck", "Quad"}) then local driveType = getVehicleHandling(enteredVehicle)["driveType"]; equippedTuning = (driveType == "fwd" and 1) or (driveType == "awd" and 2) or (driveType == "rwd" and 3); componentCompatible = true end
							elseif hoveredCategory == 5 then if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck", "Quad", "Bike"}) then equippedTuning = (getElementData(enteredVehicle, "tuning.bulletProofTires") and 2) or 1; componentCompatible = true end
							elseif hoveredCategory == 6 then if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck"}) then equippedTuning = (getElementData(enteredVehicle, "tuning.lsdDoor") and 2) or 1; setVehicleDoorOpenRatio(enteredVehicle, 2, 1, 500); setVehicleDoorOpenRatio(enteredVehicle, 3, 1, 500); setVehicleDoorToLSD(enteredVehicle, true); componentCompatible = true end
							elseif hoveredCategory == 7 then if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck", "Quad", "Bike", "BMX"}) then local steeringLock = getVehicleHandling(enteredVehicle)["steeringLock"]; equippedTuning = (steeringLock == 30 and 2) or (steeringLock == 40 and 3) or (steeringLock == 50 and 4) or (steeringLock == 60 and 5) or 1; componentCompatible = true end
							elseif hoveredCategory == 8 then if isComponentCompatible(enteredVehicle, {"Automobile", "Monster Truck", "Quad", "Bike"}) then equippedTuning = getVehiclePlateText(enteredVehicle); vehicleNumberplate = equippedTuning; componentCompatible = true end end
							if componentCompatible then setCameraAndComponentVisible(); selectedSubCategory, hoveredCategory, currentPage = hoveredCategory, 1, 1 end
						elseif selectedCategory == getMainCategoryIDByName(getLocalizedText("menu.color")) then 
						promptDialog = { ["state"] = true, ["itemName"] = categoryName .. " (" .. loopTable[hoveredCategory]["categoryName"] .. ")", ["itemPrice"] = loopTable[hoveredCategory]["tuningPrice"], ["currency"] = loopTable[hoveredCategory]["currency"] or "money", ["itemData"] = loopTable[hoveredCategory], ["cat"] = selectedCategory, ["subCat"] = selectedSubCategory, ["lvl"] = hoveredCategory } 
					end
					playSoundEffect("menuenter.mp3")
					elseif selectedCategory ~= 0 and selectedSubCategory ~= 0 then 
						promptDialog = { ["state"] = true, ["itemName"] = categoryName .. " (" .. loopTable[hoveredCategory]["categoryName"] .. ")", ["itemPrice"] = loopTable[hoveredCategory]["tuningPrice"], ["currency"] = loopTable[hoveredCategory]["currency"] or "money", ["itemData"] = loopTable[hoveredCategory], ["cat"] = selectedCategory, ["subCat"] = selectedSubCategory, ["lvl"] = hoveredCategory } 
					end
				else -- Ha rányomott a promptban a vásárlásra (ENTER)
					if tuningProcess.active then return end -- Ne lehessen spammelni!

					-- Az adatokat a felokosított promptból olvassuk ki!
					local price = promptDialog.itemPrice
					local currency = promptDialog.currency
					local canBuy = false
					
					if currency == "emerald" then
						local myEm = tonumber(getElementData(localPlayer, "player:emerald")) or 0
						if myEm >= price then canBuy = true end
					else
						if hasPlayerMoney(price) then canBuy = true end
					end
					
					if canBuy then
						-- Átadjuk a lementett, hibátlan adatokat a Töltőcsíknak!
						tuningProcess.itemData = promptDialog.itemData
						tuningProcess.itemCategory = promptDialog.cat
						tuningProcess.itemSubCategory = promptDialog.subCat
						tuningProcess.itemLevel = promptDialog.lvl
						
						promptDialog["state"] = false
						tuningProcess.active = true
						tuningProcess.startTick = getTickCount()
						playSound("files/sounds/tuning_process.mp3", false)
					else
						giveNotification("error", "Nincs elég pénzed/emeralds-od!")
						promptDialog["state"] = false
					end
				end
			end
			
			-- Egér görgő (Kamera zoom)
			if key == "mouse_wheel_up" and not promptDialog["state"] then
				if isCursorShowing() and not isMTAWindowActive() then 
					cameraSettings["zoom"] = math.max(cameraSettings["zoom"] - 5, 30)
					cameraSettings["zoomTick"] = getTickCount() 
				end
			elseif key == "mouse_wheel_down" and not promptDialog["state"] then
				if isCursorShowing() and not isMTAWindowActive() then 
					cameraSettings["zoom"] = math.min(cameraSettings["zoom"] + 5, 60)
					cameraSettings["zoomTick"] = getTickCount() 
				end
			end
		end
	end
end)

addEventHandler("tuning->ShowMenu", root, function(vehicle)
	if source and vehicle then
		if not panelState then
			enteredVehicle = vehicle
			createFonts()
			hoveredCategory, selectedCategory, selectedSubCategory = 1, 0, 0
			maxRowsPerPage, currentPage = 7, 1
			navigationBar[1][1] = getLocalizedText("navbar.select")
			navigationBar[2][1] = getLocalizedText("navbar.navigate")
			navigationBar[3][1] = getLocalizedText("navbar.back")
			
			if noticeData["timer"] then if isTimer(noticeData["timer"]) then killTimer(noticeData["timer"]) end end
			noticeData = { ["text"] = false, ["type"] = "info", ["tick"] = 0, ["state"] = "", ["height"] = 0, ["timer"] = nil }
			
			local _, _, vehicleRotation = getElementRotation(enteredVehicle)
			local cameraRotation = vehicleRotation + 60
			
			cameraSettings = { ["distance"] = 9, ["movingSpeed"] = 2, ["currentX"] = math.rad(cameraRotation), ["defaultX"] = math.rad(cameraRotation), ["currentY"] = math.rad(cameraRotation), ["currentZ"] = math.rad(15), ["maximumZ"] = math.rad(35), ["minimumZ"] = math.rad(0), ["freeModeActive"] = false, ["zoomTick"] = 0, ["zoom"] = 60 }
			cameraSettings["moveState"] = "freeMode"
			promptDialog = { ["state"] = false, ["itemName"] = "", ["itemPrice"] = 0 }
			
			panelState = true
			toggleAllControls(false)
			setPlayerHudComponentVisible("all", false)
			showChat(false)
			setElementData(localPlayer, "hudVisible", false)
			showCursor(true)
		end
	end
end)

addEventHandler("tuning->HideMenu", root, function()
	if enteredVehicle and panelState then
		panelState = false
		toggleAllControls(true)
		showChat(true)
		setElementData(localPlayer, "hudVisible", true) 
		setPlayerHudComponentVisible("crosshair", true) 
		enteredVehicle = nil
		destroyFonts()
		setCameraTarget(localPlayer)
		showCursor(false)
		triggerServerEvent("tuning->ResetMarker", root, localPlayer)
	end
end)

addEventHandler("onClientVehicleDamage", root, function(attacker, weapon, loss, x, y, z, tyre)
    -- Csak akkor foglalkozunk vele, ha a járművön van golyóálló kerék tuning
    if getElementData(source, "tuning.bulletProofTires") then
        if tyre and tyre >= 0 and tyre <= 3 then -- Ha kifejezetten valamelyik kereket érte találat
            local now = getRealTime().timestamp
            local state = getElementData(source, "bp_state") or "ready"
            
            if state == "ready" then
                -- 1. Állapot átállítása védelemre (50 másodperc)
                setElementData(source, "bp_state", "protecting")
                setElementData(source, "bp_end_time", now + 50)
                
                -- 2. Sebzés kivédése és a kerék azonnali betonba öntése!
                cancelEvent() 
                setTimer(setVehicleWheelStates, 50, 1, source, 0, 0, 0, 0)
                
            elseif state == "protecting" then
                -- Ha már védve van, minden további lövést kivédünk!
                cancelEvent()
                setTimer(setVehicleWheelStates, 50, 1, source, 0, 0, 0, 0)
            end
            
            -- Ha state == "cooldown", direkt nem csinálunk semmit, így a kerék a játék alapműködése szerint kidurran!
        end
    end
end)

function moneyChange(amount)
    local currency = loopTable[hoveredCategory]["currency"] or "money"
    if currency == "emerald" then
        triggerServerEvent("tuning->PayEmerald", localPlayer, amount)
    else
        takePlayerMoney(amount)
    end
	giveNotification("success", getLocalizedText("notification.success.purchased"))
	playSoundEffect("moneychange.wav")
	if amount > 0 then moneyChangeTable = { ["tick"] = getTickCount() + 5000, ["amount"] = amount } end
end

function createFonts()
	availableFonts = {
		chalet = dxCreateFont("files/fonts/chalet.ttf", 28 * responsiveMultiplier, false, "antialiased"),
		icons = dxCreateFont("files/fonts/icons.ttf", 16 * responsiveMultiplier, false, "antialiased"),
		moneyFont = dxCreateFont("files/fonts/pricedown.ttf", 46 * responsiveMultiplier, false, "antialiased"),
		opensans = dxCreateFont("opensans.ttf", 15 * responsiveMultiplier, false, "cleartype") -- EZT ADD HOZZÁ
	}
end

function destroyFonts()
	if availableFonts then
		for fontName, fontElement in pairs(availableFonts) do destroyElement(fontElement); availableFonts[fontName] = nil end
		availableFonts = nil
	end
end

function drawTextWithBorder(text, offset, x, y, w, h, borderColor, color, ...)
	dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x - offset, y - offset, w - offset, h - offset, borderColor or tocolor(0, 0, 0, 255), ...)
	dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x - offset, y + offset, w - offset, h + offset, borderColor or tocolor(0, 0, 0, 255), ...)
	dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x + offset, y - offset, w + offset, h - offset, borderColor or tocolor(0, 0, 0, 255), ...)
	dxDrawText(text:gsub("#%x%x%x%x%x%x", ""), x + offset, y + offset, w + offset, h + offset, borderColor or tocolor(0, 0, 0, 255), ...)
	dxDrawText(text, x, y, w, h, color, ...)
end

function giveNotification(type, text)
	type = type or "info"
	if noticeData["timer"] then if isTimer(noticeData["timer"]) then killTimer(noticeData["timer"]) end end
	noticeData = { ["text"] = text, ["type"] = type, ["tick"] = getTickCount(), ["state"] = "showNotice", ["height"] = 0, ["timer"] = nil }
	playSoundEffect("notification.mp3")
end

function getNavbarWidth()
	local barOffsetX = 0
	for _, row in ipairs(navigationBar) do
		local textLength = dxGetTextWidth(row[1], 0.5, availableFonts["chalet"]) + 20
		local navWidth = 0
		for id, icon in ipairs(row[2]) do
			local buttonWidth = 0
			if type(row[3]) == "string" and row[3] == "image" then buttonWidth = row[4]
			elseif type(row[3]) == "boolean" and row[3] then buttonWidth = dxGetTextWidth(availableIcons[icon], 1.0, availableFonts["icons"]) + (20 * responsiveMultiplier)
			elseif type(row[3]) == "boolean" and not row[3] then buttonWidth = dxGetTextWidth(icon, 0.5, availableFonts["chalet"]) + (10 * responsiveMultiplier) end
			navWidth = navWidth + buttonWidth + (10 * responsiveMultiplier)
		end
		barOffsetX = barOffsetX + (navWidth + textLength)
	end
	return barOffsetX
end

function hasPlayerMoney(money)
	if getPlayerMoney(localPlayer) >= money then return true end
	return false
end

function drawRoundedRectangle(x, y, w, h, rounding, borderColor, bgColor, postGUI)
	borderColor = borderColor or tocolor(0, 0, 0, 200); bgColor = bgColor or borderColor; rounding = rounding or 2
	dxDrawRectangle(x, y, w, h, bgColor, postGUI)
	dxDrawRectangle(x + rounding, y - 1, w - (rounding * 2), 1, borderColor, postGUI)
	dxDrawRectangle(x + rounding, y + h, w - (rounding * 2), 1, borderColor, postGUI)
	dxDrawRectangle(x - 1, y + rounding, 1, h - (rounding * 2), borderColor, postGUI)
	dxDrawRectangle(x + w, y + rounding, 1, h - (rounding * 2), borderColor, postGUI)
end

function showDefaultOpticalUpgrade()
	if panelState then
		if enteredVehicle then
			if equippedTuning ~= 0 then removeVehicleUpgrade(enteredVehicle, equippedTuning)
			elseif equippedTuning == 0 then removeVehicleUpgrade(enteredVehicle, compatibleOpticalUpgrades[hoveredCategory]) end
		end
	end
end

function showNextOpticalUpgrade()
	if panelState then
		if enteredVehicle then addVehicleUpgrade(enteredVehicle, compatibleOpticalUpgrades[hoveredCategory - 1]) end
	end
end

function resetOpticalUpgrade()
	if panelState then
		if enteredVehicle then
			if equippedTuning ~= 0 then addVehicleUpgrade(enteredVehicle, equippedTuning)
			else
				if hoveredCategory - 1 == 0 then removeVehicleUpgrade(enteredVehicle, compatibleOpticalUpgrades[hoveredCategory])
				else removeVehicleUpgrade(enteredVehicle, compatibleOpticalUpgrades[hoveredCategory - 1]) end
			end
		end
	end
end

function formatNumber(amount, spacer)
	if not spacer then spacer = "," end
	amount = math.floor(amount)
	local left, num, right = string.match(tostring(amount), "^([^%d]*%d)(%d*)(.-)$")
	return left .. (num:reverse():gsub("(%d%d%d)", "%1" .. spacer):reverse()) .. right
end

function playSoundEffect(soundFile)
	if soundFile then local soundEffect = playSound("files/sounds/" .. soundFile, false); setSoundVolume(soundEffect, 0.5) end
end

function getPositionFromElementOffset(element, offsetX, offsetY, offsetZ)
	local elementMatrix = getElementMatrix(element)
    local elementX = offsetX * elementMatrix[1][1] + offsetY * elementMatrix[2][1] + offsetZ * elementMatrix[3][1] + elementMatrix[4][1]
    local elementY = offsetX * elementMatrix[1][2] + offsetY * elementMatrix[2][2] + offsetZ * elementMatrix[3][2] + elementMatrix[4][2]
    local elementZ = offsetX * elementMatrix[1][3] + offsetY * elementMatrix[2][3] + offsetZ * elementMatrix[3][3] + elementMatrix[4][3]
    return elementX, elementY, elementZ
end

function getVehicleOffroadAbility(vehicle)
	if vehicle then
		local flags = getVehicleHandling(vehicle)["handlingFlags"]
		for name, flag in pairs(availableOffroadAbilities) do if isFlagSet(flags, flag[1]) then return flag[2] end end
		return 1
	end
end

function getVehicleWheelSize(vehicle, side)
	if vehicle and side then
		local flags = getVehicleHandling(vehicle)["handlingFlags"]
		for name, flag in pairs(availableWheelSizes[side]) do if isFlagSet(flags, flag[1]) then return flag[2] end end
		return 3
	end
end

function isGTAUpgradeSlot(slot)
	if slot then for i = 0, 16 do if slot == i then return true end end end
	return false
end

function isFlagSet(val, flag) return (bitAnd(val, flag) == flag) end

function moveCameraToComponent(component, offsetX, offsetZ, zoom)
	if component then
		local _, _, vehicleRotation = getElementRotation(enteredVehicle)
		offsetX = offsetX or cameraSettings["defaultX"]
		offsetZ = offsetZ or 15
		zoom = zoom or 9
		local cameraRotation = vehicleRotation + offsetX
		cameraSettings["moveState"] = "moveToElement"
		cameraSettings["moveTick"] = getTickCount()
		cameraSettings["viewingElement"] = component
		cameraSettings["currentX"] = math.rad(cameraRotation)
		cameraSettings["currentY"] = math.rad(cameraRotation)
		cameraSettings["currentZ"] = math.rad(offsetZ)
		cameraSettings["distance"] = zoom
	end
end

function moveCameraToDefaultPosition()
	cameraSettings["moveState"] = "backToVehicle"
	cameraSettings["moveTick"] = getTickCount()
	cameraSettings["viewingElement"] = enteredVehicle
	cameraSettings["currentX"] = cameraSettings["defaultX"]
	cameraSettings["currentY"] = cameraSettings["defaultX"]
	cameraSettings["currentZ"] = math.rad(15)
	cameraSettings["distance"] = 9
end

function _getCameraPosition(element)
	if element == "component" then
		local componentX, componentY, componentZ = getVehicleComponentPosition(enteredVehicle, cameraSettings["viewingElement"])
		local elementX, elementY, elementZ = getPositionFromElementOffset(enteredVehicle, componentX, componentY, componentZ)
		local elementZ = elementZ + 0.2
		local cameraX = elementX + math.cos(cameraSettings["currentX"]) * cameraSettings["distance"]
		local cameraY = elementY + math.sin(cameraSettings["currentY"]) * cameraSettings["distance"]
		local cameraZ = elementZ + math.sin(cameraSettings["currentZ"]) * cameraSettings["distance"]
		return cameraX, cameraY, cameraZ, elementX, elementY, elementZ
	elseif element == "vehicle" then
		local elementX, elementY, elementZ = getElementPosition(enteredVehicle)
		local elementZ = elementZ + 0.2
		local cameraX = elementX + math.cos(cameraSettings["currentX"]) * cameraSettings["distance"]
		local cameraY = elementY + math.sin(cameraSettings["currentY"]) * cameraSettings["distance"]
		local cameraZ = elementZ + math.sin(cameraSettings["currentZ"]) * cameraSettings["distance"]
		return cameraX, cameraY, cameraZ, elementX, elementY, elementZ
	elseif element == "both" then
		if type(cameraSettings["viewingElement"]) == "string" then
			local componentX, componentY, componentZ = getVehicleComponentPosition(enteredVehicle, cameraSettings["viewingElement"])
			elementX, elementY, elementZ = getPositionFromElementOffset(enteredVehicle, componentX, componentY, componentZ)
		else
			elementX, elementY, elementZ = getElementPosition(enteredVehicle)
		end
		local elementZ = elementZ + 0.2
		local cameraX = elementX + math.cos(cameraSettings["currentX"]) * cameraSettings["distance"]
		local cameraY = elementY + math.sin(cameraSettings["currentY"]) * cameraSettings["distance"]
		local cameraZ = elementZ + math.sin(cameraSettings["currentZ"]) * cameraSettings["distance"]
		return cameraX, cameraY, cameraZ, elementX, elementY, elementZ
	end
end

function isValidComponent(vehicle, componentName)
	if vehicle and componentName then for component in pairs(getVehicleComponents(vehicle)) do if componentName == component then return true end end end
	return false
end

function setVehicleColorsToDefault()
	local vehicleColor = savedVehicleColors["all"]
	local vehicleLightColor = savedVehicleColors["headlight"]
	setVehicleColor(enteredVehicle, vehicleColor[1], vehicleColor[2], vehicleColor[3], vehicleColor[4], vehicleColor[5], vehicleColor[6], vehicleColor[7], vehicleColor[8], vehicleColor[9])
	setVehicleHeadLightColor(enteredVehicle, vehicleLightColor[1], vehicleLightColor[2], vehicleLightColor[3])
	local originalPJ = getElementData(enteredVehicle, "tuning.paintjob") or 0
	applyVehicleCustomPaintjob(enteredVehicle, originalPJ)
end

function setCameraAndComponentVisible()
	if getVehicleType(enteredVehicle) == "Automobile" then
		if loopTable[hoveredCategory]["cameraSettings"] then
			local cameraSetting = loopTable[hoveredCategory]["cameraSettings"]
			if isValidComponent(enteredVehicle, cameraSetting[1]) then moveCameraToComponent(cameraSetting[1], cameraSetting[2], cameraSetting[3], cameraSetting[4]) end
			if cameraSetting[5] then setVehicleComponentVisible(enteredVehicle, cameraSetting[1], false) end
		end
	end
end

function generateString(len)
	if tonumber(len) then
		local allowed = {{48, 57}, {97, 122}}
		math.randomseed(getTickCount())
		local str = ""
		for i = 1, len do
			local charlist = allowed[math.random(1, 2)]
			if i == 4 then str = str .. " " else str = str .. string.char(math.random(charlist[1], charlist[2])) end
		end
		return utf8.upper(str)
	end
	return false
end

function isComponentCompatible(vehicle, vehicleType)
	if vehicle and vehicleType then
		if type(vehicleType) == "string" then
			if getVehicleType(vehicle) == vehicleType then return true
			else giveNotification("error", getLocalizedText("notification.error.notCompatible", loopTable[hoveredCategory]["categoryName"])) end
		elseif type(vehicleType) == "table" then
			local typeFounded = false
			for _, modelType in pairs(vehicleType) do if modelType == getVehicleType(vehicle) then typeFounded = true end end
			if typeFounded then return true
			else giveNotification("error", getLocalizedText("notification.error.notCompatible", loopTable[hoveredCategory]["categoryName"])) end
		end
	end
	return false
end

function drawBorder(x, y, w, h, size, color, postGUI)
	size = size or 2
	dxDrawRectangle(x - size, y, size, h, color or tocolor(0, 0, 0, 200), postGUI)
	dxDrawRectangle(x + w, y, size, h, color or tocolor(0, 0, 0, 200), postGUI)
	dxDrawRectangle(x - size, y - size, w + (size * 2), size, color or tocolor(0, 0, 0, 200), postGUI)
	dxDrawRectangle(x - size, y + h, w + (size * 2), size, color or tocolor(0, 0, 0, 200), postGUI)
end

function drawBorderedRectangle(x, y, w, h, borderSize, borderColor, bgColor, postGUI)
	borderSize = borderSize or 2
	borderColor = borderColor or tocolor(0, 0, 0, 200)
	bgColor = bgColor or borderColor
	dxDrawRectangle(x, y, w, h, bgColor, postGUI)
	drawBorder(x, y, w, h, borderSize, borderColor, postGUI)
end

addCommandHandler("markerpos", function()
	if getPedOccupiedVehicle(localPlayer) then
		local x, y, z = getElementPosition(getPedOccupiedVehicle(localPlayer))
		local _, _, rotation = getElementRotation(getPedOccupiedVehicle(localPlayer))
		setClipboard(x .. ", " .. y .. ", " .. z .. ", " .. rotation)
	else
		local x, y, z = getElementPosition(localPlayer)
		local rotation = getPedRotation(localPlayer)
		setClipboard(x .. ", " .. y .. ", " .. z .. ", " .. rotation)
	end
	outputDebugString("[TUNING]: Marker position set to Clipboard. Use [CTRL + V] to paste it.", 0, 2, 168, 255)
end)
-- ==========================================================
-- OEM+ TURBÓ LEFÚJÓSZELEP (TÖBB HANGGAL, RANDOMIZÁLVA)
-- ==========================================================
local lastTurboSound = 0

-- Ide írjuk be az összes elérhető hangfájlt
local turboSoundFiles = {
    "files/sounds/turbo_shift1.wav",
    "files/sounds/turbo_shift2.wav"
}

bindKey("accelerate", "up", function()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if vehicle and getVehicleController(vehicle) == localPlayer then
        
        local turboLevel = getElementData(vehicle, "tuning.turbo") or 1
        
        -- Az 5-ös szint az OEM+
        if turboLevel == 5 then
            if getTickCount() - lastTurboSound > 800 then
                
                -- Véletlenszerűen kiválasztunk egy hangot a fenti listából
                local randomSound = turboSoundFiles[math.random(1, #turboSoundFiles)]
                
                local x, y, z = getElementPosition(vehicle)
                local bovSound = playSound3D(randomSound, x, y, z)
                
                setSoundVolume(bovSound, 0.7) 
                setSoundMaxDistance(bovSound, 50)
                attachElements(bovSound, vehicle)
                
                lastTurboSound = getTickCount()
            end
        end
    end
end)
-- ==========================================================
-- VIZUÁLIS EXTRÁK (NEON, LSD) BETÖLTÉSE SZERVERRŐL
-- ==========================================================
addEvent("tuning->ApplyVisuals", true)
addEventHandler("tuning->ApplyVisuals", root, function(type, data)
    if source and isElement(source) then
        if type == "neon" and data then
            -- Megkeresi a te saját Neon berakó funkciód, és ráteszi a kocsira
            saveNeon(source, data, true)
        elseif type == "lsd" and data then
            -- Megkeresi a te saját LSD ajtó funkciód, és ráteszi a kocsira
            setVehicleDoorToLSD(source, data)
        end
    end
end)