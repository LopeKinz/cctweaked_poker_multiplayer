-- ui.lua - Simple Functional Poker UI
local ui = {}

-- Simple Color Scheme
ui.COLORS = {
    -- Table
    TABLE_FELT = colors.green,
    TABLE_BORDER = colors.black,

    -- Cards
    CARD_BG = colors.white,
    CARD_BACK = colors.blue,
    CARD_BORDER = colors.black,
    CARD_RED = colors.red,
    CARD_BLACK = colors.black,

    -- UI
    BG = colors.black,
    PANEL = colors.gray,

    -- Buttons
    BTN_FOLD = colors.red,
    BTN_CHECK = colors.lime,
    BTN_CALL = colors.orange,
    BTN_RAISE = colors.yellow,
    BTN_ALLIN = colors.purple,
    BTN_DISABLED = colors.gray,

    -- Status
    ACTIVE = colors.yellow,
    INACTIVE = colors.gray,
    DEALER = colors.orange,

    -- Text
    TEXT_WHITE = colors.white,
    TEXT_BLACK = colors.black,
    TEXT_YELLOW = colors.yellow,
    TEXT_GREEN = colors.lime,
    TEXT_RED = colors.red,

    -- Chips
    POT_BG = colors.orange,
    CHIPS_GREEN = colors.lime,
}

-- Create new UI instance
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
        timerActive = false,
        timerEnd = 0,
    }

    -- Set scale
    if monitor.setTextScale then
        monitor.setTextScale(0.5)
    end
    instance.width, instance.height = monitor.getSize()

    setmetatable(instance, {__index = ui})

    return instance
end

-- Basic drawing functions
function ui:clear(color)
    color = color or ui.COLORS.BG
    self.monitor.setBackgroundColor(color)
    self.monitor.clear()
end

function ui:drawBox(x, y, width, height, color)
    x = math.max(1, math.floor(x))
    y = math.max(1, math.floor(y))
    width = math.max(1, math.floor(width))
    height = math.max(1, math.floor(height))

    self.monitor.setBackgroundColor(color)
    for dy = 0, height - 1 do
        if y + dy <= self.height then
            self.monitor.setCursorPos(x, y + dy)
            self.monitor.write(string.rep(" ", math.min(width, self.width - x + 1)))
        end
    end
end

function ui:drawBorder(x, y, width, height, color)
    x = math.max(1, math.floor(x))
    y = math.max(1, math.floor(y))
    width = math.max(1, math.floor(width))
    height = math.max(1, math.floor(height))

    self.monitor.setBackgroundColor(color)

    -- Top and bottom
    if y >= 1 and y <= self.height then
        self.monitor.setCursorPos(x, y)
        self.monitor.write(string.rep(" ", math.min(width, self.width - x + 1)))
    end
    if y + height - 1 >= 1 and y + height - 1 <= self.height then
        self.monitor.setCursorPos(x, y + height - 1)
        self.monitor.write(string.rep(" ", math.min(width, self.width - x + 1)))
    end

    -- Sides
    for dy = 1, height - 2 do
        if y + dy >= 1 and y + dy <= self.height then
            if x >= 1 and x <= self.width then
                self.monitor.setCursorPos(x, y + dy)
                self.monitor.write(" ")
            end
            if x + width - 1 >= 1 and x + width - 1 <= self.width then
                self.monitor.setCursorPos(x + width - 1, y + dy)
                self.monitor.write(" ")
            end
        end
    end
end

function ui:drawText(x, y, text, fgColor, bgColor)
    if y < 1 or y > self.height then return end

    x = math.floor(x)
    y = math.floor(y)

    self.monitor.setCursorPos(x, y)
    self.monitor.setTextColor(fgColor)
    self.monitor.setBackgroundColor(bgColor)
    self.monitor.write(text)
end

