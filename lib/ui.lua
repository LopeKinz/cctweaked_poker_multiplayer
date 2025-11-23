-- ui.lua - UI und Touchscreen Bibliothek
local ui = {}

-- Farben
ui.COLORS = {
    BG = colors.gray,
    CARD_BG = colors.white,
    CARD_BORDER = colors.black,
    BUTTON = colors.blue,
    BUTTON_HOVER = colors.lightBlue,
    BUTTON_DISABLED = colors.gray,
    TEXT = colors.white,
    TEXT_DARK = colors.black,
    GREEN = colors.green,
    RED = colors.red,
    YELLOW = colors.yellow,
    TABLE = colors.lime
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
        scale = 1
    }

    -- Größe ermitteln
    instance.width, instance.height = monitor.getSize()

    -- Touchscreen prüfen
    if monitor.setTextScale then
        monitor.setTextScale(0.5)
        instance.scale = 0.5
        instance.width, instance.height = monitor.getSize()
    end

    setmetatable(instance, {__index = ui})
    return instance
end

-- Löscht Bildschirm
function ui:clear(color)
    self.monitor.setBackgroundColor(color or ui.COLORS.BG)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
end

-- Zeichnet Text
function ui:drawText(x, y, text, fg, bg)
    self.monitor.setCursorPos(x, y)
    if fg then self.monitor.setTextColor(fg) end
    if bg then self.monitor.setBackgroundColor(bg) end
    self.monitor.write(text)
end

