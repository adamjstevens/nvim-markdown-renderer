-- nvim --headless -u NONE -l tests/run.lua
vim.opt.rtp:prepend(".")
local mdr = require("markdown-renderer")
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "# Title", "some **bold** and `code`", "```lua", "local x = **not bold**", "```", "- item", "> quote",
})
vim.api.nvim_win_set_cursor(0, { 1, 0 })
mdr.attach(buf)

local function marks(row)
  return vim.api.nvim_buf_get_extmarks(buf, mdr.ns, { row, 0 }, { row, -1 }, { details = true })
end
assert(#marks(0) == 0, "cursor line must stay raw")
assert(#marks(1) == 6, "bold + code: 2 conceals + 1 hl each, got " .. #marks(1))
assert(#marks(2) == 1 and marks(2)[1][4].conceal == "", "opening fence concealed")
assert(#marks(3) == 0, "no inline rendering inside code block")
assert(marks(5)[1][4].virt_text[1][1] == "•", "bullet")
assert(marks(6)[1][4].virt_text[1][1] == "▎", "quote bar")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
mdr.render(buf, vim.api.nvim_get_current_win())
assert(#marks(0) == 2 and #marks(1) == 0, "rendering follows cursor")
print("ok")
