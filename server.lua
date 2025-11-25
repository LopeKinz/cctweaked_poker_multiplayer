--[[
Server-side controller for the multiplayer poker table. The original
implementation grew organically and mixed concerns (logging, validation,
configuration) across the file. The server now leans on shared runtime helpers
for consistent logging and safer error handling while keeping the gameplay
rules intact.
--]]

local poker = require("lib.poker")
local network = require("lib.network")
local runtime = require("lib.runtime")

local defaultConfig = {
    minPlayers = 2,  -- Mindestens 2 Spieler
    maxPlayers = 4,
    smallBlind = 10,
    bigBlind = 20,
    startingChips = 1000,
    turnTimeout = 60,
    -- Timing Constants
    gameStartDelay = 0.5,    -- Delay before game starts
    roundTransitionDelay = 2, -- Delay between rounds (flop/turn/river)
    showdownDelay = 5,        -- Delay after showdown
    errorRebootDelay = 30,    -- Delay before auto-reboot on error
    debug = false             -- Debug output
}

local configValidators = {
    {
        key = "minPlayers",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" then
                return defaults.minPlayers, "minPlayers muss eine Zahl sein"
            end

            value = math.max(2, math.floor(value))
            return value
        end
    },
    {
        key = "maxPlayers",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" then
                return defaults.maxPlayers, "maxPlayers muss eine Zahl sein"
            end

            value = math.floor(value)
            if value < (cfg.minPlayers or defaults.minPlayers) then
                return cfg.minPlayers or defaults.minPlayers, "maxPlayers darf nicht kleiner als minPlayers sein"
            end

            return value
        end
    },
    {
        key = "smallBlind",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" then
                return defaults.smallBlind, "smallBlind muss eine Zahl sein"
            end

            value = math.max(1, math.floor(value))
            return value
        end
    },
    {
        key = "bigBlind",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" then
                return defaults.bigBlind, "bigBlind muss eine Zahl sein"
            end

            value = math.max(cfg.smallBlind or defaults.smallBlind, math.floor(value))
            return value
        end
    },
    {
        key = "startingChips",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" then
                return defaults.startingChips, "startingChips muss eine Zahl sein"
            end

            value = math.max(cfg.bigBlind or defaults.bigBlind, math.floor(value))
            return value
        end
    },
    {
        key = "turnTimeout",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" or value <= 0 then
                return defaults.turnTimeout, "turnTimeout muss > 0 sein"
            end

            return value
        end
    },
    {
        key = "gameStartDelay",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" or value < 0 then
                return defaults.gameStartDelay, "gameStartDelay muss >= 0 sein"
            end

            return value
        end
    },
    {
        key = "roundTransitionDelay",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" or value < 0 then
                return defaults.roundTransitionDelay, "roundTransitionDelay muss >= 0 sein"
            end

            return value
        end
    },
    {
        key = "showdownDelay",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" or value < 0 then
                return defaults.showdownDelay, "showdownDelay muss >= 0 sein"
            end

            return value
        end
    },
    {
        key = "errorRebootDelay",
        validate = function(value, cfg, defaults)
            if type(value) ~= "number" or value < 0 then
                return defaults.errorRebootDelay, "errorRebootDelay muss >= 0 sein"
            end

            return value
        end
    },
    {
        key = "debug",
        validate = function(value, cfg, defaults)
            return value == true
        end
    }
}

local config = runtime.loadConfig(defaultConfig, "config.lua", configValidators)

-- Spielleiter (erster Spieler der beitritt)
local gameMaster = nil

