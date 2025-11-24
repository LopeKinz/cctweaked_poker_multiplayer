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

-- Zeichnet Raise-Buttons mit Inkrement-System
function ui:drawRaiseButtons(min, max, current, pot, x, y, width)
    x = x or 5
    y = y or self.height - 12
    width = width or self.width - 10

    -- Label mit größerem, besserem Stil
    local labelText = "RAISE: " .. current .. " chips"
    local labelWidth = #labelText + 4
    local labelX = x + math.floor((width - labelWidth) / 2)

    self:drawBox(labelX, y - 2, labelWidth, 3, ui.COLORS.BTN_RAISE)
    self:drawBorder(labelX, y - 2, labelWidth, 3, ui.COLORS.TABLE_BORDER)
    self:drawText(labelX + 2, y, labelText, ui.COLORS.TEXT_WHITE, ui.COLORS.BTN_RAISE)

    -- Inkrement-Buttons in einer Reihe
    local btnY = y + 2
    local btnHeight = 3
    local btnSpacing = 2

    -- Berechne Button-Breiten für gleichmäßige Verteilung
    local totalBtns = 5  -- -10, -1, POT, +1, +10
    local availableWidth = width - (btnSpacing * (totalBtns - 1))
    local btnWidth = math.floor(availableWidth / totalBtns)

    local currentX = x

    -- -10 Button
    local canDecrease10 = (current - 10) >= min
    self:addButton("raise_dec10", currentX, btnY, btnWidth, btnHeight,
        "-10", nil, ui.COLORS.BTN_FOLD, canDecrease10)
    currentX = currentX + btnWidth + btnSpacing

    -- -1 Button
    local canDecrease1 = (current - 1) >= min
    self:addButton("raise_dec1", currentX, btnY, btnWidth, btnHeight,
        "-1", nil, ui.COLORS.BTN_FOLD, canDecrease1)
    currentX = currentX + btnWidth + btnSpacing

    -- POT Button (Mitte)
    local potValue = math.min(pot, max)
    self:addButton("raise_pot", currentX, btnY, btnWidth, btnHeight,
        "POT", nil, ui.COLORS.BTN_ALLIN, true)
    currentX = currentX + btnWidth + btnSpacing

    -- +1 Button
    local canIncrease1 = (current + 1) <= max
    self:addButton("raise_inc1", currentX, btnY, btnWidth, btnHeight,
        "+1", nil, ui.COLORS.BTN_CALL, canIncrease1)
    currentX = currentX + btnWidth + btnSpacing

    -- +10 Button
    local canIncrease10 = (current + 10) <= max
    self:addButton("raise_inc10", currentX, btnY, btnWidth, btnHeight,
        "+10", nil, ui.COLORS.BTN_CALL, canIncrease10)

    -- Min/Max Info unter den Buttons
    local infoY = btnY + btnHeight + 1
    local minText = "Min: " .. min
    local maxText = "Max: " .. max
    self:drawText(x, infoY, minText, ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
    self:drawText(x + width - #maxText, infoY, maxText, ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)

    -- Fortschrittsbalken für visuelle Darstellung
    local barY = infoY + 1
    local barHeight = 1
    self:drawBox(x, barY, width, barHeight, ui.COLORS.PANEL)

    local percent = 0
    if max > min then
        percent = (current - min) / (max - min)
    else
        percent = 1
    end
    local fillWidth = math.floor(width * percent)
    if fillWidth > 0 then
        self:drawBox(x, barY, fillWidth, barHeight, ui.COLORS.BTN_RAISE)
    end

    return barY + 2  -- Return Y für weitere Elemente
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

-- Zeigt Poker Hand Rankings Cheat Sheet
function ui:showHandRankings()
    local dialogHeight = 24
    local dialogWidth = math.min(50, self.width - 4)
    local x = math.floor((self.width - dialogWidth) / 2)
    local y = math.floor((self.height - dialogHeight) / 2)

    -- Dialog mit Schatten
    self:drawBox(x + 1, y + 1, dialogWidth, dialogHeight, ui.COLORS.CARD_BORDER)  -- Schatten
    self:drawBox(x, y, dialogWidth, dialogHeight, ui.COLORS.PANEL_DARK)
    self:drawBorder(x, y, dialogWidth, dialogHeight, ui.COLORS.TABLE_BORDER)

    -- Titel
    local titleY = y + 1
    self:drawCenteredText(titleY, "=== POKER HAND RANKINGS ===", ui.COLORS.TEXT_YELLOW, ui.COLORS.PANEL_DARK)
    self:drawCenteredText(titleY + 1, "(Beste bis Schlechteste)", ui.COLORS.TEXT_WHITE, ui.COLORS.PANEL_DARK)

    -- Hand Rankings (von besten nach schlechtesten)
    local rankings = {
        {name = "1. Royal Flush", desc = "A-K-Q-J-10 gleiche Farbe", color = ui.COLORS.TEXT_YELLOW},
        {name = "2. Straight Flush", desc = "5 aufeinander folgende Karten, gleiche Farbe", color = ui.COLORS.TEXT_YELLOW},
        {name = "3. Four of a Kind", desc = "4 Karten gleichen Werts", color = ui.COLORS.CHIPS_GREEN},
        {name = "4. Full House", desc = "3 gleiche + 2 gleiche", color = ui.COLORS.CHIPS_GREEN},
        {name = "5. Flush", desc = "5 Karten gleicher Farbe", color = ui.COLORS.CHIPS_BLUE},
        {name = "6. Straight", desc = "5 aufeinander folgende Karten", color = ui.COLORS.CHIPS_BLUE},
        {name = "7. Three of a Kind", desc = "3 Karten gleichen Werts", color = ui.COLORS.TEXT_WHITE},
        {name = "8. Two Pair", desc = "2 Paare", color = ui.COLORS.TEXT_WHITE},
        {name = "9. Pair", desc = "2 Karten gleichen Werts", color = ui.COLORS.TEXT_WHITE},
        {name = "10. High Card", desc = "Höchste Karte", color = ui.COLORS.TEXT_WHITE},
    }

    local currentY = y + 4
    for _, ranking in ipairs(rankings) do
        self:drawText(x + 2, currentY, ranking.name, ranking.color, ui.COLORS.PANEL_DARK)
        currentY = currentY + 1
        self:drawText(x + 4, currentY, ranking.desc, ui.COLORS.TEXT_WHITE, ui.COLORS.PANEL_DARK)
        currentY = currentY + 1
    end

    -- Close Button
    local btnWidth = 20
    local btnHeight = 3
    local btnX = math.floor((dialogWidth - btnWidth) / 2) + x
    local btnY = y + dialogHeight - 4

    self:addButton("rankings_close", btnX, btnY, btnWidth, btnHeight, "SCHLIESSEN", nil, ui.COLORS.BTN_CALL)

    -- Warte auf Close
    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "monitor_touch" then
            local touchX, touchY = p2, p3
            local buttonId = self:handleTouch(touchX, touchY)

            if buttonId == "rankings_close" then
                break
            end
        end
    end

    self:clearButtons()
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
    -- +3 für Titel, +3 für jeden Spieler, +3 für "Manuell", +3 für "Zuschauer"
    local dialogHeight = math.min(#players * 3 + 14, self.height - 4)
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

    -- "Erneut scannen" Button
    btnY = btnY + 1
    self:addButton("rescan", x + 4, btnY, btnWidth, btnHeight, "Erneut scannen", nil, ui.COLORS.PANEL)

    -- "Als Zuschauer beitreten" Button
    btnY = btnY + btnHeight + 1
    self:addButton("spectator", x + 4, btnY, btnWidth, btnHeight, "Als Zuschauer beitreten", nil, ui.COLORS.BTN_CHECK)

    -- Warte auf Auswahl
    local selectedPlayer = nil

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "monitor_touch" then
            local touchX, touchY = p2, p3
            local buttonId = self:handleTouch(touchX, touchY)

            if buttonId then
                if buttonId == "rescan" then
                    -- Erneut scannen - Rückgabe eines speziellen Wertes
                    selectedPlayer = "__RESCAN__"
                    break
                elseif buttonId == "spectator" then
                    -- Zuschauer-Modus
                    selectedPlayer = "Zuschauer_" .. os.getComputerID()
                    break
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
    local dialogHeight = 16
    local y = math.floor(self.height / 2) - 8
    local width = self.width - 8
    local x = 4

    -- Verbesserte Dialog-Box mit Schatten-Effekt
    self:drawBox(x + 1, y + 1, width, dialogHeight, ui.COLORS.CARD_BORDER)  -- Schatten
    self:drawBox(x, y, width, dialogHeight, ui.COLORS.PANEL_DARK)
    self:drawBorder(x, y, width, dialogHeight, ui.COLORS.TABLE_BORDER)

    -- Titel mit Hervorhebung
    local titleY = y + 1
    local titleWidth = 18
    local titleX = math.floor((width - titleWidth) / 2) + x
    self:drawBox(titleX, titleY, titleWidth, 3, ui.COLORS.BTN_RAISE)
    self:drawBorder(titleX, titleY, titleWidth, 3, ui.COLORS.TABLE_BORDER)
    self:drawCenteredText(titleY + 1, "=== RAISE ===", ui.COLORS.TEXT_WHITE, ui.COLORS.BTN_RAISE)

    -- Pot Info
    local potY = y + 5
    local potText = "Pot: " .. pot .. " chips"
    local potWidth = #potText + 4
    local potX = math.floor((width - potWidth) / 2) + x
    self:drawBox(potX, potY, potWidth, 3, ui.COLORS.POT_BG)
    self:drawBorder(potX, potY, potWidth, 3, ui.COLORS.TABLE_BORDER)
    self:drawText(potX + 2, potY + 1, potText, ui.COLORS.TEXT_YELLOW, ui.COLORS.POT_BG)

    -- Inkrement-Buttons
    local current = min
    local buttonsY = y + 9
    local buttonsWidth = width - 4

    self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, buttonsWidth)

    -- Aktions-Buttons (RAISE, ALL-IN, CANCEL)
    local actionBtnY = y + dialogHeight - 3
    local btnWidth = math.floor((width - 10) / 3)
    local btnHeight = 2

    self:addButton("raise_confirm", x + 2, actionBtnY, btnWidth, btnHeight, "RAISE", nil, ui.COLORS.BTN_RAISE)
    self:addButton("raise_allin", x + 4 + btnWidth, actionBtnY, btnWidth, btnHeight, "ALL-IN", nil, ui.COLORS.BTN_ALLIN)
    self:addButton("raise_cancel", x + 6 + btnWidth * 2, actionBtnY, btnWidth, btnHeight, "CANCEL", nil, ui.COLORS.BTN_FOLD)

    -- Rückgabe: Warte auf Touch
    local result = {amount = current, action = nil}

    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "monitor_touch" then
            local touchX, touchY = p2, p3

            -- Check Buttons
            local buttonId = self:handleTouch(touchX, touchY)

            -- Inkrement-Buttons
            if buttonId == "raise_dec10" then
                current = math.max(min, current - 10)
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, buttonsWidth)
            elseif buttonId == "raise_dec1" then
                current = math.max(min, current - 1)
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, buttonsWidth)
            elseif buttonId == "raise_inc1" then
                current = math.min(max, current + 1)
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, buttonsWidth)
            elseif buttonId == "raise_inc10" then
                current = math.min(max, current + 10)
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, buttonsWidth)
            elseif buttonId == "raise_pot" then
                current = math.min(pot, max)
                current = math.max(min, current)  -- Sicherstellen dass >= min
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, buttonsWidth)
            -- Aktions-Buttons
            elseif buttonId == "raise_confirm" then
                result.action = "raise"
                break
            elseif buttonId == "raise_allin" then
                result.action = "all-in"
                result.amount = max
                break
            elseif buttonId == "raise_cancel" then
                result.action = "cancel"
                break
            end
        end
    end

    self:clearButtons()
    return result
end

return ui
