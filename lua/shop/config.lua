MyShop = MyShop or {}

--[[
    KATEGORIEN MIT JOB-LOCK
    jobs = nil oder {} = Alle Jobs können sehen
    jobs = {"TEAM_POLICE", "TEAM_SWAT"} = Nur diese Jobs können sehen
]]

MyShop.Categories = {
    {name = "Essen", jobs = nil}, 
    {name = "Generelles", jobs = nil}, 
    {name = "Geld Drucker", jobs = nil},  
    {name = "Gastronomie", jobs = {"TEAM_COOK"}}, 
    {name = "Meth Labor", jobs = {"TEAM_MOB"}}, 
}

--[[
    ITEMS
    category muss exakt mit dem Namen in MyShop.Categories übereinstimmen
]]

MyShop.Items = {
    -- ################## ESSEN (ÖFFENTLICH) ##################
    {
        id = "burger",
        name = "Cheeseburger",
        category = "Essen",
        price = 160,
        model = "models/food/burger.mdl",
        description = "Saftiger Doppel-Cheeseburger mit frischem Salat. (Füllt 50 Hunger auf)",
        onBuy = function(ply)
            if ply.setSelfDarkRPVar then
                local current = ply:getDarkRPVar("Energy") or 0
                ply:setSelfDarkRPVar("Energy", math.min(current + 50, 100))
            end
            ply:ChatPrint("[Shop] Du hast einen Burger gegessen!")
        end
    },
    {
        id = "hotdog",
        name = "Hotdog",
        category = "Essen", 
        price = 70,
        model = "models/food/hotdog.mdl",
        description = "Klassischer Street-Food Hotdog mit Senf und Ketchup.(Füllt 20 Hunger auf).",
        onBuy = function(ply)
            if ply.setSelfDarkRPVar then
                local current = ply:getDarkRPVar("Energy") or 0
                ply:setSelfDarkRPVar("Energy", math.min(current + 20, 100))
            end
            ply:ChatPrint("[Shop] Du hast ein Hotdog gegessen!")
        end
    },

    -- ################## GENERELLES (ÖFFENTLICH) ##################
    {
        id = "tipjar",
        name = "Spenden Glas",
        category = "Generelles",
        price = 0,
        model = "models/props_lab/jar01a.mdl",
        description = "Ideal für Straßenmusiker oder Bettler. Jeder kann Geld einwerfen!",
        spawnEntity = "darkrp_tip_jar",
        spawnOffset = Vector(25, 40, 50)
    },   
    {
        id = "hansa",
        name = "Hansaplast Pflaster",
        category = "Generelles",
        price = 3200,
        model = "models/kamen/hansaplast1.mdl",
        description = "Medizinische Erste-Hilfe für kleinere Verletzungen.",
        spawnEntity = "hansaplast", 
        spawnOffset = Vector(25, 40, 50)
    },

    -- ################## GELD DRUCKER (ÖFFENTLICH) ##################
    {
        id = "gelddrucker",
        name = "Geld Drucker",
        category = "Geld Drucker",
        price = 7500,
        model = "models/props_electronics/printer-7.mdl",
        description = "Startet auf Level 1 mit 40€ Druck pro Zyklus. Max Level 10 = 400€!",
        spawnEntity = "adv_moneyprinter",
        spawnOffset = Vector(25, 40, 50)
    },
    {
        id = "kuehleinheit",
        name = "Kühleinheit",
        category = "Geld Drucker",
        price = 5000,
        model = "models/fasteroid/computerfan.mdl",
        description = "Dein Drucker überhitzt bei Level 1 bei 40 Hitze. Ohne Kühlung explodiert der Drucker!",
        spawnEntity = "printer_cooler", 
        spawnOffset = Vector(25, 40, 50)
    },   
    {
        id = "failsafe",
        name = "Failsafe System",
        category = "Geld Drucker",
        price = 3000,
        model = "models/cheeze/wires/router.mdl",
        description = "Benachrichtigt dich sofort wenn jemand an deinem Drucker herumspielt.",
        spawnEntity = "printer_failsafe", 
        spawnOffset = Vector(25, 40, 50)
    }, 
    {
        id = "uebertaktung",
        name = "Übertaktung",
        category = "Geld Drucker",
        price = 3000,
        model = "models/jaanus/wiretool/wiretool_controlchip.mdl",
        description = "Kombiniere unbedingt mit einer Kühleinheit, sonst brennt dein Drucker ab!",
        spawnEntity = "printer_overclocker",
        spawnOffset = Vector(25, 40, 50)
    },
    {
        id = "batt1",
        name = "Kleine Batterie",
        category = "Geld Drucker",
        price = 500,
        model = "models/items/car_battery01.mdl",
        description = "Notstrom für ca. 5 Minuten. Kapazität: 500 Einheiten.",
        spawnEntity = "printer_smallbattery", 
        spawnOffset = Vector(25, 40, 50)
    },
    {
        id = "batt2",
        name = "Mittlere Batterie",
        category = "Geld Drucker",
        price = 1000,
        model = "models/items/car_battery01.mdl",
        description = "Startet mit 500 Kapazität, upgradebar.",
        spawnEntity = "printer_mediumbattery", 
        spawnOffset = Vector(25, 40, 50)
    },
    {
        id = "batt3",
        name = "Große Batterie",
        category = "Geld Drucker",
        price = 2500,
        model = "models/items/car_battery01.mdl",
        description = "Pflicht für Level 8-10 Drucker! Upgradebar auf 5000+ Kapazität.",
        spawnEntity = "printer_largebattery", 
        spawnOffset = Vector(25, 40, 50)
    },

    -- ################## GASTRONOMIE (NUR TEAM_COOK) ##################
    {
        id = "microwave",
        name = "Mikrowelle für Chinesische Nudeln",
        category = "Gastronomie",
        price = 400,
        model = "models/props/cs_office/microwave.mdl",
        description = "Die schnelle Lösung für hungrige Kunden! Bereitet in Sekunden Nudeln zu.",
        spawnEntity = "microwave",
        spawnOffset = Vector(25, 40, 50),
        maxEntities = 1
    },    
    {
        id = "stove",
        name = "Profiküchen Herd",
        category = "Gastronomie",
        price = 850,
        model = "models/props_c17/furnitureStove001a.mdl",
        description = "Schwerer Industrie-Herd für die anspruchsvolle Gastronomie.",
        spawnEntity = "stove",
        spawnOffset = Vector(25, 40, 50),
        maxEntities = 1
    },
    {
        id = "keg",
        name = "Bier Fass",
        category = "Gastronomie",
        price = 300,
        model = "models/props/de_inferno/wine_barrel.mdl",
        description = "Edles Holzfass mit kaltem Bier. Perfekt für Restaurants.",
        spawnEntity = "keg",
        spawnOffset = Vector(25, 40, 50),
        maxEntities = 1
    },

    -- ################## METH LABOR (NUR MOB) ##################
    {
        id = "zmlab2_tent",
        name = "Zelt",
        category = "Meth Labor",
        price = 800,
        model = "models/zerochain/props_methlab/zmlab2_tentkit.mdl",
        description = "Mobiles Laborzelt für diskrete Herstellung.",
        spawnEntity = "zmlab2_tent",
        spawnOffset = Vector(25, 40, 50),
        maxEntities = 1
    },
    {
        id = "zmlab2_equipment",
        name = "Ausrüstungskiste",
        category = "Meth Labor",
        price = 1100,
        model = "models/zerochain/props_methlab/zmlab2_chest.mdl",
        description = "Enthält alle notwendigen Werkzeuge für den Laboraufbau.",
        spawnEntity = "zmlab2_equipment",
        spawnOffset = Vector(25, 40, 50),
        maxEntities = 1
    }
}

-- Hilfsfunktion: Prüft ob Spieler Kategorie sehen darf
function MyShop.CanSeeCategory(ply, categoryName)
    for _, cat in ipairs(MyShop.Categories) do
        if cat.name == categoryName then
            -- Keine Jobs definiert = öffentlich
            if not cat.jobs or #cat.jobs == 0 then return true end
            
            -- Prüfe ob Spieler einen der erlaubten Jobs hat
            for _, jobName in ipairs(cat.jobs) do
                local jobTeam = _G[jobName]
                if jobTeam and ply:Team() == jobTeam then
                    return true
                end
            end
            return false
        end
    end
    return false
end

-- Hilfsfunktion: Hole alle sichtbaren Kategorien für Spieler
function MyShop.GetVisibleCategories(ply)
    local visible = {}
    for _, cat in ipairs(MyShop.Categories) do
        if MyShop.CanSeeCategory(ply, cat.name) then
            table.insert(visible, cat)
        end
    end
    return visible
end