-- client.lua - Professional Poker Client mit Touch-UI
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
    ready = false,
    myPosition = nil,  -- Position am Tisch (1-4)
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
    client.playerDetector = peripheral.find("player_detector") or
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
        return nil
    end

    -- Erhöhter Radius für bessere Erkennung
    local players = client.playerDetector.getPlayersInRange and
                    client.playerDetector.getPlayersInRange(10) or
                    client.playerDetector.getPlayers and
                    client.playerDetector.getPlayers()

    return players
end

-- Spieler auswählen
local function selectPlayer()
    print("Erkenne Spieler in der Nähe...")

    local players = detectPlayer()

    if not players or #players == 0 then
        -- Keine Spieler erkannt - manuelle Eingabe
        print("Keine Spieler erkannt - manuelle Eingabe")
        client.ui:showMessage("Keine Spieler in Reichweite!\nManuelle Eingabe...", 2, ui.COLORS.BTN_CHECK)

        -- Zeige manuellen Input
        return client.ui:showPlayerSelection({})
    elseif #players == 1 then
        -- Nur ein Spieler - automatisch auswählen
        print("Ein Spieler erkannt: " .. players[1])
        client.ui:showMessage("Spieler erkannt:\n" .. players[1], 2, ui.COLORS.BTN_CALL)
        return players[1]
    else
        -- Mehrere Spieler - Auswahl anzeigen
        print("Mehrere Spieler erkannt: " .. #players)
        return client.ui:showPlayerSelection(players)
    end
end

-- Verbindet zu Server
local function connectToServer()
    client.ui:clear()
    client.ui:showMessage("Suche Server...\nWarte bis Server online ist...", nil, ui.COLORS.PANEL)

    print("Suche Server (endlos bis gefunden)...")

    -- Versuche unendlich Server zu finden (timeout = 0)
    client.serverId = network.findServer(0)

    print("Server gefunden! ID: " .. client.serverId)

    -- Spieler auswählen (mit Touch-Liste)
    client.playerName = selectPlayer()

    if not client.playerName then
        error("Kein Spielername ausgewählt!")
    end

    print("Spieler ausgewählt: " .. client.playerName)

    -- Verbinde
    client.ui:showMessage("Verbinde...", nil, ui.COLORS.BTN_CALL)

    -- Versuche endlos mit Server zu verbinden
    local connected = false
    while not connected do
        network.send(client.serverId, network.MSG.JOIN, {
            playerName = client.playerName
        })

        -- Warte auf Willkommen
        local senderId, data = network.waitFor(network.MSG.WELCOME, 5, client.serverId)

        if senderId then
            client.playerId = data.playerId
            client.connected = true
            connected = true
            print("Verbunden! ID: " .. client.playerId)
            client.ui:showMessage("Verbunden!", 2, ui.COLORS.BTN_CALL)
        else
            print("Keine Antwort, versuche erneut...")
            client.ui:showMessage("Verbinde...\nVersuche erneut...", nil, ui.COLORS.BTN_CHECK)
            sleep(2)
        end
    end
end

-- Findet eigene Position in Spieler-Liste
local function getMyPlayerIndex()
    if not client.gameState or not client.gameState.players then return nil end

    for i, player in ipairs(client.gameState.players) do
        if player.id == client.playerId then
            return i
        end
    end
    return nil
end

-- Berechnet Spieler-Position am Tisch (relativ zu eigenem Platz)
local function getPlayerTablePosition(playerIndex)
    local myIndex = getMyPlayerIndex()
    if not myIndex then return nil end

    -- Eigene Position ist immer unten (Position 4)
    -- Andere Spieler werden relativ platziert
    local totalPlayers = #client.gameState.players

    if playerIndex == myIndex then
        return 4  -- Unten (eigene Position)
    end

    local offset = (playerIndex - myIndex + totalPlayers) % totalPlayers

    if totalPlayers == 2 then
        return 2  -- Oben
    elseif totalPlayers == 3 then
        if offset == 1 then return 1 end  -- Links
        if offset == 2 then return 2 end  -- Oben
    else  -- 4 Spieler
        if offset == 1 then return 1 end  -- Links
        if offset == 2 then return 2 end  -- Oben
        if offset == 3 then return 3 end  -- Rechts
    end

    return nil
end

-- Zeichnet kompletten Poker-Tisch
local function drawPokerTable()
    if not client.gameState then return end

    -- Tisch-Hintergrund
    client.ui:drawPokerTable()

    local state = client.gameState

    -- Community Cards
    client.ui:drawCommunityCards(state.communityCards, state.round)

    -- Pot
    if state.pot and state.pot > 0 then
        client.ui:drawPot(state.pot)
    end

    -- Zeichne alle Spieler
    for i, player in ipairs(state.players) do
        local tablePos = getPlayerTablePosition(i)
        if tablePos then
            local isMe = player.id == client.playerId
            local isActive = i == state.currentPlayerIndex
            local isDealer = i == state.dealerIndex
            local isSmallBlind = i == ((state.dealerIndex % #state.players) + 1)
            local isBigBlind = i == (((state.dealerIndex + 1) % #state.players) + 1)

            client.ui:drawPlayerBox(
                tablePos,
                player,
                isDealer,
                isSmallBlind,
                isBigBlind,
                isActive,
                isMe
            )
        end
    end

    -- Eigene Karten (groß unten)
    if client.myCards and #client.myCards == 2 then
        client.ui:drawOwnCards(client.myCards)

        -- Hand-Evaluation (wenn genug Community Cards)
        if state.communityCards and #state.communityCards >= 3 then
            local allCards = {}
            for _, card in ipairs(client.myCards) do
                table.insert(allCards, card)
            end
            for _, card in ipairs(state.communityCards) do
                table.insert(allCards, card)
            end

            local hand = poker.evaluateHand(allCards)
            client.ui:drawHandEvaluation(hand.name)
        end
    end
end

-- Zeichnet Lobby-Screen
local function drawLobby()
    client.ui:drawPokerTable()

    -- Titel
    local y = math.floor(client.ui.height / 2) - 8
    client.ui:drawCenteredText(y, "=== POKER LOBBY ===", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)

    -- Spieler-Info
    y = y + 2
    client.ui:drawCenteredText(y, "Spieler: " .. client.playerName, ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

    -- Chips
    y = y + 1
    local chips = countChips()
    client.ui:drawCenteredText(y, "Chips: " .. chips, ui.COLORS.CHIPS_GREEN, ui.COLORS.TABLE_FELT)

    -- Status
    if client.gameState then
        local playerCount = #client.gameState.players
        y = y + 2
        client.ui:drawCenteredText(y, "Spieler: " .. playerCount .. "/4", ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

        -- Spieler-Liste
        y = y + 2
        for _, player in ipairs(client.gameState.players) do
            local status = player.ready and "[BEREIT]" or "[WARTEN]"
            local color = player.ready and ui.COLORS.TEXT_GREEN or ui.COLORS.TEXT_RED
            client.ui:drawCenteredText(y, player.name .. " " .. status, color, ui.COLORS.TABLE_FELT)
            y = y + 1
        end
    end

    -- Ready Button
    if not client.ready then
        local btnWidth = 25
        local btnHeight = 3
        local btnX = math.floor((client.ui.width - btnWidth) / 2)
        local btnY = client.ui.height - 6

        client.ui:addButton("ready", btnX, btnY, btnWidth, btnHeight, "BEREIT", function()
            client.ready = true
            network.send(client.serverId, network.MSG.READY, {ready = true})
            client.ui:setButtonEnabled("ready", false)
            client.ui:showMessage("Warte auf andere...", 2, ui.COLORS.BTN_CHECK)
            drawLobby()
        end, ui.COLORS.BTN_CALL)
    else
        local y = client.ui.height - 4
        client.ui:drawCenteredText(y, "[WARTE AUF ANDERE...]", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
    end
end

-- Zeichnet Aktions-Buttons
local function drawActionButtons(canCheck, currentBet, myBet, myChips)
    -- Entferne alte Buttons
    client.ui:clearButtons()

    local btnY = client.ui.height - 2
    local btnWidth = math.floor((client.ui.width - 15) / 5)
    local btnHeight = 2

    local spacing = 2
    local totalWidth = btnWidth * 5 + spacing * 4
    local startX = math.floor((client.ui.width - totalWidth) / 2)

    -- Fold
    client.ui:addButton("fold", startX, btnY, btnWidth, btnHeight, "FOLD", function()
        network.send(client.serverId, network.MSG.ACTION, {action = "fold"})
        client.ui:clearButtons()
        drawPokerTable()
    end, ui.COLORS.BTN_FOLD)

    -- Check/Call
    if canCheck then
        client.ui:addButton("check", startX + btnWidth + spacing, btnY, btnWidth, btnHeight, "CHECK", function()
            network.send(client.serverId, network.MSG.ACTION, {action = "check"})
            client.ui:clearButtons()
            drawPokerTable()
        end, ui.COLORS.BTN_CHECK)
    else
        local callAmount = currentBet - myBet
        if callAmount <= myChips then
            local text = "CALL"
            if callAmount > 0 then
                text = "CALL " .. callAmount
                if #text > btnWidth then text = "CALL" end
            end

            client.ui:addButton("call", startX + btnWidth + spacing, btnY, btnWidth, btnHeight, text, function()
                network.send(client.serverId, network.MSG.ACTION, {action = "call"})
                client.ui:clearButtons()
                drawPokerTable()
            end, ui.COLORS.BTN_CALL)
        end
    end

    -- Raise
    if myChips > (currentBet - myBet) then
        client.ui:addButton("raise", startX + (btnWidth + spacing) * 2, btnY, btnWidth, btnHeight, "RAISE", function()
            -- Zeige Raise-Dialog
            local minRaise = (currentBet - myBet) + 20
            local maxRaise = myChips
            local pot = client.gameState.pot or 0

            drawPokerTable()  -- Redraw vor Dialog
            local result = client.ui:showRaiseInput(minRaise, maxRaise, pot)

            if result.action == "raise" then
                network.send(client.serverId, network.MSG.ACTION, {action = "raise", amount = result.amount})
            elseif result.action == "all-in" then
                network.send(client.serverId, network.MSG.ACTION, {action = "all-in"})
            end

            client.ui:clearButtons()
            drawPokerTable()
        end, ui.COLORS.BTN_RAISE)
    else
        -- Disabled Raise
        client.ui:addButton("raise_disabled", startX + (btnWidth + spacing) * 2, btnY, btnWidth, btnHeight, "RAISE", nil, ui.COLORS.BTN_DISABLED, false)
    end

    -- All-In
    if myChips > 0 then
        client.ui:addButton("allin", startX + (btnWidth + spacing) * 3, btnY, btnWidth, btnHeight, "ALL-IN", function()
            network.send(client.serverId, network.MSG.ACTION, {action = "all-in"})
            client.ui:clearButtons()
            drawPokerTable()
        end, ui.COLORS.BTN_ALLIN)
    else
        client.ui:addButton("allin_disabled", startX + (btnWidth + spacing) * 3, btnY, btnWidth, btnHeight, "ALL-IN", nil, ui.COLORS.BTN_DISABLED, false)
    end

    -- Info Button
    client.ui:addButton("info", startX + (btnWidth + spacing) * 4, btnY, btnWidth, btnHeight, "INFO", function()
        local info = "Pot: " .. (client.gameState.pot or 0) .. "\n"
        info = info .. "Current Bet: " .. currentBet .. "\n"
        info = info .. "Your Bet: " .. myBet .. "\n"
        info = info .. "Your Chips: " .. myChips
        client.ui:showMessage(info, 3, ui.COLORS.PANEL)
        drawPokerTable()
        drawActionButtons(canCheck, currentBet, myBet, myChips)
    end, ui.COLORS.PANEL)
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
        drawPokerTable()
    end
end

-- Behandelt "Your Turn"
local function handleYourTurn(data)
    client.ui:showMessage("DU BIST DRAN!", 1, ui.COLORS.ACTIVE)

    -- Finde eigene Spieler-Daten
    local myPlayer = nil
    for _, player in ipairs(client.gameState.players) do
        if player.id == client.playerId then
            myPlayer = player
            break
        end
    end

    if myPlayer then
        drawPokerTable()
        drawActionButtons(
            data.canCheck,
            data.currentBet,
            myPlayer.bet,
            myPlayer.chips
        )

        -- Starte Timer
        client.ui:startTimer(config.turnTimeout or 60)
    end
end

-- Behandelt Runden-Ende
local function handleRoundEnd(data)
    -- Stoppt Timer
    client.ui:stopTimer()

    drawPokerTable()

    -- Zeige Gewinner
    local winnerNames = {}
    for _, winnerId in ipairs(data.winners) do
        for _, player in ipairs(client.gameState.players) do
            if player.id == winnerId then
                table.insert(winnerNames, player.name)
            end
        end
    end

    local message = "=== GEWINNER ===\n"
    message = message .. table.concat(winnerNames, ", ") .. "\n"
    if data.winningHand then
        message = message .. data.winningHand .. "\n"
    end
    message = message .. "Pot: " .. data.pot .. " chips"

    client.ui:showMessage(message, 5, ui.COLORS.BTN_CALL, true)

    client.ready = false
    client.ui:clearButtons()
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
                    client.ui:showMessage("Spiel startet!", 2, ui.COLORS.BTN_CALL)
                    drawPokerTable()

                elseif msgType == network.MSG.PLAYER_JOINED then
                    print("Spieler beigetreten: " .. data.playerName)
                    if client.gameState and client.gameState.round == "waiting" then
                        drawLobby()
                    end

                elseif msgType == network.MSG.PLAYER_LEFT then
                    print("Spieler verlassen: " .. data.playerName)
                    if client.gameState and client.gameState.round == "waiting" then
                        drawLobby()
                    end

                elseif msgType == network.MSG.ERROR then
                    client.ui:showMessage("FEHLER: " .. data.message, 3, ui.COLORS.BTN_FOLD)
                    if client.gameState then
                        if client.gameState.round == "waiting" then
                            drawLobby()
                        else
                            drawPokerTable()
                        end
                    end
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

-- Timer Update Loop
local function timerLoop()
    while true do
        if client.ui and client.ui.timerActive then
            client.ui:updateTimer()
        end
        sleep(0.5)
    end
end

-- Hauptprogramm
local function main()
    print("=== Professional Poker Client ===")

    -- Initialisiere
    findPeripherals()

    -- Netzwerk
    network.init(false)

    -- Verbinde zu Server
    connectToServer()

    -- Zeige Lobby
    drawLobby()

    -- Starte parallel: Events, Heartbeat, Timer
    parallel.waitForAny(
        handleEvents,
        heartbeat,
        timerLoop
    )
end

-- Fehlerbehandlung
local success, err = pcall(main)
if not success then
    if client.ui then
        client.ui:clear(ui.COLORS.BG)
        client.ui:showMessage("FEHLER:\n" .. tostring(err), 5, ui.COLORS.BTN_FOLD)
    end
    print("FEHLER: " .. tostring(err))
    network.close()
end
