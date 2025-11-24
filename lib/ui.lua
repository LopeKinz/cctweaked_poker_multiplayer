-- ui.lua - Professional Poker UI with Touchscreen
local ui = {}

-- Farben für Poker-Tisch
ui.COLORS = {
    -- Tisch
    TABLE_FELT = colors.green,
    TABLE_BORDER = colors.brown,
    TABLE_RAIL = colors.orange,

    -- Karten
    CARD_BG = colors.white,
    CARD_BACK = colors.blue,
    CARD_BORDER = colors.black,
    CARD_RED = colors.red,
    CARD_BLACK = colors.black,

    -- UI Elemente
    BG = colors.black,
    PANEL = colors.gray,
    PANEL_DARK = colors.lightGray,

    -- Buttons
    BTN_FOLD = colors.red,
    BTN_CHECK = colors.yellow,
    BTN_CALL = colors.lime,
    BTN_RAISE = colors.orange,
    BTN_ALLIN = colors.purple,
    BTN_DISABLED = colors.gray,
    BTN_TEXT = colors.white,

    -- Status
    ACTIVE = colors.yellow,
    INACTIVE = colors.gray,
    DEALER = colors.orange,
    BLIND = colors.lightBlue,

    -- Text
    TEXT_WHITE = colors.white,
    TEXT_BLACK = colors.black,
    TEXT_YELLOW = colors.yellow,
    TEXT_GREEN = colors.lime,
    TEXT_RED = colors.red,

    -- Pot und Chips
    POT_BG = colors.brown,
    CHIPS_GREEN = colors.lime,
    CHIPS_RED = colors.red,
    CHIPS_BLUE = colors.lightBlue,
}

-- Erstellt neues UI
function ui.new(monitor)
    if not monitor then
        monitor = peripheral.find("monitor")
    end

    if not monitor then
        error("Kein Monitor gefunden!")
    end

    local instance = {
        monitor = monitor,
        width = 0,
        height = 0,
        buttons = {},
        scale = 1,

        -- Poker-spezifisch
        playerPositions = {},
        dealerButton = nil,
        timerActive = false,
        timerEnd = 0,
    }

    -- Größe ermitteln und Skala setzen
    if monitor.setTextScale then
        monitor.setTextScale(0.5)
        instance.scale = 0.5
    end
    instance.width, instance.height = monitor.getSize()

    -- Setze metatable BEVOR wir Methoden aufrufen
    setmetatable(instance, {__index = ui})

    -- Spieler-Positionen berechnen (4 Spieler um den Tisch)
    instance.playerPositions = instance:calculatePlayerPositions()

    return instance
end

-- Berechnet Positionen für 4 Spieler um den Tisch
function ui:calculatePlayerPositions()
    local positions = {}

    -- Position 1: Links (Spieler 2)
    positions[1] = {x = 2, y = math.floor(self.height / 2) - 4, side = "left"}

    -- Position 2: Oben (Spieler 3)
    positions[2] = {x = math.floor(self.width / 2) - 10, y = 2, side = "top"}

    -- Position 3: Rechts (Spieler 4)
    positions[3] = {x = self.width - 22, y = math.floor(self.height / 2) - 4, side = "right"}

    -- Position 4: Unten/Eigen (Spieler 1) - eigene Position
    positions[4] = {x = math.floor(self.width / 2) - 6, y = self.height - 10, side = "bottom"}

    return positions
end

-- Basis-Zeichenfunktionen
function ui:clear(color)
    self.monitor.setBackgroundColor(color or ui.COLORS.TABLE_FELT)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
end

function ui:drawText(x, y, text, fg, bg)
    self.monitor.setCursorPos(x, y)
    if fg then self.monitor.setTextColor(fg) end
    if bg then self.monitor.setBackgroundColor(bg) end
    self.monitor.write(text)
end

