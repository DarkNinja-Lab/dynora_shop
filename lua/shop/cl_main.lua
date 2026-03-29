--[[
    DYNORA 24/7 SHOP - GTA Style Interface
    Job-Lock System: Zeigt nur Kategorien/Items für aktuellen Job
]]

local PANEL = {}

MyShop = MyShop or {}
MyShop.Cache = MyShop.Cache or {
    VisibleCategories = {},
    ItemsByCategory = {},
    AllVisibleItems = {},
    Favorites = {},
    History = {},
    Initialized = false,
    Materials = {},
    CurrentJob = nil
}

MyShop.Cooldowns = MyShop.Cooldowns or {
    lastMultiBuy = 0,
    lastSingleBuy = 0,
    buyCount = 0,
    buyResetTime = 0
}

MyShop.Stats = MyShop.Stats or {
    totalSpent = 0,
    totalBought = 0,
    mostBoughtItem = nil,
    mostBoughtCount = 0,
    itemCounts = {}
}

-- GTA STYLE COLORS
local COL = {
    bg = Color(10, 15, 25, 250),
    bgDark = Color(5, 8, 15, 255),
    bgPanel = Color(20, 28, 40, 240),
    bgHeader = Color(15, 22, 35, 255),
    primary = Color(0, 120, 215),
    primaryDark = Color(0, 90, 160),
    primaryLight = Color(60, 160, 255),
    accent = Color(255, 180, 0),
    accentRed = Color(220, 50, 50),
    accentGreen = Color(50, 200, 100),
    accentOrange = Color(255, 140, 0),
    text = Color(240, 245, 255),
    textMuted = Color(140, 155, 175),
    textDark = Color(80, 95, 115),
    border = Color(40, 55, 75, 150),
    borderLight = Color(60, 80, 105, 200),
    rarity = {
        common = Color(200, 200, 200),
        uncommon = Color(80, 220, 120),
        rare = Color(80, 160, 255),
        epic = Color(180, 80, 255),
        legendary = Color(255, 180, 60)
    }
}

local ICONS = {
    cart = "icon16/basket.png",
    fav = "icon16/star.png",
    favEmpty = "icon16/bullet_white.png",
    search = "icon16/magnifier.png",
    close = "icon16/cross.png",
    history = "icon16/time.png",
    add = "icon16/add.png",
    remove = "icon16/delete.png",
    buy = "icon16/money.png",
    chart = "icon16/chart_bar.png",
    lock = "icon16/lock.png"
}

-- Material Cache
function MyShop.GetMaterial(path)
    if not MyShop.Cache.Materials[path] then
        MyShop.Cache.Materials[path] = Material(path, "smooth noclamp")
    end
    return MyShop.Cache.Materials[path]
end

local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(num)
end

-- BLUR FUNCTION
local blurMat = Material("pp/blurscreen")
local function DrawGTABlur(panel, amount)
    local x, y = panel:LocalToScreen(0, 0)
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(blurMat)
    for i = -1, 1, 0.12 do
        blurMat:SetFloat("$blur", (i * amount) + 3)
        blurMat:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
    end
end

