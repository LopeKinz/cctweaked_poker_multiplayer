-- server.lua - Poker Server
local poker = require("lib.poker")
local network = require("lib.network")

-- Konfiguration
local config = {
    minPlayers = 2,  -- Mindestens 2 Spieler
    maxPlayers = 4,
    smallBlind = 10,
    bigBlind = 20,
    startingChips = 1000,
    turnTimeout = 60
}

-- Spielleiter (erster Spieler der beitritt)
local gameMaster = nil

-- Spielstatus
local game = {
    players = {},
    activePlayers = {},
    deck = {},
    communityCards = {},
    pot = 0,
    currentBet = 0,
    dealerIndex = 1,
    currentPlayerIndex = 1,
    round = "waiting", -- waiting, preflop, flop, turn, river, showdown
    roundBets = {}
}

-- Forward declarations
local startGame
local placeBet
local broadcastGameState
local nextPlayer
local startBettingRound
local handlePlayerAction
local endBettingRound
local endHand
local isBettingRoundComplete

-- Fügt Spieler hinzu
local function addPlayer(clientId, playerName, initialChips)
    if #game.players >= config.maxPlayers then
        network.send(clientId, network.MSG.ERROR, {message = "Spiel ist voll"})
        return false
    end

    -- Prüfe ob Spieler bereits existiert
    for _, player in ipairs(game.players) do
        if player.id == clientId then
            network.send(clientId, network.MSG.ERROR, {message = "Bereits verbunden"})
            return false
        end
    end

    -- Verwende Client-Chips falls vorhanden, sonst Standardwert
    local startChips = initialChips or config.startingChips

    local player = {
        id = clientId,
        name = playerName,
        chips = startChips,
        cards = {},
        bet = 0,
        folded = false,
        allIn = false,
        ready = false,
        connected = true
    }

    table.insert(game.players, player)

    -- Erster NICHT-Zuschauer wird Spielleiter
    -- Zuschauer (Name beginnt mit "Zuschauer_") können kein Spielleiter sein
    local isSpectator = playerName:match("^Zuschauer_") ~= nil

    if not gameMaster and not isSpectator then
        gameMaster = clientId
        print("Spieler " .. playerName .. " ist jetzt SPIELLEITER (" .. clientId .. ")")
    elseif isSpectator then
        print("Zuschauer " .. playerName .. " beigetreten (" .. clientId .. ")")
    else
        print("Spieler " .. playerName .. " beigetreten (" .. clientId .. ")")
    end

    -- Sende Willkommensnachricht
    network.send(clientId, network.MSG.WELCOME, {
        playerId = clientId,
        playerCount = #game.players,
        config = config,
        isGameMaster = (clientId == gameMaster)
    })

    -- Benachrichtige andere Spieler
    for _, p in ipairs(game.players) do
        if p.id ~= clientId then
            network.send(p.id, network.MSG.PLAYER_JOINED, {
                playerId = clientId,
                playerName = playerName,
                playerCount = #game.players
            })
        end
    end

    -- Broadcast aktuellen Spielstatus an alle (damit Lobby aktualisiert wird)
    broadcastGameState()

    return true
end

