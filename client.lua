-- client.lua - Poker Client mit Touchscreen UI
local poker = require("lib.poker")
local network = require("lib.network")
local ui = require("lib.ui")

-- Konfiguration
local config = {
    playerDetectorSide = "left",
    chestSide = "front",
    rsBridgeSide = "right",
    useBank = false,
    serverTimeout = 10
}

-- Lade Konfig falls vorhanden
if fs.exists("config.lua") then
    local customConfig = dofile("config.lua")
    for k, v in pairs(customConfig) do
        config[k] = v
    end
end

-- Client-Status
local client = {
    serverId = nil,
    playerId = nil,
    playerName = nil,
    gameState = nil,
    myCards = {},
    monitor = nil,
    ui = nil,
    chest = nil,
    playerDetector = nil,
    rsbridge = nil,
    connected = false,
    ready = false
}

-- Findet Peripherie
local function findPeripherals()
    print("Suche Peripherie...")

    -- Monitor
    client.monitor = peripheral.find("monitor")
    if not client.monitor then
        error("Kein Monitor gefunden!")
    end
    print("Monitor gefunden: " .. peripheral.getName(client.monitor))

    -- UI initialisieren
    client.ui = ui.new(client.monitor)

    -- Truhe
    client.chest = peripheral.find("minecraft:chest") or
                   peripheral.wrap(config.chestSide)
    if client.chest then
        print("Truhe gefunden: " .. peripheral.getName(client.chest))
    else
        print("WARNUNG: Keine Truhe gefunden!")
    end

    -- Player Detector
    client.playerDetector = peripheral.find("playerDetector") or
                            peripheral.wrap(config.playerDetectorSide)
    if client.playerDetector then
        print("Player Detector gefunden")
    else
        print("WARNUNG: Kein Player Detector gefunden!")
    end

    -- RS Bridge (optional)
    if config.useBank then
        client.rsbridge = peripheral.find("rs_bridge") or
                         peripheral.wrap(config.rsBridgeSide)
        if client.rsbridge then
            print("RS Bridge gefunden")
        else
            print("WARNUNG: RS Bridge nicht gefunden (Bank deaktiviert)")
            config.useBank = false
        end
    end
end

-- Zählt Chips in Truhe
local function countChips()
    if not client.chest then return 0 end

    local total = 0
    for slot = 1, client.chest.size() do
        local item = client.chest.getItemDetail(slot)
        if item then
            total = total + item.count
        end
    end

    return total
end

-- Erkennt Spieler
local function detectPlayer()
    if not client.playerDetector then
        return "Player"
    end

    local players = client.playerDetector.getPlayersInRange and
                    client.playerDetector.getPlayersInRange(3) or
                    client.playerDetector.getPlayers and
                    client.playerDetector.getPlayers()

    if players and #players > 0 then
        return players[1]
    end

    return nil
end

-- Verbindet zu Server
local function connectToServer()
    client.ui:clear()
    client.ui:showMessage("Suche Server...", nil, ui.COLORS.BLUE)

    print("Suche Server...")
    client.serverId = network.findServer(config.serverTimeout)

    if not client.serverId then
        client.ui:showMessage("Kein Server gefunden!", 3, ui.COLORS.RED)
        error("Kein Server gefunden!")
    end

    -- Erkenne Spieler
    client.ui:showMessage("Warte auf Spieler...", nil, ui.COLORS.YELLOW)

    while not client.playerName do
        client.playerName = detectPlayer()
        if not client.playerName then
            sleep(1)
        end
    end

    print("Spieler erkannt: " .. client.playerName)

    -- Verbinde
    client.ui:showMessage("Verbinde...", nil, ui.COLORS.BLUE)

    network.send(client.serverId, network.MSG.JOIN, {
        playerName = client.playerName
    })

    -- Warte auf Willkommen
    local senderId, data = network.waitFor(network.MSG.WELCOME, 5, client.serverId)

    if not senderId then
        client.ui:showMessage("Verbindung fehlgeschlagen!", 3, ui.COLORS.RED)
        error("Keine Antwort vom Server")
    end

    client.playerId = data.playerId
    client.connected = true

    print("Verbunden! ID: " .. client.playerId)
    client.ui:showMessage("Verbunden!", 2, ui.COLORS.GREEN)
end

