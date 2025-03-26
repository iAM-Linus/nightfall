-- Main script modification to load test integration
-- Add this to the main.lua file

-- Load test integration when in development mode
if os.getenv("NIGHTFALL_ENV") == "development" or true then
    require("src.test.main_menu_integration")
end
