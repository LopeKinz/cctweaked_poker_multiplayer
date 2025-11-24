-- installer.lua - Poker Multiplayer Installer
local GITHUB_BASE = "https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/"

local FILES = {
    -- Bibliotheken
    "lib/poker.lua",
    "lib/network.lua",
    "lib/ui.lua",
    "lib/bank.lua",

    -- Programme
    "server.lua",
    "client.lua",
    "update.lua",

    -- Konfiguration
    "config.example.lua",

    -- Dokumentation
    "README.md"
}

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

-- Fortschrittsbalken
local function drawProgress(current, total, text)
    local width = term.getSize()
    local barWidth = width - 10

    term.setCursorPos(1, 10)
    term.clearLine()

    local progress = current / total
    local filled = math.floor(barWidth * progress)

    term.write("[")
    term.setBackgroundColor(colors.green)
    term.write(string.rep(" ", filled))
    term.setBackgroundColor(colors.black)
    term.write(string.rep(" ", barWidth - filled))
    term.write("]")

    term.setCursorPos(1, 11)
    term.clearLine()
    print(text)

    term.setCursorPos(1, 12)
    term.clearLine()
    print(current .. "/" .. total .. " (" .. math.floor(progress * 100) .. "%)")
end

-- Download-Funktion mit Fehlerbehandlung
local function downloadFile(url, path)
    -- Erstelle Verzeichnis falls nötig
    local dir = fs.getDir(path)
    if not fs.exists(dir) and dir ~= "" then
        fs.makeDir(dir)
    end

    -- Download mit mehreren Versuchen
    for attempt = 1, 3 do
        local response = http.get(url)

        if response then
            local content = response.readAll()
            response.close()

            local file = fs.open(path, "w")
            file.write(content)
            file.close()

            return true, "OK"
        else
            if attempt < 3 then
                sleep(1)
            end
        end
    end

    return false, "Download fehlgeschlagen nach 3 Versuchen"
end

-- Hauptmenü
local function showMenu()
    term.clear()
    term.setCursorPos(1, 1)

    printColor("=====================================", colors.yellow)
    printColor("    Poker Multiplayer Installer     ", colors.yellow)
    printColor("=====================================", colors.yellow)
    print("")

    printColor("Was möchtest du installieren?", colors.white)
    print("")
    printColor("1. Server", colors.green)
    printColor("2. Client", colors.blue)
    printColor("3. Alles (Server + Client)", colors.orange)
    printColor("4. Nur Updates", colors.lightBlue)
    printColor("5. Beenden", colors.red)
    print("")

    write("Auswahl: ")
    local choice = read()

    return tonumber(choice) or 0
end

