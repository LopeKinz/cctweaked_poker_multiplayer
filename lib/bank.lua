-- bank.lua - Bank-System mit RS Bridge Integration (Advanced Peripherals)
local bank = {}

bank.config = {
    rsBridgeSide = "right",
    chipItem = "minecraft:diamond", -- Standard: Diamanten
    minWithdraw = 1,
    maxWithdraw = 10000
}

-- Initialisiert Bank-System
function bank.init(config)
    if config then
        for k, v in pairs(config) do
            bank.config[k] = v
        end
    end

    -- Finde RS Bridge
    local bridge = peripheral.find("rs_bridge") or
                   peripheral.wrap(bank.config.rsBridgeSide)

    if not bridge then
        return nil, "RS Bridge nicht gefunden"
    end

    return bridge
end

-- Holt Item-Details aus ME System
function bank.getItemDetails(bridge, itemName)
    if not bridge then return nil end

    -- Nur getItem verwenden (KEIN listItems!)
    if not bridge.getItem then
        print("FEHLER: RS Bridge hat keine getItem() Methode!")
        return nil
    end

    local success, item = pcall(function()
        return bridge.getItem({name = itemName})
    end)

    if success and item then
        return item
    end

    return nil
end

-- Zählt Chips im ME System
function bank.getBalance(bridge, itemFilter)
    if not bridge then return 0 end

    if not itemFilter then
        print("FEHLER: Kein Item-Filter angegeben!")
        return 0
    end

    -- Verwende NUR getItem() - KEIN listItems()
    if not bridge.getItem then
        print("FEHLER: RS Bridge hat keine getItem() Methode!")
        return 0
    end

    local success, item = pcall(function()
        return bridge.getItem({name = itemFilter})
    end)

    if success and item and item.amount then
        return item.amount
    end

    return 0
end

-- Exportiert Items aus ME System in Truhe
function bank.withdraw(bridge, chest, itemName, amount)
    if not bridge or not chest then
        return false, "Bridge oder Truhe nicht verfunden"
    end

    if amount < bank.config.minWithdraw then
        return false, "Betrag zu klein"
    end

    if amount > bank.config.maxWithdraw then
        return false, "Betrag zu groß"
    end

    -- Exportiere Items
    local success, result = pcall(function()
        return bridge.exportItem({
            name = itemName,
            count = amount
        }, "down") -- Annahme: Truhe ist unter der Bridge
    end)

    if not success then
        return false, "Export fehlgeschlagen: " .. tostring(result)
    end

    return true, result
end

-- Importiert Items von Truhe in ME System
function bank.deposit(bridge, chest, itemName, amount)
    if not bridge or not chest then
        return false, "Bridge oder Truhe nicht gefunden"
    end

    -- Finde Items in Truhe
    local itemsToDeposit = {}

    for slot = 1, chest.size() do
        local item = chest.getItemDetail(slot)
        if item and (item.name == itemName or not itemName) then
            local depositCount = math.min(item.count, amount)
            table.insert(itemsToDeposit, {
                slot = slot,
                count = depositCount
            })

            amount = amount - depositCount
            if amount <= 0 then break end
        end
    end

    if #itemsToDeposit == 0 then
        return false, "Keine Items zum Einzahlen gefunden"
    end

    -- Importiere Items
    local totalImported = 0

    for _, itemInfo in ipairs(itemsToDeposit) do
        local success, result = pcall(function()
            return bridge.importItem({
                fromSlot = itemInfo.slot,
                count = itemInfo.count
            }, "down")
        end)

        if success and result then
            totalImported = totalImported + itemInfo.count
        end
    end

    return true, totalImported
end

-- Auto-Deposit: Alle Items aus Truhe ins ME System
function bank.autoDeposit(bridge, chest)
    if not bridge or not chest then
        return false, "Bridge oder Truhe nicht gefunden"
    end

    local totalDeposited = 0

    for slot = 1, chest.size() do
        local item = chest.getItemDetail(slot)
        if item then
            local success, count = pcall(function()
                return bridge.importItem({
                    fromSlot = slot,
                    count = item.count
                }, "down")
            end)

            if success and count then
                totalDeposited = totalDeposited + count
            end
        end
    end

    return true, totalDeposited
end

