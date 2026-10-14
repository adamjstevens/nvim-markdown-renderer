-- Renders markdown like Claude Code CLI. The cursor line stays raw.
local M = {}
local ns = vim.api.nvim_create_namespace("markdown-renderer")
local api = vim.api

local function set_hl()
  local function set(name, opts)
    opts.default = true
    api.nvim_set_hl(0, name, opts)
  end
  set("MdrH1", { bold = true, italic = true, underline = true })
  set("MdrH", { bold = true })
  set("MdrBold", { bold = true })
  set("MdrItalic", { italic = true })
  set("MdrStrike", { strikethrough = true })
  set("MdrCode", { fg = "#b1b9f9" })
  set("MdrLink", { fg = "#b1b9f9", underline = true })
  set("MdrQuote", { link = "Comment" })
  set("MdrDim", { link = "Comment" })
end

local function mark(buf, row, col, opts)
  pcall(api.nvim_buf_set_extmark, buf, ns, row, col, opts)
end

local function conceal(buf, row, s, e)
  if e > s then mark(buf, row, s, { end_col = e, conceal = "" }) end
end

local function hl(buf, row, s, e, group)
  if e > s then mark(buf, row, s, { end_col = e, hl_group = group }) end
end

-- Inline spans: `code`, [link](url), **bold**, ~~strike~~, *italic*.
local function inline(buf, row, line)
  local taken = {}
  local function free(s, e)
    for _, r in ipairs(taken) do
      if s < r[2] and e > r[1] then return false end
    end
    return true
  end
  -- Lua 1-based find result -> conceal delimiters, highlight inner text.
  local function scan(pat, open, close, group, word_boundary)
    local init = 1
    while true do
      local s, e = line:find(pat, init)
      if not s then return end
      local ok = free(s, e + 1) and not (word_boundary and s > 1 and line:sub(s - 1, s - 1):match("%w"))
      if ok then
        table.insert(taken, { s, e + 1 })
        conceal(buf, row, s - 1, s - 1 + open)
        hl(buf, row, s - 1 + open, e - close, group)
        conceal(buf, row, e - close, e)
      end
      init = e + 1
    end
  end

  scan("`[^`]+`", 1, 1, "MdrCode")
  for s, text, e in line:gmatch("()%[([^%]]+)%]%([^)]+%)()") do
    if free(s, e) then
      table.insert(taken, { s, e })
      conceal(buf, row, s - 1, s)
      hl(buf, row, s, s + #text, "MdrLink")
      conceal(buf, row, s + #text, e - 1)
    end
  end
  scan("%*%*[^*]+%*%*", 2, 2, "MdrBold")
  scan("__[^_]+__", 2, 2, "MdrBold", true)
  scan("~~[^~]+~~", 2, 2, "MdrStrike")
  scan("%*[^%s*][^*]-%*", 1, 1, "MdrItalic", true)
  scan("_[^%s_][^_]-_", 1, 1, "MdrItalic", true)
end

local function render_line(buf, win, row, line)
  local hashes, text_col = line:match("^(#+)%s+()")
  if hashes and #hashes <= 6 then
    conceal(buf, row, 0, text_col - 1)
    hl(buf, row, text_col - 1, #line, #hashes == 1 and "MdrH1" or "MdrH")
    return inline(buf, row, line)
  end

  if line:match("^%-%-%-+%s*$") or line:match("^%*%*%*+%s*$") or line:match("^___+%s*$") then
    local width = api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff
    return mark(buf, row, 0, { virt_text = { { ("─"):rep(width), "MdrDim" } }, virt_text_pos = "overlay" })
  end

  local q = line:match("^%s*()>")
  if q then
    mark(buf, row, q - 1, { virt_text = { { "▎", "MdrQuote" } }, virt_text_pos = "overlay" })
    hl(buf, row, q, #line, "MdrQuote")
    mark(buf, row, q, { end_col = #line, hl_group = "MdrItalic" })
  end

  local b = line:match("^%s*()[-*+]%s")
  if b then
    mark(buf, row, b - 1, { virt_text = { { "•" } }, virt_text_pos = "overlay" })
  end

  inline(buf, row, line)
end

function M.render(buf, win)
  if not api.nvim_buf_is_valid(buf) or api.nvim_win_get_buf(win) ~= buf then return end
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local top, bot = vim.fn.line("w0", win), vim.fn.line("w$", win)
  local cur = api.nvim_win_get_cursor(win)[1]
  -- Scan from the top so we know whether visible lines sit inside a fence.
  local fence
  for i, line in ipairs(api.nvim_buf_get_lines(buf, 0, bot, false)) do
    local row, visible = i - 1, i >= top and i ~= cur
    local f = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if fence then
      local closing = f and f:sub(1, 1) == fence:sub(1, 1) and #f >= #fence and line:match("^%s*[`~]+%s*$")
      if closing then
        fence = nil
        if visible then conceal(buf, row, 0, #line) end
      end
    elseif f then
      fence = f
      if visible then conceal(buf, row, 0, #line) end
    elseif visible then
      render_line(buf, win, row, line)
    end
  end
end

function M.attach(buf)
  set_hl()
  vim.opt_local.conceallevel = 2
  local group = api.nvim_create_augroup("markdown-renderer-" .. buf, { clear = true })
  -- ponytail: extmarks are per-buffer, so one buffer in two windows follows the last-active window's cursor.
  api.nvim_create_autocmd(
    { "BufWinEnter", "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI", "WinScrolled", "WinResized" },
    { group = group, buffer = buf, callback = function() M.render(buf, api.nvim_get_current_win()) end }
  )
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
  M.render(buf, api.nvim_get_current_win())
end

M.ns = ns
return M