-- Entfernt Spieler
local function removePlayer(clientId)
    -- Finde den Spieler
    local playerIndex = nil
    local playerData = nil
    for i, player in ipairs(game.players) do
        if player.id == clientId then
            playerIndex = i
            playerData = player
            break
        end
    end

    if not playerData then
        return false
    end

    -- Prüfe ob Spieler Spielleiter ist
    local isGameMaster = (clientId == gameMaster)
    local isSpectator = playerData.name:match("^Zuschauer_") ~= nil

    if isGameMaster then
        -- Zähle andere Nicht-Zuschauer Spieler
        local otherNonSpectators = 0
        for _, p in ipairs(game.players) do
            if p.id ~= clientId then
                local pIsSpectator = p.name:match("^Zuschauer_") ~= nil
                if not pIsSpectator then
                    otherNonSpectators = otherNonSpectators + 1
                end
            end
        end

        -- Spielleiter kann nur verlassen wenn keine anderen Spieler da sind
        if otherNonSpectators > 0 then
            network.send(clientId, network.MSG.ERROR, {
                message = "Spielleiter kann nur verlassen wenn alle anderen Spieler das Spiel verlassen haben!"
            })
            return false
        end
    end

    -- Entferne Spieler
    table.remove(game.players, playerIndex)
    print("Spieler " .. playerData.name .. " hat verlassen")

    -- KRITISCH: Auch aus activePlayers entfernen falls Spiel läuft
    if game.round ~= "waiting" and game.activePlayers then
        for i = #game.activePlayers, 1, -1 do
            if game.activePlayers[i].id == clientId then
                table.remove(game.activePlayers, i)
                print("Spieler aus activePlayers entfernt")

                -- Wenn Dealer entfernt wurde, passe dealerIndex an
                if i <= game.dealerIndex then
                    game.dealerIndex = math.max(1, game.dealerIndex - 1)
                end

                -- Wenn current player entfernt wurde, passe an
                if i <= game.currentPlayerIndex then
                    game.currentPlayerIndex = math.max(1, game.currentPlayerIndex - 1)
                end
                break
            end
        end

        -- Prüfe ob genug Spieler übrig sind
        if #game.activePlayers < config.minPlayers then
            print("Nicht genug Spieler - beende Spiel")
            game.round = "waiting"
            game.pot = 0
            game.currentBet = 0
            game.communityCards = {}
        end
    end

    -- Benachrichtige andere
    for _, p in ipairs(game.players) do
        network.send(p.id, network.MSG.PLAYER_LEFT, {
            playerId = clientId,
            playerName = playerData.name
        })
    end

    -- Wenn Spielleiter verlassen hat und noch Spieler da sind, wähle neuen Spielleiter
    if isGameMaster and #game.players > 0 then
        -- Finde ersten Nicht-Zuschauer
        for _, p in ipairs(game.players) do
            local pIsSpectator = p.name:match("^Zuschauer_") ~= nil
            if not pIsSpectator then
                gameMaster = p.id
                print("Neuer Spielleiter: " .. p.name .. " (" .. p.id .. ")")
                break
            end
        end

        -- Falls alle Zuschauer sind, setze ersten als Spielleiter
        if not gameMaster and #game.players > 0 then
            gameMaster = game.players[1].id
            print("Neuer Spielleiter (Zuschauer): " .. game.players[1].name)
        end
    end

    -- Wenn keine Spieler mehr da sind, setze Spielleiter zurück
    if #game.players == 0 then
        gameMaster = nil
        print("Alle Spieler haben verlassen")
    end

    -- Broadcast aktuellen Spielstatus an alle
    broadcastGameState()

    return true
end

-- Findet Spieler nach ID
local function getPlayer(clientId)
    for _, player in ipairs(game.players) do
        if player.id == clientId then
            return player
        end
    end
    return nil
end

