vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(a) require("markdown-renderer").attach(a.buf) end,
})