-- Zeichnet Lobby-Screen
local function drawLobby()
    client.ui:clear()

    -- Titel
    client.ui:drawCenteredText(2, "=== POKER ===", ui.COLORS.YELLOW, ui.COLORS.BG)

    -- Spieler-Info
    client.ui:drawText(2, 4, "Spieler: " .. client.playerName, ui.COLORS.WHITE, ui.COLORS.BG)

    -- Chips
    local chips = countChips()
    client.ui:drawText(2, 5, "Chips: " .. chips, ui.COLORS.GREEN, ui.COLORS.BG)

    -- Status
    if client.gameState then
        local playerCount = #client.gameState.players
        client.ui:drawText(2, 7, "Spieler: " .. playerCount .. "/4", ui.COLORS.WHITE, ui.COLORS.BG)

        -- Spieler-Liste
        local y = 9
        for _, player in ipairs(client.gameState.players) do
            local status = player.ready and "[BEREIT]" or "[WARTEN]"
            local color = player.ready and ui.COLORS.GREEN or ui.COLORS.RED
            client.ui:drawText(2, y, player.name .. " " .. status, color, ui.COLORS.BG)
            y = y + 1
        end
    end

    -- Ready Button
    if not client.ready then
        client.ui:addButton("ready", 2, client.ui.height - 3, 20, 3, "BEREIT", function()
            client.ready = true
            network.send(client.serverId, network.MSG.READY, {ready = true})
            client.ui:setButtonEnabled("ready", false)
            client.ui:showMessage("Warte auf andere...", 2, ui.COLORS.YELLOW)
        end, ui.COLORS.GREEN)
    else
        client.ui:drawText(2, client.ui.height - 2, "[WARTE AUF ANDERE...]", ui.COLORS.YELLOW, ui.COLORS.BG)
    end
end

-- Zeichnet Spiel-Screen
local function drawGame()
    if not client.gameState then return end

    client.ui:clear()

    local state = client.gameState

    -- Community Cards
    client.ui:drawCenteredText(2, "=== " .. string.upper(state.round) .. " ===", ui.COLORS.YELLOW, ui.COLORS.BG)
    client.ui:drawCommunityCards(4, state.communityCards)

    -- Pot
    client.ui:drawPot(9, state.pot)

    -- Eigene Karten
    local cardY = client.ui.height - 6
    client.ui:drawText(2, cardY - 1, "Deine Hand:", ui.COLORS.WHITE, ui.COLORS.BG)
    client.ui:drawHand(2, cardY, client.myCards, true)

    -- Eigene Hand-Bewertung
    if client.myCards and #client.myCards == 2 and state.communityCards and #state.communityCards >= 3 then
        local allCards = {}
        for _, card in ipairs(client.myCards) do
            table.insert(allCards, card)
        end
        for _, card in ipairs(state.communityCards) do
            table.insert(allCards, card)
        end

        local hand = poker.evaluateHand(allCards)
        client.ui:drawText(14, cardY, hand.name, ui.COLORS.YELLOW, ui.COLORS.BG)
    end

    -- Spieler-Infos (kompakt)
    local infoY = 11
    for i, player in ipairs(state.players) do
        local isMe = player.id == client.playerId
        local isActive = i == state.currentPlayerIndex
        local prefix = isMe and "> " or "  "

        if isActive then prefix = "* " end

        local statusText = player.name .. ": " .. player.chips .. " chips"
        if player.bet > 0 then
            statusText = statusText .. " (Bet: " .. player.bet .. ")"
        end
        if player.folded then
            statusText = statusText .. " [FOLD]"
        end
        if player.allIn then
            statusText = statusText .. " [ALL-IN]"
        end

        local color = isMe and ui.COLORS.GREEN or ui.COLORS.WHITE
        if player.folded then color = ui.COLORS.RED end

        client.ui:drawText(2, infoY, prefix .. statusText, color, ui.COLORS.BG)
        infoY = infoY + 1
    end
end

-- Zeichnet Aktions-Buttons
local function drawActionButtons(canCheck, currentBet, myBet, myChips)
    local buttonY = client.ui.height - 9
    local buttonWidth = math.floor((client.ui.width - 10) / 4)

    -- Entferne alte Buttons
    client.ui.buttons = {}

    -- Fold
    client.ui:addButton("fold", 2, buttonY, buttonWidth, 3, "FOLD", function()
        network.send(client.serverId, network.MSG.ACTION, {action = "fold"})
        client.ui.buttons = {}
    end, ui.COLORS.RED)

    -- Check/Call
    if canCheck then
        client.ui:addButton("check", 4 + buttonWidth, buttonY, buttonWidth, 3, "CHECK", function()
            network.send(client.serverId, network.MSG.ACTION, {action = "check"})
            client.ui.buttons = {}
        end, ui.COLORS.YELLOW)
    else
        local callAmount = currentBet - myBet
        if callAmount <= myChips then
            client.ui:addButton("call", 4 + buttonWidth, buttonY, buttonWidth, 3, "CALL " .. callAmount, function()
                network.send(client.serverId, network.MSG.ACTION, {action = "call"})
                client.ui.buttons = {}
            end, ui.COLORS.YELLOW)
        end
    end

    -- Raise
    if myChips > (currentBet - myBet) then
        client.ui:addButton("raise", 6 + buttonWidth * 2, buttonY, buttonWidth, 3, "RAISE", function()
            -- Zeige Raise-Dialog
            local raiseAmount = tonumber(client.ui:showInput("Raise Betrag:", "20"))
            if raiseAmount and raiseAmount > 0 then
                network.send(client.serverId, network.MSG.ACTION, {action = "raise", amount = raiseAmount})
            end
            client.ui.buttons = {}
        end, ui.COLORS.GREEN)
    end

    -- All-In
    if myChips > 0 then
        client.ui:addButton("allin", 8 + buttonWidth * 3, buttonY, buttonWidth, 3, "ALL-IN", function()
            network.send(client.serverId, network.MSG.ACTION, {action = "all-in"})
            client.ui.buttons = {}
        end, ui.COLORS.RED)
    end
