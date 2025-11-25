-- network.lua - Netzwerk Kommunikations-Bibliothek
local runtime = require("lib.runtime")
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

local function findModem()
    local ok, modem = pcall(peripheral.find, "modem", function(_, wrapped)
        return not (wrapped.isWireless and wrapped.isWireless())
    end)

    if ok and modem then
        return modem
    end

    -- Letzte Chance: irgendein Modem akzeptieren
    ok, modem = pcall(peripheral.find, "modem")
    if ok and modem then
        return modem
    end

    error("Kein Modem gefunden!")
end

-- Initialisiert Netzwerk
function network.init(isServer)
    local modem = findModem()

    runtime.info("Nutze Modem", peripheral.getName(modem))
    local ok, err = pcall(rednet.open, peripheral.getName(modem))
    if not ok then
        error("Rednet konnte nicht geoeffnet werden: " .. tostring(err))
    end

    if isServer then
        runtime.safeCall("rednet.host", rednet.host, network.PROTOCOL, "poker_server")
    end

    return modem
end

local function safeSend(target, message)
    local ok, err
    if target then
        ok, err = pcall(rednet.send, target, message, network.PROTOCOL)
    else
        ok, err = pcall(rednet.broadcast, message, network.PROTOCOL)
    end

    if not ok then
        runtime.warn("Senden fehlgeschlagen:", tostring(err))
    end
end

-- Sendet Nachricht
function network.send(target, msgType, data)
    local message = {
        type = msgType,
        data = data or {},
        timestamp = os.epoch("utc")
    }

    safeSend(target, message)
end

-- Empfängt Nachricht (mit Timeout)
function network.receive(timeout)
    timeout = timeout or network.TIMEOUT
    local ok, senderId, message, protocol = pcall(rednet.receive, network.PROTOCOL, timeout)

    if not ok then
        runtime.warn("Netzwerkempfang fehlgeschlagen:", tostring(senderId))
        return nil, nil, nil
    end

    if senderId and message and type(message) == "table" and message.type then
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

    local ok, serverId = pcall(rednet.lookup, network.PROTOCOL, "poker_server")
    if ok and serverId then
        return serverId
    end

    -- Warte auf Server
    local startTime = os.epoch("utc")
    while infinite or (os.epoch("utc") - startTime) / 1000 < timeout do
        ok, serverId = pcall(rednet.lookup, network.PROTOCOL, "poker_server")
        if ok and serverId then
            return serverId
        end
        sleep(0.5)
    end

    return nil
end

-- Schließt Netzwerk
function network.close()
    runtime.safeCall("rednet.unhost", rednet.unhost, network.PROTOCOL)
    local modem = peripheral.find("modem")
    if modem then
        runtime.safeCall("rednet.close", rednet.close, peripheral.getName(modem))
    end
end

return network
