-- config.lua - Beispiel Konfiguration
-- Kopiere diese Datei zu "config.lua" und passe sie an

return {
    -- Peripherie-Seiten (Client)
    playerDetectorSide = "left",  -- Seite des Player Detectors
    chestSide = "front",          -- Seite der Truhe (oder "auto" für automatische Erkennung)
    rsBridgeSide = "right",       -- Seite der RS Bridge (für Bank-System)

    -- Bank-System
    useBank = false,              -- true = RS Bridge Integration aktivieren
    chipItem = "minecraft:diamond",  -- Item-ID für Chips (Standard: Diamanten)

    -- Server-Einstellungen
    minPlayers = 2,               -- Minimum Spieler zum Starten
    maxPlayers = 4,               -- Maximum Spieler

    -- Spiel-Einstellungen
    smallBlind = 10,              -- Small Blind Betrag
    bigBlind = 20,                -- Big Blind Betrag
    startingChips = 1000,         -- Start-Chips pro Spieler
    turnTimeout = 60,             -- Sekunden pro Zug

    -- Netzwerk
    serverTimeout = 10,           -- Sekunden zum Suchen des Servers

    -- UI
    monitorScale = 0.5,           -- Text-Skalierung (0.5 - 5.0)

    -- Debug
    debug = false                 -- Debug-Ausgaben aktivieren
}
