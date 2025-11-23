# Installation & Setup Guide

Detaillierte Anleitung für die Installation und Konfiguration des Poker Multiplayer Systems.

## Voraussetzungen

### Minecraft Mods
- **CC:Tweaked** (ComputerCraft)
- **Advanced Peripherals**

### Items benötigt

#### Für den Server (1x)
- 1x Advanced Computer
- 1x Wired Modem
- Netzwerkkabel

#### Für jeden Client (4x)
- 1x Advanced Computer
- 20x Advanced Monitor (für 4x5 Bildschirm)
- 1x Wired Modem
- 1x Truhe
- 1x Player Detector (Advanced Peripherals)
- 1x RS Bridge (Optional, für ME System Integration)
- Netzwerkkabel
- Items für Chips (z.B. Goldbarren, Diamanten, etc.)

## Schritt 1: Hardware aufbauen

### Server Computer
1. Platziere Advanced Computer
2. Füge Wired Modem hinzu (beliebige Seite)
3. Verbinde Modem mit Netzwerkkabel

### Client Computer (4x wiederholen)
1. Platziere Advanced Computer
2. Baue 4x5 Monitor Grid:
   ```
   [M][M][M][M]
   [M][M][M][M]
   [M][M][M][M]
   [M][M][M][M]
   [M][M][M][M]
   ```
3. Füge Wired Modem zum Computer hinzu
4. **WICHTIG**: Rechtsklick mit Modem auf Monitor (verbindet als Peripherie)
5. Platziere Truhe direkt vor dem Computer (front)
6. Platziere Player Detector links vom Computer (left)
7. Optional: RS Bridge rechts vom Computer (right)
8. Verbinde Modem mit Netzwerkkabel zum Server

### Netzwerk-Topologie Beispiel
```
Server
  |
  +---- Client 1
  |
  +---- Client 2
  |
  +---- Client 3
  |
  +---- Client 4
```

## Schritt 2: Software Installation

### Automatische Installation (Empfohlen)

#### Auf dem Server:
```lua
> wget run https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/installer.lua
```
Wähle Option **1** (Server)

#### Auf jedem Client:
```lua
> wget run https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/installer.lua
```
Wähle Option **2** (Client)

### Manuelle Installation

#### Server:
```lua
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/server.lua server.lua
> mkdir lib
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/lib/poker.lua lib/poker.lua
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/lib/network.lua lib/network.lua
```

#### Client:
```lua
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/client.lua client.lua
> mkdir lib
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/lib/poker.lua lib/poker.lua
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/lib/network.lua lib/network.lua
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/lib/ui.lua lib/ui.lua
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/lib/bank.lua lib/bank.lua
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/config.example.lua config.example.lua
```

## Schritt 3: Konfiguration

### Client Konfiguration

Auf jedem Client:
```lua
> cp config.example.lua config.lua
> edit config.lua
```

Passe folgende Werte an:

```lua
return {
    -- Peripherie-Seiten anpassen falls nötig
    playerDetectorSide = "left",
    chestSide = "front",
    rsBridgeSide = "right",

    -- Bank-System (nur wenn RS Bridge vorhanden)
    useBank = false,  -- auf true setzen für ME System Integration

    -- Server-Timeout erhöhen bei langsamen Netzwerken
    serverTimeout = 10,
}
```

### Peripherie-Seiten herausfinden

Falls du nicht sicher bist, welche Seite welche Peripherie hat:
```lua
> lua
lua> peripheral.getNames()
```

Oder mit einem einfachen Skript:
```lua
> peripherals
```

## Schritt 4: Chips vorbereiten

Lege Items in die Truhen der Clients:
- **1 Item = 1 Chip** im Spiel
- Empfohlen: 1000 Items pro Spieler für Standard-Spiel
- Beispiel-Items: Goldbarren, Diamanten, Smaragde, etc.

## Schritt 5: System starten

### Reihenfolge:
1. **Server zuerst starten:**
   ```lua
   > server
   ```

2. **Dann alle Clients:**
   ```lua
   > client
   ```

### Mit Auto-Start (optional)

Um das System automatisch beim Computer-Start zu starten:
```lua
> wget https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/startup.lua startup.lua
```

Danach: Computer neu starten (`Strg+R`)

## Schritt 6: Spielen

1. Stelle dich vor den Player Detector eines Clients
2. Warte bis dein Name erkannt wird
3. Drücke "BEREIT" auf dem Touchscreen
4. Warte bis mindestens 2 Spieler bereit sind
5. Spiel startet automatisch!

## Troubleshooting

### Monitor wird nicht erkannt
```lua
> peripherals
```
Prüfe ob Monitor erscheint. Falls nicht:
- Rechtsklick mit Modem auf Monitor
- Monitor muss an Computer angrenzen

### Netzwerk-Probleme

**Server wird nicht gefunden:**
```lua
# Auf Client:
> lua
lua> rednet.lookup("POKER_MP", "poker_server")
```

Sollte Server-ID zurückgeben. Falls nicht:
- Alle Modems mit Netzwerkkabel verbunden?
- Server läuft?
- Modems aktiviert? (Rechtsklick)

**Prüfe Modem-Status:**
```lua
> lua
lua> m = peripheral.find("modem")
lua> print(m.isWireless())  -- sollte false sein
```

### Truhe nicht erkannt
```lua
> lua
lua> peripheral.find("minecraft:chest")
```

Falls `nil`:
- Truhe direkt an Computer?
- Richtige Seite in config.lua?

### Player Detector funktioniert nicht
```lua
> lua
lua> pd = peripheral.find("playerDetector")
lua> print(pd.getPlayers())
```

Stelle dich in Reichweite (3 Blöcke) und prüfe Ausgabe.

### Performance-Probleme

Bei langsamen Monitoren:
```lua
> edit config.lua
```
Setze `monitorScale = 1.0` für größere, aber schnellere UI

## ME System Integration (Optional)

### Mit RS Bridge:

1. Platziere RS Bridge rechts vom Computer
2. Verbinde RS Bridge mit ME System (ME Interface)
3. In config.lua:
   ```lua
   useBank = true
   ```

4. Chips werden automatisch vom ME System verwaltet
5. Truhe wird als Buffer verwendet

## Server-Konfiguration anpassen

Im server.lua Header kannst du folgendes anpassen:

```lua
local config = {
    minPlayers = 2,        -- Minimum Spieler (2-4)
    maxPlayers = 4,        -- Maximum Spieler (2-4)
    smallBlind = 10,       -- Small Blind
    bigBlind = 20,         -- Big Blind
    startingChips = 1000,  -- Start-Chips
    turnTimeout = 60       -- Sekunden pro Zug
}
```

## Updates installieren

```lua
> wget run https://raw.githubusercontent.com/LopeKinz/cctweaked_poker_multiplayer/main/installer.lua
```
Wähle Option **4** (Updates)

## Backup erstellen

```lua
> cp server.lua server.lua.bak
> cp client.lua client.lua.bak
> cp config.lua config.lua.bak
```

## Support

Bei Problemen:
1. Prüfe alle Peripherie-Verbindungen
2. Lies die Fehlermeldungen
3. Prüfe Logs auf Server und Client
4. Erstelle Issue auf GitHub mit Details

## Weitere Tipps

- **Label Computer**: `> label set poker_server_1`
- **Fernwartung**: Nutze Pocket Computer mit Wireless Modem
- **Monitoring**: Füge zusätzlichen Monitor am Server für Status
- **Chunk Loading**: Stelle sicher dass alle Computer in geladenen Chunks sind
