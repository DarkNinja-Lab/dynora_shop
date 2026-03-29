MyShop = MyShop or {}
MyShop.Config = {}
MyShop.Version = "2.0"

MyShop.Config.Database = {Type = "sqlite"}
MyShop.Config.Currency = "€"

if SERVER then
    include("shop/config.lua")
    include("shop/sv_main.lua")
    
    AddCSLuaFile("shop/config.lua")
    AddCSLuaFile("shop/cl_main.lua")
else
    include("shop/config.lua")
    include("shop/cl_main.lua")
end

print("[Dynora Shop System] v" .. MyShop.Version .. " geladen!")