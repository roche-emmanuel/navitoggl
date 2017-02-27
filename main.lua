local utils = require("utils")

log("Starting conversion.")
local cfgFile="config.lua"

if(#arg > 0) then
  -- Retrieve the config file::
  cfgFile=arg[1]
  log("Using config file: ",cfgFile)
end

-- Load the config file:
local cfg=dofile(cfgFile)

-- log("Input config: ",cfg)
log("Input csv file: ",cfg.input_csv)

-- local input = utils.loadCSV(cfg.input_csv,1)
-- log("Input CSV:", input)

local entries = utils.loadTogglEntries(cfg.input_csv)
-- log("Toggl entries:", entries)

local naviEntries = utils.togglToNavi(entries,cfg)
-- log("Navision entries:", naviEntries)

log("Writing entries...")
utils.writeNaviEntries(naviEntries, cfg)

log("Done.")
