local ffi = require "ffi"
local Preview = {}

local border_shift = { -1, -1, -1, -1 }

local preview = {}

---Open popup window with linked file preview. Also set autocommands to close
---popup window and change its size on scrolling and vim resizing.
---@param file string path of file to preview
function Preview.show_preview(file)
  local auid
  ---Current buffer ID
  local curbufnr = vim.api.nvim_get_current_buf()

  preview[curbufnr] = {}

  local cursor_pos = vim.fn.getcurpos()

  ---The number of window rows from the current cursor line to the end of the
  ---window. I.e. room below for float window.
  local room_below = vim.api.nvim_win_get_height(0) - vim.fn.winline() + 1

  ---The maximum line length of the region.
  local max_line_len = 0

  if not vim.loop.fs_stat(file) then
    print "File unreadable or broken hyperlink"
    return
  end

  local lines = {}

  local link_file, msg = io.open(file, "r")
  if not link_file then
    print(msg)
  end

  for line in link_file:lines() do
    table.insert(lines, line)
  end
  link_file:close()

  local indent = #(lines[1]:match "^%s+" or "")
  for i, line in ipairs(lines) do
    if indent > 0 then
      line = line:sub(indent + 1)
    end
    lines[i] = line
    local line_len = vim.fn.strdisplaywidth(line)
    if line_len > max_line_len then
      max_line_len = line_len
    end
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
  vim.bo[bufnr].filetype = vim.bo.filetype
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  preview.current_buf = bufnr
  ---The width of offset of a window, occupied by line number column,
  ---fold column and sign column.
  ffi.cdef [[
    int curwin_col_off(void);
    ]]
  local gutter_width = ffi.C.curwin_col_off()

  ---The number of columns from the left boundary of the preview window to the
  ---right boundary of the current window.
  local room_right = vim.api.nvim_win_get_width(0) - gutter_width - indent

  local winid = vim.api.nvim_open_win(bufnr, false, {
    border = "double",
    relative = "win",
    bufpos = { -- Zero-indexed, that's why minus one.
      cursor_pos[2] - 1,
      cursor_pos[3] - 1,
    },
    -- The position of the window relative to 'bufos' field.
    row = border_shift[1],
    col = border_shift[4],

    width = max_line_len + 2 < room_right and max_line_len + 1 or room_right - 1,
    height = #lines < room_below and #lines or room_below,
    style = "minimal",
    focusable = false,
    noautocmd = true,
  })
  vim.wo[winid].foldenable = false
  vim.wo[winid].signcolumn = "no"
  preview.current_win = winid

  preview[curbufnr].close = function()
    if vim.fn.win_gettype(preview.current_win) ~= "unknown" then
      vim.api.nvim_win_close(preview.current_win, false)
    end
    if vim.fn.bufexists(preview.current_buf) == 1 then
      vim.api.nvim_buf_delete(bufnr, { force = true, unload = false })
    end
    preview[curbufnr] = nil
    preview.current_win = nil
    preview.current_buf = nil
    vim.g.orgwiki_preview = false
  end

  preview[curbufnr].scroll = function()
    room_below = vim.api.nvim_win_get_height(0) - vim.fn.winline() + 1
    vim.api.nvim_win_set_height(winid, #lines < room_below and #lines or room_below)
  end

  preview[curbufnr].resize = function()
    room_right = vim.api.nvim_win_get_width(0) - gutter_width - indent
    vim.api.nvim_win_set_width(winid, max_line_len < room_right and max_line_len or room_right)
  end

  if not auid then
    auid = vim.api.nvim_create_augroup("org_preview", { clear = true })
  end

  vim.api.nvim_create_autocmd({ "CursorMoved", "CmdlineEnter", "InsertEnter" }, {
    group = auid,
    buffer = curbufnr,
    callback = function()
      if preview[curbufnr] then
        preview[curbufnr].close()
      end
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "CmdlineEnter", "InsertEnter" }, {
    group = auid,
    buffer = preview.current_buf,
    callback = function()
      if preview[curbufnr] then
        preview[curbufnr].close()
      end
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd("WinScrolled", {
    group = auid,
    buffer = bufnr,
    callback = function()
      preview[curbufnr].scroll()
    end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = auid,
    buffer = bufnr,
    callback = function()
      preview[curbufnr].resize()
    end,
  })
  vim.keymap.set("n", "<Esc>", preview[curbufnr].close, { buffer = curbufnr, desc = "Close preview" })
  vim.keymap.set("n", "q", preview[curbufnr].close, { buffer = curbufnr, desc = "Close preview" })
  vim.keymap.set("n", "<Esc>", preview[curbufnr].close, { buffer = bufnr, desc = "Close preview" })
  vim.keymap.set("n", "q", preview[curbufnr].close, { buffer = bufnr, desc = "Close preview" })
end

function Preview.open_or_focus(path)
  if not vim.g.orgwiki_preview then
    vim.g.orgwiki_preview = true
    Preview.show_preview(path)
  elseif vim.g.orgwiki_preview then
    vim.g.orgwiki_preview = false
    local bufnr = vim.api.nvim_get_current_buf()
    if preview[bufnr] then
      vim.fn.win_gotoid(preview.current_win)
    end
  end
end

return Preview