-- Spielstatus
local game = {
    players = {},
    playerMap = {},  -- Hash map für schnellen Zugriff: id -> player
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

local function logDebug(...)
    runtime.debug(config.debug, ...)
end

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
    if not clientId or not playerName then
        runtime.warn("JOIN abgelehnt: fehlende Parameter von", tostring(clientId))
        return false
    end

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

    -- Verwende Client-Chips falls vorhanden, aber deckel auf Server-Config
    local startChips = tonumber(initialChips) or config.startingChips
    if startChips < 0 then
        runtime.warn("Startchips kleiner als 0 - setze auf Standardwert")
        startChips = config.startingChips
    elseif startChips > config.startingChips then
        runtime.warn("Startchips von", playerName, "auf", startChips, "begrenzt auf", config.startingChips)
        startChips = config.startingChips
    end

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
    game.playerMap[clientId] = player  -- Add to hash map for O(1) lookup

    -- Erster NICHT-Zuschauer wird Spielleiter
    -- Zuschauer (Name beginnt mit "Zuschauer_") können kein Spielleiter sein
    local isSpectator = playerName:match("^Zuschauer_") ~= nil

    if not gameMaster and not isSpectator then
        gameMaster = clientId
        runtime.info("Spieler", playerName, "ist jetzt SPIELLEITER (" .. clientId .. ")")
    elseif isSpectator then
        runtime.info("Zuschauer", playerName, "beigetreten (" .. clientId .. ")")
    else
        runtime.info("Spieler", playerName, "beigetreten (" .. clientId .. ")")
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
    game.playerMap[clientId] = nil  -- Remove from hash map
    runtime.info("Spieler", playerData.name, "hat verlassen")

    -- KRITISCH: Auch aus activePlayers entfernen falls Spiel läuft
    if game.round ~= "waiting" and game.activePlayers then
        for i = #game.activePlayers, 1, -1 do
            if game.activePlayers[i].id == clientId then
                table.remove(game.activePlayers, i)
                logDebug("Spieler aus activePlayers entfernt")

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
            runtime.warn("Nicht genug Spieler - beende Spiel")
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
                runtime.info("Neuer Spielleiter:", p.name .. " (" .. p.id .. ")")
                break
            end
        end

        -- Falls alle Zuschauer sind, setze ersten als Spielleiter
        if not gameMaster and #game.players > 0 then
            gameMaster = game.players[1].id
            runtime.info("Neuer Spielleiter (Zuschauer):", game.players[1].name)
        end
    end

    -- Wenn keine Spieler mehr da sind, setze Spielleiter zurück
    if #game.players == 0 then
        gameMaster = nil
        runtime.warn("Alle Spieler haben verlassen")
    end

    -- Broadcast aktuellen Spielstatus an alle
    broadcastGameState()

    return true
end

-- Findet Spieler nach ID (O(1) mit Hash Map)
local function getPlayer(clientId)
    return game.playerMap[clientId]
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

    runtime.info("Spielleiter startet das Spiel mit", #game.players, "Spielern")

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
    runtime.info("=== Starte neues Spiel ===")

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
        runtime.warn("Nicht genug Spieler mit Chips!")
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

    -- Setze currentBet auf den tatsächlich geposteten Big Blind (auch bei Short Stacks)
    game.currentBet = bigBlindPlayer.bet

    -- Benachrichtige Clients über Spielstart
    runtime.info("Sende GAME_START an alle Clients...")
    for _, player in ipairs(game.players) do
        network.send(player.id, network.MSG.GAME_START, {})
    end

    -- Kurze Pause damit alle Clients GAME_START verarbeiten können
    sleep(config.gameStartDelay)

    -- Setze ersten Spieler am Zug (nach Big Blind)
    game.currentPlayerIndex = ((game.dealerIndex + 2) % #game.activePlayers) + 1

    -- Sende aktuellen Spielstatus (mit richtigem currentPlayerIndex)
    broadcastGameState()

    -- Kurze Pause damit GAME_STATE beim Client ankommt
    sleep(config.gameStartDelay)

    -- Starte erste Wettrunde
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
    runtime.info("=== Wettrunde:", game.round, "===")

    logDebug("activePlayers count = " .. #game.activePlayers)
    logDebug("currentPlayerIndex = " .. game.currentPlayerIndex)

    -- SICHERHEIT: Prüfe ob activePlayers leer ist
    if not game.activePlayers or #game.activePlayers == 0 then
        runtime.error("Keine aktiven Spieler!")
        game.round = "waiting"
        broadcastGameState()
        return
    end

    -- SICHERHEIT: Prüfe Index-Bounds
    if game.currentPlayerIndex < 1 or game.currentPlayerIndex > #game.activePlayers then
        runtime.error("Ungültiger currentPlayerIndex:", game.currentPlayerIndex)
        game.currentPlayerIndex = 1
    end

    -- Sende aktuellem Spieler "Your Turn"
    local currentPlayer = game.activePlayers[game.currentPlayerIndex]
    if not currentPlayer then
        runtime.error("Kein Spieler bei Index", game.currentPlayerIndex)
        endBettingRound()
        return
    end

    logDebug("Sende YOUR_TURN an Spieler: " .. currentPlayer.name .. " (ID: " .. currentPlayer.id .. ")")
    logDebug("currentBet=" .. game.currentBet .. ", canCheck=" .. tostring(currentPlayer.bet >= game.currentBet))

    network.send(currentPlayer.id, network.MSG.YOUR_TURN, {
        currentBet = game.currentBet,
        minRaise = config.bigBlind,
        canCheck = currentPlayer.bet >= game.currentBet
    })

    logDebug("YOUR_TURN gesendet!")

    -- Starte Timer
    local timeoutTimer = os.startTimer(config.turnTimeout)

    -- Warte auf Aktion
    while true do
        local event, param1, param2 = os.pullEvent()

        if event == "timer" and param1 == timeoutTimer then
            -- Timeout - automatisch fold
            runtime.warn("Timeout für", currentPlayer.name)
            handlePlayerAction(currentPlayer.id, "fold", 0)
            break
        elseif event == "rednet_message" then
            local senderId = param1
            local message = param2

            if type(message) ~= "table" or not message.type then
                runtime.warn("Ungültige Nachricht während Wettrunde von", tostring(senderId))
            elseif message.type == network.MSG.ACTION and senderId == currentPlayer.id then
                os.cancelTimer(timeoutTimer)
                local action = message.data.action
                local amount = message.data.amount or 0
                handlePlayerAction(senderId, action, amount)
                break
            elseif message.type == network.MSG.LEAVE then
                removePlayer(senderId)

                if senderId == currentPlayer.id then
                    os.cancelTimer(timeoutTimer)

                    if game.round ~= "waiting" and game.activePlayers and #game.activePlayers > 0 then
                        nextPlayer()
                    end

                    break
                end
            elseif message.type == network.MSG.JOIN then
                addPlayer(senderId, message.data and message.data.playerName, message.data and message.data.chips)
            elseif message.type == network.MSG.READY then
                setPlayerReady(senderId, message.data and message.data.ready)
            elseif message.type == network.MSG.PING then
                network.send(senderId, network.MSG.PONG, {})
            elseif message.type == network.MSG.HEARTBEAT then
                network.send(senderId, network.MSG.PONG, {})
                local pingedPlayer = getPlayer(senderId)
                if pingedPlayer then
                    pingedPlayer.connected = true
                end
            end
        end
    end
end

-- Verarbeitet Spieler-Aktion
handlePlayerAction = function(clientId, action, amount)
    local player = getPlayer(clientId)
    if not player then
        runtime.error("Spieler nicht gefunden:", tostring(clientId))
        return
    end

    -- INPUT VALIDATION
    if not action or type(action) ~= "string" then
        runtime.error("Ungültige Aktion von", player.name)
        return
    end

    -- Validate amount for raise
    if action == "raise" then
        if not amount or type(amount) ~= "number" or amount < 0 then
            runtime.error("Ungültiger Raise-Betrag von", player.name .. ": " .. tostring(amount))
            network.send(clientId, network.MSG.ERROR, {message = "Ungültiger Raise-Betrag"})
            return
        end

        -- Validate minimum raise
        local minRaise = config.bigBlind
        if amount < minRaise then
            runtime.error("Raise-Betrag zu klein:", amount, "<", minRaise)
            network.send(clientId, network.MSG.ERROR, {message = "Raise-Betrag zu klein (min: " .. minRaise .. ")"})
            return
        end

        -- Validate maximum raise (can't raise more than you have)
        local raiseAmount = game.currentBet - player.bet + amount
        if raiseAmount > player.chips then
            runtime.error("Raise-Betrag zu groß:", raiseAmount, ">", player.chips)
            network.send(clientId, network.MSG.ERROR, {message = "Nicht genug Chips"})
            return
        end
    end

    runtime.info(player.name .. " -> " .. action .. " (" .. (amount or 0) .. ")")

    if action == "fold" then
        player.folded = true

    elseif action == "check" then
        -- Validate check is allowed
        if player.bet < game.currentBet then
            runtime.error("Check nicht erlaubt - muss callen")
            network.send(clientId, network.MSG.ERROR, {message = "Check nicht erlaubt - muss callen"})
            return
        end

    elseif action == "call" then
        local callAmount = game.currentBet - player.bet
        if callAmount < 0 then callAmount = 0 end
        placeBet(player, callAmount)

    elseif action == "raise" then
        local raiseAmount = game.currentBet - player.bet + amount
        placeBet(player, raiseAmount)
        game.currentBet = player.bet

    elseif action == "all-in" then
        local allInAmount = player.chips
        if allInAmount <= 0 then
            runtime.error("Keine Chips für All-In")
            return
        end
        placeBet(player, allInAmount)
        if player.bet > game.currentBet then
            game.currentBet = player.bet
        end
    else
        runtime.error("Unbekannte Aktion:", tostring(action))
        return
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
        runtime.error("Keine aktiven Spieler in nextPlayer!")
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
            runtime.error("Kein Spieler bei Index", game.currentPlayerIndex)
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
    runtime.info("=== Wettrunde beendet ===")

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
        sleep(config.roundTransitionDelay)
        game.currentPlayerIndex = game.dealerIndex
        nextPlayer()

    elseif game.round == "flop" then
        game.round = "turn"
        table.insert(game.communityCards, poker.drawCard(game.deck))
        broadcastGameState()
        sleep(config.roundTransitionDelay)
        game.currentPlayerIndex = game.dealerIndex
        nextPlayer()

    elseif game.round == "turn" then
        game.round = "river"
        table.insert(game.communityCards, poker.drawCard(game.deck))
        broadcastGameState()
        sleep(config.roundTransitionDelay)
        game.currentPlayerIndex = game.dealerIndex
        nextPlayer()

    elseif game.round == "river" then
        game.round = "showdown"
        endHand()
    end
end

-- Beendet Hand (Showdown)
endHand = function()
    runtime.info("=== Showdown ===")

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
        runtime.info("Gewinner:", winner.name .. " (alle gefoldet)")

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
            runtime.info(player.name .. ": " .. hands[player.id].name)
        end

        -- Finde Gewinner
        local winners, bestHand = poker.findWinners(hands)

        -- Verteile Pot
        local winAmount = math.floor(game.pot / #winners)
        local remainder = game.pot - (winAmount * #winners)

        for index, winnerId in ipairs(winners) do
            local winner = getPlayer(winnerId)
            local bonus = (index <= remainder) and 1 or 0
            winner.chips = winner.chips + winAmount + bonus
            runtime.info("Gewinner:", winner.name, "mit", bestHand.name)
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

    -- Warte kurz damit Spieler Ergebnis sehen können
    sleep(config.showdownDelay)

    -- IMMER zurück zur Lobby nach einer Runde
    runtime.info("Runde beendet - zurueck zur Lobby")

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

    -- SICHERHEIT: nil checks für Index-Konvertierung
    local dealerIdx = nil
    local currentIdx = nil

    if game.round ~= "waiting" and #game.activePlayers > 0 then
        dealerIdx = activeIndexToPlayerIndex(game.dealerIndex)
        currentIdx = activeIndexToPlayerIndex(game.currentPlayerIndex)
    end

    local state = {
        round = game.round,
        pot = game.pot,
        currentBet = game.currentBet,
        communityCards = game.communityCards,
        dealerIndex = dealerIdx,
        currentPlayerIndex = currentIdx,
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
    runtime.info("=== Poker Server ===")
    runtime.info("Initialisiere Netzwerk...")

    network.init(true)
    runtime.info("Server gestartet!")
    runtime.info("Warte auf Spieler...")

    while true do
        local senderId, msgType, data = network.receive(1)

        if senderId and msgType then
            local payload = data or {}

            if msgType == network.MSG.JOIN then
                if type(payload.playerName) ~= "string" or payload.playerName == "" then
                    runtime.warn("Ungültiger JOIN ohne Namen von", senderId)
                else
                    addPlayer(senderId, payload.playerName, payload.chips)
                end

            elseif msgType == network.MSG.READY then
                setPlayerReady(senderId, payload.ready)

            elseif msgType == network.MSG.LEAVE then
                removePlayer(senderId)

            elseif msgType == network.MSG.PING then
                network.send(senderId, network.MSG.PONG, {})
            elseif msgType == network.MSG.HEARTBEAT then
                network.send(senderId, network.MSG.PONG, {})
                local heartbeatPlayer = getPlayer(senderId)
                if heartbeatPlayer then
                    heartbeatPlayer.connected = true
                end
            else
                runtime.debug(config.debug, "Ignoriere unbekannte Nachricht", msgType, "von", senderId)
            end
        end
    end
end

-- Fehlerbehandlung mit Auto-Reboot
while true do
    local success, err = pcall(main)

    if not success then
        runtime.error("===================")
        runtime.error("FEHLER:", tostring(err))
        runtime.error("===================")
        runtime.warn("Automatischer Neustart in " .. config.errorRebootDelay .. " Sekunden...")
        network.close()

        -- Wartezeit vor Neustart
        sleep(config.errorRebootDelay)

        runtime.info("Neustart...")
        os.reboot()
    else
        break
    end
end
