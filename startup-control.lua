-- startup-control.lua - Auto-Start für Control-Computer
-- Diese Datei als "startup.lua" auf dem Control-Computer speichern

local function main()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== Poker Control Computer ===")
    print("")
    print("Starte Steuerungs-Interface...")
    print("")

    if not fs.exists("control.lua") then
        print("FEHLER: control.lua nicht gefunden!")
        print("")
        print("Installation:")
        print("> wget https://raw.githubusercontent.com/")
        print("  LopeKinz/cctweaked_poker_multiplayer/")
        print("  main/control.lua")
        print("")
        return
    end

    sleep(1)
    shell.run("control.lua")
end

-- Auto-Restart bei Fehler
while true do
    local success, err = pcall(main)

    if not success then
        print("")
        print("FEHLER: " .. tostring(err))
        print("")
        print("Neustart in 5 Sekunden...")
        print("Drücke Strg+T zum Abbrechen")
        sleep(5)
    else
        -- Wenn control.lua normal beendet wird
        print("")
        print("Control beendet.")
        print("Neustart in 3 Sekunden...")
        sleep(3)
    end
end
