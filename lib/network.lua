-- network.lua - Netzwerk Kommunikations-Bibliothek
local network = {}

network.PROTOCOL = "POKER_MP"
network.TIMEOUT = 5

-- Nachrichtentypen
network.MSG = {
    -- Client -> Server
    JOIN = "JOIN",
    READY = "READY",
    ACTION = "ACTION",
    LEAVE = "LEAVE",
    HEARTBEAT = "HEARTBEAT",

    -- Server -> Client
    WELCOME = "WELCOME",
    PLAYER_JOINED = "PLAYER_JOINED",
    PLAYER_LEFT = "PLAYER_LEFT",
    GAME_START = "GAME_START",
    GAME_STATE = "GAME_STATE",
    YOUR_TURN = "YOUR_TURN",
    ROUND_END = "ROUND_END",
    GAME_END = "GAME_END",
    ERROR = "ERROR",

    -- Bidirektional
    PING = "PING",
    PONG = "PONG"
}

-- Initialisiert Netzwerk
function network.init(isServer)
    -- Finde Modem (bevorzuge verkabelte Modems)
    local modem = peripheral.find("modem", function(name, wrapped)
        -- Bevorzuge nicht-wireless Modems
        return not (wrapped.isWireless and wrapped.isWireless())
    end)

    if not modem then
        error("Kein Modem gefunden!")
    end

    -- Öffne Rednet
    rednet.open(peripheral.getName(modem))

    if isServer then
        rednet.host(network.PROTOCOL, "poker_server")
    end

    return modem
end

-- Sendet Nachricht
function network.send(target, msgType, data)
    local message = {
        type = msgType,
        data = data or {},
        timestamp = os.epoch("utc")
    }

    if target then
        rednet.send(target, message, network.PROTOCOL)
    else
        rednet.broadcast(message, network.PROTOCOL)
    end
end

-- Empfängt Nachricht (mit Timeout)
function network.receive(timeout)
    timeout = timeout or network.TIMEOUT
    local senderId, message, protocol = rednet.receive(network.PROTOCOL, timeout)

    if senderId and message and message.type then
        return senderId, message.type, message.data
    end

    return nil, nil, nil
end

-- Wartet auf spezifischen Nachrichtentyp
function network.waitFor(msgType, timeout, fromSender)
    local startTime = os.epoch("utc")
    timeout = timeout or network.TIMEOUT

    while true do
        local senderId, receivedType, data = network.receive(1)

        if senderId then
            if receivedType == msgType then
                if not fromSender or senderId == fromSender then
                    return senderId, data
                end
            end
        end

        if (os.epoch("utc") - startTime) / 1000 > timeout then
            return nil, nil
        end
    end
end

-- Findet Server
-- timeout: Sekunden bis Abbruch, 0 = unendlich versuchen
function network.findServer(timeout)
    timeout = timeout or 5
    local infinite = (timeout == 0)

    local serverId = rednet.lookup(network.PROTOCOL, "poker_server")
    if serverId then
        return serverId
    end

    -- Warte auf Server
    local startTime = os.epoch("utc")
    while infinite or (os.epoch("utc") - startTime) / 1000 < timeout do
        serverId = rednet.lookup(network.PROTOCOL, "poker_server")
        if serverId then
            return serverId
        end
        sleep(0.5)
    end

    return nil
end

-- Schließt Netzwerk
function network.close()
    rednet.unhost(network.PROTOCOL)
    local modem = peripheral.find("modem")
    if modem then
        rednet.close(peripheral.getName(modem))
    end
end

return network
