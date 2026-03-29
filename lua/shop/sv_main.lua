util.AddNetworkString("MyShop_Buy")
util.AddNetworkString("MyShop_Refund")

MyShop.ItemCache = MyShop.ItemCache or {}
MyShop.CategoryCache = MyShop.CategoryCache or {}

-- Initialisiere Cache
hook.Add("Initialize", "MyShop_InitCache", function()
    timer.Simple(1, function()
        -- Items in Lookup-Table
        for _, item in ipairs(MyShop.Items or {}) do
            MyShop.ItemCache[item.id] = item
        end
        
        -- Kategorien mit Job-Locks cachen
        for _, cat in ipairs(MyShop.Categories or {}) do
            MyShop.CategoryCache[cat.name] = cat.jobs -- Kann nil, {} oder {"TEAM_XXX"} sein
            print("[MyShop] Cached category '" .. cat.name .. "' with jobs: " .. tostring(cat.jobs and table.concat(cat.jobs, ", ") or "PUBLIC"))
        end
    end)
end)

net.Receive("MyShop_Buy", function(len, ply)
    local item_id = net.ReadString()
    local amount = net.ReadUInt(8)
    local quickBuy = net.ReadBool()
    
    MyShop.BuyItem(ply, item_id, amount)
end)

function MyShop.CanSeeCategory(ply, categoryName)
    local allowedJobs = MyShop.CategoryCache[categoryName]
    
    -- Keine Jobs definiert = öffentlich
    if not allowedJobs or #allowedJobs == 0 then return true end
    
    -- Prüfe ob Spieler einen erlaubten Job hat
    for _, jobName in ipairs(allowedJobs) do
        local jobTeam = _G[jobName]
        if jobTeam and ply:Team() == jobTeam then
            return true
        end
    end
    
    return false
end

