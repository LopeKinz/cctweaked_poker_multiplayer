-- poker.lua - Poker Logik Bibliothek
local poker = {}

-- Kartenfarben und Werte
poker.SUITS = {"hearts", "diamonds", "clubs", "spades"}
poker.SUIT_SYMBOLS = {hearts = "\3", diamonds = "\4", clubs = "\5", spades = "\6"}
poker.SUIT_COLORS = {hearts = colors.red, diamonds = colors.red, clubs = colors.black, spades = colors.black}

poker.RANKS = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}
poker.RANK_VALUES = {
    ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6,
    ["7"] = 7, ["8"] = 8, ["9"] = 9, ["10"] = 10,
    ["J"] = 11, ["Q"] = 12, ["K"] = 13, ["A"] = 14
}

-- Hand-Rankings
poker.HAND_RANKS = {
    HIGH_CARD = 1,
    PAIR = 2,
    TWO_PAIR = 3,
    THREE_OF_KIND = 4,
    STRAIGHT = 5,
    FLUSH = 6,
    FULL_HOUSE = 7,
    FOUR_OF_KIND = 8,
    STRAIGHT_FLUSH = 9,
    ROYAL_FLUSH = 10
}

poker.HAND_NAMES = {
    [1] = "High Card",
    [2] = "Pair",
    [3] = "Two Pair",
    [4] = "Three of a Kind",
    [5] = "Straight",
    [6] = "Flush",
    [7] = "Full House",
    [8] = "Four of a Kind",
    [9] = "Straight Flush",
    [10] = "Royal Flush"
}

-- Erstellt ein neues Kartendeck
function poker.createDeck()
    local deck = {}
    for _, suit in ipairs(poker.SUITS) do
        for _, rank in ipairs(poker.RANKS) do
            table.insert(deck, {suit = suit, rank = rank})
        end
    end
    return deck
end

-- Mischt ein Kartendeck
function poker.shuffleDeck(deck)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- Zieht eine Karte vom Deck
function poker.drawCard(deck)
    return table.remove(deck, 1)
end

-- Konvertiert Karte zu String
function poker.cardToString(card)
    return card.rank .. poker.SUIT_SYMBOLS[card.suit]
end

-- Sortiert Karten nach Wert
function poker.sortCards(cards)
    local sorted = {}
    for i, card in ipairs(cards) do
        sorted[i] = card
    end

    table.sort(sorted, function(a, b)
        return poker.RANK_VALUES[a.rank] > poker.RANK_VALUES[b.rank]
    end)

    return sorted
end

