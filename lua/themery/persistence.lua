local constants = require("themery.constants")
local config = require("themery.config")
local utils = require("themery.utils")

local function saveTheme(theme)
  local configFilePath = config.settings.themesConfigFile
  local file = io.open(configFilePath , "r")

  if file == nil then
    print(constants.MSG_ERROR.READ_FILE..": "..configFilePath)
    return
  end

  local content = file:read("*all")

  local start_marker = "-- Themery block"
  local end_marker = "-- end themery"

  local start_pos, end_pos = content:find(start_marker .. "\n(.+)\n" .. end_marker)

  if not start_pos or not end_pos then
    print(constants.MSG_ERROR.NO_MARKETS)
    return
  end

  local beforeCode = ""
  local afterCode = ""

  if theme.before then
    beforeCode = utils.trimStartSpaces(theme.before).."\n"
  end

  if theme.after then
    afterCode = "\n"..utils.trimStartSpaces(theme.after)
  end

  local configToWrite = "-- This block will be replaced by Themery.\n"
  configToWrite = configToWrite..beforeCode
  configToWrite = configToWrite.."vim.cmd(\"colorscheme "
  configToWrite = configToWrite..theme.colorscheme.."\")\n"
  configToWrite = configToWrite..afterCode

  local replaced_content = content:sub(1, start_pos-1)
    ..start_marker.."\n"
    ..configToWrite
    ..end_marker
    ..content:sub(end_pos+1)

  local outfile = io.open(configFilePath, "w")

  if outfile == nil then
    print(constants.MSG_ERROR.WRITE_FILE..": "..configFilePath)
    return
  end

  outfile:write(replaced_content)
  outfile:close()
end

return {
  saveTheme = saveTheme,
}
