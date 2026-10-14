# nvim-markdown-renderer

Renders markdown in Neovim the way Claude Code CLI does. The cursor line stays raw markdown.

- Headings: `#` hidden; H1 bold/italic/underline, others bold
- `**bold**`, `*italic*`, `~~strike~~`, `` `code` ``, `[links](url)` with markers hidden
- Bullets as `•`, blockquotes as `▎`, `---` as a full-width rule
- Code fences hidden; code content left to your syntax highlighting

## Install

lazy.nvim:

```lua
{ "adamjstevens/nvim-markdown-renderer", ft = "markdown" }
```

No setup needed. Attaches on `FileType markdown`.

## Highlights

Override any of: `MdrH1`, `MdrH`, `MdrBold`, `MdrItalic`, `MdrStrike`, `MdrCode`, `MdrLink`, `MdrQuote`, `MdrDim`.

## Test

```sh
nvim --headless -u NONE -l tests/run.lua
```