--[[
    KORRIGIERTE SPAWN-FUNKTION
    - Entfernt: SetOwner() (blockiert Physgun!)
    - Behält: Setowning_ent() (DarkRP TipJar etc.)
    - Fügt: CPPI Support für FPP/SAM
    - Fügt: Saubere Physics-Initialisierung
]]
function MyShop.SpawnEntityForPlayer(ply, item, amount)
    local entClass = item.spawnEntity or item.spawnVehicle
    if not entClass then return false end

    amount = math.Clamp(amount or 1, 1, 10)
    
    -- Entity Limit Check
    if item.maxEntities then
        local count = 0
        for _, ent in ipairs(ents.FindByClass(entClass)) do
            if ent.ShopOwner == ply then
                count = count + 1
            end
        end
        
        if count >= item.maxEntities then
            ply:ChatPrint("[Shop] Limit erreicht! Du hast bereits " .. count .. "/" .. item.maxEntities .. " " .. item.name)
            return false
        end
    end
    
    -- Geld erstmal behalten, erst nach erfolgreichem Spawn bestätigen
    local totalPrice = item.price * amount
    local spawnedCount = 0
    local failedSpawns = 0
    
    for i = 1, amount do
        timer.Simple((i-1) * 0.1, function()
            if not IsValid(ply) then 
                failedSpawns = failedSpawns + 1
                return 
            end
            
            -- Spawn Position (Kreis um Spieler)
            local yaw = (i - 1) * (360 / amount)
            local rad = math.rad(yaw)
            local offset = Vector(math.cos(rad) * 50, math.sin(rad) * 50, 0)
            local spawnPos = ply:GetPos() + offset + Vector(0, 0, 40)
            
            -- Boden check mit TraceHull für bessere Kollision
            local trace = util.TraceHull({
                start = spawnPos,
                endpos = spawnPos - Vector(0, 0, 100),
                mins = Vector(-16, -16, 0),
                maxs = Vector(16, 16, 72),
                filter = ply
            })
            
            if trace.Hit then 
                spawnPos = trace.HitPos + Vector(0, 0, 5) 
            end

            local ent = ents.Create(entClass)
            if not IsValid(ent) then
                ply:ChatPrint("[Shop] FEHLER: Entity '" .. entClass .. "' nicht gefunden!")
                failedSpawns = failedSpawns + 1
                return
            end

            ent:SetPos(spawnPos)
            local ang = ply:GetAngles()
            ang.p = 0
            ang.r = 0
            ang.y = ang.y + yaw
            ent:SetAngles(ang)
            
            ent:Spawn()
            ent:Activate()

            -- WICHTIG: Ownership Setup (Reihenfolge ist wichtig!)
            
            -- 1. Unsere interne Owner-Variable (für Cleanup)
            ent.ShopOwner = ply
            
            -- 2. DarkRP Ownership (für TipJar, MoneyPrinter, etc.)
            -- Setowning_ent ist SAFE für Physgun (im Gegensatz zu SetOwner)
            if ent.Setowning_ent then 
                ent:Setowning_ent(ply) 
            end
            
            -- 3. FPP/SAM/CPPI Ownership (muss nach Spawn passieren)
            timer.Simple(0, function()
                if not IsValid(ent) then return end
                
                -- CPPI (Falcos Prop Protection Standard)
                if CPPI and ent.CPPISetOwner then 
                    local success, err = pcall(function()
                        ent:CPPISetOwner(ply)
                    end)
                    if not success then
                        print("[MyShop] CPPI Error: " .. tostring(err))
                    end
                end
                
                -- SAM Admin Mod Kompatibilität
                if sam and sam.player and sam.player.set_entity_owner then
                    pcall(function()
                        sam.player.set_entity_owner(ply, ent)
                    end)
                elseif sam and sam.entity and sam.entity.set_owner then
                    pcall(function()
                        sam.entity.set_owner(ent, ply)
                    end)
                end
                
                -- S-Admin (anderes Admin System)
                if sAdmin and sAdmin.SetOwner then
                    pcall(function()
                        sAdmin.SetOwner(ent, ply)
                    end)
                end
            end)
            
            -- 4. Networked Vars für Client (nur wenn supported)
            if ent.SetNW2Entity then
                ent:SetNW2Entity("Owner", ply)
                ent:SetNW2String("OwnerName", ply:Nick())
                ent:SetNW2String("ShopItemID", item.id)
            end

            -- 5. Physics Setup (WICHTIG für Beweglichkeit!)
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                phys:Wake()
                phys:EnableMotion(true)
                phys:ClearVelocity() -- Keine wilden Flugbewegungen
                
                -- Unfreeze damit es nicht eingefroren ist
                if phys.IsFrozen and phys:IsFrozen() then
                    phys:EnableMotion(true)
                end
                
                -- Falls es eine Masse hat, sicherstellen dass es beweglich ist
                if phys.GetMass and phys:GetMass() > 0 then
                    phys:EnableMotion(true)
                end
            end
            
            -- Speziell für DarkRP Entities: Manche brauchen extra Setup
            if entClass == "darkrp_tip_jar" or entClass == "darkrp_tip_jar" then
                -- TipJar spezifische Initialisierung falls nötig
                if ent.Setowning_ent then
                    ent:Setowning_ent(ply)
                end
            end
            
            spawnedCount = spawnedCount + 1
            
            -- Sound nur beim ersten Item
            if i == 1 then
                ply:EmitSound("ambient/levels/labs/coinslot1.wav", 60, 100)
            end
        end)
    end
    
    -- Erfolgsbestätigung nach allen Spawns
    timer.Simple(amount * 0.1 + 0.2, function()
        if IsValid(ply) then
            if spawnedCount > 0 then
                ply:ChatPrint("[Shop] " .. item.name .. " x" .. spawnedCount .. " gekauft!")
            end
            if failedSpawns > 0 then
                ply:ChatPrint("[Shop] WARNUNG: " .. failedSpawns .. " Items konnten nicht gespawnt werden!")
                -- Geld für fehlgeschlagene zurückgeben
                local refund = item.price * failedSpawns
                ply:addMoney(refund)
            end
        end
    end)
    
    return true
end

