-- client.lua - Professional Poker Client mit Touch-UI
local poker = require("lib.poker")
local network = require("lib.network")
local ui = require("lib.ui")
local bank = require("lib.bank")

-- Konfiguration
local config = {
    playerDetectorSide = "left",
    chestSide = "front",
    rsBridgeSide = "right",
    useBank = false,
    chipItem = "minecraft:diamond",  -- 1 Diamant = 1 Chip
    serverTimeout = 10,
    turnTimeout = 60  -- Sekunden für Spieler-Turn
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
    bankManager = nil,  -- Bank-Manager wenn useBank = true
    connected = false,
    ready = false,
    myPosition = nil,  -- Position am Tisch (1-4)
    isGameMaster = false,  -- Ist dieser Client der Spielleiter?
    isSpectator = false,  -- Ist dieser Client Zuschauer?
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

    -- RS Bridge und Bank-System (optional)
    if config.useBank then
        client.rsbridge = peripheral.find("rs_bridge") or
                         peripheral.wrap(config.rsBridgeSide)
        if client.rsbridge and client.chest then
            print("RS Bridge gefunden")

            -- Initialisiere Bank-Manager
            client.bankManager = bank.createManager(config.rsBridgeSide, config.chestSide)

            if client.bankManager then
                print("Bank-System aktiviert!")
                print("Chip-Item: " .. (client.bankManager.chipItem or config.chipItem))

                -- Setze Chip-Item falls nicht auto-erkannt
                if not client.bankManager.chipItem then
                    client.bankManager.chipItem = config.chipItem
                end
            else
                print("WARNUNG: Bank-Manager konnte nicht erstellt werden")
                config.useBank = false
            end
        else
            print("WARNUNG: RS Bridge oder Truhe nicht gefunden (Bank deaktiviert)")
            config.useBank = false
        end
    end
end

-- Zählt Chips in Truhe (oder ME System wenn useBank = true)
local function countChips()
    if config.useBank and client.bankManager then
        -- Zähle aus ME System + Truhe
        local meBalance = client.bankManager:getBalance()
        local chestChips = 0

        if client.chest then
            for slot = 1, client.chest.size() do
                local item = client.chest.getItemDetail(slot)
                if item and item.name == config.chipItem then
                    chestChips = chestChips + item.count
                end
            end
        end

        return meBalance + chestChips
    else
        -- Standard: Zähle nur in Truhe
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
end

-- Synchronisiert Chips mit Bank-System
local function syncChipsWithBank(targetChips)
    if not config.useBank or not client.bankManager then
        return
    end

    print("Synchronisiere Chips mit Bank...")
    print("Ziel: " .. targetChips .. " Chips")

    -- Synchronisiere
    local success, result = client.bankManager:sync(targetChips)

    if success then
        print("Chips synchronisiert: " .. (result or 0) .. " transferiert")
    else
        print("WARNUNG: Chip-Sync fehlgeschlagen: " .. tostring(result))
    end
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
    while true do
        print("Erkenne Spieler in der Nähe...")

        local players = detectPlayer()

        if not players or #players == 0 then
            -- Keine Spieler erkannt - trotzdem Auswahhliste zeigen
            print("Keine Spieler erkannt")
            client.ui:showMessage("Keine Spieler in Reichweite!\nErneut scannen möglich", 2, ui.COLORS.BTN_CHECK)
        else
            -- Spieler erkannt - Info anzeigen
            print("Spieler erkannt: " .. #players)
            client.ui:showMessage("Spieler erkannt: " .. #players .. "\nWähle deinen Namen", 2, ui.COLORS.BTN_CALL)
        end

        -- IMMER Auswahlliste zeigen (auch bei 0 oder 1 Spieler)
        -- Nutzer kann auch bewusst "Zuschauer werden" oder erneut scannen
        local selectedName = client.ui:showPlayerSelection(players or {})

        -- Wenn "__RESCAN__" zurückgegeben wird, scanne erneut
        if selectedName == "__RESCAN__" then
            print("Scanne erneut...")
            client.ui:showMessage("Scanne erneut...", 1, ui.COLORS.BTN_CHECK)
            -- Loop continues
        else
            -- Gültiger Name ausgewählt
            return selectedName
        end
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
            client.isGameMaster = data.isGameMaster or false
            connected = true

            if client.isGameMaster then
                print("Verbunden! ID: " .. client.playerId .. " (SPIELLEITER)")
                client.ui:showMessage("Verbunden!\nDu bist SPIELLEITER!", 2, ui.COLORS.BTN_CALL)
            else
                print("Verbunden! ID: " .. client.playerId)
                client.ui:showMessage("Verbunden!", 2, ui.COLORS.BTN_CALL)
            end
        else
            print("Keine Antwort, versuche erneut...")
            client.ui:showMessage("Verbinde...\nVersuche erneut...", nil, ui.COLORS.BTN_CHECK)
            sleep(2)
        end
    end
end

-- Findet eigene Position in Spieler-Liste
local function getMyPlayerIndex()
    if not client.playerId or not client.gameState or not client.gameState.players then
        return nil
    end

    for i, player in ipairs(client.gameState.players) do
        if player.id == client.playerId then
            return i
        end
    end
    return nil
end

-- Berechnet Spieler-Position am Tisch (relativ zu eigenem Platz)
local function getPlayerTablePosition(playerIndex)
    if not playerIndex then return nil end

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

    -- Prüfe ob Zuschauer (Name beginnt mit "Zuschauer_")
    client.isSpectator = (client.playerName ~= nil and client.playerName:match("^Zuschauer_") ~= nil)

    -- Zuschauer-Overlay
    if client.isSpectator then
        local y = 2
        local width = 30
        local x = math.floor((client.ui.width - width) / 2)
        client.ui:drawBox(x, y, width, 3, ui.COLORS.POT_BG)
        client.ui:drawBorder(x, y, width, 3, ui.COLORS.TABLE_BORDER)
        client.ui:drawCenteredText(y + 1, "=== ZUSCHAUER ===", ui.COLORS.TEXT_YELLOW, ui.COLORS.POT_BG)
    end

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
            local isSmallBlind = i == state.smallBlindIndex
            local isBigBlind = i == state.bigBlindIndex

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

    -- Prüfe ob Zuschauer (Name beginnt mit "Zuschauer_")
    client.isSpectator = (client.playerName ~= nil and client.playerName:match("^Zuschauer_") ~= nil)
    local playerCount = client.gameState and #client.gameState.players or 0
    local myIndex = getMyPlayerIndex()

    -- Zuschauer-Modus
    if client.isSpectator then
        local y = math.floor(client.ui.height / 2) - 4
        client.ui:drawCenteredText(y, "===========================", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
        y = y + 1
        client.ui:drawCenteredText(y, "Z U S C H A U E R", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
        y = y + 1
        client.ui:drawCenteredText(y, "===========================", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
        y = y + 3
        client.ui:drawCenteredText(y, "Du schaust zu", ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)
        y = y + 1
        client.ui:drawCenteredText(y, "Maximale Spielerzahl erreicht", ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

        -- Verlassen Button für Zuschauer
        local btnWidth = 25
        local btnHeight = 3
        local btnX = math.floor((client.ui.width - btnWidth) / 2)
        local btnY = client.ui.height - 6

        client.ui:addButton("leave", btnX, btnY, btnWidth, btnHeight, "VERLASSEN", function()
            network.send(client.serverId, network.MSG.LEAVE, {})
            client.ui:showMessage("Verlasse Spiel...", 2, ui.COLORS.TEXT_WHITE)
            sleep(1)
            os.reboot()
        end, ui.COLORS.BTN_FOLD, true)

        return
    end

    -- Titel
    local y = math.floor(client.ui.height / 2) - 8
    client.ui:drawCenteredText(y, "=== POKER LOBBY ===", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)

    -- Spielleiter-Anzeige
    if client.isGameMaster then
        y = y + 1
        client.ui:drawCenteredText(y, "[SPIELLEITER]", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)
    end

    -- Spieler-Info
    y = y + 2
    client.ui:drawCenteredText(y, "Spieler: " .. client.playerName, ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

    -- Chips
    y = y + 1
    local chips = countChips()
    client.ui:drawCenteredText(y, "Chips: " .. chips, ui.COLORS.CHIPS_GREEN, ui.COLORS.TABLE_FELT)

    -- Status
    if client.gameState then
        y = y + 2
        client.ui:drawCenteredText(y, "Spieler: " .. playerCount .. "/4", ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)

        -- Spieler-Liste
        y = y + 2
        for i, player in ipairs(client.gameState.players) do
            if i <= 4 then  -- Nur erste 4 Spieler zeigen
                local nameText = player.name
                if player.id == client.gameState.gameMaster then
                    nameText = nameText .. " [LEITER]"
                end
                client.ui:drawCenteredText(y, nameText, ui.COLORS.TEXT_WHITE, ui.COLORS.TABLE_FELT)
                y = y + 1
            end
        end
    end

    -- Start Button (nur für Spielleiter)
    if client.isGameMaster then
        local btnWidth = 30
        local btnHeight = 3
        local btnX = math.floor((client.ui.width - btnWidth) / 2)
        local btnY = client.ui.height - 13

        local canStart = playerCount >= 2
        local btnText = canStart and "SPIEL STARTEN" or "Mindestens 2 Spieler"
        local btnColor = canStart and ui.COLORS.BTN_CALL or ui.COLORS.BTN_DISABLED

        client.ui:addButton("start", btnX, btnY, btnWidth, btnHeight, btnText, function()
            if canStart then
                network.send(client.serverId, network.MSG.READY, {ready = true})
                client.ui:clearButtons()
                client.ui:showMessage("Starte Spiel...\nWarte auf Server...", nil, ui.COLORS.BTN_CALL)
                -- Kein Timeout - warte bis GAME_STATE kommt
            end
        end, btnColor, canStart)

        -- Help Button
        btnY = btnY + btnHeight + 1
        client.ui:addButton("help", btnX, btnY, btnWidth, btnHeight, "HAND RANKINGS", function()
            client.ui:showHandRankings()
            drawLobby()
        end, ui.COLORS.BTN_CHECK, true)

        -- Verlassen Button für Spielleiter
        btnY = btnY + btnHeight + 1
        client.ui:addButton("leave", btnX, btnY, btnWidth, btnHeight, "VERLASSEN", function()
            network.send(client.serverId, network.MSG.LEAVE, {})
            client.ui:showMessage("Verlasse Spiel...", 2, ui.COLORS.TEXT_WHITE)
            sleep(1)
            os.reboot()
        end, ui.COLORS.BTN_FOLD, true)
    else
        -- Nicht-Spielleiter warten
        local y = client.ui.height - 13
        client.ui:drawCenteredText(y, "[WARTE AUF SPIELLEITER...]", ui.COLORS.TEXT_YELLOW, ui.COLORS.TABLE_FELT)

        -- Help Button für normale Spieler
        local btnWidth = 25
        local btnHeight = 3
        local btnX = math.floor((client.ui.width - btnWidth) / 2)
        local btnY = client.ui.height - 9

        client.ui:addButton("help", btnX, btnY, btnWidth, btnHeight, "HAND RANKINGS", function()
            client.ui:showHandRankings()
            drawLobby()
        end, ui.COLORS.BTN_CHECK, true)

        -- Verlassen Button für normale Spieler
        btnY = btnY + btnHeight + 1
        client.ui:addButton("leave", btnX, btnY, btnWidth, btnHeight, "VERLASSEN", function()
            network.send(client.serverId, network.MSG.LEAVE, {})
            client.ui:showMessage("Verlasse Spiel...", 2, ui.COLORS.TEXT_WHITE)
            sleep(1)
            os.reboot()
        end, ui.COLORS.BTN_FOLD, true)
    end
end

-- Zeichnet Aktions-Buttons
local function drawActionButtons(canCheck, currentBet, myBet, myChips, minRaise)
    -- Entferne alte Buttons
    client.ui:clearButtons()

    -- minRaise default (sollte vom Server kommen)
    minRaise = minRaise or 20

    local btnY = client.ui.height - 2
    local btnWidth = math.floor((client.ui.width - 18) / 6)
    local btnHeight = 2

    local spacing = 2
    local totalWidth = btnWidth * 6 + spacing * 5
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
    local callAmount = currentBet - myBet
    local raiseMinAmount = callAmount + minRaise
    if myChips >= raiseMinAmount then
        client.ui:addButton("raise", startX + (btnWidth + spacing) * 2, btnY, btnWidth, btnHeight, "RAISE", function()
            -- Zeige Raise-Dialog
            local minRaiseAmount = raiseMinAmount
            local maxRaise = myChips
            local pot = client.gameState.pot or 0

            drawPokerTable()  -- Redraw vor Dialog
            local result = client.ui:showRaiseInput(minRaiseAmount, maxRaise, pot)

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

    -- Help Button (Hand Rankings)
    client.ui:addButton("help", startX + (btnWidth + spacing) * 4, btnY, btnWidth, btnHeight, "HELP", function()
        client.ui:showHandRankings()
        drawPokerTable()
        drawActionButtons(canCheck, currentBet, myBet, myChips, minRaise)
    end, ui.COLORS.BTN_CHECK)

    -- Info Button
    client.ui:addButton("info", startX + (btnWidth + spacing) * 5, btnY, btnWidth, btnHeight, "INFO", function()
        local info = "Pot: " .. (client.gameState.pot or 0) .. "\n"
        info = info .. "Current Bet: " .. currentBet .. "\n"
        info = info .. "Your Bet: " .. myBet .. "\n"
        info = info .. "Your Chips: " .. myChips
        client.ui:showMessage(info, 3, ui.COLORS.PANEL)
        drawPokerTable()
        drawActionButtons(canCheck, currentBet, myBet, myChips, minRaise)
    end, ui.COLORS.PANEL)
end

-- Behandelt Spielstatus-Update
local function handleGameState(state)
    client.gameState = state

    if state.myCards then
        client.myCards = state.myCards
    end

    -- LIVE Chip-Sync: Verluste gehen SOFORT ins ME, Gewinne kommen SOFORT aus ME
    if config.useBank and client.playerId then
        for _, player in ipairs(state.players) do
            if player.id == client.playerId then
                syncChipsWithBank(player.chips)
                break
            end
        end
    end

    if state.round == "waiting" then
        drawLobby()
    else
        drawPokerTable()
    end
end

-- Behandelt "Your Turn"
local function handleYourTurn(data)
    -- Zuschauer bekommen keinen Turn
    if client.isSpectator then
        return
    end

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
            myPlayer.chips,
            data.minRaise
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

    -- LIVE Chip-Sync nach Runde: Gewinner bekommen Diamanten, Verlierer verlieren sie
    if config.useBank and client.playerId and client.gameState then
        for _, player in ipairs(client.gameState.players) do
            if player.id == client.playerId then
                syncChipsWithBank(player.chips)
                break
            end
        end
    end

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
                    -- Spiel startet
                    print("Game starting...")

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

                elseif msgType == network.MSG.GAME_END then
                    -- Spiel beendet - zurück zur Lobby
                    print("Spiel beendet - zurueck zur Lobby")
                    client.ui:stopTimer()
                    client.ui:clearButtons()
                    client.myCards = {}

                    -- Finale Synchronisierung (falls noch nicht durch GAME_STATE geschehen)
                    if config.useBank and client.playerId and client.gameState then
                        for _, player in ipairs(client.gameState.players) do
                            if player.id == client.playerId then
                                syncChipsWithBank(player.chips)
                                break
                            end
                        end
                    end

                    -- Warte kurz damit GAME_STATE ankommt
                    sleep(0.5)
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

-- Fehlerbehandlung mit Auto-Reboot
while true do
    local success, err = pcall(main)

    if not success then
        if client.ui then
            client.ui:clear(ui.COLORS.BG)
            client.ui:showMessage("FEHLER:\n" .. tostring(err) .. "\n\nNeustart in 30s...", nil, ui.COLORS.BTN_FOLD)
        end
        print("===================")
        print("FEHLER: " .. tostring(err))
        print("===================")
        print("Automatischer Neustart in 30 Sekunden...")
        network.close()

        -- 30 Sekunden Wartezeit
        sleep(30)

        print("Neustart...")
        os.reboot()
    else
        break
    end
end
