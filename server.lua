-- server.lua - Poker Server
local poker = require("lib.poker")
local network = require("lib.network")

-- Konfiguration
local config = {
    minPlayers = 2,
    maxPlayers = 4,
    smallBlind = 10,
    bigBlind = 20,
    startingChips = 1000,
    turnTimeout = 60
}

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

-- Fügt Spieler hinzu
local function addPlayer(clientId, playerName)
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

    local player = {
        id = clientId,
        name = playerName,
        chips = config.startingChips,
        cards = {},
        bet = 0,
        folded = false,
        allIn = false,
        ready = false,
        connected = true
    }

    table.insert(game.players, player)

    print("Spieler " .. playerName .. " beigetreten (" .. clientId .. ")")

    -- Sende Willkommensnachricht
    network.send(clientId, network.MSG.WELCOME, {
        playerId = clientId,
        playerCount = #game.players,
        config = config
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

    return true
end

-- Entfernt Spieler
local function removePlayer(clientId)
    for i, player in ipairs(game.players) do
        if player.id == clientId then
            table.remove(game.players, i)
            print("Spieler " .. player.name .. " hat verlassen")

            -- Benachrichtige andere
            for _, p in ipairs(game.players) do
                network.send(p.id, network.MSG.PLAYER_LEFT, {
                    playerId = clientId,
                    playerName = player.name
                })
            end

            return true
        end
    end
    return false
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

-- Setzt Spieler als bereit
local function setPlayerReady(clientId, ready)
    local player = getPlayer(clientId)
    if player then
        player.ready = ready
        print("Spieler " .. player.name .. " ist " .. (ready and "bereit" or "nicht bereit"))

        -- Prüfe ob genug Spieler bereit sind
        local readyCount = 0
        for _, p in ipairs(game.players) do
            if p.ready then
                readyCount = readyCount + 1
            end
        end

        if readyCount >= config.minPlayers and readyCount == #game.players then
            -- Starte Spiel
            startGame()
        end
    end
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
        if player.chips > 0 then
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

    -- Benachrichtige Clients
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

    -- Sende aktuellem Spieler "Your Turn"
    local currentPlayer = game.activePlayers[game.currentPlayerIndex]

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
    local startIndex = game.currentPlayerIndex

    repeat
        game.currentPlayerIndex = (game.currentPlayerIndex % #game.activePlayers) + 1
        local nextPlayer = game.activePlayers[game.currentPlayerIndex]

        -- Prüfe ob dieser Spieler noch aktiv ist
        if not nextPlayer.folded and not nextPlayer.allIn then
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
function isBettingRoundComplete()
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

        network.send(winner.id, network.MSG.ROUND_END, {
            winners = {winner.id},
            pot = game.pot,
            reason = "all_folded"
        })

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

    -- Prüfe ob Spiel weitergeht
    local playersWithChips = 0
    for _, player in ipairs(game.players) do
        if player.chips > 0 then
            playersWithChips = playersWithChips + 1
        end
    end

    if playersWithChips >= config.minPlayers then
        startGame()
    else
        print("Nicht genug Spieler mit Chips!")
        game.round = "waiting"
        broadcastGameState()
    end
end

-- Broadcast Spielstatus
broadcastGameState = function()
    local state = {
        round = game.round,
        pot = game.pot,
        currentBet = game.currentBet,
        communityCards = game.communityCards,
        dealerIndex = game.dealerIndex,
        currentPlayerIndex = game.currentPlayerIndex,
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
                addPlayer(senderId, data.playerName)

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

-- Fehlerbehandlung
local success, err = pcall(main)
if not success then
    print("FEHLER: " .. tostring(err))
    network.close()
end