-- CACHE BUILDER - Nur sichtbare Items für aktuellen Job
function MyShop.BuildCache(forceRebuild)
    if not IsValid(LocalPlayer()) then 
        timer.Simple(0.5, function() MyShop.BuildCache(true) end)
        return 
    end
    
    local currentTeam = LocalPlayer():Team()
    local jobName = team.GetName(currentTeam) or "Unknown"
    
    -- Nur neu builden wenn Job gewechselt oder forced
    if MyShop.Cache.Initialized and not forceRebuild and MyShop.Cache.CurrentJob == currentTeam then 
        return 
    end
    
    MyShop.Cache.CurrentJob = currentTeam
    MyShop.Cache.VisibleCategories = {}
    MyShop.Cache.ItemsByCategory = {}
    MyShop.Cache.AllVisibleItems = {}
    
    print("[MyShop] Building cache for Job: " .. jobName .. " (Team: " .. currentTeam .. ")")
    
    -- Filtere Kategorien nach Job
    for _, cat in ipairs(MyShop.Categories or {}) do
        local canSee = false
        
        -- Prüfe Job-Lock
        if not cat.jobs or #cat.jobs == 0 then
            canSee = true
            print("[MyShop] Category '" .. cat.name .. "' is PUBLIC")
        else
            for _, jobName in ipairs(cat.jobs) do
                local jobValue = _G[jobName]
                if jobValue and currentTeam == jobValue then
                    canSee = true
                    print("[MyShop] Category '" .. cat.name .. "' ALLOWED for " .. jobName)
                    break
                end
            end
            if not canSee then
                print("[MyShop] Category '" .. cat.name .. "' DENIED for current job")
            end
        end
        
        if canSee then
            table.insert(MyShop.Cache.VisibleCategories, cat)
            MyShop.Cache.ItemsByCategory[cat.name] = {}
            
            -- Filtere Items dieser Kategorie
            for _, item in ipairs(MyShop.Items or {}) do
                if item.category == cat.name then
                    table.insert(MyShop.Cache.ItemsByCategory[cat.name], item)
                    table.insert(MyShop.Cache.AllVisibleItems, item)
                end
            end
            
            print("[MyShop] Added category '" .. cat.name .. "' with " .. #MyShop.Cache.ItemsByCategory[cat.name] .. " items")
        end
    end
    
    -- Lade gespeicherte Daten
    MyShop.Cache.Favorites = util.JSONToTable(file.Read("myshop_favorites.txt", "DATA") or "[]") or {}
    MyShop.Cache.History = util.JSONToTable(file.Read("myshop_history.txt", "DATA") or "[]") or {}
    
    local statsData = util.JSONToTable(file.Read("myshop_stats.txt", "DATA") or "{}") or {}
    MyShop.Stats.totalSpent = statsData.totalSpent or 0
    MyShop.Stats.totalBought = statsData.totalBought or 0
    MyShop.Stats.mostBoughtItem = statsData.mostBoughtItem
    MyShop.Stats.mostBoughtCount = statsData.mostBoughtCount or 0
    MyShop.Stats.itemCounts = statsData.itemCounts or {}
    
    MyShop.Cache.Initialized = true
    
    -- UI neu laden wenn offen
    if IsValid(MyShop_Menu) then
        MyShop_Menu:Remove()
        MyShop_Menu = vgui.Create("MyShop_Menu")
    end
end

function MyShop.SaveStats()
    file.Write("myshop_stats.txt", util.TableToJSON({
        totalSpent = MyShop.Stats.totalSpent,
        totalBought = MyShop.Stats.totalBought,
        mostBoughtItem = MyShop.Stats.mostBoughtItem,
        mostBoughtCount = MyShop.Stats.mostBoughtCount,
        itemCounts = MyShop.Stats.itemCounts
    }))
end

function MyShop.SaveFavorites()
    file.Write("myshop_favorites.txt", util.TableToJSON(MyShop.Cache.Favorites))
end

function MyShop.SaveHistory()
    while #MyShop.Cache.History > 20 do
        table.remove(MyShop.Cache.History, 1)
    end
    file.Write("myshop_history.txt", util.TableToJSON(MyShop.Cache.History))
end

function MyShop.AddToHistory(item, amount)
    table.insert(MyShop.Cache.History, {
        id = item.id,
        name = item.name,
        amount = amount,
        price = item.price * amount,
        time = os.time()
    })
    MyShop.SaveHistory()
end

function MyShop.IsFavorite(itemId)
    for _, id in ipairs(MyShop.Cache.Favorites) do
        if id == itemId then return true end
    end
    return false
end

function MyShop.ToggleFavorite(itemId)
    for i, id in ipairs(MyShop.Cache.Favorites) do
        if id == itemId then
            table.remove(MyShop.Cache.Favorites, i)
            MyShop.SaveFavorites()
            return false
        end
    end
    table.insert(MyShop.Cache.Favorites, itemId)
    MyShop.SaveFavorites()
    return true
end

function MyShop.UpdateStats(item, amount, price)
    MyShop.Stats.totalSpent = MyShop.Stats.totalSpent + price
    MyShop.Stats.totalBought = MyShop.Stats.totalBought + amount
    
    local currentCount = MyShop.Stats.itemCounts[item.id] or 0
    currentCount = currentCount + amount
    MyShop.Stats.itemCounts[item.id] = currentCount
    
    if currentCount > MyShop.Stats.mostBoughtCount then
        MyShop.Stats.mostBoughtCount = currentCount
        MyShop.Stats.mostBoughtItem = item.name
    end
    
    MyShop.SaveStats()
end

function MyShop.CanBuy(amount)
    local now = CurTime()
    
    if now - MyShop.Cooldowns.buyResetTime >= 60 then
        MyShop.Cooldowns.buyCount = 0
        MyShop.Cooldowns.buyResetTime = now
    end
    
    if MyShop.Cooldowns.buyCount >= 50 then
        return false, "Anti-Spam: Max 50 Käufe pro Minute!"
    end
    
    if amount == 1 then
        if now - MyShop.Cooldowns.lastSingleBuy < 2 then
            local wait = math.ceil(2 - (now - MyShop.Cooldowns.lastSingleBuy))
            return false, "Warte " .. wait .. " Sekunden..."
        end
        MyShop.Cooldowns.lastSingleBuy = now
        MyShop.Cooldowns.buyCount = MyShop.Cooldowns.buyCount + 1
        return true
    else
        if now - MyShop.Cooldowns.lastMultiBuy < 30 then
            local wait = math.ceil(30 - (now - MyShop.Cooldowns.lastMultiBuy))
            return false, "Multi-Buy Cooldown: " .. wait .. " Sekunden..."
        end
        MyShop.Cooldowns.lastMultiBuy = now
        MyShop.Cooldowns.lastSingleBuy = now
        MyShop.Cooldowns.buyCount = MyShop.Cooldowns.buyCount + 1
        return true
    end
end

-- ==================== MAIN PANEL ====================

function PANEL:Init()
    MyShop.BuildCache()
    
    -- GRÖSSERES FENSTER (1300x850 statt 1100x750)
    local w, h = 1300, 850
    self:SetSize(w, h)
    self:Center()
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:MakePopup()
    self:SetAlpha(0)
    self:AlphaTo(255, 0.3, 0)
    self:SetDraggable(false)
    
    self.CurrentCategory = nil
    self.SearchText = ""
    self.Cart = {}
    self.ShowingFavorites = false
    
    self.Paint = function(s, w, h)
        DrawGTABlur(s, 8)
        draw.RoundedBox(0, 0, 0, w, h, COL.bg)
        draw.RoundedBox(0, 0, 0, w, 50, COL.bgHeader)
        surface.SetDrawColor(COL.primary)
        surface.DrawRect(0, 48, w, 2)
        
        -- Logo
        local logoX = 20
        surface.SetFont("DermaLarge")
        local logoW, _ = surface.GetTextSize("24/7")
        draw.SimpleText("24/7", "DermaLarge", logoX, 25, COL.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        
        local sepX = logoX + logoW + 15
        draw.SimpleText("|", "DermaLarge", sepX, 25, COL.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        
        local textX = sepX + 20
        draw.SimpleText("SHOP", "DermaDefaultBold", textX, 25, COL.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        
        -- UHRZEIT WEITER LINKS (w - 200 statt w - 120)
        draw.SimpleText(os.date("%H:%M:%S"), "DermaDefault", w - 200, 25, COL.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Job Info
        local ply = LocalPlayer()
        draw.SimpleText(team.GetName(ply:Team()), "DermaDefault", w - 350, 25, COL.primaryLight, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    
    -- Close Button
    local closeBtn = vgui.Create("DButton", self)
    closeBtn:SetSize(40, 40)
    closeBtn:SetPos(w - 55, 5)
    closeBtn:SetText("X")
    closeBtn:SetFont("DermaLarge")
    closeBtn:SetTextColor(COL.textMuted)
    
    closeBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, COL.accentRed)
            self:SetTextColor(COL.text)
        else
            self:SetTextColor(COL.textMuted)
        end
    end
    
    closeBtn.DoClick = function()
        self:AlphaTo(0, 0.2, 0, function() self:Remove() end)
    end
    
    -- Stats Button
    local statsBtn = vgui.Create("DButton", self)
    statsBtn:SetSize(40, 40)
    statsBtn:SetPos(w - 105, 5)
    statsBtn:SetText("")
    statsBtn:SetTooltip("Statistiken")
    
    local statsIcon = vgui.Create("DImage", statsBtn)
    statsIcon:SetSize(16, 16)
    statsIcon:Center()
    statsIcon:SetMaterial(MyShop.GetMaterial(ICONS.chart))
    
    statsBtn.Paint = function(s, w, h)
        local col = s:IsHovered() and COL.primary or COL.bgPanel
        draw.RoundedBox(8, 0, 0, w, h, col)
    end
    
    statsBtn.DoClick = function()
        self:ShowStats()
    end
    
    self:BuildSidebar(w, h)
    self:BuildMainArea(w, h)
    self:BuildCartButton(w, h)
    
    -- Lade erste sichtbare Kategorie
    if MyShop.Cache.VisibleCategories[1] then
        self:LoadCategory(MyShop.Cache.VisibleCategories[1].name)
    end
end

function PANEL:BuildSidebar(w, h)
    local nav = vgui.Create("DPanel", self)
    nav:SetPos(0, 50)
    nav:SetSize(220, h - 50)
    nav.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.bgDark)
        surface.SetDrawColor(COL.border)
        surface.DrawLine(w - 1, 0, w - 1, h)
    end
    
    -- Search Bar
    local searchPanel = vgui.Create("DPanel", nav)
    searchPanel:SetPos(10, 20)
    searchPanel:SetSize(200, 45)
    searchPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COL.bgPanel)
        surface.SetDrawColor(COL.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    local searchIcon = vgui.Create("DImage", searchPanel)
    searchIcon:SetSize(16, 16)
    searchIcon:SetPos(12, 14)
    searchIcon:SetMaterial(MyShop.GetMaterial(ICONS.search))
    
    local searchEntry = vgui.Create("DTextEntry", searchPanel)
    searchEntry:SetSize(165, 35)
    searchEntry:SetPos(35, 5)
    searchEntry:SetPlaceholderText("Suche...")
    searchEntry:SetTextColor(COL.text)
    searchEntry:SetDrawBackground(false)
    searchEntry:SetFont("DermaDefault")
    
    searchEntry.OnChange = function(s)
        self.SearchText = string.lower(s:GetText())
        if self.SearchText == "" then
            if self.ShowingFavorites then
                self:ShowFavorites()
            elseif self.CurrentCategory then
                self:LoadCategory(self.CurrentCategory)
            end
        else
            self:DoGlobalSearch()
        end
    end
    
    -- Favoriten Button
    local favBtn = vgui.Create("DButton", nav)
    favBtn:SetPos(10, 75)
    favBtn:SetSize(200, 45)
    favBtn:SetText("")
    favBtn.id = "favorites"
    
    favBtn.Paint = function(self, w, h)
        local isActive = self.ShowingFavorites
        local isHover = self:IsHovered()
        
        if isActive then
            draw.RoundedBox(4, 0, 0, w, h, COL.accent)
            surface.SetDrawColor(COL.accentOrange)
            surface.DrawRect(0, 0, 4, h)
        elseif isHover then
            draw.RoundedBox(4, 0, 0, w, h, COL.bgPanel)
            surface.SetDrawColor(COL.accent)
            surface.DrawRect(0, 0, 4, h)
        end
        
        draw.SimpleText("★", "DermaLarge", 15, h/2, isActive and COL.text or COL.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("FAVORITEN", "DermaDefaultBold", 45, h/2, isActive and COL.text or (isHover and COL.text or COL.textMuted), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    favBtn.DoClick = function()
        self.ShowingFavorites = true
        self.CurrentCategory = nil
        for _, btn in ipairs(self.CategoryButtons or {}) do
            btn.active = false
        end
        self:ShowFavorites()
    end
    
    -- Separator
    local sep = vgui.Create("DPanel", nav)
    sep:SetPos(15, 130)
    sep:SetSize(190, 2)
    sep.Paint = function(self, w, h)
        surface.SetDrawColor(COL.border)
        surface.DrawRect(0, 0, w, h)
    end
    
    -- Kategorien Titel
    local catTitle = vgui.Create("DLabel", nav)
    catTitle:SetPos(15, 145)
    catTitle:SetSize(190, 25)
    catTitle:SetText("KATEGORIEN")
    catTitle:SetFont("DermaDefaultBold")
    catTitle:SetTextColor(COL.accent)
    
    -- Kategorien Liste - NUR SICHTBARE
    local yPos = 175
    self.CategoryButtons = {}
    
    -- Hinweis wenn keine Kategorien verfügbar
    if #MyShop.Cache.VisibleCategories == 0 then
        local noCat = vgui.Create("DLabel", nav)
        noCat:SetPos(15, yPos)
        noCat:SetSize(190, 60)
        noCat:SetText("Keine Kategorien für deinen Job verfügbar")
        noCat:SetFont("DermaDefault")
        noCat:SetTextColor(COL.accentRed)
        noCat:SetWrap(true)
    else
        for _, cat in ipairs(MyShop.Cache.VisibleCategories) do
            local btn = vgui.Create("DButton", nav)
            btn:SetPos(10, yPos)
            btn:SetSize(200, 45)
            btn:SetText("")
            btn.Category = cat.name
            btn.active = false
            
            btn.Paint = function(self, w, h)
                local isActive = self.active
                local isHover = self:IsHovered()
                
                if isActive then
                    draw.RoundedBox(4, 0, 0, w, h, COL.primary)
                    surface.SetDrawColor(COL.primaryLight)
                    surface.DrawRect(0, 0, 4, h)
                elseif isHover then
                    draw.RoundedBox(4, 0, 0, w, h, COL.bgPanel)
                    surface.SetDrawColor(COL.primary)
                    surface.DrawRect(0, 0, 4, h)
                end
                
                draw.SimpleText("▪", "DermaLarge", 15, h/2, isActive and COL.text or COL.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(string.upper(cat.name), "DermaDefaultBold", 35, h/2, isActive and COL.text or (isHover and COL.text or COL.textMuted), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            
            btn.DoClick = function()
                self.ShowingFavorites = false
                for _, b in ipairs(self.CategoryButtons) do
                    b.active = false
                end
                self.active = true
                self:LoadCategory(cat.name)
            end
            
            table.insert(self.CategoryButtons, btn)
            yPos = yPos + 50
        end
    end
    
    -- Verlauf Button
    local histBtn = vgui.Create("DButton", nav)
    histBtn:SetPos(10, h - 60)
    histBtn:SetSize(200, 40)
    histBtn:SetText("")
    
    histBtn.Paint = function(self, w, h)
        local isHover = self:IsHovered()
        draw.RoundedBox(4, 0, 0, w, h, isHover and COL.bgPanel or COL.bgDark)
        draw.SimpleText("VERLAUF", "DermaDefaultBold", 45, h/2, isHover and COL.text or COL.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    local histIcon = vgui.Create("DImage", histBtn)
    histIcon:SetSize(16, 16)
    histIcon:SetPos(15, 12)
    histIcon:SetMaterial(MyShop.GetMaterial(ICONS.history))
    
    histBtn.DoClick = function()
        self:ShowHistory()
    end
end

function PANEL:BuildMainArea(w, h)
    self.MainPanel = vgui.Create("DPanel", self)
    self.MainPanel:SetPos(220, 50)
    self.MainPanel:SetSize(w - 220, h - 50)
    self.MainPanel.Paint = function() end
    
    self.ScrollPanel = vgui.Create("DScrollPanel", self.MainPanel)
    self.ScrollPanel:SetPos(15, 15)
    self.ScrollPanel:SetSize(self.MainPanel:GetWide() - 30, self.MainPanel:GetTall() - 30)
    
    local vbar = self.ScrollPanel:GetVBar()
    vbar:SetWide(6)
    vbar.Paint = function() end
    vbar.btnGrip.Paint = function(s, w, h)
        local hover = s:IsHovered()
        draw.RoundedBox(4, 0, 0, w, h, hover and COL.primaryLight or COL.primary)
    end
    
    self.ItemGrid = vgui.Create("DIconLayout", self.ScrollPanel)
    self.ItemGrid:SetSize(self.ScrollPanel:GetWide() - 15, self.ScrollPanel:GetTall())
    self.ItemGrid:SetPos(0, 0)
    self.ItemGrid:SetSpaceX(15)
    self.ItemGrid:SetSpaceY(15)
end

function PANEL:BuildCartButton(w, h)
    self.CartBtn = vgui.Create("DButton", self)
    self.CartBtn:SetSize(70, 70)
    self.CartBtn:SetPos(w - 95, h - 95)
    self.CartBtn:SetText("")
    
    self.CartBtn.Paint = function(s, w, h)
        draw.RoundedBox(35, 0, 0, w, h, COL.accent)
        
        if s:IsHovered() then
            surface.SetDrawColor(255,255,255,30)
            surface.DrawRect(0, 0, w, h)
        end
        
        surface.SetMaterial(MyShop.GetMaterial(ICONS.cart))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(22, 20, 26, 26)
        
        local cartCount = table.Count(self.Cart)
        if cartCount > 0 then
            draw.RoundedBox(12, w-22, 5, 24, 24, COL.accentRed)
            draw.SimpleText(tostring(cartCount), "DermaDefaultBold", w-10, 17, COL.text, TEXT_ALIGN_CENTER)
        end
    end
    
    self.CartBtn.DoClick = function()
        self:ShowCart()
    end
end

function PANEL:LoadCategory(category)
    self.CurrentCategory = category
    self.ShowingFavorites = false
    
    for _, btn in ipairs(self.CategoryButtons) do
        btn.active = (btn.Category == category)
    end
    
    self.ItemGrid:Clear()
    
    local items = MyShop.Cache.ItemsByCategory[category] or {}
    
    if #items == 0 then
        local empty = vgui.Create("DLabel", self.ItemGrid)
        empty:SetText("Keine Items in dieser Kategorie verfügbar")
        empty:SetFont("DermaDefaultBold")
        empty:SetTextColor(COL.textMuted)
        empty:SetSize(400, 50)
        empty:SetContentAlignment(5)
    else
        for _, item in ipairs(items) do
            self:CreateItemCard(item)
        end
    end
end

function PANEL:ShowFavorites()
    self.ItemGrid:Clear()
    
    local hasFavorites = false
    for _, item in ipairs(MyShop.Cache.AllVisibleItems) do
        if MyShop.IsFavorite(item.id) then
            self:CreateItemCard(item)
            hasFavorites = true
        end
    end
    
    if not hasFavorites then
        local empty = vgui.Create("DLabel", self.ItemGrid)
        empty:SetText("Keine Favoriten vorhanden. Klicke auf den Stern bei Items!")
        empty:SetFont("DermaDefault")
        empty:SetTextColor(COL.textMuted)
        empty:SetSize(400, 50)
        empty:SetContentAlignment(5)
    end
end

function PANEL:DoGlobalSearch()
    self.ItemGrid:Clear()
    self.CurrentCategory = nil
    self.ShowingFavorites = false
    
    for _, btn in ipairs(self.CategoryButtons) do
        btn.active = false
    end
    
    if self.SearchText == "" then return end
    
    local found = false
    for _, item in ipairs(MyShop.Cache.AllVisibleItems) do
        local name = string.lower(item.name)
        local desc = string.lower(item.description or "")
        local cat = string.lower(item.category or "")
        
        if string.find(name, self.SearchText) or string.find(desc, self.SearchText) or string.find(cat, self.SearchText) then
            self:CreateItemCard(item)
            found = true
        end
    end
    
    if not found then
        local empty = vgui.Create("DLabel", self.ItemGrid)
        empty:SetText("Keine Items gefunden")
        empty:SetFont("DermaDefault")
        empty:SetTextColor(COL.textMuted)
        empty:SetSize(400, 50)
        empty:SetContentAlignment(5)
    end
end

function PANEL:CreateItemCard(item)
    local isFav = MyShop.IsFavorite(item.id)
    
    local card = vgui.Create("DPanel", self.ItemGrid)
    card:SetSize(200, 280)
    
    card.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COL.bgPanel)
        
        local lineCol = item.rarity and COL.rarity[item.rarity] or COL.primary
        surface.SetDrawColor(lineCol)
        surface.DrawRect(10, 10, w - 20, 3)
        
        if s:IsHovered() then
            surface.SetDrawColor(COL.primary.r, COL.primary.g, COL.primary.b, 30)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(COL.primary)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
    end
    
    card.OnMousePressed = function(s, code)
        if code == MOUSE_RIGHT then
            local canDo, msg = MyShop.CanBuy(1)
            if not canDo then
                notification.AddLegacy(msg, NOTIFY_ERROR, 2)
                surface.PlaySound("buttons/button10.wav")
                return
            end
            self:QuickBuy(item, 1)
        elseif code == MOUSE_LEFT then
            if input.IsKeyDown(KEY_LSHIFT) then
                local canDo, msg = MyShop.CanBuy(10)
                if not canDo then
                    notification.AddLegacy(msg, NOTIFY_ERROR, 2)
                    surface.PlaySound("buttons/button10.wav")
                    return
                end
                self:QuickBuy(item, 10)
            else
                local amount = tonumber(s.AmountEntry and s.AmountEntry:GetText()) or 1
                amount = math.Clamp(amount, 1, 10)
                
                local canDo, msg = MyShop.CanBuy(amount)
                if not canDo then
                    notification.AddLegacy(msg, NOTIFY_ERROR, 2)
                    surface.PlaySound("buttons/button10.wav")
                    return
                end
                
                self:ShowConfirmDialog(item, amount)
            end
        end
    end
    
    -- Favoriten Button
    local favBtn = vgui.Create("DButton", card)
    favBtn:SetSize(28, 28)
    favBtn:SetPos(165, 8)
    favBtn:SetText("")
    
    local favIcon = vgui.Create("DImage", favBtn)
    favIcon:SetSize(16, 16)
    favIcon:Center()
    favIcon:SetMaterial(MyShop.GetMaterial(isFav and ICONS.fav or ICONS.favEmpty))
    
    favBtn.Paint = function(s, w, h)
        draw.RoundedBox(14, 0, 0, w, h, Color(0,0,0,100))
        if s:IsHovered() then
            draw.RoundedBox(14, 0, 0, w, h, Color(255,255,255,20))
        end
    end
    
    favBtn.DoClick = function()
        local newFav = MyShop.ToggleFavorite(item.id)
        favIcon:SetMaterial(MyShop.GetMaterial(newFav and ICONS.fav or ICONS.favEmpty))
        
        if self.ShowingFavorites then
            timer.Simple(0.1, function()
                self:ShowFavorites()
            end)
        end
    end
    
    -- Model Panel
    local model = vgui.Create("DModelPanel", card)
    model:SetSize(180, 120)
    model:SetPos(10, 35)
    model:SetModel(item.model or "models/error.mdl")
    model:SetFOV(45)
    model:SetAnimated(false)
    
    if model.Entity then
        local mn, mx = model.Entity:GetRenderBounds()
        local size = math.max(mn:Distance(mx))
        model:SetCamPos(Vector(size, size, size) * 0.5)
        model:SetLookAt((mn + mx) * 0.5)
        model.Entity:SetAngles(Angle(0, 45, 0))
    end
    
    -- Name
    local nameLabel = vgui.Create("DLabel", card)
    nameLabel:SetSize(180, 20)
    nameLabel:SetPos(10, 160)
    nameLabel:SetText(item.name)
    nameLabel:SetFont("DermaDefaultBold")
    nameLabel:SetTextColor(COL.text)
    nameLabel:SetContentAlignment(5)
    
    -- Description
    local descLabel = vgui.Create("DLabel", card)
    descLabel:SetSize(180, 35)
    descLabel:SetPos(10, 180)
    descLabel:SetText(item.description or "")
    descLabel:SetFont("DermaDefault")
    descLabel:SetTextColor(COL.textMuted)
    descLabel:SetWrap(true)
    descLabel:SetContentAlignment(5)
    
    -- Price
    local priceLabel = vgui.Create("DLabel", card)
    priceLabel:SetSize(180, 20)
    priceLabel:SetPos(10, 215)
    priceLabel:SetText(FormatNumber(item.price) .. " $")
    priceLabel:SetFont("DermaDefaultBold")
    priceLabel:SetTextColor(COL.accentGreen)
    priceLabel:SetContentAlignment(5)
    
    -- Amount Entry
    local amountPanel = vgui.Create("DPanel", card)
    amountPanel:SetSize(60, 30)
    amountPanel:SetPos(10, 245)
    amountPanel.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL.bgDark)
        surface.SetDrawColor(COL.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    local amountEntry = vgui.Create("DTextEntry", amountPanel)
    amountEntry:Dock(FILL)
    amountEntry:DockMargin(5, 5, 5, 5)
    amountEntry:SetText("1")
    amountEntry:SetTextColor(COL.text)
    amountEntry:SetDrawBackground(false)
    amountEntry:SetNumeric(true)
    card.AmountEntry = amountEntry
    
    amountEntry.OnChange = function(s)
        local val = tonumber(s:GetText()) or 1
        if val > 10 then s:SetText("10")
        elseif val < 1 then s:SetText("1") end
    end
    
    -- Buy Button
    local buyBtn = vgui.Create("DButton", card)
    buyBtn:SetSize(75, 30)
    buyBtn:SetPos(80, 245)
    buyBtn:SetText("KAUFEN")
    buyBtn:SetFont("DermaDefaultBold")
    buyBtn:SetTextColor(COL.text)
    
    buyBtn.Paint = function(s, w, h)
        local col = s:IsHovered() and COL.accentGreen or Color(COL.accentGreen.r, COL.accentGreen.g, COL.accentGreen.b, 150)
        draw.RoundedBox(6, 0, 0, w, h, col)
    end
    
    buyBtn.DoClick = function()
        local amount = tonumber(amountEntry:GetText()) or 1
        amount = math.Clamp(amount, 1, 10)
        
        local canDo, msg = MyShop.CanBuy(amount)
        if not canDo then
            notification.AddLegacy(msg, NOTIFY_ERROR, 2)
            surface.PlaySound("buttons/button10.wav")
            return
        end
        
        self:ShowConfirmDialog(item, amount)
    end
    
    -- Cart Button
    local cartBtn = vgui.Create("DButton", card)
    cartBtn:SetSize(30, 30)
    cartBtn:SetPos(160, 245)
    cartBtn:SetText("")
    
    local cartIcon = vgui.Create("DImage", cartBtn)
    cartIcon:SetSize(16, 16)
    cartIcon:Center()
    cartIcon:SetMaterial(MyShop.GetMaterial(ICONS.add))
    
    cartBtn.Paint = function(s, w, h)
        local col = s:IsHovered() and COL.primary or COL.bgDark
        draw.RoundedBox(6, 0, 0, w, h, col)
    end
    
    cartBtn.DoClick = function()
        local amount = tonumber(amountEntry:GetText()) or 1
        amount = math.Clamp(amount, 1, 10)
        self:AddToCart(item, amount)
    end
end

function PANEL:QuickBuy(item, amount)
    net.Start("MyShop_Buy")
    net.WriteString(item.id)
    net.WriteUInt(amount, 8)
    net.WriteBool(true)
    net.SendToServer()
    
    local totalPrice = item.price * amount
    MyShop.UpdateStats(item, amount, totalPrice)
    MyShop.AddToHistory(item, amount)
    notification.AddLegacy("Gekauft: " .. item.name .. " x" .. amount, NOTIFY_GENERIC, 3)
    surface.PlaySound("buttons/button14.wav")
end

function PANEL:ShowConfirmDialog(item, amount)
    amount = math.Clamp(amount or 1, 1, 10)
    local totalPrice = item.price * amount
    
    local confirm = vgui.Create("DFrame")
    confirm:SetSize(400, 220)
    confirm:Center()
    confirm:SetTitle("")
    confirm:ShowCloseButton(false)
    confirm:MakePopup()
    confirm:SetAlpha(0)
    confirm:AlphaTo(255, 0.2, 0)
    
    confirm.Paint = function(s, w, h)
        DrawGTABlur(s, 6)
        draw.RoundedBox(8, 0, 0, w, h, COL.bg)
        surface.SetDrawColor(COL.primary)
        surface.DrawRect(0, 0, w, 3)
    end
    
    local text = vgui.Create("DLabel", confirm)
    text:Dock(TOP)
    text:SetHeight(100)
    text:SetText(item.name .. "\nMenge: " .. amount .. "\n\nGesamtpreis:\n" .. FormatNumber(totalPrice) .. " $")
    text:SetFont("DermaDefaultBold")
    text:SetTextColor(COL.text)
    text:SetContentAlignment(5)
    
    local yes = vgui.Create("DButton", confirm)
    yes:SetSize(150, 40)
    yes:SetPos(40, 160)
    yes:SetText("JA")
    yes:SetFont("DermaDefaultBold")
    yes:SetTextColor(COL.text)
    
    yes.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL.accentGreen)
    end
    
    yes.DoClick = function()
        net.Start("MyShop_Buy")
        net.WriteString(item.id)
        net.WriteUInt(amount, 8)
        net.WriteBool(false)
        net.SendToServer()
        
        MyShop.UpdateStats(item, amount, totalPrice)
        MyShop.AddToHistory(item, amount)
        confirm:Remove()
    end
    
    local no = vgui.Create("DButton", confirm)
    no:SetSize(150, 40)
    no:SetPos(210, 160)
    no:SetText("NEIN")
    no:SetFont("DermaDefaultBold")
    no:SetTextColor(COL.text)
    
    no.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL.accentRed)
    end
    
    no.DoClick = function() confirm:Remove() end
end

function PANEL:ShowStats()
    local statsFrame = vgui.Create("DFrame")
    statsFrame:SetSize(450, 350)
    statsFrame:Center()
    statsFrame:SetTitle("")
    statsFrame:ShowCloseButton(false)
    statsFrame:MakePopup()
    
    statsFrame.Paint = function(s, w, h)
        DrawGTABlur(s, 6)
        draw.RoundedBox(8, 0, 0, w, h, COL.bg)
        surface.SetDrawColor(COL.primary)
        surface.DrawRect(0, 0, w, 3)
    end
    
    local header = vgui.Create("DPanel", statsFrame)
    header:Dock(TOP)
    header:SetHeight(60)
    header.Paint = function(s, w, h)
        draw.SimpleText("STATISTIKEN", "DermaLarge", w/2, 15, COL.accent, TEXT_ALIGN_CENTER)
    end
    
    local closeBtn = vgui.Create("DButton", header)
    closeBtn:SetSize(35, 35)
    closeBtn:SetPos(400, 12)
    closeBtn:SetText("X")
    closeBtn:SetFont("DermaLarge")
    closeBtn:SetTextColor(COL.textMuted)
    
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, COL.accentRed)
            s:SetTextColor(COL.text)
        else
            s:SetTextColor(COL.textMuted)
        end
    end
    closeBtn.DoClick = function() statsFrame:Remove() end
    
    local content = vgui.Create("DPanel", statsFrame)
    content:Dock(FILL)
    content:DockMargin(20, 20, 20, 20)
    content.Paint = function() end
    
    local panels = {
        {title = "Gesamtausgaben", value = FormatNumber(MyShop.Stats.totalSpent) .. " $", color = COL.primary},
        {title = "Items gekauft", value = tostring(MyShop.Stats.totalBought), color = COL.accentGreen},
        {title = "Lieblingsitem", value = (MyShop.Stats.mostBoughtItem or "-") .. " (" .. MyShop.Stats.mostBoughtCount .. "x)", color = COL.accent},
    }
    
    for _, data in ipairs(panels) do
        local p = vgui.Create("DPanel", content)
        p:Dock(TOP)
        p:SetHeight(70)
        p:DockMargin(0, 0, 0, 10)
        p.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, COL.bgPanel)
            surface.SetDrawColor(data.color)
            surface.DrawRect(0, 0, 4, h)
            draw.SimpleText(data.title, "DermaDefault", 15, 12, COL.textMuted)
            draw.SimpleText(data.value, "DermaLarge", 15, 35, COL.text)
        end
    end
end

function PANEL:AddToCart(item, amount)
    amount = math.Clamp(amount, 1, 10)
    
    if self.Cart[item.id] then
        local newAmount = self.Cart[item.id].amount + amount
        if newAmount > 10 then newAmount = 10 end
        self.Cart[item.id].amount = newAmount
    else
        self.Cart[item.id] = {item = item, amount = amount}
    end
    
    if self.CartBtn and IsValid(self.CartBtn) then
        self.CartBtn:InvalidateLayout()
    end
    
    surface.PlaySound("buttons/button9.wav")
    notification.AddLegacy(item.name .. " zum Warenkorb hinzugefügt", NOTIFY_HINT, 2)
end

function PANEL:ShowCart()
    local cartCount = table.Count(self.Cart)
    if cartCount == 0 then
        notification.AddLegacy("Warenkorb ist leer!", NOTIFY_ERROR, 3)
        return
    end
    
    local cartFrame = vgui.Create("DFrame")
    cartFrame:SetSize(500, 450)
    cartFrame:Center()
    cartFrame:SetTitle("")
    cartFrame:ShowCloseButton(false)
    cartFrame:MakePopup()
    cartFrame:SetAlpha(0)
    cartFrame:AlphaTo(255, 0.2, 0)
    
    cartFrame.Paint = function(s, w, h)
        DrawGTABlur(s, 6)
        draw.RoundedBox(8, 0, 0, w, h, COL.bg)
        surface.SetDrawColor(COL.primary)
        surface.DrawRect(0, 0, w, 3)
    end
    
    local header = vgui.Create("DPanel", cartFrame)
    header:Dock(TOP)
    header:SetHeight(60)
    header.Paint = function(s, w, h)
        draw.SimpleText("WARENKORB", "DermaLarge", w/2, 15, COL.accent, TEXT_ALIGN_CENTER)
        draw.SimpleText(cartCount .. " Artikel", "DermaDefault", w/2, 42, COL.textMuted, TEXT_ALIGN_CENTER)
    end
    
    local closeBtn = vgui.Create("DButton", header)
    closeBtn:SetSize(35, 35)
    closeBtn:SetPos(450, 12)
    closeBtn:SetText("X")
    closeBtn:SetFont("DermaLarge")
    closeBtn:SetTextColor(COL.textMuted)
    
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, COL.accentRed)
            s:SetTextColor(COL.text)
        else
            s:SetTextColor(COL.textMuted)
        end
    end
    closeBtn.DoClick = function() cartFrame:Remove() end
    
    local list = vgui.Create("DScrollPanel", cartFrame)
    list:Dock(FILL)
    list:DockMargin(15, 10, 15, 80)
    
    local vbar = list:GetVBar()
    vbar:SetWide(5)
    vbar.Paint = function() end
    vbar.btnGrip.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, COL.primary)
    end
    
    local total = 0
    local yPos = 0
    
    for id, data in pairs(self.Cart) do
        local line = vgui.Create("DPanel", list)
        line:SetSize(450, 55)
        line:SetPos(0, yPos)
        yPos = yPos + 60
        
        local itemTotal = data.item.price * data.amount
        total = total + itemTotal
        
        line.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, COL.bgPanel)
            draw.SimpleText(data.item.name, "DermaDefaultBold", 15, 10, COL.text)
            draw.SimpleText("x" .. data.amount .. " @ " .. FormatNumber(data.item.price) .. " $", "DermaDefault", 15, 32, COL.textMuted)
            draw.SimpleText(FormatNumber(itemTotal) .. " $", "DermaDefaultBold", w-50, 27, COL.accentGreen, TEXT_ALIGN_RIGHT)
        end
        
        local removeBtn = vgui.Create("DButton", line)
        removeBtn:SetSize(25, 25)
        removeBtn:SetPos(410, 15)
        removeBtn:SetText("")
        
        local remIcon = vgui.Create("DImage", removeBtn)
        remIcon:SetSize(14, 14)
        remIcon:Center()
        remIcon:SetMaterial(MyShop.GetMaterial(ICONS.remove))
        
        removeBtn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and COL.accentRed or COL.bgDark)
        end
        
        removeBtn.DoClick = function()
            self.Cart[id] = nil
            line:Remove()
            
            local newY = 0
            for _, child in pairs(list:GetCanvas():GetChildren()) do
                if IsValid(child) and child ~= vbar then
                    child:SetPos(0, newY)
                    newY = newY + 60
                end
            end
            
            if table.Count(self.Cart) == 0 then
                cartFrame:Remove()
            else
                total = 0
                for _, d in pairs(self.Cart) do
                    total = total + (d.item.price * d.amount)
                end
                cartFrame.TotalLabel:SetText("GESAMT: " .. FormatNumber(total) .. " $")
            end
        end
    end
    
    local bottom = vgui.Create("DPanel", cartFrame)
    bottom:Dock(BOTTOM)
    bottom:SetHeight(70)
    bottom.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.bgDark)
        surface.SetDrawColor(COL.border)
        surface.DrawRect(0, 0, w, 1)
    end
    
    cartFrame.TotalLabel = vgui.Create("DLabel", bottom)
    cartFrame.TotalLabel:SetSize(200, 25)
    cartFrame.TotalLabel:SetPos(20, 10)
    cartFrame.TotalLabel:SetText("GESAMT: " .. FormatNumber(total) .. " $")
    cartFrame.TotalLabel:SetFont("DermaDefaultBold")
    cartFrame.TotalLabel:SetTextColor(COL.accent)
    
    local buyAll = vgui.Create("DButton", bottom)
    buyAll:SetSize(140, 40)
    buyAll:SetPos(20, 35)
    buyAll:SetText("KAUFEN")
    buyAll:SetFont("DermaDefaultBold")
    buyAll:SetTextColor(COL.text)
    
    buyAll.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL.accentGreen)
    end
    
    buyAll.DoClick = function()
        for id, data in pairs(self.Cart) do
            if data.amount > 1 then
                local canDo, msg = MyShop.CanBuy(data.amount)
                if not canDo then
                    notification.AddLegacy("Cooldown aktiv! " .. msg, NOTIFY_ERROR, 3)
                    return
                end
            end
        end
        
        local delay = 0
        for id, data in pairs(self.Cart) do
            timer.Simple(delay, function()
                net.Start("MyShop_Buy")
                net.WriteString(id)
                net.WriteUInt(data.amount, 8)
                net.WriteBool(false)
                net.SendToServer()
                
                MyShop.UpdateStats(data.item, data.amount, data.item.price * data.amount)
                MyShop.AddToHistory(data.item, data.amount)
            end)
            delay = delay + 0.1
        end
        
        self.Cart = {}
        cartFrame:Remove()
        notification.AddLegacy("Einkauf abgeschlossen!", NOTIFY_GENERIC, 3)
        surface.PlaySound("ambient/levels/labs/coinslot1.wav")
    end
    
    local clear = vgui.Create("DButton", bottom)
    clear:SetSize(100, 40)
    clear:SetPos(170, 35)
    clear:SetText("LEEREN")
    clear:SetFont("DermaDefaultBold")
    clear:SetTextColor(COL.text)
    
    clear.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL.accentRed)
    end
    
    clear.DoClick = function()
        self.Cart = {}
        cartFrame:Remove()
    end
    
    local closeBtn2 = vgui.Create("DButton", bottom)
    closeBtn2:SetSize(100, 40)
    closeBtn2:SetPos(280, 35)
    closeBtn2:SetText("SCHLIESSEN")
    closeBtn2:SetFont("DermaDefaultBold")
    closeBtn2:SetTextColor(COL.text)
    closeBtn2.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL.bgPanel)
        if s:IsHovered() then
            draw.RoundedBox(6, 0, 0, w, h, COL.primary)
        end
    end
    closeBtn2.DoClick = function() cartFrame:Remove() end
