-- startup.lua - Auto-Start für Poker System
-- Diese Datei automatisch beim Computerstart ausgeführt

local function detectMode()
    -- Prüfe ob Server oder Client basierend auf Hardware
    local hasMonitor = peripheral.find("monitor") ~= nil

    if hasMonitor then
        return "client"
    else
        return "server"
    end
end

local function main()
    print("=== Poker System Startup ===")
    print("")

    -- Starte Daemon im Hintergrund
    if fs.exists("daemon.lua") then
        print("Starte Daemon im Hintergrund...")
        shell.run("bg daemon.lua")
        sleep(0.5)
    else
        print("WARNUNG: daemon.lua nicht gefunden!")
        print("Netzwerk-Steuerung nicht verfügbar.")
        sleep(1)
    end

    local mode = detectMode()

    print("Erkannter Modus: " .. mode:upper())
    print("")

    if mode == "server" then
        if fs.exists("server.lua") then
            print("Starte Server...")
            sleep(1)
            shell.run("server.lua")
        else
            print("FEHLER: server.lua nicht gefunden!")
            print("Führe 'installer' aus.")
        end

    else -- client
        if fs.exists("client.lua") then
            print("Starte Client...")
            sleep(1)
            shell.run("client.lua")
        else
            print("FEHLER: client.lua nicht gefunden!")
            print("Führe 'installer' aus.")
        end
    end
end

-- Auto-Restart bei Fehler
while true do
    local success, err = pcall(main)

    if not success then
        print("")
        print("FEHLER: " .. tostring(err))
        print("")
        print("Neustart in 10 Sekunden...")
        print("Drücke Strg+T zum Abbrechen")
        sleep(10)
    else
        break
    end
end