function MyShop.BuyItem(ply, item_id, amount)
    amount = math.Clamp(amount or 1, 1, 10)
    
    local item = MyShop.ItemCache[item_id]
    if not item then
        -- Suche in Items falls nicht gecached
        for _, v in ipairs(MyShop.Items or {}) do
            if v.id == item_id then
                item = v
                MyShop.ItemCache[item_id] = v
                break
            end
        end
    end

    if not item then
        ply:ChatPrint("[Shop] Item nicht gefunden!")
        return
    end

    -- JOB CHECK (Wichtig!)
    if not MyShop.CanSeeCategory(ply, item.category) then
        ply:ChatPrint("[Shop] Dieses Item ist für deinen Job nicht verfuegbar!")
        ply:ChatPrint("[Shop] Kategorie: " .. item.category)
        return
    end

    local totalPrice = item.price * amount
    
    if not ply:canAfford(totalPrice) then
        ply:ChatPrint("[Shop] Nicht genug Geld! Benoetigt: " .. totalPrice .. " $")
        return
    end

    -- Geld abziehen (vor dem Spawn, da Spawn Zeit braucht)
    ply:addMoney(-totalPrice)

    -- Entity Spawn (oder onBuy)
    if item.spawnEntity or item.spawnVehicle then
        local success = MyShop.SpawnEntityForPlayer(ply, item, amount)
        if not success then
            -- Wenn Spawn fehlschlägt, Geld zurück
            ply:addMoney(totalPrice)
            ply:ChatPrint("[Shop] Kauf fehlgeschlagen! Geld zurueckerstattet.")
            return
        end
    end

    -- onBuy Funktion (nur wenn kein Entity gespawnt wird oder zusätzlich)
    if item.onBuy then
        for i = 1, amount do
            timer.Simple(i * 0.05, function()
                if IsValid(ply) then
                    local success, err = pcall(function() item.onBuy(ply) end)
                    if not success then
                        print("[MyShop Error] onBuy failed for " .. item.id .. ": " .. err)
                    end
                end
            end)
        end
    end

    print("[MyShop] " .. ply:Nick() .. " bought " .. item.name .. " x" .. amount .. " for " .. totalPrice)
end

-- Cleanup beim Disconnect (alle Entities des Spielers entfernen)
hook.Add("PlayerDisconnected", "MyShop_CleanupEntities", function(ply)
    local count = 0
    for _, ent in ipairs(ents.GetAll()) do
        if ent.ShopOwner == ply then
            ent:Remove()
            count = count + 1
        end
    end
    if count > 0 then
        print("[MyShop] Cleaned up " .. count .. " entities from " .. ply:Nick())
    end
end)

-- PHYSGUN SUPPORT: Erlaube dem ShopOwner sein Entity zu bewegen
-- (Falls FPP/SAM das blockieren, überschreibt das hier)
hook.Add("PhysgunPickup", "MyShop_AllowOwnerPickup", function(ply, ent)
    if not IsValid(ent) or not IsValid(ply) then return end
    
    -- Prüfe unseren ShopOwner
    if ent.ShopOwner == ply then
        return true -- Erlaubt das Aufheben
    end
    
    -- Prüfe CPPI Owner (FPP/SAM Fallback)
    if ent.CPPIGetOwner then
        local owner = ent:CPPIGetOwner()
        if owner == ply then
            return true
        end
    end
end)

-- FPP Kompatibilität: Setze Owner auch bei Undo/Cleanup
hook.Add("PlayerSpawnedSENT", "MyShop_TrackSpawned", function(ply, ent)
    -- Wenn das Entity von uns gespawnt wurde (erkennbar an ShopOwner)
    if ent.ShopOwner then
        -- Stelle sicher dass FPP es registriert
        if CPPI and ent.CPPISetOwner then
            ent:CPPISetOwner(ent.ShopOwner)
        end
    end
end)

-- Prevent Prop Minge (Optional: Verhindere dass andere Spieler es mit Toolgun entfernen)
hook.Add("CanTool", "MyShop_ProtectEntities", function(ply, trace, tool)
    local ent = trace.Entity
    if not IsValid(ent) then return end
    
    -- Nur wenn es ein Shop Entity ist
    if ent.ShopOwner and ent.ShopOwner ~= ply then
        -- Erlaube Remover nur für Admins
        if tool == "remover" and not ply:IsAdmin() then
            ply:ChatPrint("[Shop] Das gehört " .. ent.ShopOwner:Nick() .. "!")
            return false
        end
    end
end)