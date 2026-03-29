# 🏪 Dynora 24/7 Shop System v1.0.0

Ein modernes, GTA-Style DarkRP Shop-System mit Job-Lock, sicherem Entity-Spawning und FPP/SAM Kompatibilität.

[![Garry's Mod](https://img.shields.io/badge/Garry's%20Mod-13+-blue.svg)](https://gmod.facepunch.com/)
[![DarkRP](https://img.shields.io/badge/DarkRP-2.7+-orange.svg)](https://github.com/FPtje/DarkRP)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ Features

- **🎮 GTA V Style Interface** - Modernes, verschwommenes UI mit intuitiver Bedienung
- **🔒 Job-Lock System** - Kategorien nur für bestimmte Jobs sichtbar (z.B. Meth-Lab nur für Gangster)
- **🛒 Warenkorb** - Mehrere Items auf einmal kaufen
- **⭐ Favoriten** - Items markieren für schnellen Zugriff
- **📊 Statistiken** - Einkaufsverlauf und Ausgaben-Tracking
- **🛡️ FPP/SAM Kompatibel** - Entities können mit Physgun bewegt werden (kein SetOwner-Bug)
- **⚡ Anti-Spam** - Cooldown-System gegen Massenkäufe
- **💾 SQLite** - Keine MySQL-Datenbank nötig

## 📸 Screenshots

*[Screenshots hier einfügen]*

## 🚀 Installation

1. **Download** das Repository
2. **Entpacke** den Ordner in `garrysmod/addons/`
3. **Benenne** den Ordner um in `dynora-shop` (wichtig!)
4. **Restart** deinen Server
5. **Optional**: Passe die Config in `config.lua` an


## ⚙️ Konfiguration

### Job-Lock (Categories)

```lua
MyShop.Categories = {
    {name = "Essen", jobs = nil},                    -- Öffentlich
    {name = "Gastronomie", jobs = {"TEAM_COOK"}},    -- Nur Köche
    {name = "Meth Labor", jobs = {"TEAM_MOB", "TEAM_GANG"}}, -- Nur Gangster
}
```

Items hinzufügen

```lua
{
    id = "gelddrucker",           -- Eindeutige ID
    name = "Geld Drucker",        -- Anzeigename
    category = "Geld Drucker",    -- Muss mit Category-Name übereinstimmen
    price = 7500,                 -- Preis
    model = "models/props/...",   -- 3D Model
    description = "Druckt Geld",  -- Beschreibung
    spawnEntity = "adv_moneyprinter", -- Entity Class
    maxEntities = 2               -- Limit pro Spieler (optional)
}
```

Consumables (Essen/Heilung)

```lua

{
    id = "burger",
    name = "Cheeseburger",
    price = 160,
    onBuy = function(ply)
        -- DarkRP Hunger Mod
        if ply.setSelfDarkRPVar then
            local current = ply:getDarkRPVar("Energy") or 0
            ply:setSelfDarkRPVar("Energy", math.min(current + 50, 100))
        end
        ply:ChatPrint("Lecker!")
    end
}
```

