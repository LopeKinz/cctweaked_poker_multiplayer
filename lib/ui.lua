-- ui.lua - Modern Professional Poker UI with Premium Design
local ui = {}

-- Premium Color Scheme - Moderne Casino-Ästhetik
ui.COLORS = {
    -- Tisch - Dunklerer, eleganterer Look
    TABLE_FELT = colors.cyan,        -- Dunkles Teal statt Grün
    TABLE_BORDER = colors.gray,      -- Dunkelgrauer Hauptrand
    TABLE_BORDER_INNER = colors.lightGray,  -- Innerer Rand für Tiefe
    TABLE_RAIL = colors.brown,       -- Holz-Akzent

    -- Karten - Hochkontrast
    CARD_BG = colors.white,
    CARD_BACK = colors.blue,
    CARD_BACK_PATTERN = colors.lightBlue,
    CARD_BORDER = colors.black,
    CARD_SHADOW = colors.gray,
    CARD_RED = colors.red,
    CARD_BLACK = colors.black,

    -- UI Elemente - Modern & Clean
    BG = colors.black,
    PANEL = colors.gray,
    PANEL_DARK = colors.black,
    PANEL_LIGHT = colors.lightGray,

    -- Buttons - Kräftige Farben
    BTN_FOLD = colors.red,
    BTN_CHECK = colors.orange,
    BTN_CALL = colors.lime,
    BTN_RAISE = colors.yellow,
    BTN_ALLIN = colors.purple,
    BTN_DISABLED = colors.gray,
    BTN_TEXT = colors.white,
    BTN_BORDER = colors.black,

    -- Status - Klare Indikatoren
    ACTIVE = colors.lime,            -- Heller für aktiven Spieler
    ACTIVE_GLOW = colors.yellow,     -- Glow-Effekt
    INACTIVE = colors.gray,
    DEALER = colors.orange,
    DEALER_TEXT = colors.white,
    BLIND = colors.lightBlue,

    -- Text - Hoher Kontrast
    TEXT_WHITE = colors.white,
    TEXT_BLACK = colors.black,
    TEXT_YELLOW = colors.yellow,
    TEXT_GOLD = colors.orange,       -- Gold-Akzent
    TEXT_GREEN = colors.lime,
    TEXT_RED = colors.red,

    -- Pot und Chips - Premium Look
    POT_BG = colors.yellow,          -- Gold für Pot
    POT_BORDER = colors.orange,
    CHIPS_GREEN = colors.lime,
    CHIPS_RED = colors.red,
    CHIPS_BLUE = colors.lightBlue,
    CHIPS_GOLD = colors.yellow,
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

    -- Position 1: Links
    positions[1] = {x = 3, y = math.floor(self.height / 2) - 5, side = "left"}

    -- Position 2: Oben
    positions[2] = {x = math.floor(self.width / 2) - 12, y = 3, side = "top"}

    -- Position 3: Rechts
    positions[3] = {x = self.width - 25, y = math.floor(self.height / 2) - 5, side = "right"}

    -- Position 4: Unten/Eigen (eigene Position)
    positions[4] = {x = math.floor(self.width / 2) - 8, y = self.height - 12, side = "bottom"}

    return positions
end

-- === BASIS-ZEICHENFUNKTIONEN ===

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

-- Verbesserte Border mit Doppelrand-Option
function ui:drawBorder(x, y, width, height, color, double)
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

    -- Doppelrand für Premium-Look
    if double and width > 4 and height > 4 then
        local innerColor = ui.COLORS.TABLE_BORDER_INNER
        self.monitor.setBackgroundColor(innerColor)
        -- Innerer Rand
        self.monitor.setCursorPos(x + 1, y + 1)
        self.monitor.write(string.rep(" ", width - 2))
        self.monitor.setCursorPos(x + 1, y + height - 2)
        self.monitor.write(string.rep(" ", width - 2))
        for dy = 2, height - 3 do
            self.monitor.setCursorPos(x + 1, y + dy)
            self.monitor.write(" ")
            self.monitor.setCursorPos(x + width - 2, y + dy)
            self.monitor.write(" ")
        end
    end
end

-- Schatten-Effekt
function ui:drawShadow(x, y, width, height)
    self.monitor.setBackgroundColor(ui.COLORS.CARD_SHADOW)
    -- Rechter Schatten
    for dy = 1, height do
        if x + width <= self.width then
            self.monitor.setCursorPos(x + width, y + dy)
            self.monitor.write(" ")
        end
    end
    -- Unterer Schatten
    if y + height <= self.height then
        self.monitor.setCursorPos(x + 1, y + height)
        local shadowWidth = math.min(width, self.width - x)
        self.monitor.write(string.rep(" ", shadowWidth))
    end
end

-- === POKER-TISCH DESIGN ===

function ui:drawPokerTable()
    -- Tisch-Filz (dunkles Cyan für modernen Look)
    self:clear(ui.COLORS.TABLE_FELT)

    -- Äußerer Rand (Holz-Look)
    self:drawBox(1, 1, self.width, 1, ui.COLORS.TABLE_RAIL)
    self:drawBox(1, self.height, self.width, 1, ui.COLORS.TABLE_RAIL)
    for y = 2, self.height - 1 do
        self:drawBox(1, y, 1, 1, ui.COLORS.TABLE_RAIL)
        self:drawBox(self.width, y, 1, 1, ui.COLORS.TABLE_RAIL)
    end

    -- Innerer Doppelrand für Tiefe
    self:drawBorder(2, 2, self.width - 2, self.height - 2, ui.COLORS.TABLE_BORDER, true)

    -- Premium Titel mit Hintergrund
    local titleWidth = 25
    local titleX = math.floor((self.width - titleWidth) / 2)
    self:drawBox(titleX, 2, titleWidth, 3, ui.COLORS.PANEL_DARK)
    self:drawBorder(titleX, 2, titleWidth, 3, ui.COLORS.TEXT_GOLD)
    self:drawCenteredText(3, "TEXAS HOLD'EM", ui.COLORS.TEXT_GOLD, ui.COLORS.PANEL_DARK)
end

-- === KARTEN-DARSTELLUNG (VERBESSERT) ===

function ui:drawCard(x, y, card, faceUp, large)
    local width = large and 8 or 6
    local height = large and 6 or 4

    if not faceUp or not card then
        -- Kartenrückseite mit Pattern
        self:drawShadow(x, y, width, height)
        self:drawBox(x, y, width, height, ui.COLORS.CARD_BACK)
        self:drawBorder(x, y, width, height, ui.COLORS.CARD_BORDER)

        -- Pattern für Kartenrückseite
        if large then
            self:drawText(x + 2, y + 1, "####", ui.COLORS.CARD_BACK_PATTERN, ui.COLORS.CARD_BACK)
            self:drawText(x + 2, y + 2, "####", ui.COLORS.CARD_BACK_PATTERN, ui.COLORS.CARD_BACK)
            self:drawText(x + 2, y + 3, "####", ui.COLORS.CARD_BACK_PATTERN, ui.COLORS.CARD_BACK)
            self:drawText(x + 2, y + 4, "####", ui.COLORS.CARD_BACK_PATTERN, ui.COLORS.CARD_BACK)
        else
            self:drawText(x + 1, y + 1, "####", ui.COLORS.CARD_BACK_PATTERN, ui.COLORS.CARD_BACK)
            self:drawText(x + 1, y + 2, "####", ui.COLORS.CARD_BACK_PATTERN, ui.COLORS.CARD_BACK)
        end
    else
        -- Kartenvorderseite
        local poker = require("lib.poker")
        local suitColor = poker.SUIT_COLORS[card.suit]

        self:drawShadow(x, y, width, height)
        self:drawBox(x, y, width, height, ui.COLORS.CARD_BG)
        self:drawBorder(x, y, width, height, ui.COLORS.CARD_BORDER)

        local rank = card.rank
        local suit = poker.SUIT_SYMBOLS[card.suit]

        if large then
            -- Große Karte - besseres Layout
            self:drawText(x + 2, y + 1, rank, suitColor, ui.COLORS.CARD_BG)
            self:drawText(x + math.floor(width/2) - 1, y + math.floor(height/2), suit, suitColor, ui.COLORS.CARD_BG)
            self:drawText(x + math.floor(width/2), y + math.floor(height/2), suit, suitColor, ui.COLORS.CARD_BG)
            local rankX = x + width - 2 - (#rank > 1 and 1 or 0) - 1
            self:drawText(rankX, y + height - 2, rank, suitColor, ui.COLORS.CARD_BG)
        else
            -- Normale Karte
            self:drawText(x + 1, y + 1, rank, suitColor, ui.COLORS.CARD_BG)
            self:drawText(x + math.floor(width/2), y + 2, suit, suitColor, ui.COLORS.CARD_BG)
        end
    end
end

-- === COMMUNITY CARDS (REDESIGNED) ===

function ui:drawCommunityCards(cards, round)
    local cardWidth = 8
    local cardHeight = 6
    local spacing = 2
    local totalWidth = 5 * cardWidth + 4 * spacing
    local startX = math.floor((self.width - totalWidth) / 2)
    local startY = math.floor(self.height / 2) - 5

    -- Runden-Name mit Premium-Style
    if round and round ~= "waiting" then
        local roundText = string.upper(round)
        local roundWidth = #roundText + 6
        local roundX = math.floor((self.width - roundWidth) / 2)
        self:drawBox(roundX, startY - 3, roundWidth, 3, ui.COLORS.PANEL_DARK)
        self:drawBorder(roundX, startY - 3, roundWidth, 3, ui.COLORS.TEXT_GOLD)
        self:drawCenteredText(startY - 2, roundText, ui.COLORS.TEXT_GOLD, ui.COLORS.PANEL_DARK)
    end

    -- Untergrund für Community Cards (Poker-Tisch Bereich)
    local bgPadding = 3
    self:drawBox(startX - bgPadding, startY - 1, totalWidth + bgPadding * 2, cardHeight + 2, ui.COLORS.PANEL_DARK)
    self:drawBorder(startX - bgPadding, startY - 1, totalWidth + bgPadding * 2, cardHeight + 2, ui.COLORS.TABLE_BORDER)

    -- Zeichne 5 Karten
    for i = 1, 5 do
        local x = startX + (i - 1) * (cardWidth + spacing)
        if cards and cards[i] then
            self:drawCard(x, startY, cards[i], true, true)
        else
            self:drawCard(x, startY, nil, false, true)
        end
    end
end

-- === POT-ANZEIGE (PREMIUM DESIGN) ===

function ui:drawPot(pot, y)
    y = y or math.floor(self.height / 2) + 3

    local text = pot .. " CHIPS"
    local width = #text + 8
    local x = math.floor((self.width - width) / 2)

    -- Schatten
    self:drawShadow(x, y, width, 4)

    -- Gold-Hintergrund für Pot
    self:drawBox(x, y, width, 4, ui.COLORS.POT_BG)
    self:drawBorder(x, y, width, 4, ui.COLORS.POT_BORDER)

    -- "POT" Label
    self:drawText(x + 2, y + 1, "POT:", ui.COLORS.PANEL_DARK, ui.COLORS.POT_BG)

    -- Betrag
    self:drawText(x + 2, y + 2, text, ui.COLORS.PANEL_DARK, ui.COLORS.POT_BG)
end

-- === SPIELER-BOX (MODERN REDESIGN) ===

function ui:drawPlayerBox(position, player, isDealer, isSmallBlind, isBigBlind, isActive, isMe)
    local pos = self.playerPositions[position]
    if not pos then return end

    local x, y = pos.x, pos.y
    local width = 24
    local height = 10

    -- Schatten-Effekt
    self:drawShadow(x, y, width, height)

    -- Hintergrund basierend auf Status
    local bgColor = ui.COLORS.PANEL
    local borderColor = ui.COLORS.TABLE_BORDER

    if isActive then
        bgColor = ui.COLORS.PANEL_DARK
        borderColor = ui.COLORS.ACTIVE
    elseif isMe then
        bgColor = ui.COLORS.PANEL_DARK
        borderColor = ui.COLORS.TEXT_GOLD
    end

    self:drawBox(x, y, width, height, bgColor)
    self:drawBorder(x, y, width, height, borderColor)

    -- Innerer Akzent für aktiven Spieler
    if isActive then
        self:drawBox(x + 1, y + 1, width - 2, 1, ui.COLORS.ACTIVE_GLOW)
    end

    -- Name mit Style
    local name = player.name or "Player"
    if #name > width - 6 then
        name = name:sub(1, width - 9) .. "..."
    end
    local nameColor = isMe and ui.COLORS.TEXT_GOLD or ui.COLORS.TEXT_WHITE
    self:drawText(x + 2, y + 1, name, nameColor, bgColor)

    -- Dealer/Blind Buttons (kompakt und stylish)
    local buttonY = y + 1
    local buttonX = x + width - 3

    if isDealer then
        self:drawBox(buttonX - 2, buttonY, 3, 1, ui.COLORS.DEALER)
        self:drawText(buttonX - 1, buttonY, "D", ui.COLORS.DEALER_TEXT, ui.COLORS.DEALER)
        buttonX = buttonX - 4
    end
    if isBigBlind then
        self:drawBox(buttonX - 2, buttonY, 3, 1, ui.COLORS.BLIND)
        self:drawText(buttonX - 1, buttonY, "B", ui.COLORS.TEXT_WHITE, ui.COLORS.BLIND)
        buttonX = buttonX - 4
    end
    if isSmallBlind then
        self:drawBox(buttonX - 2, buttonY, 3, 1, ui.COLORS.BLIND)
        self:drawText(buttonX - 1, buttonY, "S", ui.COLORS.TEXT_WHITE, ui.COLORS.BLIND)
    end

    -- Chips mit Icon
    local chipsText = player.chips .. " $"
    self:drawText(x + 2, y + 3, chipsText, ui.COLORS.CHIPS_GOLD, bgColor)

    -- Bet (wenn vorhanden) - hervorgehoben
    if player.bet and player.bet > 0 then
        local betText = "BET: " .. player.bet
        self:drawBox(x + 2, y + 4, #betText + 2, 1, ui.COLORS.BTN_RAISE)
        self:drawText(x + 3, y + 4, betText, ui.COLORS.PANEL_DARK, ui.COLORS.BTN_RAISE)
    end

    -- Status mit Icons
    if player.folded then
        self:drawText(x + 2, y + 6, "[FOLDED]", ui.COLORS.TEXT_RED, bgColor)
    elseif player.allIn then
        self:drawBox(x + 2, y + 6, 9, 1, ui.COLORS.BTN_ALLIN)
        self:drawText(x + 2, y + 6, "[ALL-IN]", ui.COLORS.TEXT_WHITE, ui.COLORS.BTN_ALLIN)
    elseif isActive then
        self:drawBox(x + 2, y + 6, 8, 1, ui.COLORS.ACTIVE)
        self:drawText(x + 2, y + 6, ">> TURN", ui.COLORS.PANEL_DARK, ui.COLORS.ACTIVE)
    end

    -- Karten (kleine Vorschau)
    local cardY = y + 8
    if not isMe and not player.folded then
        self:drawCard(x + 2, cardY, nil, false, false)
        self:drawCard(x + 9, cardY, nil, false, false)
    end
end

-- === EIGENE KARTEN (PREMIUM STYLE) ===

function ui:drawOwnCards(cards)
    if not cards or #cards < 2 then return end

    local cardWidth = 8
    local cardHeight = 6
    local spacing = 3
    local y = self.height - 9
    local totalWidth = 2 * cardWidth + spacing
    local startX = math.floor((self.width - totalWidth) / 2)

    -- Premium Box für eigene Karten
    local boxPadding = 4
    local boxWidth = totalWidth + boxPadding * 2
    local boxHeight = cardHeight + 3
    local boxX = startX - boxPadding
    local boxY = y - 2

    self:drawBox(boxX, boxY, boxWidth, boxHeight, ui.COLORS.PANEL_DARK)
    self:drawBorder(boxX, boxY, boxWidth, boxHeight, ui.COLORS.TEXT_GOLD)

    -- Label
    self:drawCenteredText(boxY + 1, "YOUR HAND", ui.COLORS.TEXT_GOLD, ui.COLORS.PANEL_DARK)

    -- Karten
    self:drawCard(startX, y, cards[1], true, true)
    self:drawCard(startX + cardWidth + spacing, y, cards[2], true, true)
end

-- === HAND-EVALUATION (STYLISH) ===

function ui:drawHandEvaluation(handName, x, y)
    if not handName then return end

    local width = #handName + 6
    x = x or math.floor((self.width - width) / 2)
    y = y or self.height - 2

    self:drawBox(x, y, width, 1, ui.COLORS.PANEL_DARK)
    self:drawText(x + 1, y, ">> " .. handName, ui.COLORS.TEXT_GOLD, ui.COLORS.PANEL_DARK)
end

-- === BUTTONS (MODERN DESIGN) ===

function ui:drawButton(x, y, width, height, text, color, textColor, enabled)
    enabled = enabled == nil and true or enabled
    local btnColor = enabled and color or ui.COLORS.BTN_DISABLED
    local txtColor = enabled and textColor or ui.COLORS.TEXT_BLACK

    -- Schatten für 3D-Effekt
    if enabled then
        self:drawShadow(x, y, width, height)
    end

    self:drawBox(x, y, width, height, btnColor)
    self:drawBorder(x, y, width, height, ui.COLORS.BTN_BORDER)

    -- Highlight oben für 3D-Look
    if enabled and height > 2 then
        self:drawBox(x + 1, y + 1, width - 2, 1, ui.COLORS.PANEL_LIGHT)

        -- Text mit Offset für 3D
        local textX = x + math.floor((width - #text) / 2)
        local textY = y + math.floor(height / 2)
        self:drawText(textX, textY, text, txtColor, btnColor)
    else
        -- Normal zentriert
        local textX = x + math.floor((width - #text) / 2)
        local textY = y + math.floor(height / 2)
        self:drawText(textX, textY, text, txtColor, btnColor)
    end
end

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

function ui:setButtonEnabled(id, enabled)
    local button = self.buttons[id]
    if button then
        button.enabled = enabled
        self:drawButton(button.x, button.y, button.width, button.height, button.text, button.color, ui.COLORS.BTN_TEXT, enabled)
    end
end

function ui:clearButtons()
    self.buttons = {}
end

-- === RAISE BUTTONS (VERBESSERT) ===

function ui:drawRaiseButtons(min, max, current, pot, x, y, width)
    x = x or 5
    y = y or self.height - 12
    width = width or self.width - 10

    -- Premium Label
    local labelText = "RAISE: " .. current .. " $"
    local labelWidth = #labelText + 6
    local labelX = x + math.floor((width - labelWidth) / 2)

    self:drawShadow(labelX, y - 3, labelWidth, 3)
    self:drawBox(labelX, y - 3, labelWidth, 3, ui.COLORS.BTN_RAISE)
    self:drawBorder(labelX, y - 3, labelWidth, 3, ui.COLORS.BTN_BORDER)
    self:drawText(labelX + 3, y - 2, labelText, ui.COLORS.PANEL_DARK, ui.COLORS.BTN_RAISE)

    -- Buttons
    local btnY = y
    local btnHeight = 3
    local btnSpacing = 2
    local totalBtns = 5
    local availableWidth = width - (btnSpacing * (totalBtns - 1))
    local btnWidth = math.floor(availableWidth / totalBtns)
    local currentX = x

    -- -10
    local canDecrease10 = (current - 10) >= min
    self:addButton("raise_dec10", currentX, btnY, btnWidth, btnHeight, "-10", nil, ui.COLORS.BTN_FOLD, canDecrease10)
    currentX = currentX + btnWidth + btnSpacing

    -- -1
    local canDecrease1 = (current - 1) >= min
    self:addButton("raise_dec1", currentX, btnY, btnWidth, btnHeight, "-1", nil, ui.COLORS.BTN_FOLD, canDecrease1)
    currentX = currentX + btnWidth + btnSpacing

    -- POT
    self:addButton("raise_pot", currentX, btnY, btnWidth, btnHeight, "POT", nil, ui.COLORS.BTN_ALLIN, true)
    currentX = currentX + btnWidth + btnSpacing

    -- +1
    local canIncrease1 = (current + 1) <= max
    self:addButton("raise_inc1", currentX, btnY, btnWidth, btnHeight, "+1", nil, ui.COLORS.BTN_CALL, canIncrease1)
    currentX = currentX + btnWidth + btnSpacing

    -- +10
    local canIncrease10 = (current + 10) <= max
    self:addButton("raise_inc10", currentX, btnY, btnWidth, btnHeight, "+10", nil, ui.COLORS.BTN_CALL, canIncrease10)

    -- Info
    local infoY = btnY + btnHeight + 1
    self:drawText(x, infoY, "Min: " .. min, ui.COLORS.TEXT_GOLD, ui.COLORS.TABLE_FELT)
    self:drawText(x + width - #("Max: " .. max), infoY, "Max: " .. max, ui.COLORS.TEXT_GOLD, ui.COLORS.TABLE_FELT)

    -- Premium Progress Bar
    local barY = infoY + 1
    local barHeight = 2
    self:drawBox(x, barY, width, barHeight, ui.COLORS.PANEL_DARK)
    self:drawBorder(x, barY, width, barHeight, ui.COLORS.TABLE_BORDER)

    local percent = (max > min) and ((current - min) / (max - min)) or 1
    local fillWidth = math.floor((width - 2) * percent)
    if fillWidth > 0 then
        self:drawBox(x + 1, barY + 1, fillWidth, barHeight - 2, ui.COLORS.BTN_RAISE)
    end

    return barY + 3
end

-- === TIMER (MODERN) ===

function ui:drawTimer(secondsLeft, x, y)
    x = x or self.width - 16
    y = y or 3

    local width = 14
    local height = 3

    self:drawShadow(x, y, width, height)
    self:drawBox(x, y, width, height, ui.COLORS.PANEL_DARK)
    self:drawBorder(x, y, width, height, ui.COLORS.TABLE_BORDER)

    local color = secondsLeft > 10 and ui.COLORS.TEXT_GREEN or ui.COLORS.TEXT_RED
    local text = "TIME: " .. secondsLeft .. "s"
    self:drawText(x + 2, y + 1, text, color, ui.COLORS.PANEL_DARK)
end

function ui:startTimer(seconds)
    self.timerActive = true
    self.timerEnd = os.epoch("utc") / 1000 + seconds
end

function ui:stopTimer()
    self.timerActive = false
end

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

-- === HAND RANKINGS (MODERN DIALOG) ===

function ui:showHandRankings()
    local dialogHeight = 26
    local dialogWidth = math.min(54, self.width - 4)
    local x = math.floor((self.width - dialogWidth) / 2)
    local y = math.floor((self.height - dialogHeight) / 2)

    -- Schatten
    self:drawShadow(x, y, dialogWidth, dialogHeight)

    -- Dialog
    self:drawBox(x, y, dialogWidth, dialogHeight, ui.COLORS.PANEL_DARK)
    self:drawBorder(x, y, dialogWidth, dialogHeight, ui.COLORS.TEXT_GOLD)

    -- Titel
    local titleY = y + 2
    self:drawCenteredText(titleY, "=== POKER HAND RANKINGS ===", ui.COLORS.TEXT_GOLD, ui.COLORS.PANEL_DARK)
    self:drawCenteredText(titleY + 1, "(Beste bis Schlechteste)", ui.COLORS.TEXT_WHITE, ui.COLORS.PANEL_DARK)

    -- Rankings
    local rankings = {
        {name = "1. Royal Flush", desc = "A-K-Q-J-10 gleiche Farbe", color = ui.COLORS.TEXT_GOLD},
        {name = "2. Straight Flush", desc = "5 aufeinander folgende, gleiche Farbe", color = ui.COLORS.TEXT_GOLD},
        {name = "3. Four of a Kind", desc = "4 Karten gleichen Werts", color = ui.COLORS.CHIPS_GREEN},
        {name = "4. Full House", desc = "3 gleiche + 2 gleiche", color = ui.COLORS.CHIPS_GREEN},
        {name = "5. Flush", desc = "5 Karten gleicher Farbe", color = ui.COLORS.CHIPS_BLUE},
        {name = "6. Straight", desc = "5 aufeinander folgende Karten", color = ui.COLORS.CHIPS_BLUE},
        {name = "7. Three of a Kind", desc = "3 Karten gleichen Werts", color = ui.COLORS.TEXT_WHITE},
        {name = "8. Two Pair", desc = "2 Paare", color = ui.COLORS.TEXT_WHITE},
        {name = "9. Pair", desc = "2 Karten gleichen Werts", color = ui.COLORS.TEXT_WHITE},
        {name = "10. High Card", desc = "Höchste Karte", color = ui.COLORS.TEXT_WHITE},
    }

    local currentY = y + 5
    for _, ranking in ipairs(rankings) do
        self:drawText(x + 3, currentY, ranking.name, ranking.color, ui.COLORS.PANEL_DARK)
        currentY = currentY + 1
        self:drawText(x + 5, currentY, ranking.desc, ui.COLORS.TEXT_WHITE, ui.COLORS.PANEL_DARK)
        currentY = currentY + 1
    end

    -- Close Button
    local btnWidth = 22
    local btnHeight = 3
    local btnX = math.floor((dialogWidth - btnWidth) / 2) + x
    local btnY = y + dialogHeight - 4

    self:addButton("rankings_close", btnX, btnY, btnWidth, btnHeight, "SCHLIESSEN", nil, ui.COLORS.BTN_CALL)

    -- Wait
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "monitor_touch" then
            if self:handleTouch(p2, p3) == "rankings_close" then
                break
            end
        end
    end

    self:clearButtons()
end

-- === MESSAGE OVERLAY (MODERN) ===

function ui:showMessage(message, duration, color, large)
    local lines = {}
    for line in message:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local maxWidth = 0
    for _, line in ipairs(lines) do
        if #line > maxWidth then maxWidth = #line end
    end

    local width = math.min(maxWidth + 6, self.width - 4)
    local height = #lines + 4
    local x = math.floor((self.width - width) / 2)
    local y = math.floor((self.height - height) / 2)

    if large then
        height = height + 2
        y = y - 1
    end

    -- Schatten
    self:drawShadow(x, y, width, height)

    -- Box
    self:drawBox(x, y, width, height, color or ui.COLORS.PANEL)
    self:drawBorder(x, y, width, height, ui.COLORS.TEXT_GOLD)

    -- Text
    for i, line in ipairs(lines) do
        local lineX = x + math.floor((width - #line) / 2)
        self:drawText(lineX, y + i + 1, line, ui.COLORS.TEXT_WHITE, color or ui.COLORS.PANEL)
    end

    if duration then
        sleep(duration)
        -- Don't auto-redraw - let the caller decide what to draw after
    end
end

-- === PLAYER SELECTION (MODERN) ===

function ui:showPlayerSelection(players)
    local dialogHeight = math.min(#players * 3 + 14, self.height - 4)
    local y = math.floor((self.height - dialogHeight) / 2)
    local width = math.min(44, self.width - 8)
    local x = math.floor((self.width - width) / 2)

    self:clear(ui.COLORS.TABLE_FELT)

    self:drawShadow(x, y, width, dialogHeight)
    self:drawBox(x, y, width, dialogHeight, ui.COLORS.PANEL_DARK)
    self:drawBorder(x, y, width, dialogHeight, ui.COLORS.TEXT_GOLD)

    -- Titel
    self:drawCenteredText(y + 1, "SPIELER AUSWAHL", ui.COLORS.TEXT_GOLD, ui.COLORS.PANEL_DARK)
    self:drawCenteredText(y + 2, "Wähle deinen Namen:", ui.COLORS.TEXT_WHITE, ui.COLORS.PANEL_DARK)

    -- Buttons
    local btnY = y + 4
    local btnHeight = 2
    local btnWidth = width - 8

    self:clearButtons()

    for i, playerName in ipairs(players) do
        self:addButton("player_" .. i, x + 4, btnY, btnWidth, btnHeight, playerName, nil, ui.COLORS.BTN_CALL)
        btnY = btnY + btnHeight + 1
        if i >= 10 then break end
    end

    btnY = btnY + 1
    self:addButton("rescan", x + 4, btnY, btnWidth, btnHeight, "Erneut scannen", nil, ui.COLORS.PANEL)

    btnY = btnY + btnHeight + 1
    self:addButton("spectator", x + 4, btnY, btnWidth, btnHeight, "Als Zuschauer beitreten", nil, ui.COLORS.BTN_CHECK)

    local selectedPlayer = nil
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "monitor_touch" then
            local buttonId = self:handleTouch(p2, p3)
            if buttonId == "rescan" then
                selectedPlayer = "__RESCAN__"
                break
            elseif buttonId == "spectator" then
                selectedPlayer = "Zuschauer_" .. os.getComputerID()
                break
            elseif buttonId then
                local playerIndex = tonumber(buttonId:match("player_(%d+)"))
                if playerIndex and players[playerIndex] then
                    selectedPlayer = players[playerIndex]
                    break
                end
            end
        end
    end

    self:clearButtons()
    return selectedPlayer
end

-- === RAISE INPUT (PREMIUM) ===

function ui:showRaiseInput(min, max, pot)
    local dialogHeight = 18
    local y = math.floor(self.height / 2) - 9
    local width = self.width - 8
    local x = 4

    -- Premium Dialog
    self:drawShadow(x, y, width, dialogHeight)
    self:drawBox(x, y, width, dialogHeight, ui.COLORS.PANEL_DARK)
    self:drawBorder(x, y, width, dialogHeight, ui.COLORS.TEXT_GOLD)

    -- Titel
    local titleY = y + 1
    local titleWidth = 20
    local titleX = math.floor((width - titleWidth) / 2) + x
    self:drawBox(titleX, titleY, titleWidth, 3, ui.COLORS.BTN_RAISE)
    self:drawBorder(titleX, titleY, titleWidth, 3, ui.COLORS.BTN_BORDER)
    self:drawCenteredText(titleY + 1, "=== RAISE ===", ui.COLORS.PANEL_DARK, ui.COLORS.BTN_RAISE)

    -- Pot
    local potY = y + 5
    local potText = "POT: " .. pot .. " $"
    local potWidth = #potText + 4
    local potX = math.floor((width - potWidth) / 2) + x
    self:drawBox(potX, potY, potWidth, 3, ui.COLORS.POT_BG)
    self:drawBorder(potX, potY, potWidth, 3, ui.COLORS.POT_BORDER)
    self:drawText(potX + 2, potY + 1, potText, ui.COLORS.PANEL_DARK, ui.COLORS.POT_BG)

    -- Raise Buttons
    local current = min
    local buttonsY = y + 9
    self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, width - 4)

    -- Action Buttons
    local actionBtnY = y + dialogHeight - 3
    local btnWidth = math.floor((width - 10) / 3)
    local btnHeight = 2

    self:addButton("raise_confirm", x + 2, actionBtnY, btnWidth, btnHeight, "RAISE", nil, ui.COLORS.BTN_RAISE)
    self:addButton("raise_allin", x + 4 + btnWidth, actionBtnY, btnWidth, btnHeight, "ALL-IN", nil, ui.COLORS.BTN_ALLIN)
    self:addButton("raise_cancel", x + 6 + btnWidth * 2, actionBtnY, btnWidth, btnHeight, "CANCEL", nil, ui.COLORS.BTN_FOLD)

    local result = {amount = current, action = nil}

    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "monitor_touch" then
            local buttonId = self:handleTouch(p2, p3)

            if buttonId == "raise_dec10" then
                current = math.max(min, current - 10)
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, width - 4)
            elseif buttonId == "raise_dec1" then
                current = math.max(min, current - 1)
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, width - 4)
            elseif buttonId == "raise_inc1" then
                current = math.min(max, current + 1)
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, width - 4)
            elseif buttonId == "raise_inc10" then
                current = math.min(max, current + 10)
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, width - 4)
            elseif buttonId == "raise_pot" then
                current = math.max(min, math.min(pot, max))
                result.amount = current
                self:drawRaiseButtons(min, max, current, pot, x + 2, buttonsY, width - 4)
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