function ui:drawCenteredText(y, text, fg, bg)
    local x = math.floor((self.width - #text) / 2) + 1
    self:drawText(x, y, text, fg, bg)
end

function ui:drawBox(x, y, width, height, color)
    self.monitor.setBackgroundColor(color)
    for dy = 0, height - 1 do
        self.monitor.setCursorPos(x, y + dy)
        self.monitor.write(string.rep(" ", width))
    end
end

function ui:drawBorder(x, y, width, height, color)
    self.monitor.setBackgroundColor(color or ui.COLORS.CARD_BORDER)
    -- Oben und unten
    self.monitor.setCursorPos(x, y)
    self.monitor.write(string.rep(" ", width))
    self.monitor.setCursorPos(x, y + height - 1)
    self.monitor.write(string.rep(" ", width))
    -- Links und rechts
    for dy = 1, height - 2 do
        self.monitor.setCursorPos(x, y + dy)
        self.monitor.write(" ")
        self.monitor.setCursorPos(x + width - 1, y + dy)
        self.monitor.write(" ")
    end
end

-- Zeichnet Poker-Tisch Hintergrund
function ui:drawPokerTable()
    -- Tisch-Filz (grün)
    self:clear(ui.COLORS.TABLE_FELT)

    -- Tisch-Rand (braun)
    self:drawBorder(1, 1, self.width, self.height, ui.COLORS.TABLE_BORDER)

    -- Tisch-Name oben
    self:drawCenteredText(1, "=== TEXAS HOLD'EM ===", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_BORDER)
end

-- Zeichnet eine Karte (verbessert)
function ui:drawCard(x, y, card, faceUp, large)
    local width = large and 7 or 5
    local height = large and 5 or 3

    if not faceUp or not card then
        -- Kartenrückseite
        self:drawBox(x, y, width, height, ui.COLORS.CARD_BACK)
        self:drawBorder(x, y, width, height, ui.COLORS.CARD_BORDER)

        if large then
            self:drawText(x + 1, y + 1, string.rep("#", width-2), ui.COLORS.TEXT_WHITE, ui.COLORS.CARD_BACK)
            self:drawText(x + 1, y + 2, string.rep("#", width-2), ui.COLORS.TEXT_WHITE, ui.COLORS.CARD_BACK)
            self:drawText(x + 1, y + 3, string.rep("#", width-2), ui.COLORS.TEXT_WHITE, ui.COLORS.CARD_BACK)
        else
            self:drawText(x + 1, y + 1, "###", ui.COLORS.TEXT_WHITE, ui.COLORS.CARD_BACK)
        end
    else
        -- Kartenvorderseite
        local poker = require("lib.poker")
        local suitColor = poker.SUIT_COLORS[card.suit]

        self:drawBox(x, y, width, height, ui.COLORS.CARD_BG)
        self:drawBorder(x, y, width, height, ui.COLORS.CARD_BORDER)

        local rank = card.rank
        local suit = poker.SUIT_SYMBOLS[card.suit]

        if large then
            -- Große Karte
            self:drawText(x + 1, y + 1, rank, suitColor, ui.COLORS.CARD_BG)
            self:drawText(x + math.floor(width/2), y + math.floor(height/2), suit, suitColor, ui.COLORS.CARD_BG)
            self:drawText(x + width - 2 - (#rank > 1 and 1 or 0), y + height - 2, rank, suitColor, ui.COLORS.CARD_BG)
        else
            -- Normale Karte
            if #rank == 1 then rank = " " .. rank end
            self:drawText(x + 1, y + 1, rank, suitColor, ui.COLORS.CARD_BG)
            self:drawText(x + 2, y + 2, suit, suitColor, ui.COLORS.CARD_BG)
        end
    end
end

-- Zeichnet Community Cards in der Mitte
function ui:drawCommunityCards(cards, round)
    local startY = math.floor(self.height / 2) - 3
    local totalWidth = 5 * 7 + 4 * 2  -- 5 Karten * 7 breit + 4 * 2 Abstand
    local startX = math.floor((self.width - totalWidth) / 2)

    -- Runden-Name
    if round and round ~= "waiting" then
        self:drawCenteredText(startY - 2, string.upper(round), ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
    end

    -- Zeichne 5 Karten
    for i = 1, 5 do
        local x = startX + (i - 1) * 9
        if cards and cards[i] then
            self:drawCard(x, startY, cards[i], true, true)
        else
            self:drawCard(x, startY, nil, false, true)
        end
    end
end

-- Zeichnet Pot in der Mitte
function ui:drawPot(pot, y)
    y = y or math.floor(self.height / 2) + 3

    local text = "POT: " .. pot .. " chips"
    local width = #text + 4
    local x = math.floor((self.width - width) / 2)

    self:drawBox(x, y, width, 3, ui.COLORS.POT_BG)
    self:drawBorder(x, y, width, 3, ui.COLORS.TABLE_BORDER)
    self:drawText(x + 2, y + 1, text, ui.COLORS.TEXT_YELLOW, ui.COLORS.POT_BG)
end

-- Zeichnet Spieler-Info Box
function ui:drawPlayerBox(position, player, isDealer, isSmallBlind, isBigBlind, isActive, isMe)
    local pos = self.playerPositions[position]
    if not pos then return end

    local x, y = pos.x, pos.y
    local width = 20
    local height = 8

    -- Hintergrund
    local bgColor = isActive and ui.COLORS.ACTIVE or ui.COLORS.INACTIVE
    if isMe then bgColor = ui.COLORS.PANEL_DARK end

    self:drawBox(x, y, width, height, bgColor)
    self:drawBorder(x, y, width, height, ui.COLORS.TABLE_BORDER)

    -- Name
    local name = player.name or "Player"
    if #name > width - 4 then
        name = name:sub(1, width - 7) .. "..."
    end
    self:drawText(x + 2, y + 1, name, ui.COLORS.TEXT_WHITE, bgColor)

    -- Dealer/Blind Buttons
    local buttonX = x + width - 4
    if isDealer then
        self:drawText(buttonX, y + 1, " D ", ui.COLORS.TEXT_WHITE, ui.COLORS.DEALER)
        buttonX = buttonX - 4
    end
    if isSmallBlind then
        self:drawText(buttonX, y + 1, "SB", ui.COLORS.TEXT_WHITE, ui.COLORS.BLIND)
        buttonX = buttonX - 3
    end
    if isBigBlind then
        self:drawText(buttonX, y + 1, "BB", ui.COLORS.TEXT_WHITE, ui.COLORS.BLIND)
    end

    -- Chips
    local chipsText = tostring(player.chips) .. " chips"
    self:drawText(x + 2, y + 2, chipsText, ui.COLORS.CHIPS_GREEN, bgColor)

    -- Bet (wenn vorhanden)
    if player.bet and player.bet > 0 then
        self:drawText(x + 2, y + 3, "Bet: " .. player.bet, ui.COLORS.TEXT_YELLOW, bgColor)
    end

    -- Status
    if player.folded then
        self:drawText(x + 2, y + 4, "[FOLDED]", ui.COLORS.TEXT_RED, bgColor)
    elseif player.allIn then
        self:drawText(x + 2, y + 4, "[ALL-IN]", ui.COLORS.TEXT_YELLOW, bgColor)
    elseif isActive then
        self:drawText(x + 2, y + 4, "[TURN]", ui.COLORS.TEXT_GREEN, bgColor)
    end

    -- Karten (kleine Vorschau, verdeckt für andere)
    local cardY = y + 6
    if not isMe and not player.folded then
        self:drawCard(x + 2, cardY, nil, false, false)
        self:drawCard(x + 8, cardY, nil, false, false)
    end
end

-- Zeichnet eigene Karten (groß unten)
function ui:drawOwnCards(cards)
    if not cards or #cards < 2 then return end

    local y = self.height - 8
    local totalWidth = 2 * 7 + 3  -- 2 Karten + Abstand
    local startX = math.floor((self.width - totalWidth) / 2)

    -- Label
    self:drawText(startX, y - 1, "YOUR HAND:", ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

    -- Karten
    self:drawCard(startX, y, cards[1], true, true)
    self:drawCard(startX + 10, y, cards[2], true, true)
end

-- Zeichnet Hand-Evaluation
function ui:drawHandEvaluation(handName, x, y)
    if not handName then return end

    local width = #handName + 4
    x = x or math.floor((self.width - width) / 2)
    y = y or self.height - 2

    self:drawBox(x, y, width, 1, ui.COLORS.TABLE_FELT)
    self:drawText(x, y, "[" .. handName .. "]", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
end

-- Zeichnet Touch-Button (verbessert)
function ui:drawButton(x, y, width, height, text, color, textColor, enabled)
    enabled = enabled == nil and true or enabled
    local btnColor = enabled and color or ui.COLORS.BTN_DISABLED
    local txtColor = enabled and textColor or ui.COLORS.TEXT_BLACK

    self:drawBox(x, y, width, height, btnColor)
    self:drawBorder(x, y, width, height, ui.COLORS.CARD_BORDER)

    -- Text zentrieren
    local textX = x + math.floor((width - #text) / 2)
    local textY = y + math.floor(height / 2)

    self:drawText(textX, textY, text, txtColor, btnColor)
end

-- Registriert Button
function ui:addButton(id, x, y, width, height, text, callback, color, enabled)
    self.buttons[id] = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        callback = callback,
        color = color or ui.COLORS.PANEL,
        enabled = enabled == nil and true or enabled
    }
    self:drawButton(x, y, width, height, text, color or ui.COLORS.PANEL, ui.COLORS.BTN_TEXT, enabled)
end

-- Prüft Touch auf Button
function ui:handleTouch(x, y)
    for id, button in pairs(self.buttons) do
        if button.enabled and
           x >= button.x and x < button.x + button.width and
           y >= button.y and y < button.y + button.height then
            if button.callback then
                button.callback(id)
            end
            return id
        end
    end
    return nil
end

-- Aktiviert/Deaktiviert Button
function ui:setButtonEnabled(id, enabled)
    local button = self.buttons[id]
    if button then
        button.enabled = enabled
        self:drawButton(button.x, button.y, button.width, button.height, button.text, button.color, ui.COLORS.BTN_TEXT, enabled)
    end
end

-- Entfernt alle Buttons
function ui:clearButtons()
    self.buttons = {}
end

-- Zeichnet Raise-Slider
function ui:drawRaiseSlider(min, max, current, x, y, width)
    x = x or 5
    y = y or self.height - 12
    width = width or self.width - 10

    -- Label
    self:drawText(x, y - 1, "Raise Amount: " .. current, ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

    -- Slider-Hintergrund
    self:drawBox(x, y, width, 2, ui.COLORS.PANEL)

    -- Slider-Füllung
    local percent = 0
    if max > min then
        percent = (current - min) / (max - min)
    else
        percent = 1  -- Wenn nur ein Betrag möglich, volle Füllung
    end
    local fillWidth = math.floor(width * percent)
    if fillWidth > 0 then
        self:drawBox(x, y, fillWidth, 2, ui.COLORS.BTN_RAISE)
    end

    -- Min/Max Labels
    self:drawText(x, y + 3, "Min:" .. min, ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)
    self:drawText(x + width - 8, y + 3, "Max:" .. max, ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

    -- Pot Button in der Mitte
    local potText = "POT"
    local potX = x + math.floor(width / 2) - 2
    self:addButton("raise_pot", potX, y + 3, 5, 1, potText, nil, ui.COLORS.BTN_RAISE)

    return y + 5  -- Return Y für weitere Elemente
end

-- Slider-Touch-Handler
function ui:handleSliderTouch(x, y, sliderX, sliderY, sliderWidth, min, max)
    if y >= sliderY and y < sliderY + 2 then
        -- Guard gegen Division durch Null
        if max <= min then
            return min
        end

        local percent = (x - sliderX) / sliderWidth
        percent = math.max(0, math.min(1, percent))
        local value = math.floor(min + (max - min) * percent)
        return value
    end
    return nil
end

-- Zeichnet Timer
function ui:drawTimer(secondsLeft, x, y)
    x = x or self.width - 15
    y = y or 2

    local width = 13
    local height = 3

    self:drawBox(x, y, width, height, ui.COLORS.PANEL)
    self:drawBorder(x, y, width, height, ui.COLORS.CARD_BORDER)

    local color = secondsLeft > 10 and ui.COLORS.TEXT_GREEN or ui.COLORS.TEXT_RED
    self:drawText(x + 2, y + 1, "TIME: " .. secondsLeft .. "s", color, ui.COLORS.PANEL)
end

-- Startet Timer
function ui:startTimer(seconds)
    self.timerActive = true
    self.timerEnd = os.epoch("utc") / 1000 + seconds
end

-- Stoppt Timer
function ui:stopTimer()
    self.timerActive = false
end

-- Update Timer (call in game loop)
function ui:updateTimer()
    if self.timerActive then
        local now = os.epoch("utc") / 1000
        local left = math.ceil(self.timerEnd - now)
        if left >= 0 then
            self:drawTimer(left)
        else
            self.timerActive = false
        end
    end
end

-- Zeigt Overlay-Nachricht
function ui:showMessage(message, duration, color, large)
    local lines = {}
    for line in message:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local maxWidth = 0
    for _, line in ipairs(lines) do
        if #line > maxWidth then maxWidth = #line end
    end

    local width = math.min(maxWidth + 4, self.width - 4)
    local height = #lines + 2
    local x = math.floor((self.width - width) / 2)
    local y = math.floor((self.height - height) / 2)

    if large then
        height = height + 2
        y = y - 1
    end

    -- Box
    self:drawBox(x, y, width, height, color or ui.COLORS.PANEL)
    self:drawBorder(x, y, width, height, ui.COLORS.TABLE_BORDER)

    -- Text
    for i, line in ipairs(lines) do
        local lineX = x + math.floor((width - #line) / 2)
        self:drawText(lineX, y + i, line, ui.COLORS.TEXT_WHITE, color or ui.COLORS.PANEL)
    end

    if duration then
        sleep(duration)
        self:drawPokerTable()
    end
end

-- Spieler-Auswahl Dialog
function ui:showPlayerSelection(players)
    local dialogHeight = math.min(#players * 3 + 8, self.height - 4)
    local y = math.floor((self.height - dialogHeight) / 2)
    local width = math.min(40, self.width - 8)
    local x = math.floor((self.width - width) / 2)

    self:clear(ui.COLORS.TABLE_FELT)
    self:drawBox(x, y, width, dialogHeight, ui.COLORS.PANEL)
    self:drawBorder(x, y, width, dialogHeight, ui.COLORS.TABLE_BORDER)

    -- Titel
    self:drawCenteredText(y + 1, "SPIELER AUSWAHL", ui.COLORS.TEXT_YELLOW, ui.COLORS.PANEL)
    self:drawCenteredText(y + 2, "Wähle deinen Namen:", ui.COLORS.TEXT_WHITE, ui.COLORS.PANEL)

    -- Spieler-Buttons
    local btnY = y + 4
    local btnHeight = 2
    local btnWidth = width - 8

    -- Cleariere Buttons
    self:clearButtons()

    -- Erstelle Button für jeden Spieler
    for i, playerName in ipairs(players) do
        local btnId = "player_" .. i
        self:addButton(btnId, x + 4, btnY, btnWidth, btnHeight, playerName, nil, ui.COLORS.BTN_CALL)
        btnY = btnY + btnHeight + 1

        -- Maximale Anzahl Buttons (falls zu viele Spieler)
        if i >= 10 then break end
    end

    -- "Manuell eingeben" Button
    btnY = btnY + 1
    self:addButton("manual_input", x + 4, btnY, btnWidth, btnHeight, "Manuell eingeben", nil, ui.COLORS.PANEL)

    -- Warte auf Auswahl
    local selectedPlayer = nil

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "monitor_touch" then
            local touchX, touchY = p2, p3
            local buttonId = self:handleTouch(touchX, touchY)

            if buttonId then
                if buttonId == "manual_input" then
                    -- Manuelle Eingabe
                    self:clear(ui.COLORS.TABLE_FELT)
                    self:drawBox(x, y, width, 10, ui.COLORS.PANEL)
                    self:drawBorder(x, y, width, 10, ui.COLORS.TABLE_BORDER)
                    self:drawCenteredText(y + 1, "Spieler-Name eingeben:", ui.COLORS.TEXT_YELLOW, ui.COLORS.PANEL)

                    -- Input-Feld
                    self:drawBox(x + 4, y + 4, width - 8, 1, colors.black)
                    self.monitor.setCursorPos(x + 4, y + 4)
                    self.monitor.setTextColor(colors.white)
                    self.monitor.setBackgroundColor(colors.black)
                    self.monitor.setCursorBlink(true)

                    local input = read()
                    self.monitor.setCursorBlink(false)

                    if input and #input > 0 then
                        selectedPlayer = input
                        break
                    end
                else
                    -- Spieler aus Liste gewählt
                    local playerIndex = tonumber(buttonId:match("player_(%d+)"))
                    if playerIndex and players[playerIndex] then
                        selectedPlayer = players[playerIndex]
                        break
                    end
                end
            end
        end
    end

    self:clearButtons()
    return selectedPlayer
end

-- Input-Dialog für Raise-Betrag
function ui:showRaiseInput(min, max, pot)
    local dialogHeight = 14
    local y = math.floor(self.height / 2) - 6
    local width = self.width - 8
    local x = 4

    self:drawBox(x, y, width, dialogHeight, ui.COLORS.PANEL)
    self:drawBorder(x, y, width, dialogHeight, ui.COLORS.TABLE_BORDER)

    -- Titel
    self:drawCenteredText(y + 1, "RAISE AMOUNT", ui.COLORS.TEXT_YELLOW, ui.COLORS.PANEL)

    -- Info
    self:drawText(x + 2, y + 3, "Min: " .. min .. " chips", ui.COLORS.TEXT_WHITE, ui.COLORS.PANEL)
    self:drawText(x + 2, y + 4, "Max: " .. max .. " chips", ui.COLORS.TEXT_WHITE, ui.COLORS.PANEL)
    self:drawText(x + 2, y + 5, "Pot: " .. pot .. " chips", ui.COLORS.TEXT_YELLOW, ui.COLORS.PANEL)

    -- Slider
    local sliderY = y + 7
    local sliderWidth = width - 4
    local current = min

    self:drawRaiseSlider(min, max, current, x + 2, sliderY, sliderWidth)

    -- Buttons
    local btnY = y + dialogHeight - 2
    local btnWidth = math.floor((width - 10) / 3)

    self:addButton("raise_confirm", x + 2, sliderY + 6, btnWidth, 2, "RAISE", nil, ui.COLORS.BTN_RAISE)
    self:addButton("raise_allin", x + 4 + btnWidth, sliderY + 6, btnWidth, 2, "ALL-IN", nil, ui.COLORS.BTN_ALLIN)
    self:addButton("raise_cancel", x + 6 + btnWidth * 2, sliderY + 6, btnWidth, 2, "CANCEL", nil, ui.COLORS.BTN_FOLD)

    -- Rückgabe: Warte auf Touch
    local result = {amount = current, action = nil}

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "monitor_touch" then
            local touchX, touchY = p2, p3

            -- Check Slider
            local newValue = self:handleSliderTouch(touchX, touchY, x + 2, sliderY, sliderWidth, min, max)
            if newValue then
                current = newValue
                result.amount = current
                self:drawRaiseSlider(min, max, current, x + 2, sliderY, sliderWidth)
            end

            -- Check Buttons
            local buttonId = self:handleTouch(touchX, touchY)

            if buttonId == "raise_confirm" then
                result.action = "raise"
                break
            elseif buttonId == "raise_allin" then
                result.action = "all-in"
                result.amount = max
                break
            elseif buttonId == "raise_cancel" then
                result.action = "cancel"
                break
            elseif buttonId == "raise_pot" then
                current = math.min(pot, max)
                result.amount = current
                self:drawRaiseSlider(min, max, current, x + 2, sliderY, sliderWidth)
            end
        end
    end

    self:clearButtons()
    return result
end

return ui
