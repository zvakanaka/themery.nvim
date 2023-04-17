local greet = require("themery.module")
local utils = require("themery.utils")

local api = vim.api
local config = {}
local buf, win
local resultsStart = 2
local position = 0
local currentThemeIndex = -1
local currentThemeName = ""

local function normalizeThemesConfig()
  for i,v in ipairs(config.themes) do
    if(type(v) == "string") then
      config.themes[i] = {
        name = v,
        colorscheme = v
      }
    end
  end
end

local function setup(userConfig)
  config = vim.tbl_deep_extend("keep", userConfig or {}, {
    themes = {},
    themesConfigFile = "",
    livePreview = true,
  })

  normalizeThemesConfig()
end

local function loadActualThemeConfig()
  currentThemeName = vim.g.colors_name
  for k in pairs(config.themes) do
    if currentThemeName == config.themes[k].colorscheme then
      currentThemeIndex = k
      position = k + resultsStart - 1
      return
    end
  end
end

local function getWinTransform()
  local totalWidth = api.nvim_get_option("columns")
  local totalHeight = api.nvim_get_option("lines")
  local height = math.ceil(totalHeight * 0.4 - 4)
  local width = math.ceil(totalWidth * 0.3)

  return {
    row = math.ceil((totalHeight - height) / 2 - 1),
    col = math.ceil((totalWidth - width) / 2),
    height = height,
    width = width,
  }
end

local function openWindow()
  buf = api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'themery')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  local winTransform = getWinTransform()

  local opts = {
    style = "minimal",
    relative = "editor",
    border="rounded",
    width = winTransform.width,
    height = winTransform.height,
    row = winTransform.row,
    col = winTransform.col,
  }

  win = api.nvim_open_win(buf, true, opts)
  vim.api.nvim_win_set_option(win, 'cursorline', true)

  local title = utils.centerHorizontal('Themery - Theme Selector')
  api.nvim_buf_set_lines(buf, 0, -1, false, { title })
end

local function printNoThemesLoaded()
  local text = "No temes configured. See :help Themery"
  api.nvim_buf_set_lines(buf, 1, -1, false, { text })

end

local function setColorscheme(theme)
  if theme.before then
    local fn, err = load(theme.before)
    if err then
      print("Themery error: "..err)
      return false
    end
    if fn then fn() end
  end

  local ok, _ = pcall(
    vim.cmd,
    "colorscheme "..theme.colorscheme
  )

  -- check if the colorscheme was loaded successfully
  if not ok then
    print("Themery error: Could not load theme: "..theme)
    -- Restore previus
    vim.cmd('colorscheme '..currentThemeName)
    return false
  end

  if theme.after then
    local fn, err = load(theme.after)
    if err then
      print("Themery error: "..err)
      return false
    end
    if fn then fn() end
  end

  return true
end

local function updateView(direction)
  position = position + direction
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  if position < resultsStart then position = resultsStart end
  if position > #config.themes + 1 then position = #config.themes + 1 end

  if #config.themes == 0 then
    printNoThemesLoaded()
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    return
  end

  local resultToPrint = {}
  for i in ipairs(config.themes) do
    local prefix = '  '

    if currentThemeIndex == i then
      prefix = '> '
    end

    resultToPrint[i] = prefix..config.themes[i].name
  end

  api.nvim_buf_set_lines(buf, 1, -1, false, resultToPrint)
  api.nvim_win_set_cursor(win, {position, 0})

  if config.livePreview then
    setColorscheme(config.themes[position-1])
  end

  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function closeWindow()
  api.nvim_win_close(win, true)
end

local function saveTheme()
  local theme = config.themes[position-1]
  local file = io.open(config.themesConfigfile, "r")

  if file == nil then
    print("Themery error: Could not open file for read")
    return
  end

  local content = file:read("*all")

  local start_marker = "-- Themery block"
  local end_marker = "-- end themery"

  local start_pos, end_pos = content:find(start_marker .. "\n(.+)\n" .. end_marker)

  if not start_pos or not end_pos then
    print("Could not find markers in config file")
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

  local outfile = io.open(config.themesConfigfile, "w")

  if outfile == nil then
    print("Error: Could not open file for writing")
    return
  end

  outfile:write(replaced_content)
  outfile:close()

  currentThemeName = config.themes[position-1].colorscheme
  currentThemeIndex = position - 1
  closeWindow()
end

local function setMappings()
  local mappings = {
    k = 'updateView(-1)',
    j = 'updateView(1)',
    q = 'closeWindow()',
    ['<Esc>'] = 'closeWindow()',
    ['<cr>'] = 'saveTheme()',
  }

  for k,v in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, 'n', k, ':lua require("themery").'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end
end

local function pop()
  setup({
    themes = {"tokyonight", {
      name = "gruvbox dark",
      colorscheme = "gruvbox",
      before = [[
        vim.opt.background="dark"
      ]]
    }, {
      name = "gruvbox light",
      colorscheme = "gruvbox",
      after = [[
        vim.opt.background="light"
      ]]
      }, "kanagawa", "kanagawa-dragon"},
    themesConfigfile = "~/.config/nvim/lua/settings/theme.lua",
  }) -- TEMP
  loadActualThemeConfig()
  openWindow()
  setMappings()
  updateView(0)
end

return {
  setup = setup,
  greet = greet,
  pop = pop,
  updateView = updateView,
  closeWindow = closeWindow,
  saveTheme = saveTheme,
}
