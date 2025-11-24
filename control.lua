-- control.lua - Steuerungs-Computer für Poker Netzwerk
-- Verwaltet alle Computer im Netzwerk (Server + Clients)

-- Farben für Ausgabe
local function printColor(text, color)
    if term.isColor() then
        term.setTextColor(color or colors.white)
    end
    print(text)
    if term.isColor() then
        term.setTextColor(colors.white)
    end
end

-- Netzwerk-Protokoll
local PROTOCOL = "POKER_CONTROL"

-- Befehle
local CMD = {
    PING = "PING",
    PONG = "PONG",
    START = "START",
    STOP = "STOP",
    REBOOT = "REBOOT",
    STATUS = "STATUS",
    STATUS_RESPONSE = "STATUS_RESPONSE"
}

-- Computer-Liste
local computers = {}

-- Initialisiert Netzwerk
local function initNetwork()
    local modem = peripheral.find("modem")
    if not modem then
        printColor("FEHLER: Kein Modem gefunden!", colors.red)
        return false
    end

    rednet.open(peripheral.getName(modem))
    return true
end

-- Scannt Netzwerk nach Poker-Computern
local function scanNetwork()
    printColor("=== Scanne Netzwerk ===", colors.yellow)
    print("")

    computers = {}

    -- Sende Ping
    rednet.broadcast({type = CMD.PING}, PROTOCOL)
    printColor("Ping gesendet...", colors.lightGray)

    printColor("Warte auf Antworten (10 Sekunden)...", colors.lightGray)
    local startTime = os.epoch("utc")

    while (os.epoch("utc") - startTime) / 1000 < 10 do
        local senderId, message, protocol = rednet.receive(PROTOCOL, 1)

        if senderId and protocol == PROTOCOL and type(message) == "table" then
            if message.type == CMD.PONG then
                if not computers[senderId] then
                    computers[senderId] = {
                        id = senderId,
                        type = message.computerType or "unknown",
                        label = message.label or "Computer #" .. senderId,
                        online = true,
                        lastSeen = os.epoch("utc")
                    }

                    printColor("Gefunden: #" .. senderId .. " (" .. computers[senderId].type .. ") - " .. computers[senderId].label, colors.green)
                end
            end
        end
    end

    print("")
    local count = 0
    for _ in pairs(computers) do count = count + 1 end

    if count == 0 then
        printColor("Keine Computer gefunden!", colors.red)
    else
        printColor("Gefunden: " .. count .. " Computer", colors.green)
    end

    print("")
end

-- Sendet Befehl an Computer
local function sendCommand(computerId, command)
    rednet.send(computerId, {type = command}, PROTOCOL)
end

-- Sendet Befehl an alle Computer
local function broadcastCommand(command)
    rednet.broadcast({type = command}, PROTOCOL)
end

-- Zeigt Computer-Liste
local function showComputers()
    term.clear()
    term.setCursorPos(1, 1)

    printColor("=== Poker Netzwerk-Steuerung ===", colors.yellow)
    print("")

    if next(computers) == nil then
        printColor("Keine Computer gefunden.", colors.red)
        print("Führe 'Scan' aus um Computer zu finden.")
        return
    end

    printColor("ID  | Typ     | Label", colors.lightBlue)
    printColor("----+----------+-----------------------", colors.gray)

    for id, comp in pairs(computers) do
        local status = comp.online and "●" or "○"
        local statusColor = comp.online and colors.green or colors.red

        term.setTextColor(statusColor)
        write(status .. " ")
        term.setTextColor(colors.white)

        local idStr = tostring(id)
        while #idStr < 3 do idStr = idStr .. " " end

        local typeStr = comp.type
        while #typeStr < 8 do typeStr = typeStr .. " " end

        print(idStr .. "| " .. typeStr .. "| " .. comp.label)
    end

    print("")
end

