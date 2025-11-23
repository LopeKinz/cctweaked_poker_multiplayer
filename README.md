# CC:Tweaked Multiplayer Poker

Ein vollständiges 4-Spieler Texas Hold'em Poker-Spiel für CC:Tweaked und Advanced Peripherals.

## Features

- 4 Spieler + automatischer Dealer
- Touchscreen-Interface (4x5 Monitor)
- Banksystem über RS Bridge (Advanced Peripherals)
- Spielererkennung via Player Detector
- Einsätze über Truhen
- Vollständige Texas Hold'em Poker-Regeln

## Hardware-Anforderungen

### Server (1x)
- 1x Advanced Computer
- 1x Wired Modem (für Netzwerk)

### Pro Spieler (4x)
- 1x Advanced Computer
- 4x5 Advanced Monitor (Touchscreen)
- 1x Truhe (für Einsätze)
- 1x Player Detector (Advanced Peripherals)
- 1x RS Bridge (Advanced Peripherals) - optional für Banksystem
- 1x Wired Modem (für Netzwerk)

## Installation

### Automatische Installation (Empfohlen)

```lua
wget run https://raw.githubusercontent.com/IhrUsername/cctweaked_poker_multiplayer/main/installer.lua
```

### Manuelle Installation

1. Alle Dateien in den Computer kopieren
2. `server.lua` auf dem Server-Computer ausführen
3. `client.lua` auf jedem Spieler-Computer ausführen

## Verkabelung

1. Alle Computer mit Wired Modems verbinden (Netzwerkkabel)
2. Monitor an Client-Computer anschließen (Rechtsklick mit Modem)
3. Truhe direkt an Client-Computer anschließen
4. Player Detector an Client-Computer anschließen
5. RS Bridge für Banksystem konfigurieren

## Peripherie-Seiten

Standardmäßig:
- **Monitor**: Beliebige Seite (wird automatisch erkannt)
- **Truhe**: "front" oder automatisch erkannt
- **Player Detector**: "left" (konfigurierbar)
- **RS Bridge**: "right" (konfigurierbar)

Diese können in der `config.lua` angepasst werden.

## Spielregeln

### Texas Hold'em Poker

- Jeder Spieler erhält 2 Karten (Hole Cards)
- 5 Gemeinschaftskarten (Flop: 3, Turn: 1, River: 1)
- Wettrunden: Pre-Flop, Flop, Turn, River
- Aktionen: Fold, Check, Call, Raise

### Einsätze

- Chips werden über die Truhe verwaltet
- Items in der Truhe = Chips (1 Item = 1 Chip)
- Standard Chip-Item: **Diamanten** (minecraft:diamond)
- Optional: Banksystem über RS Bridge für automatisches Item-Management

## Konfiguration

Siehe `config.lua` für:
- Peripherie-Seiten
- Netzwerk-IDs
- Blinds und Ante
- Bankintegration

## Verwendung

### Server starten
```lua
server
```

### Client starten
```lua
client
```

## Spielablauf

1. Server starten
2. Alle Clients verbinden
3. Spieler vor Player Detector positionieren
4. Chips in Truhe legen
5. "Ready" auf Touchscreen drücken
6. Spiel beginnt automatisch wenn 2-4 Spieler bereit

## Fehlerbehebung

### Monitor wird nicht erkannt
- Modem mit Rechtsklick auf Monitor verwenden
- `peripherals` Befehl prüfen

### Netzwerkprobleme
- Alle Computer im gleichen Wired-Netzwerk?
- Modems aktiviert (rotes Signal)?

### Truhe nicht gefunden
- Truhe direkt an Computer?
- Richtige Seite in config.lua?

## Lizenz

MIT License

## Credits

Erstellt für All the Mods 10 mit CC:Tweaked und Advanced Peripherals
