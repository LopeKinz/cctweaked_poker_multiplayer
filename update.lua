-- update.lua - Netzwerk-Update für alle Computer
local GITHUB_BASE = "https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/"

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

-- Download-Funktion
local function downloadFile(url, path)
    local dir = fs.getDir(path)
    if not fs.exists(dir) and dir ~= "" then
        fs.makeDir(dir)
    end

    for attempt = 1, 3 do
        local response = http.get(url)
        if response then
            local content = response.readAll()
            response.close()

            local file = fs.open(path, "w")
            file.write(content)
            file.close()

            return true
        end
        if attempt < 3 then sleep(1) end
    end

    return false
end

-- Ermittelt Computer-Typ
local function detectType()
    if fs.exists("server.lua") then
        return "server"
    elseif fs.exists("client.lua") then
        return "client"
    else
        return "unknown"
    end
end

-- Updated lokalen Computer
local function updateLocal()
    printColor("=== Lokales Update ===", colors.yellow)
    print("")

    local computerType = detectType()

    if computerType == "unknown" then
        printColor("Kein Poker-System gefunden!", colors.red)
        return false
    end

    printColor("Typ: " .. computerType:upper(), colors.green)
    print("")

    local files = {}

    if computerType == "server" then
        files = {
            "lib/poker.lua",
            "lib/network.lua",
            "server.lua"
        }
    else -- client
        files = {
            "lib/poker.lua",
            "lib/network.lua",
            "lib/ui.lua",
            "lib/bank.lua",
            "client.lua"
        }
    end

    local success = 0
    local failed = 0

    for i, file in ipairs(files) do
        write("Update " .. file .. "... ")
        local url = GITHUB_BASE .. file
        if downloadFile(url, file) then
            printColor("OK", colors.green)
            success = success + 1
        else
            printColor("FEHLER", colors.red)
            failed = failed + 1
        end
    end

    print("")
    if failed == 0 then
        printColor("Update erfolgreich! (" .. success .. " Dateien)", colors.green)
        return true
    else
        printColor("Update mit Fehlern. " .. failed .. " fehlgeschlagen.", colors.red)
        return false
    end
end

-- Netzwerk-Update Protocol
local PROTOCOL = "POKER_UPDATE"
local UPDATE_COMMAND = "UPDATE_NOW"
local UPDATE_DONE = "UPDATE_DONE"

-- Startet als Update-Daemon (empfängt Update-Befehle)
local function startDaemon()
    printColor("=== Update-Daemon ===", colors.yellow)
    print("Warte auf Update-Befehle...")
    print("Drücke Strg+T zum Beenden")
    print("")

    -- Öffne Netzwerk
    local modem = peripheral.find("modem")
    if not modem then
        printColor("FEHLER: Kein Modem gefunden!", colors.red)
        return
    end

    rednet.open(peripheral.getName(modem))

    while true do
        local senderId, message, protocol = rednet.receive(PROTOCOL, 1)

        if senderId and message == UPDATE_COMMAND then
            printColor("Update-Befehl empfangen von Computer #" .. senderId, colors.yellow)

            if updateLocal() then
                rednet.send(senderId, UPDATE_DONE, PROTOCOL)
                printColor("Neustart in 3 Sekunden...", colors.yellow)
                sleep(3)
                os.reboot()
            else
                rednet.send(senderId, "UPDATE_FAILED", PROTOCOL)
            end
        end
    end
end

-- Sendet Update-Befehl an alle Computer im Netzwerk
local function broadcastUpdate()
    printColor("=== Netzwerk-Update ===", colors.yellow)
    print("")

    -- Öffne Netzwerk
    local modem = peripheral.find("modem")
    if not modem then
        printColor("FEHLER: Kein Modem gefunden!", colors.red)
        return
    end

    rednet.open(peripheral.getName(modem))

    -- Update zuerst lokal
    printColor("1. Update lokaler Computer...", colors.lightBlue)
    print("")
    if not updateLocal() then
        printColor("Lokales Update fehlgeschlagen!", colors.red)
        return
    end

    print("")
    printColor("2. Sende Update-Befehl an Netzwerk...", colors.lightBlue)
    print("")

    -- Broadcast Update-Befehl
    rednet.broadcast(UPDATE_COMMAND, PROTOCOL)

    -- Warte auf Antworten
    printColor("Warte auf Antworten (10 Sekunden)...", colors.yellow)
    print("")

    local updated = 0
    local failed = 0
    local startTime = os.epoch("utc")

    while (os.epoch("utc") - startTime) / 1000 < 10 do
        local senderId, message, protocol = rednet.receive(PROTOCOL, 1)

        if senderId and protocol == PROTOCOL then
            if message == UPDATE_DONE then
                printColor("Computer #" .. senderId .. " erfolgreich geupdatet", colors.green)
                updated = updated + 1
            elseif message == "UPDATE_FAILED" then
                printColor("Computer #" .. senderId .. " Update fehlgeschlagen", colors.red)
                failed = failed + 1
            end
        end
    end

    print("")
    printColor("=== Update abgeschlossen ===", colors.yellow)
    printColor("Erfolgreich: " .. updated, colors.green)
    if failed > 0 then
        printColor("Fehlgeschlagen: " .. failed, colors.red)
    end
    print("")
    printColor("Alle Computer wurden geupdatet und neustarten automatisch.", colors.green)
    print("")

    write("Diesen Computer auch neustarten? (j/n): ")
    local answer = read()
    if answer:lower() == "j" then
        os.reboot()
    end

    rednet.close()
end

-- Hauptmenü
local function main()
    term.clear()
    term.setCursorPos(1, 1)

    printColor("=====================================", colors.yellow)
    printColor("      Poker Netzwerk-Update         ", colors.yellow)
    printColor("=====================================", colors.yellow)
    print("")

    printColor("Was möchtest du tun?", colors.white)
    print("")
    printColor("1. Lokales Update (nur dieser Computer)", colors.green)
    printColor("2. Netzwerk-Update (alle Computer)", colors.orange)
    printColor("3. Update-Daemon starten (empfängt Updates)", colors.blue)
    printColor("4. Beenden", colors.red)
    print("")

    write("Auswahl: ")
    local choice = read()

    term.clear()
    term.setCursorPos(1, 1)

    if choice == "1" then
        updateLocal()
        print("")
        write("Neustart? (j/n): ")
        if read():lower() == "j" then
            os.reboot()
        end

    elseif choice == "2" then
        broadcastUpdate()

    elseif choice == "3" then
        startDaemon()

    elseif choice == "4" then
        printColor("Beendet.", colors.green)
        return
    else
        printColor("Ungültige Auswahl!", colors.red)
    end
end

-- Prüfe HTTP API
if not http then
    printColor("FEHLER: HTTP API ist deaktiviert!", colors.red)
    return
end

-- Fehlerbehandlung
local success, err = pcall(main)
if not success then
    term.clear()
    term.setCursorPos(1, 1)
    printColor("FEHLER:", colors.red)
    printColor(tostring(err), colors.white)
end
