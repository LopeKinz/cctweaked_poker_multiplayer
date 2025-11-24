-- daemon.lua - Control-Daemon für Poker Computer
-- Läuft im Hintergrund und empfängt Steuerungsbefehle

local PROTOCOL = "POKER_CONTROL"

local CMD = {
    PING = "PING",
    PONG = "PONG",
    START = "START",
    STOP = "STOP",
    REBOOT = "REBOOT",
    STATUS = "STATUS",
    STATUS_RESPONSE = "STATUS_RESPONSE",
    UPDATE = "UPDATE"
}

-- Ermittelt Computer-Typ basierend auf Hardware und Konfiguration
local function getComputerType()
    -- 1. Prüfe ob spezielle Typ-Datei existiert
    if fs.exists(".type") then
        local file = fs.open(".type", "r")
        local computerType = file.readLine()
        file.close()
        if computerType then
            return computerType
        end
    end

    -- 2. Prüfe auf Monitor (Client hat Monitor, Server nicht)
    local hasMonitor = false
    for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
        if peripheral.getType(side) == "monitor" then
            hasMonitor = true
            break
        end
    end

    if hasMonitor then
        -- Speichere Typ für nächstes Mal
        local file = fs.open(".type", "w")
        file.write("client")
        file.close()
        return "client"
    end

    -- 3. Keine Monitor gefunden -> Server
    local file = fs.open(".type", "w")
    file.write("server")
    file.close()
    return "server"
end

-- Initialisiert Netzwerk
local function initNetwork()
    local modem = peripheral.find("modem")
    if not modem then
        print("FEHLER: Kein Modem gefunden!")
        return false
    end

    rednet.open(peripheral.getName(modem))
    return true
end

-- Startet Programm
local function startProgram()
    local computerType = getComputerType()

    if computerType == "server" then
        shell.run("bg server.lua")
        print("[Daemon] Server gestartet")
    elseif computerType == "client" then
        shell.run("bg client.lua")
        print("[Daemon] Client gestartet")
    else
        print("[Daemon] Kein Poker-Programm gefunden")
    end
end

-- Stoppt Programm
local function stopProgram()
    -- Finde laufende Poker-Programme
    local programs = {"server.lua", "client.lua", "server", "client"}

    for _, program in ipairs(programs) do
        shell.run("kill " .. program)
    end

    print("[Daemon] Programme gestoppt")
end

-- Update-Funktion
local function updateSystem()
    print("[Daemon] Starte Update...")

    local computerType = getComputerType()

    -- GitHub Repository URL
    local baseUrl = "https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/"

    -- Gemeinsame Dateien
    local commonFiles = {
        "lib/poker.lua",
        "lib/network.lua",
        "daemon.lua",
        "startup.lua",
        "update.lua"
    }

    -- Computer-spezifische Dateien
    local typeFiles = {}
    if computerType == "server" then
        typeFiles = {"server.lua"}
    elseif computerType == "client" then
        typeFiles = {
            "client.lua",
            "lib/ui.lua",
            "lib/bank.lua",
            "config.example.lua"
        }
    end

    -- Download Dateien
    local function downloadFile(file)
        local url = baseUrl .. file
        print("  Lade " .. file .. "...")

        -- Erstelle Verzeichnis falls nötig
        local dir = fs.getDir(file)
        if dir ~= "" and not fs.exists(dir) then
            fs.makeDir(dir)
        end

        -- Download
        shell.run("wget", url, file)

        return fs.exists(file)
    end

    -- Download alle Dateien
    local success = true

    for _, file in ipairs(commonFiles) do
        if not downloadFile(file) then
            success = false
            print("  FEHLER: " .. file)
        end
    end

    for _, file in ipairs(typeFiles) do
        if not downloadFile(file) then
            success = false
            print("  FEHLER: " .. file)
        end
    end

    if success then
        print("[Daemon] Update erfolgreich!")
        print("[Daemon] Neustart in 3 Sekunden...")
        sleep(3)
        os.reboot()
    else
        print("[Daemon] Update fehlgeschlagen!")
    end
end

-- Hauptschleife
local function main()
    print("=== Poker Control Daemon ===")
    print("Warte auf Steuerungsbefehle...")
    print("")

    if not initNetwork() then
        return
    end

    local computerType = getComputerType()
    local computerLabel = os.getComputerLabel() or ("Computer #" .. os.getComputerID())

    print("Typ: " .. computerType)
    print("Label: " .. computerLabel)
    print("ID: " .. os.getComputerID())
    print("")

    while true do
        local senderId, message, protocol = rednet.receive(PROTOCOL, 1)

        if senderId and protocol == PROTOCOL and type(message) == "table" then
            local cmd = message.type

            if cmd == CMD.PING then
                -- Antworte auf Ping
                rednet.send(senderId, {
                    type = CMD.PONG,
                    computerType = computerType,
                    label = computerLabel
                }, PROTOCOL)

                print("[" .. os.date("%H:%M:%S") .. "] Ping von #" .. senderId)

            elseif cmd == CMD.START then
                print("[" .. os.date("%H:%M:%S") .. "] START von #" .. senderId)
                startProgram()

            elseif cmd == CMD.STOP then
                print("[" .. os.date("%H:%M:%S") .. "] STOP von #" .. senderId)
                stopProgram()

            elseif cmd == CMD.REBOOT then
                print("[" .. os.date("%H:%M:%S") .. "] REBOOT von #" .. senderId)
                print("Neustart in 2 Sekunden...")
                sleep(2)
                os.reboot()

            elseif cmd == CMD.UPDATE then
                print("[" .. os.date("%H:%M:%S") .. "] UPDATE von #" .. senderId)
                updateSystem()

            elseif cmd == CMD.STATUS then
                -- Status-Abfrage
                rednet.send(senderId, {
                    type = CMD.STATUS_RESPONSE,
                    computerType = computerType,
                    label = computerLabel,
                    online = true
                }, PROTOCOL)
            end
        end
    end
end

-- Fehlerbehandlung mit Auto-Restart
while true do
    local success, err = pcall(main)

    if not success then
        print("FEHLER: " .. tostring(err))
        print("Neustart in 5 Sekunden...")
        sleep(5)
    else
        break
    end
end