-- Zeichnet zentrierten Text
function ui:drawCenteredText(y, text, fg, bg)
    local x = math.floor((self.width - #text) / 2) + 1
    self:drawText(x, y, text, fg, bg)
end

-- Zeichnet Box
function ui:drawBox(x, y, width, height, color)
    self.monitor.setBackgroundColor(color)
    for dy = 0, height - 1 do
        self.monitor.setCursorPos(x, y + dy)
        self.monitor.write(string.rep(" ", width))
    end
end

-- Zeichnet Rahmen
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

-- Zeichnet Button
function ui:drawButton(x, y, width, height, text, color, textColor)
    self:drawBox(x, y, width, height, color or ui.COLORS.BUTTON)

    -- Text zentrieren
    local textX = x + math.floor((width - #text) / 2)
    local textY = y + math.floor(height / 2)

    self:drawText(textX, textY, text, textColor or ui.COLORS.TEXT, color or ui.COLORS.BUTTON)
end

-- Registriert Button
function ui:addButton(id, x, y, width, height, text, callback, color)
    self.buttons[id] = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        callback = callback,
        color = color or ui.COLORS.BUTTON,
        enabled = true
    }
    self:drawButton(x, y, width, height, text, color)
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
        local color = enabled and button.color or ui.COLORS.BUTTON_DISABLED
        self:drawButton(button.x, button.y, button.width, button.height, button.text, color)
    end
end

-- Entfernt Button
function ui:removeButton(id)
    local button = self.buttons[id]
    if button then
        self:drawBox(button.x, button.y, button.width, button.height, ui.COLORS.BG)
        self.buttons[id] = nil
    end
end

-- Zeichnet Karte
function ui:drawCard(x, y, card, faceUp)
    if not faceUp then
        -- Kartenrückseite
        self:drawBox(x, y, 5, 3, colors.blue)
        self:drawBorder(x, y, 5, 3, colors.black)
        self:drawText(x + 1, y + 1, "###", colors.white, colors.blue)
    else
        -- Kartenvorderseite
        local poker = require("lib.poker")
        local color = poker.SUIT_COLORS[card.suit]

        self:drawBox(x, y, 5, 3, colors.white)
        self:drawBorder(x, y, 5, 3, colors.black)

        local rank = card.rank
        if #rank == 1 then rank = " " .. rank end

        self:drawText(x + 1, y + 1, rank, color, colors.white)
        self:drawText(x + 2, y + 2, poker.SUIT_SYMBOLS[card.suit], color, colors.white)
    end
end

-- Zeichnet Hand (2 Karten)
function ui:drawHand(x, y, cards, faceUp)
    if cards and #cards >= 2 then
        self:drawCard(x, y, cards[1], faceUp)
        self:drawCard(x + 6, y, cards[2], faceUp)
    else
        -- Leere Karten
        self:drawCard(x, y, nil, false)
        self:drawCard(x + 6, y, nil, false)
    end
end

-- Zeichnet Community Cards
function ui:drawCommunityCards(y, cards)
    if not cards then cards = {} end

    local startX = math.floor((self.width - (5 * 6 - 1)) / 2) + 1

    for i = 1, 5 do
        if cards[i] then
            self:drawCard(startX + (i - 1) * 6, y, cards[i], true)
        else
            self:drawCard(startX + (i - 1) * 6, y, nil, false)
        end
    end
end

-- Zeichnet Spieler Info
function ui:drawPlayerInfo(x, y, player, isActive)
    local width = 20
    local height = 8

    -- Hintergrund
    local bgColor = isActive and colors.yellow or colors.gray
    self:drawBox(x, y, width, height, bgColor)
    self:drawBorder(x, y, width, height, colors.black)

    -- Name
    local name = player.name or "Player " .. player.id
    if #name > width - 2 then
        name = name:sub(1, width - 5) .. "..."
    end
    self:drawText(x + 1, y + 1, name, colors.white, bgColor)

    -- Chips
    self:drawText(x + 1, y + 2, "Chips: " .. player.chips, colors.white, bgColor)

    -- Status
    if player.folded then
        self:drawText(x + 1, y + 3, "FOLDED", colors.red, bgColor)
    elseif player.allIn then
        self:drawText(x + 1, y + 3, "ALL IN", colors.yellow, bgColor)
    elseif player.bet > 0 then
        self:drawText(x + 1, y + 3, "Bet: " .. player.bet, colors.green, bgColor)
    end

    -- Karten (wenn vorhanden)
    if player.showCards and player.cards then
        self:drawHand(x + 2, y + 5, player.cards, true)
    end
end

-- Zeichnet Pot
function ui:drawPot(y, pot)
    local text = "Pot: " .. pot
    self:drawCenteredText(y, text, colors.yellow, ui.COLORS.BG)
end

-- Zeichnet Fortschrittsbalken
function ui:drawProgressBar(x, y, width, progress, color)
    -- Hintergrund
    self:drawBox(x, y, width, 1, colors.gray)

    -- Fortschritt
    local fillWidth = math.floor(width * progress)
    if fillWidth > 0 then
        self:drawBox(x, y, fillWidth, 1, color or colors.green)
    end
end

-- Zeichnet Nachricht
function ui:showMessage(message, duration, color)
    local y = math.floor(self.height / 2)
    local width = math.min(#message + 4, self.width - 4)
    local x = math.floor((self.width - width) / 2)

    self:drawBox(x, y - 1, width, 3, color or colors.blue)
    self:drawBorder(x, y - 1, width, 3, colors.black)
    self:drawCenteredText(y, message, colors.white, color or colors.blue)

    if duration then
        sleep(duration)
        self:drawBox(x, y - 1, width, 3, ui.COLORS.BG)
    end
end

-- Zeichnet Input-Dialog
function ui:showInput(prompt, default)
    local y = math.floor(self.height / 2)
    local width = self.width - 4
    local x = 3

    self:drawBox(x, y - 2, width, 5, colors.blue)
    self:drawBorder(x, y - 2, width, 5, colors.black)
    self:drawText(x + 2, y - 1, prompt, colors.white, colors.blue)

    -- Input-Feld
    self:drawBox(x + 2, y + 1, width - 4, 1, colors.black)

    self.monitor.setCursorPos(x + 2, y + 1)
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.setCursorBlink(true)

    local input = read(nil, nil, nil, default)

    self.monitor.setCursorBlink(false)
    self:drawBox(x, y - 2, width, 5, ui.COLORS.BG)

    return input
end

return ui