-- Zählt Karten gleichen Rangs
function poker.countRanks(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        counts[card.rank] = (counts[card.rank] or 0) + 1
    end
    return counts
end

-- Zählt Karten gleicher Farbe
function poker.countSuits(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        counts[card.suit] = (counts[card.suit] or 0) + 1
    end
    return counts
end

-- Prüft auf Flush
function poker.isFlush(cards)
    local suitCounts = poker.countSuits(cards)
    for suit, count in pairs(suitCounts) do
        if count >= 5 then
            return true, suit
        end
    end
    return false
end

-- Prüft auf Straight
function poker.isStraight(cards)
    local sorted = poker.sortCards(cards)
    local values = {}

    -- Sammle einzigartige Werte
    for _, card in ipairs(sorted) do
        local val = poker.RANK_VALUES[card.rank]
        if not values[val] then
            table.insert(values, val)
            values[val] = true
        end
    end

    table.sort(values, function(a, b) return a > b end)

    -- Prüfe auf 5 aufeinanderfolgende Karten
    for i = 1, #values - 4 do
        local isStraight = true
        for j = 0, 3 do
            if values[i + j] - values[i + j + 1] ~= 1 then
                isStraight = false
                break
            end
        end
        if isStraight then
            return true, values[i]
        end
    end

    -- Spezialfall: A-2-3-4-5 (Wheel)
    if values[1] == 14 and values[#values] == 2 and
       values[#values-1] == 3 and values[#values-2] == 4 and values[#values-3] == 5 then
        return true, 5
    end

    return false
end

-- Bewertet eine Pokerhand (7 Karten)
function poker.evaluateHand(cards)
    if #cards < 5 then
        return {rank = 0, value = 0, name = "Invalid"}
    end

    local sorted = poker.sortCards(cards)
    local rankCounts = poker.countRanks(cards)
    local isFlush, flushSuit = poker.isFlush(cards)
    local isStraight, straightHigh = poker.isStraight(cards)

    -- Zähle Paare, Drillinge, etc.
    local pairs = {}
    local threes = {}
    local fours = {}

    for rank, count in pairs(rankCounts) do
        if count == 2 then
            table.insert(pairs, poker.RANK_VALUES[rank])
        elseif count == 3 then
            table.insert(threes, poker.RANK_VALUES[rank])
        elseif count == 4 then
            table.insert(fours, poker.RANK_VALUES[rank])
        end
    end

    table.sort(pairs, function(a, b) return a > b end)
    table.sort(threes, function(a, b) return a > b end)
    table.sort(fours, function(a, b) return a > b end)

    -- Royal Flush
    if isFlush and isStraight and straightHigh == 14 then
        return {
            rank = poker.HAND_RANKS.ROYAL_FLUSH,
            value = 14,
            name = poker.HAND_NAMES[poker.HAND_RANKS.ROYAL_FLUSH],
            cards = sorted
        }
    end

    -- Straight Flush
    if isFlush and isStraight then
        return {
            rank = poker.HAND_RANKS.STRAIGHT_FLUSH,
            value = straightHigh,
            name = poker.HAND_NAMES[poker.HAND_RANKS.STRAIGHT_FLUSH],
            cards = sorted
        }
    end

    -- Four of a Kind
    if #fours > 0 then
        return {
            rank = poker.HAND_RANKS.FOUR_OF_KIND,
            value = fours[1],
            name = poker.HAND_NAMES[poker.HAND_RANKS.FOUR_OF_KIND],
            cards = sorted
        }
    end

    -- Full House
    if #threes > 0 and (#pairs > 0 or #threes > 1) then
        local value = threes[1] * 100
        if #threes > 1 then
            value = value + threes[2]
        else
            value = value + pairs[1]
        end
        return {
            rank = poker.HAND_RANKS.FULL_HOUSE,
            value = value,
            name = poker.HAND_NAMES[poker.HAND_RANKS.FULL_HOUSE],
            cards = sorted
        }
    end

    -- Flush
    if isFlush then
        return {
            rank = poker.HAND_RANKS.FLUSH,
            value = poker.RANK_VALUES[sorted[1].rank],
            name = poker.HAND_NAMES[poker.HAND_RANKS.FLUSH],
            cards = sorted
        }
    end

    -- Straight
    if isStraight then
        return {
            rank = poker.HAND_RANKS.STRAIGHT,
            value = straightHigh,
            name = poker.HAND_NAMES[poker.HAND_RANKS.STRAIGHT],
            cards = sorted
        }
    end

    -- Three of a Kind
    if #threes > 0 then
        return {
            rank = poker.HAND_RANKS.THREE_OF_KIND,
            value = threes[1],
            name = poker.HAND_NAMES[poker.HAND_RANKS.THREE_OF_KIND],
            cards = sorted
        }
    end

    -- Two Pair
    if #pairs >= 2 then
        local value = pairs[1] * 100 + pairs[2]
        return {
            rank = poker.HAND_RANKS.TWO_PAIR,
            value = value,
            name = poker.HAND_NAMES[poker.HAND_RANKS.TWO_PAIR],
            cards = sorted
        }
    end

    -- One Pair
    if #pairs == 1 then
        return {
            rank = poker.HAND_RANKS.PAIR,
            value = pairs[1],
            name = poker.HAND_NAMES[poker.HAND_RANKS.PAIR],
            cards = sorted
        }
    end

    -- High Card
    return {
        rank = poker.HAND_RANKS.HIGH_CARD,
        value = poker.RANK_VALUES[sorted[1].rank],
        name = poker.HAND_NAMES[poker.HAND_RANKS.HIGH_CARD],
        cards = sorted
    }
end

-- Vergleicht zwei Hände
function poker.compareHands(hand1, hand2)
    if hand1.rank > hand2.rank then
        return 1
    elseif hand1.rank < hand2.rank then
        return -1
    else
        if hand1.value > hand2.value then
            return 1
        elseif hand1.value < hand2.value then
            return -1
        else
            return 0
        end
    end
end

-- Findet Gewinner aus mehreren Händen
function poker.findWinners(hands)
    local bestHand = nil
    local winners = {}

    for playerId, hand in pairs(hands) do
        if bestHand == nil then
            bestHand = hand
            winners = {playerId}
        else
            local cmp = poker.compareHands(hand, bestHand)
            if cmp > 0 then
                bestHand = hand
                winners = {playerId}
            elseif cmp == 0 then
                table.insert(winners, playerId)
            end
        end
    end

    return winners, bestHand
end

return poker