end

-- Behandelt Spielstatus-Update
local function handleGameState(state)
    client.gameState = state

    if state.myCards then
        client.myCards = state.myCards
    end

    if state.round == "waiting" then
        drawLobby()
    else
        drawGame()
    end
end

-- Behandelt "Your Turn"
local function handleYourTurn(data)
    client.ui:showMessage("DU BIST DRAN!", 1, ui.COLORS.YELLOW)

    -- Finde eigene Spieler-Daten
    local myPlayer = nil
    for _, player in ipairs(client.gameState.players) do
        if player.id == client.playerId then
            myPlayer = player
            break
        end
    end

    if myPlayer then
        drawGame()
        drawActionButtons(
            data.canCheck,
            data.currentBet,
            myPlayer.bet,
            myPlayer.chips
        )
    end
end

-- Behandelt Runden-Ende
local function handleRoundEnd(data)
    drawGame()

    -- Zeige Gewinner
    local winnerNames = {}
    for _, winnerId in ipairs(data.winners) do
        for _, player in ipairs(client.gameState.players) do
            if player.id == winnerId then
                table.insert(winnerNames, player.name)
            end
        end
    end

    local message = "Gewinner: " .. table.concat(winnerNames, ", ")
    if data.winningHand then
        message = message .. "\n" .. data.winningHand
    end
    message = message .. "\nPot: " .. data.pot

    client.ui:showMessage(message, 5, ui.COLORS.GREEN)

    client.ready = false
end

-- Event-Handler
local function handleEvents()
    while true do
        local event, param1, param2, param3 = os.pullEvent()

        if event == "monitor_touch" then
            client.ui:handleTouch(param2, param3)

        elseif event == "rednet_message" then
            local senderId = param1
            local message = param2

            if senderId == client.serverId and message.type then
                local msgType = message.type
                local data = message.data

                if msgType == network.MSG.GAME_STATE then
                    handleGameState(data)

                elseif msgType == network.MSG.YOUR_TURN then
                    handleYourTurn(data)

                elseif msgType == network.MSG.ROUND_END then
                    handleRoundEnd(data)

                elseif msgType == network.MSG.GAME_START then
                    client.ui:showMessage("Spiel startet!", 2, ui.COLORS.GREEN)

                elseif msgType == network.MSG.PLAYER_JOINED then
                    print("Spieler beigetreten: " .. data.playerName)

                elseif msgType == network.MSG.PLAYER_LEFT then
                    print("Spieler verlassen: " .. data.playerName)

                elseif msgType == network.MSG.ERROR then
                    client.ui:showMessage("FEHLER: " .. data.message, 3, ui.COLORS.RED)
                end
            end
        end
    end
end

-- Heartbeat (hält Verbindung aktiv)
local function heartbeat()
    while client.connected do
        sleep(5)
        if client.serverId then
            network.send(client.serverId, network.MSG.HEARTBEAT, {})
        end
    end
end

-- Hauptprogramm
local function main()
    print("=== Poker Client ===")

    -- Initialisiere
    findPeripherals()

    -- Netzwerk
    network.init(false)

    -- Verbinde zu Server
    connectToServer()

    -- Zeige Lobby
    drawLobby()

    -- Starte Heartbeat parallel
    parallel.waitForAny(
        handleEvents,
        heartbeat
    )
end

-- Fehlerbehandlung
local success, err = pcall(main)
if not success then
    if client.ui then
        client.ui:clear()
        client.ui:showMessage("FEHLER: " .. tostring(err), 5, ui.COLORS.RED)
    end
    print("FEHLER: " .. tostring(err))
    network.close()
end