-- Hauptmenü
local function showMenu()
    printColor("Befehle:", colors.yellow)
    print("")
    printColor("1. Scan - Scanne Netzwerk", colors.white)
    printColor("2. Status - Zeige alle Computer", colors.white)
    printColor("3. Start - Starte alle Programme", colors.white)
    printColor("4. Stop - Stoppe alle Programme", colors.white)
    printColor("5. Reboot - Starte alle Computer neu", colors.white)
    printColor("6. Custom - Einzelnen Computer steuern", colors.white)
    printColor("7. Beenden", colors.white)
    print("")
end

-- Starte alle Programme
local function startAll()
    printColor("Starte alle Programme...", colors.yellow)
    broadcastCommand(CMD.START)

    sleep(1)
    printColor("Befehle gesendet!", colors.green)
end

-- Stoppe alle Programme
local function stopAll()
    printColor("Stoppe alle Programme...", colors.yellow)
    broadcastCommand(CMD.STOP)

    sleep(1)
    printColor("Befehle gesendet!", colors.green)
end

-- Starte alle Computer neu
local function rebootAll()
    printColor("WARNUNG: Alle Computer werden neu gestartet!", colors.red)
    write("Fortfahren? (j/n): ")
    local answer = read()

    if answer:lower() ~= "j" then
        printColor("Abgebrochen.", colors.yellow)
        return
    end

    printColor("Starte alle Computer neu...", colors.yellow)
    broadcastCommand(CMD.REBOOT)

    sleep(1)
    printColor("Befehle gesendet!", colors.green)
    sleep(2)

    -- Lösche Computer-Liste
    computers = {}
end

-- Custom Steuerung
local function customControl()
    showComputers()

    write("Computer-ID: ")
    local idInput = read()
    local id = tonumber(idInput)

    if not id or not computers[id] then
        printColor("Ungültige Computer-ID!", colors.red)
        sleep(2)
        return
    end

    print("")
    printColor("Computer #" .. id .. " - " .. computers[id].label, colors.lightBlue)
    print("")
    printColor("1. Start", colors.white)
    printColor("2. Stop", colors.white)
    printColor("3. Reboot", colors.white)
    printColor("4. Zurück", colors.white)
    print("")

    write("Auswahl: ")
    local choice = read()

    if choice == "1" then
        sendCommand(id, CMD.START)
        printColor("Start-Befehl gesendet!", colors.green)
    elseif choice == "2" then
        sendCommand(id, CMD.STOP)
        printColor("Stop-Befehl gesendet!", colors.green)
    elseif choice == "3" then
        sendCommand(id, CMD.REBOOT)
        printColor("Reboot-Befehl gesendet!", colors.green)
        computers[id] = nil
    else
        return
    end

    sleep(2)
end

-- Hauptschleife
local function main()
    if not initNetwork() then
        return
    end

    printColor("=================================", colors.yellow)
    printColor("  Poker Netzwerk-Steuerung      ", colors.yellow)
    printColor("=================================", colors.yellow)
    print("")
    printColor("Steuerung für alle Poker-Computer", colors.lightGray)
    print("")

    -- Initial-Scan
    scanNetwork()

    while true do
        showComputers()
        showMenu()

        write("> ")
        local choice = read()

        if choice == "1" then
            scanNetwork()

        elseif choice == "2" then
            -- Status wird bereits in showComputers() angezeigt
            sleep(0)

        elseif choice == "3" then
            startAll()

        elseif choice == "4" then
            stopAll()

        elseif choice == "5" then
            rebootAll()

        elseif choice == "6" then
            customControl()

        elseif choice == "7" then
            term.clear()
            term.setCursorPos(1, 1)
            printColor("Steuerung beendet.", colors.green)
            break

        else
            printColor("Ungültige Auswahl!", colors.red)
            sleep(1)
        end
    end

    rednet.close()
end

-- Fehlerbehandlung
local success, err = pcall(main)
if not success then
    term.clear()
    term.setCursorPos(1, 1)
    printColor("FEHLER:", colors.red)
    printColor(tostring(err), colors.white)
end