-- Setzt Spieler als bereit (nur Spielleiter darf starten)
local function setPlayerReady(clientId, ready)
    -- Nur Spielleiter darf das Spiel starten
    if clientId ~= gameMaster then
        network.send(clientId, network.MSG.ERROR, {message = "Nur der Spielleiter kann das Spiel starten!"})
        return
    end

    -- Prüfe ob mindestens 2 Spieler da sind
    if #game.players < config.minPlayers then
        network.send(clientId, network.MSG.ERROR, {message = "Mindestens " .. config.minPlayers .. " Spieler benötigt!"})
        return
    end

    print("Spielleiter startet das Spiel mit " .. #game.players .. " Spielern")

    -- Alle Spieler als bereit markieren
    for _, p in ipairs(game.players) do
        p.ready = true
    end

    -- Starte Spiel
    startGame()
end

-- Mischt und verteilt Karten
local function dealCards()
    game.deck = poker.createDeck()
    poker.shuffleDeck(game.deck)
    game.communityCards = {}

    -- Verteile 2 Karten an jeden Spieler
    for _, player in ipairs(game.activePlayers) do
        player.cards = {
            poker.drawCard(game.deck),
            poker.drawCard(game.deck)
        }
    end
end

-- Startet neue Runde
startGame = function()
    print("=== Starte neues Spiel ===")

    -- Reset Spielstatus
    game.activePlayers = {}
    for _, player in ipairs(game.players) do
        -- Zuschauer (Name beginnt mit "Zuschauer_") werden übersprungen
        local isSpectator = player.name:match("^Zuschauer_") ~= nil
        if player.chips > 0 and not isSpectator then
            player.folded = false
            player.allIn = false
            player.bet = 0
            player.cards = {}
            table.insert(game.activePlayers, player)
        end
    end

    if #game.activePlayers < config.minPlayers then
        print("Nicht genug Spieler mit Chips!")
        return
    end

    game.pot = 0
    game.currentBet = 0
    game.round = "preflop"
    game.roundBets = {}

    -- Dealer Button rotieren
    game.dealerIndex = (game.dealerIndex % #game.activePlayers) + 1

    -- Karten verteilen
    dealCards()

    -- Blinds setzen
    local smallBlindPlayer = game.activePlayers[(game.dealerIndex % #game.activePlayers) + 1]
    local bigBlindPlayer = game.activePlayers[((game.dealerIndex + 1) % #game.activePlayers) + 1]

    placeBet(smallBlindPlayer, config.smallBlind)
    placeBet(bigBlindPlayer, config.bigBlind)

    game.currentBet = config.bigBlind

    -- Benachrichtige Clients über Spielstart
    print("Sende GAME_START an alle Clients...")
    for _, player in ipairs(game.players) do
        network.send(player.id, network.MSG.GAME_START, {})
    end

    -- Kurze Pause damit alle Clients GAME_START verarbeiten können
    sleep(0.5)

    -- Sende aktuellen Spielstatus
    broadcastGameState()

    -- Starte erste Wettrunde
    game.currentPlayerIndex = ((game.dealerIndex + 2) % #game.activePlayers) + 1
    startBettingRound()
end

-- Platziert Einsatz
placeBet = function(player, amount)
    local actualBet = math.min(amount, player.chips)
    player.chips = player.chips - actualBet
    player.bet = player.bet + actualBet
    game.pot = game.pot + actualBet

    if player.chips == 0 then
        player.allIn = true
    end

    return actualBet
end

-- Startet Wettrunde
startBettingRound = function()
    print("=== Wettrunde: " .. game.round .. " ===")

    -- SICHERHEIT: Prüfe ob activePlayers leer ist
    if not game.activePlayers or #game.activePlayers == 0 then
        print("FEHLER: Keine aktiven Spieler!")
        game.round = "waiting"
        broadcastGameState()
        return
    end

    -- SICHERHEIT: Prüfe Index-Bounds
    if game.currentPlayerIndex < 1 or game.currentPlayerIndex > #game.activePlayers then
        print("FEHLER: Ungültiger currentPlayerIndex: " .. game.currentPlayerIndex)
        game.currentPlayerIndex = 1
    end

    -- Sende aktuellem Spieler "Your Turn"
    local currentPlayer = game.activePlayers[game.currentPlayerIndex]
    if not currentPlayer then
        print("FEHLER: Kein Spieler bei Index " .. game.currentPlayerIndex)
        endBettingRound()
        return
    end

    network.send(currentPlayer.id, network.MSG.YOUR_TURN, {
        currentBet = game.currentBet,
        minRaise = config.bigBlind,
        canCheck = currentPlayer.bet >= game.currentBet
    })

    -- Starte Timer
    local timeoutTimer = os.startTimer(config.turnTimeout)

    -- Warte auf Aktion
    while true do
        local event, param1, param2 = os.pullEvent()

        if event == "timer" and param1 == timeoutTimer then
            -- Timeout - automatisch fold
            print("Timeout für " .. currentPlayer.name)
            handlePlayerAction(currentPlayer.id, "fold", 0)
            break
        elseif event == "rednet_message" then
            local senderId = param1
            local message = param2

            if message.type == network.MSG.ACTION and senderId == currentPlayer.id then
                os.cancelTimer(timeoutTimer)
                local action = message.data.action
                local amount = message.data.amount or 0
                handlePlayerAction(senderId, action, amount)
                break
            end
        end
    end
end

-- Verarbeitet Spieler-Aktion
handlePlayerAction = function(clientId, action, amount)
    local player = getPlayer(clientId)
    if not player then return end

    print(player.name .. " -> " .. action .. " (" .. amount .. ")")

    if action == "fold" then
        player.folded = true

    elseif action == "check" then
        -- Nichts tun

    elseif action == "call" then
        local callAmount = game.currentBet - player.bet
        placeBet(player, callAmount)

    elseif action == "raise" then
        local raiseAmount = game.currentBet - player.bet + amount
        placeBet(player, raiseAmount)
        game.currentBet = player.bet

    elseif action == "all-in" then
        local allInAmount = player.chips
        placeBet(player, allInAmount)
        if player.bet > game.currentBet then
            game.currentBet = player.bet
        end
    end

    game.roundBets[player.id] = player.bet

    -- Broadcast State
    broadcastGameState()

    -- Nächster Spieler oder Runde beenden
    nextPlayer()
end

-- Nächster Spieler
nextPlayer = function()
    -- SICHERHEIT: Prüfe ob activePlayers leer ist (Division durch Null!)
    if not game.activePlayers or #game.activePlayers == 0 then
        print("FEHLER: Keine aktiven Spieler in nextPlayer!")
        game.round = "waiting"
        broadcastGameState()
        return
    end

    local startIndex = game.currentPlayerIndex

    repeat
        game.currentPlayerIndex = (game.currentPlayerIndex % #game.activePlayers) + 1
        local currentPlayer = game.activePlayers[game.currentPlayerIndex]

        -- SICHERHEIT: Prüfe ob Spieler existiert
        if not currentPlayer then
            print("FEHLER: Kein Spieler bei Index " .. game.currentPlayerIndex)
            endBettingRound()
            return
        end

        -- Prüfe ob dieser Spieler noch aktiv ist
        if not currentPlayer.folded and not currentPlayer.allIn then
            -- Prüfe ob Wettrunde beendet ist
            if game.currentPlayerIndex == startIndex or isBettingRoundComplete() then
                endBettingRound()
                return
            else
                startBettingRound()
                return
            end
        end

    until game.currentPlayerIndex == startIndex

    -- Alle gefoldet oder all-in
    endBettingRound()
end

-- Prüft ob Wettrunde komplett ist
isBettingRoundComplete = function()
    for _, player in ipairs(game.activePlayers) do
        if not player.folded and not player.allIn then
            if player.bet < game.currentBet then
                return false
            end
        end
    end
    return true
end

-- Beendet Wettrunde
endBettingRound = function()
    print("=== Wettrunde beendet ===")

    -- Reset Einsätze
    for _, player in ipairs(game.activePlayers) do
        player.bet = 0
    end
    game.currentBet = 0
    game.roundBets = {}

    -- Nächste Phase
    if game.round == "preflop" then
        game.round = "flop"
        -- 3 Community Cards
        table.insert(game.communityCards, poker.drawCard(game.deck))
        table.insert(game.communityCards, poker.drawCard(game.deck))
        table.insert(game.communityCards, poker.drawCard(game.deck))
        broadcastGameState()
        sleep(2)
        game.currentPlayerIndex = game.dealerIndex
        nextPlayer()

    elseif game.round == "flop" then
        game.round = "turn"
        table.insert(game.communityCards, poker.drawCard(game.deck))
        broadcastGameState()
        sleep(2)
        game.currentPlayerIndex = game.dealerIndex
        nextPlayer()

    elseif game.round == "turn" then
        game.round = "river"
        table.insert(game.communityCards, poker.drawCard(game.deck))
        broadcastGameState()
        sleep(2)
        game.currentPlayerIndex = game.dealerIndex
        nextPlayer()

    elseif game.round == "river" then
        game.round = "showdown"
        endHand()
    end
end

-- Beendet Hand (Showdown)
endHand = function()
    print("=== Showdown ===")

    -- Zähle aktive Spieler
    local activePlayers = {}
    for _, player in ipairs(game.activePlayers) do
        if not player.folded then
            table.insert(activePlayers, player)
        end
    end

    if #activePlayers == 1 then
        -- Nur ein Spieler übrig
        local winner = activePlayers[1]
        winner.chips = winner.chips + game.pot
        print("Gewinner: " .. winner.name .. " (alle gefoldet)")

        -- Benachrichtige ALLE Spieler über das Rundenergebnis
        for _, player in ipairs(game.players) do
            network.send(player.id, network.MSG.ROUND_END, {
                winners = {winner.id},
                pot = game.pot,
                reason = "all_folded"
            })
        end

    else
        -- Bewerte Hände
        local hands = {}
        for _, player in ipairs(activePlayers) do
            local allCards = {}
            for _, card in ipairs(player.cards) do
                table.insert(allCards, card)
            end
            for _, card in ipairs(game.communityCards) do
                table.insert(allCards, card)
            end

            hands[player.id] = poker.evaluateHand(allCards)
            print(player.name .. ": " .. hands[player.id].name)
        end

        -- Finde Gewinner
        local winners, bestHand = poker.findWinners(hands)

        -- Verteile Pot
        local winAmount = math.floor(game.pot / #winners)
        for _, winnerId in ipairs(winners) do
            local winner = getPlayer(winnerId)
            winner.chips = winner.chips + winAmount
            print("Gewinner: " .. winner.name .. " mit " .. bestHand.name)
        end

        -- Benachrichtige alle
        for _, player in ipairs(game.players) do
            network.send(player.id, network.MSG.ROUND_END, {
                winners = winners,
                pot = game.pot,
                winningHand = bestHand.name,
                hands = hands
            })
        end
    end

    -- Warte kurz
    sleep(5)

    -- IMMER zurück zur Lobby nach einer Runde
    print("Runde beendet - zurueck zur Lobby")

    -- Sende GAME_END an alle
    for _, player in ipairs(game.players) do
        network.send(player.id, network.MSG.GAME_END, {
            message = "Runde beendet"
        })
    end

    -- Zurück zu Wartezustand
    game.round = "waiting"
    game.pot = 0
    game.currentBet = 0
    game.communityCards = {}

    -- Sende Update
    broadcastGameState()
end

-- Konvertiert activePlayers-Index zu players-Index
local function activeIndexToPlayerIndex(activeIndex)
    if not activeIndex or activeIndex < 1 or activeIndex > #game.activePlayers then
        return nil
    end

    local activePlayer = game.activePlayers[activeIndex]
    if not activePlayer then return nil end

    for i, player in ipairs(game.players) do
        if player.id == activePlayer.id then
            return i
        end
    end
    return nil
end

-- Broadcast Spielstatus
broadcastGameState = function()
    -- Berechne Blind-Positionen
    local smallBlindIndex = nil
    local bigBlindIndex = nil

    if game.round ~= "waiting" and #game.activePlayers >= 2 then
        local sbActiveIndex = (game.dealerIndex % #game.activePlayers) + 1
        local bbActiveIndex = ((game.dealerIndex + 1) % #game.activePlayers) + 1
        smallBlindIndex = activeIndexToPlayerIndex(sbActiveIndex)
        bigBlindIndex = activeIndexToPlayerIndex(bbActiveIndex)
    end

    local state = {
        round = game.round,
        pot = game.pot,
        currentBet = game.currentBet,
        communityCards = game.communityCards,
        dealerIndex = activeIndexToPlayerIndex(game.dealerIndex),
        currentPlayerIndex = activeIndexToPlayerIndex(game.currentPlayerIndex),
        smallBlindIndex = smallBlindIndex,
        bigBlindIndex = bigBlindIndex,
        gameMaster = gameMaster,
        players = {}
    }

    -- Füge Spieler-Infos hinzu (ohne Karten)
    for _, player in ipairs(game.players) do
        table.insert(state.players, {
            id = player.id,
            name = player.name,
            chips = player.chips,
            bet = player.bet,
            folded = player.folded,
            allIn = player.allIn,
            ready = player.ready
        })
    end

    -- Sende an alle Spieler
    for _, player in ipairs(game.players) do
        local playerState = {}
        for k, v in pairs(state) do
            playerState[k] = v
        end

        -- Füge eigene Karten hinzu
        playerState.myCards = player.cards

        network.send(player.id, network.MSG.GAME_STATE, playerState)
    end
end

-- Hauptschleife
local function main()
    print("=== Poker Server ===")
    print("Initialisiere Netzwerk...")

    network.init(true)
    print("Server gestartet!")
    print("Warte auf Spieler...")

    while true do
        local senderId, msgType, data = network.receive(1)

        if senderId and msgType then
            if msgType == network.MSG.JOIN then
                addPlayer(senderId, data.playerName, data.chips)

            elseif msgType == network.MSG.READY then
                setPlayerReady(senderId, data.ready)

            elseif msgType == network.MSG.LEAVE then
                removePlayer(senderId)

            elseif msgType == network.MSG.PING then
                network.send(senderId, network.MSG.PONG, {})
            end
        end
    end
end

-- Fehlerbehandlung mit Auto-Reboot
while true do
    local success, err = pcall(main)

    if not success then
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