-- Auto-Withdraw: Stelle sicher dass X Items in Truhe sind
function bank.ensureChestHas(bridge, chest, itemName, targetAmount)
    if not bridge or not chest then
        return false, "Bridge oder Truhe nicht gefunden"
    end

    -- Zähle aktuelle Items in Truhe
    local currentAmount = 0

    for slot = 1, chest.size() do
        local item = chest.getItemDetail(slot)
        if item and item.name == itemName then
            currentAmount = currentAmount + item.count
        end
    end

    -- Berechne benötigte Menge
    local needed = targetAmount - currentAmount

    if needed <= 0 then
        return true, 0 -- Bereits genug
    end

    -- Exportiere fehlende Menge
    return bank.withdraw(bridge, chest, itemName, needed)
end

-- Synchronisiert Chips zwischen Truhe und ME System
function bank.syncChips(bridge, chest, itemName, playerChips)
    if not bridge or not chest then
        return false, "Bridge oder Truhe nicht gefunden"
    end

    -- Zähle Items in Truhe
    local chestChips = 0

    for slot = 1, chest.size() do
        local item = chest.getItemDetail(slot)
        if item and item.name == itemName then
            chestChips = chestChips + item.count
        end
    end

    -- Synchronisiere
    if chestChips < playerChips then
        -- Spieler braucht mehr Chips
        local needed = playerChips - chestChips
        return bank.withdraw(bridge, chest, itemName, needed)

    elseif chestChips > playerChips then
        -- Spieler hat zu viele Chips
        local excess = chestChips - playerChips
        return bank.deposit(bridge, chest, itemName, excess)
    end

    return true, 0 -- Bereits synchron
end

-- Hilfsfunktion: Finde häufigstes Item (für Auto-Chip-Detection)
function bank.detectChipItem(chest)
    if not chest then return nil end

    local itemCounts = {}

    for slot = 1, chest.size() do
        local item = chest.getItemDetail(slot)
        if item then
            itemCounts[item.name] = (itemCounts[item.name] or 0) + item.count
        end
    end

    -- Finde häufigstes Item
    local mostCommon = nil
    local maxCount = 0

    for itemName, count in pairs(itemCounts) do
        if count > maxCount then
            maxCount = count
            mostCommon = itemName
        end
    end

    return mostCommon, maxCount
end

-- Wrapper für einfache Integration
function bank.createManager(rsBridgeSide, chestSide)
    local manager = {
        bridge = nil,
        chest = nil,
        chipItem = nil
    }

    -- Initialisiere Bridge
    manager.bridge = peripheral.find("rs_bridge") or
                     peripheral.wrap(rsBridgeSide or bank.config.rsBridgeSide)

    -- Initialisiere Truhe
    manager.chest = peripheral.find("minecraft:chest") or
                    peripheral.wrap(chestSide or "down")

    if not manager.bridge then
        print("WARNUNG: RS Bridge nicht gefunden - Bank deaktiviert")
        return nil
    end

    if not manager.chest then
        print("WARNUNG: Truhe nicht gefunden - Bank deaktiviert")
        return nil
    end

    -- Prüfe ob Bridge gültige Methoden hat
    if not manager.bridge.exportItem and not manager.bridge.importItem then
        print("FEHLER: RS Bridge hat keine export/import Methoden!")
        print("Stelle sicher dass Advanced Peripherals installiert ist.")
        print("Bank-System deaktiviert.")
        return nil
    end

    -- Auto-detect Chip Item oder verwende Diamanten als Standard
    manager.chipItem = bank.detectChipItem(manager.chest) or bank.config.chipItem

    if manager.chipItem then
        print("Chip-Item: " .. manager.chipItem)
    else
        print("WARNUNG: Kein Chip-Item erkannt - verwende Standard")
        manager.chipItem = bank.config.chipItem
    end

    -- Methoden
    function manager:getBalance()
        return bank.getBalance(self.bridge, self.chipItem)
    end

    function manager:withdraw(amount)
        return bank.withdraw(self.bridge, self.chest, self.chipItem, amount)
    end

    function manager:deposit(amount)
        return bank.deposit(self.bridge, self.chest, self.chipItem, amount)
    end

    function manager:autoDeposit()
        return bank.autoDeposit(self.bridge, self.chest)
    end

    function manager:sync(playerChips)
        return bank.syncChips(self.bridge, self.chest, self.chipItem, playerChips)
    end

    return manager
end

return bank