function ui:drawCenteredText(y, text, fgColor, bgColor)
    local x = math.floor((self.width - #text) / 2) + 1
    self:drawText(x, y, text, fgColor, bgColor)
end

-- Poker table
function ui:drawPokerTable()
    self:clear(ui.COLORS.BG)

    -- Simple table
    local tableWidth = self.width - 4
    local tableHeight = self.height - 4
    local tableX = 3
    local tableY = 3

    self:drawBox(tableX, tableY, tableWidth, tableHeight, ui.COLORS.TABLE_FELT)
    self:drawBorder(tableX, tableY, tableWidth, tableHeight, ui.COLORS.TABLE_BORDER)
end

-- Cards
function ui:drawCard(x, y, card, faceDown)
    x = math.floor(x)
    y = math.floor(y)

    local width = 5
    local height = 3

    if faceDown then
        self:drawBox(x, y, width, height, ui.COLORS.CARD_BACK)
        self:drawBorder(x, y, width, height, ui.COLORS.CARD_BORDER)
        self:drawText(x + 2, y + 1, "?", ui.COLORS.TEXT_WHITE, ui.COLORS.CARD_BACK)
    else
        local suitColor = (card.suit == "hearts" or card.suit == "diamonds") and ui.COLORS.CARD_RED or ui.COLORS.CARD_BLACK
        local suitSymbol = {hearts = "\3", diamonds = "\4", clubs = "\5", spades = "\6"}

        self:drawBox(x, y, width, height, ui.COLORS.CARD_BG)
        self:drawBorder(x, y, width, height, ui.COLORS.CARD_BORDER)
        self:drawText(x + 1, y + 1, card.rank .. suitSymbol[card.suit], suitColor, ui.COLORS.CARD_BG)
    end
end

-- Player box
function ui:drawPlayerBox(position, player, isDealer, isSmallBlind, isBigBlind, isActive, isMe)
    local positions = {
        {x = 3, y = math.floor(self.height / 2) - 2, side = "left"},   -- Left
        {x = math.floor(self.width / 2) - 10, y = 3, side = "top"},    -- Top
        {x = self.width - 23, y = math.floor(self.height / 2) - 2, side = "right"}, -- Right
        {x = math.floor(self.width / 2) - 10, y = self.height - 6, side = "bottom"} -- Bottom (me)
    }

    local pos = positions[position]
    if not pos then return end

    local boxWidth = 20
    local boxHeight = 5

    -- Box color
    local boxColor = isActive and ui.COLORS.ACTIVE or ui.COLORS.PANEL

    self:drawBox(pos.x, pos.y, boxWidth, boxHeight, boxColor)
    self:drawBorder(pos.x, pos.y, boxWidth, boxHeight, ui.COLORS.TABLE_BORDER)

    -- Name
    local name = player.name
    if #name > boxWidth - 2 then
        name = name:sub(1, boxWidth - 5) .. "..."
    end
    self:drawText(pos.x + 1, pos.y + 1, name, ui.COLORS.TEXT_WHITE, boxColor)

    -- Chips
    self:drawText(pos.x + 1, pos.y + 2, "Chips: " .. player.chips, ui.COLORS.CHIPS_GREEN, boxColor)

    -- Bet
    if player.bet > 0 then
        self:drawText(pos.x + 1, pos.y + 3, "Bet: " .. player.bet, ui.COLORS.TEXT_YELLOW, boxColor)
    end

    -- Status
    local status = ""
    if player.folded then
        status = "[FOLD]"
    elseif player.allIn then
        status = "[ALL-IN]"
    elseif isDealer then
        status = "[D]"
    elseif isSmallBlind then
        status = "[SB]"
    elseif isBigBlind then
        status = "[BB]"
    end

    if status ~= "" then
        self:drawText(pos.x + 1, pos.y + 4, status, ui.COLORS.TEXT_YELLOW, boxColor)
    end
end

-- Community cards
function ui:drawCommunityCards(cards, round)
    if not cards or #cards == 0 then return end

    local totalWidth = #cards * 6 - 1
    local startX = math.floor((self.width - totalWidth) / 2)
    local y = math.floor(self.height / 2) - 2

    for i, card in ipairs(cards) do
        self:drawCard(startX + (i - 1) * 6, y, card, false)
    end
end

-- Pot
function ui:drawPot(amount)
    local text = "POT: " .. amount
    local width = #text + 4
    local x = math.floor((self.width - width) / 2)
    local y = math.floor(self.height / 2) + 2

    self:drawBox(x, y, width, 3, ui.COLORS.POT_BG)
    self:drawText(x + 2, y + 1, text, ui.COLORS.TEXT_BLACK, ui.COLORS.POT_BG)
end

-- Own cards
function ui:drawOwnCards(cards)
    if not cards or #cards ~= 2 then return end

    local startX = math.floor(self.width / 2) - 6
    local y = self.height - 4

    self:drawCard(startX, y, cards[1], false)
    self:drawCard(startX + 6, y, cards[2], false)
end

-- Hand evaluation
function ui:drawHandEvaluation(handName)
    if not handName then return end

    local y = self.height - 1
    self:drawCenteredText(y, "[" .. handName .. "]", ui.COLORS.TEXT_YELLOW, ui.COLORS.BG)
end

-- Buttons
function ui:clearButtons()
    self.buttons = {}
end

function ui:addButton(id, x, y, width, height, text, callback, color, enabled)
    x = math.floor(x)
    y = math.floor(y)
    width = math.floor(width)
    height = math.floor(height)

    enabled = enabled ~= false

    self.buttons[id] = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        callback = callback,
        color = color or ui.COLORS.PANEL,
        enabled = enabled
    }

    -- Draw button
    self:drawBox(x, y, width, height, color)

    if enabled then
        self:drawBorder(x, y, width, height, ui.COLORS.TABLE_BORDER)
    end

    -- Center text
    local textX = x + math.floor((width - #text) / 2)
    local textY = y + math.floor(height / 2)
    self:drawText(textX, textY, text, ui.COLORS.TEXT_WHITE, color)
end

function ui:handleTouch(x, y)
    for _, button in pairs(self.buttons) do
        if button.enabled and button.callback then
            if x >= button.x and x < button.x + button.width and
               y >= button.y and y < button.y + button.height then
                button.callback()
                return true
            end
        end
    end
    return false
end

-- Messages
function ui:showMessage(message, timeout, color)
    color = color or ui.COLORS.PANEL

    local lines = {}
    for line in message:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local maxWidth = 0
    for _, line in ipairs(lines) do
        if #line > maxWidth then
            maxWidth = #line
        end
    end

    local width = math.min(maxWidth + 4, self.width - 4)
    local height = #lines + 2
    local x = math.floor((self.width - width) / 2)
    local y = math.floor((self.height - height) / 2)

    self:drawBox(x, y, width, height, color)
    self:drawBorder(x, y, width, height, ui.COLORS.TABLE_BORDER)

    for i, line in ipairs(lines) do
        self:drawCenteredText(y + i, line, ui.COLORS.TEXT_WHITE, color)
    end

    if timeout then
        sleep(timeout)
    end
end

-- Hand rankings
function ui:showHandRankings()
    self:clear(ui.COLORS.BG)

    self:drawCenteredText(2, "=== HAND RANKINGS ===", ui.COLORS.TEXT_YELLOW, ui.COLORS.BG)

    local rankings = {
        "1. Royal Flush",
        "2. Straight Flush",
        "3. Four of a Kind",
        "4. Full House",
        "5. Flush",
        "6. Straight",
        "7. Three of a Kind",
        "8. Two Pair",
        "9. One Pair",
        "10. High Card"
    }

    local y = 5
    for _, rank in ipairs(rankings) do
        self:drawCenteredText(y, rank, ui.COLORS.TEXT_WHITE, ui.COLORS.BG)
        y = y + 1
    end

    self:drawCenteredText(self.height - 2, "Druecke Monitor zum Schliessen", ui.COLORS.TEXT_YELLOW, ui.COLORS.BG)

    -- Wait for touch
    repeat
        local event, side, x, y = os.pullEvent("monitor_touch")
    until true
end

-- Player selection
function ui:showPlayerSelection(players)
    players = players or {}

    self:clear(ui.COLORS.BG)

    self:drawCenteredText(3, "=== SPIELER WAEHLEN ===", ui.COLORS.TEXT_YELLOW, ui.COLORS.BG)

    local buttons = {}
    local y = 6
    local btnWidth = 30
    local btnX = math.floor((self.width - btnWidth) / 2)

    -- Add detected players
    for i, playerName in ipairs(players) do
        if i <= 6 then
            self:addButton("player_" .. i, btnX, y, btnWidth, 3, playerName, function()
                table.insert(buttons, playerName)
            end, ui.COLORS.BTN_CALL, true)
            y = y + 4
        end
    end

    -- Spectator option
    self:addButton("spectator", btnX, y, btnWidth, 3, "Als Zuschauer beitreten", function()
        table.insert(buttons, "Zuschauer_" .. os.getComputerID())
    end, ui.COLORS.BTN_CHECK, true)
    y = y + 4

    -- Rescan option
    self:addButton("rescan", btnX, y, btnWidth, 3, "Erneut scannen", function()
        table.insert(buttons, "__RESCAN__")
    end, ui.COLORS.BTN_FOLD, true)

    -- Wait for selection
    while #buttons == 0 do
        local event, side, x, y = os.pullEvent("monitor_touch")
        self:handleTouch(x, y)
    end

    return buttons[1]
end

-- Raise input
function ui:showRaiseInput(minAmount, maxAmount, pot)
    self:clear(ui.COLORS.TABLE_FELT)

    local currentAmount = minAmount

    local function redraw()
        self:clear(ui.COLORS.TABLE_FELT)

        self:drawCenteredText(5, "=== RAISE ===", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
        self:drawCenteredText(7, "Betrag: " .. currentAmount, ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)
        self:drawCenteredText(8, "Min: " .. minAmount .. " | Max: " .. maxAmount, ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

        local y = 12
        local btnWidth = 15
        local spacing = 2
        local startX = math.floor((self.width - (btnWidth * 4 + spacing * 3)) / 2)

        -- Amount buttons
        self:addButton("minus_big", startX, y, btnWidth, 3, "-" .. math.floor(pot/4), nil, ui.COLORS.BTN_FOLD, currentAmount > minAmount)
        self:addButton("minus_small", startX + btnWidth + spacing, y, btnWidth, 3, "-10", nil, ui.COLORS.BTN_FOLD, currentAmount > minAmount)
        self:addButton("plus_small", startX + (btnWidth + spacing) * 2, y, btnWidth, 3, "+10", nil, ui.COLORS.BTN_CALL, currentAmount < maxAmount)
        self:addButton("plus_big", startX + (btnWidth + spacing) * 3, y, btnWidth, 3, "+" .. math.floor(pot/4), nil, ui.COLORS.BTN_CALL, currentAmount < maxAmount)

        y = y + 5

        -- Action buttons
        local actionWidth = 20
        local actionStartX = math.floor((self.width - (actionWidth * 2 + spacing)) / 2)

        self:addButton("confirm", actionStartX, y, actionWidth, 3, "RAISE", nil, ui.COLORS.BTN_RAISE, true)
        self:addButton("all_in", actionStartX + actionWidth + spacing, y, actionWidth, 3, "ALL-IN", nil, ui.COLORS.BTN_ALLIN, true)

        y = y + 4
        self:addButton("cancel", actionStartX, y, actionWidth * 2 + spacing, 3, "ABBRECHEN", nil, ui.COLORS.BTN_FOLD, true)
    end

    redraw()

    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")

        for id, button in pairs(self.buttons) do
            if button.enabled and x >= button.x and x < button.x + button.width and
               y >= button.y and y < button.y + button.height then

                if id == "minus_big" then
                    currentAmount = math.max(minAmount, currentAmount - math.floor(pot/4))
                    redraw()
                elseif id == "minus_small" then
                    currentAmount = math.max(minAmount, currentAmount - 10)
                    redraw()
                elseif id == "plus_small" then
                    currentAmount = math.min(maxAmount, currentAmount + 10)
                    redraw()
                elseif id == "plus_big" then
                    currentAmount = math.min(maxAmount, currentAmount + math.floor(pot/4))
                    redraw()
                elseif id == "confirm" then
                    return {action = "raise", amount = currentAmount}
                elseif id == "all_in" then
                    return {action = "all-in"}
                elseif id == "cancel" then
                    return {action = "cancel"}
                end
            end
        end
    end
end

-- Timer
function ui:startTimer(seconds)
    self.timerActive = true
    self.timerEnd = os.epoch("utc") + (seconds * 1000)
end

function ui:stopTimer()
    self.timerActive = false
end

function ui:updateTimer()
    if not self.timerActive then return end

    local remaining = math.max(0, math.ceil((self.timerEnd - os.epoch("utc")) / 1000))

    local x = self.width - 10
    local y = 2

    self:drawBox(x, y, 10, 1, ui.COLORS.BG)
    self:drawText(x, y, "Time:" .. remaining, ui.COLORS.TEXT_YELLOW, ui.COLORS.BG)

    if remaining <= 0 then
        self.timerActive = false
    end
end

return ui