end

function PANEL:ShowHistory()
    local histFrame = vgui.Create("DFrame")
    histFrame:SetSize(450, 400)
    histFrame:Center()
    histFrame:SetTitle("")
    histFrame:ShowCloseButton(false)
    histFrame:MakePopup()
    
    histFrame.Paint = function(s, w, h)
        DrawGTABlur(s, 6)
        draw.RoundedBox(8, 0, 0, w, h, COL.bg)
        surface.SetDrawColor(COL.primary)
        surface.DrawRect(0, 0, w, 3)
    end
    
    local header = vgui.Create("DPanel", histFrame)
    header:Dock(TOP)
    header:SetHeight(60)
    header.Paint = function(s, w, h)
        draw.SimpleText("KAUFVERLAUF", "DermaLarge", w/2, 15, COL.accent, TEXT_ALIGN_CENTER)
    end
    
    local closeBtn = vgui.Create("DButton", header)
    closeBtn:SetSize(35, 35)
    closeBtn:SetPos(400, 12)
    closeBtn:SetText("X")
    closeBtn:SetFont("DermaLarge")
    closeBtn:SetTextColor(COL.textMuted)
    
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, COL.accentRed)
            s:SetTextColor(COL.text)
        else
            s:SetTextColor(COL.textMuted)
        end
    end
    closeBtn.DoClick = function() histFrame:Remove() end
    
    local list = vgui.Create("DScrollPanel", histFrame)
    list:Dock(FILL)
    list:DockMargin(15, 10, 15, 15)
    
    local history = MyShop.Cache.History or {}
    
    if #history == 0 then
        local empty = vgui.Create("DLabel", list)
        empty:Dock(TOP)
        empty:SetHeight(100)
        empty:SetText("Noch keine Käufe")
        empty:SetFont("DermaDefault")
        empty:SetTextColor(COL.textMuted)
        empty:SetContentAlignment(5)
    else
        for i = #history, 1, -1 do
            local entry = history[i]
            local line = vgui.Create("DPanel", list)
            line:Dock(TOP)
            line:SetHeight(45)
            line:DockMargin(0, 0, 0, 5)
            
            local timeStr = os.date("%d.%m.%Y %H:%M", entry.time)
            
            line.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, COL.bgPanel)
                draw.SimpleText(timeStr, "DermaDefault", 15, h/2, COL.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(entry.name, "DermaDefaultBold", 130, h/2, COL.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("x" .. entry.amount, "DermaDefault", w-100, h/2, COL.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                draw.SimpleText(FormatNumber(entry.price) .. " $", "DermaDefaultBold", w-15, h/2, COL.accentGreen, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
    end
end

vgui.Register("MyShop_Menu", PANEL, "DFrame")

-- Key Handler
MyShop_LastKeyCheck = 0
MyShop_KeyDown = false

hook.Add("Think", "MyShop_KeyCheck", function()
    if CurTime() - MyShop_LastKeyCheck < 0.15 then return end
    MyShop_LastKeyCheck = CurTime()
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if gui.IsConsoleVisible() then return end
    if ply:IsTyping() then return end
    
    local panel = vgui.GetKeyboardFocus()
    if IsValid(panel) then
        local name = panel:GetName()
        if name ~= "MyShop_Menu" and name ~= "" and not string.find(name:lower(), "shop") then
            return
        end
    end
    
    local key = KEY_F8
    if DynoraKeybinds and DynoraKeybinds.GetBind then
        key = DynoraKeybinds.GetBind("shop", "open") or KEY_F8
    end
    
    if input.IsKeyDown(key) then
        if not MyShop_KeyDown then
            MyShop_KeyDown = true
            if IsValid(MyShop_Menu) then
                MyShop_Menu:AlphaTo(0, 0.15, 0, function()
                    if IsValid(MyShop_Menu) then
                        MyShop_Menu:Remove()
                        MyShop_Menu = nil
                    end
                end)
            else
                MyShop_Menu = vgui.Create("MyShop_Menu")
            end
        end
    else
        MyShop_KeyDown = false
    end
end)

hook.Add("InitPostEntity", "MyShop_RegisterKeybind", function()
    timer.Simple(2, function()
        MyShop.BuildCache(true)
    end)
    
    timer.Simple(4, function()
        if DynoraKeybinds and DynoraKeybinds.RegisterBind then
            DynoraKeybinds.RegisterBind("shop", "open", KEY_F8, "Shop oeffnen/schliessen")
        end
    end)
end)

-- WICHTIG: Cache neu bauen bei Jobwechsel
hook.Add("OnPlayerChangedTeam", "MyShop_RefreshCache", function(ply, oldTeam, newTeam)
    if ply == LocalPlayer() then
        print("[MyShop] Job changed, rebuilding cache...")
        MyShop.Cache.Initialized = false
        MyShop.BuildCache(true)
        
        -- UI aktualisieren wenn offen
        if IsValid(MyShop_Menu) then
            MyShop_Menu:Remove()
            MyShop_Menu = vgui.Create("MyShop_Menu")
        end
    end
end)

hook.Add("ShutDown", "MyShop_Cleanup", function()
    if IsValid(MyShop_Menu) then
        MyShop_Menu:Remove()
    end
end)