-- Installiert Dateien
local function installFiles(fileList)
    term.clear()
    term.setCursorPos(1, 1)

    printColor("Installiere Dateien...", colors.yellow)
    print("")

    local success = 0
    local failed = 0

    for i, file in ipairs(fileList) do
        drawProgress(i, #fileList, "Lade: " .. file)

        local url = GITHUB_BASE .. file
        local ok, err = downloadFile(url, file)

        if ok then
            success = success + 1
        else
            failed = failed + 1
            printColor("FEHLER: " .. file .. " - " .. err, colors.red)
        end
    end

    term.setCursorPos(1, 14)
    print("")

    if failed == 0 then
        printColor("Installation erfolgreich!", colors.green)
        printColor("Erfolgreich: " .. success, colors.green)
    else
        printColor("Installation mit Fehlern abgeschlossen.", colors.yellow)
        printColor("Erfolgreich: " .. success, colors.green)
        printColor("Fehlgeschlagen: " .. failed, colors.red)
    end

    return failed == 0
end

-- Server-Installation
local function installServer()
    local serverFiles = {
        "lib/poker.lua",
        "lib/network.lua",
        "server.lua",
        "update.lua"
    }

    return installFiles(serverFiles)
end

-- Client-Installation
local function installClient()
    local clientFiles = {
        "lib/poker.lua",
        "lib/network.lua",
        "lib/ui.lua",
        "lib/bank.lua",
        "client.lua",
        "update.lua",
        "config.example.lua"
    }

    return installFiles(clientFiles)
end

-- Vollständige Installation
local function installAll()
    return installFiles(FILES)
end

-- Konfiguration erstellen
local function setupConfig()
    print("")
    printColor("Konfiguration erstellen...", colors.yellow)

    if fs.exists("config.lua") then
        write("config.lua existiert bereits. Überschreiben? (j/n): ")
        local answer = read()
        if answer:lower() ~= "j" then
            printColor("Konfiguration übersprungen.", colors.yellow)
            return
        end
    end

    if fs.exists("config.example.lua") then
        fs.copy("config.example.lua", "config.lua")
        printColor("config.lua erstellt!", colors.green)
        printColor("Bitte passe config.lua an deine Hardware an.", colors.yellow)
    else
        printColor("WARNUNG: config.example.lua nicht gefunden!", colors.red)
    end
end

-- Erkennt Computertyp
local function detectComputerType()
    local hasMonitor = peripheral.find("monitor") ~= nil
    local hasPlayerDetector = peripheral.find("playerDetector") ~= nil

    if hasMonitor and hasPlayerDetector then
        return "client"
    elseif hasMonitor or hasPlayerDetector then
        return "client"
    else
        return "server"
    end
end

-- Auto-Installation
local function autoInstall()
    term.clear()
    term.setCursorPos(1, 1)

    printColor("Auto-Installation", colors.yellow)
    print("")

    local computerType = detectComputerType()

    printColor("Erkannter Typ: " .. computerType:upper(), colors.green)
    print("")

    write("Stimmt das? (j/n): ")
    local answer = read()

    if answer:lower() ~= "j" then
        printColor("Installation abgebrochen.", colors.red)
        return false
    end

    local success = false

    if computerType == "server" then
        success = installServer()
    else
        success = installClient()
        if success then
            setupConfig()
        end
    end

    return success
end

-- Post-Installation Infos
local function showPostInstall(installType)
    print("")
    printColor("=====================================", colors.yellow)
    printColor("    Installation abgeschlossen!     ", colors.green)
    printColor("=====================================", colors.yellow)
    print("")

    if installType == "server" or installType == "all" then
        printColor("Server starten:", colors.yellow)
        printColor("  > server", colors.white)
        print("")
    end

    if installType == "client" or installType == "all" then
        printColor("Client starten:", colors.yellow)
        printColor("  1. Passe config.lua an", colors.orange)
        printColor("  2. > client", colors.white)
        print("")
    end

    printColor("Dokumentation: README.md", colors.lightBlue)
    print("")

    write("Drücke Enter...")
    read()
end

-- Hauptprogramm
local function main()
    -- Prüfe HTTP API
    if not http then
        printColor("FEHLER: HTTP API ist deaktiviert!", colors.red)
        printColor("Aktiviere http in der ComputerCraft Konfiguration.", colors.yellow)
        return
    end

    while true do
        local choice = showMenu()

        if choice == 1 then
            -- Server
            if installServer() then
                showPostInstall("server")
            end

        elseif choice == 2 then
            -- Client
            if installClient() then
                setupConfig()
                showPostInstall("client")
            end

        elseif choice == 3 then
            -- Alles
            if installAll() then
                setupConfig()
                showPostInstall("all")
            end

        elseif choice == 4 then
            -- Updates
            autoInstall()

        elseif choice == 5 then
            -- Beenden
            term.clear()
            term.setCursorPos(1, 1)
            printColor("Installation beendet.", colors.green)
            return

        else
            printColor("Ungültige Auswahl!", colors.red)
            sleep(1)
        end
    end
end

-- Fehlerbehandlung
local success, err = pcall(main)

if not success then
    term.clear()
    term.setCursorPos(1, 1)
    printColor("KRITISCHER FEHLER:", colors.red)
    printColor(tostring(err), colors.white)
    print("")
    printColor("Bitte melde diesen Fehler.", colors.yellow)
end
