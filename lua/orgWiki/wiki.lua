local utils = require "orgWiki.utils"
local exec = vim.api.nvim_command
local linkLines = {}
local isIndexed = false

local wikiPath = vim.g.orgwiki_path
local wikiIndexFileName = vim.g.orgwiki_index_filename

local current_wiki = ""
local current_index

local wiki = {}

---Open the default wiki
---@param editcmd string eg: "vs","e","tabnew"
function wiki.openIndex(editcmd)
  local opencmd = editcmd and editcmd .. " " or "e "
  local current_path = current_wiki ~= "" and current_wiki or wikiPath[1]
  current_wiki = current_path
  exec("cd " .. current_path)
  exec(opencmd .. wikiIndexFileName)
end

---If <cWORD> is not a hyperlink, create hyperlink interactively and jump to the link
function wiki.followOrCreate()
  local line = vim.api.nvim_get_current_line()
  local word = vim.fn.expand "<cWORD>"

  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()
  local newwin

  local output = utils.find_link_string(line)

  if not output then
    utils.text_around_cword(line, word)
    utils.create_path(word)
    return
  end

  output = utils.find_path(output)
  if not output then
    return
  end

  local ok, index = utils.has_win(utils.stack, winnr)

  if not ok then
    newwin = utils.new_stack(winnr)
    table.insert(newwin.buffers, bufnr)
    table.insert(utils.stack, newwin)
  else
    table.insert(utils.stack[index].buffers, bufnr)
  end

  utils.follow_link(output)
end

---Delete hyperlink under cursor
function wiki.deleteLink()
  local line = vim.api.nvim_get_current_line()
  line = utils.find_link_string(line)

  if not line then
    return
  end
  local newline

  if utils.not_links.has_before then
    newline = utils.not_links.before
  end
  if utils.not_links.has_after then
    if newline then
      newline = newline .. " " .. utils.not_links.after
    else
      newline = utils.not_links.after
    end
  end

  if newline then
    vim.api.nvim_set_current_line(newline)
  else
    vim.api.nvim_del_current_line()
  end

  wiki.find_all_links(vim.api.nvim_get_current_buf())
  utils.clear_text_link_table()
end

---Jump back one step in the hyperlink jump-stack
function wiki.back()
  local newBuf
  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()
  local w_ok, windex = utils.has_win(utils.stack, winnr)

  if w_ok then
    local b_ok, bindex = utils.has_buf(utils.stack[windex].buffers, bufnr)
    if b_ok then
      if utils.stack[windex].buffers[bufnr] == 1 then
        print "Bottom of the move stack"
        return
      end

      table.remove(utils.stack[windex].buffers, bindex)
      if utils.stack[windex].buffers[bindex - 1] then
        newBuf = utils.stack[windex].buffers[bindex - 1]
      else
        print "Bottom of the move stack"
        return
      end
    else
      print "This buffer is not in the stack"
      return
    end
  else
    print "Buffers in this window not found on stack"
    return
  end

  vim.cmd("b " .. newBuf)
  vim.cmd "lcd %:p:h"
end

---Switch between Wikis if maintaining multiple wikis
---@param editcmd string eg: "vs","e","tabnew"
function wiki.nextWiki(editcmd)
  local index = current_index or 1
  if wikiPath[index + 1] then
    index = index + 1
    current_index = index
    current_wiki = wikiPath[index]
    wiki.openIndex(editcmd)
  elseif wikiPath[#wikiPath - 1] then
    index = #wikiPath - 1
    current_index = index
    current_wiki = wikiPath[index]
    wiki.openIndex(editcmd)
  else
    print "No other Wiki found!"
  end
end

---Choose a wiki to open from the list
---@param editcmd string eg: "vs","e","tabnew"
function wiki.select(editcmd)
  if #wikiPath > 1 then
    vim.ui.select(wikiPath, { prompt = "Choose wiki" }, function(choice)
      current_wiki = choice
      for index, value in ipairs(wikiPath) do
        if value == choice then
          current_index = index
        end
      end
      wiki.openIndex(editcmd)
    end)
  else
    current_wiki = wikiPath[1]
    wiki.openIndex(editcmd)
  end
end

--- Find the the next link closest to the cursor
--- Jump the cursot to the link
function wiki.gotoNext()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local nextLinkLine, nextLinkCol

  if not isIndexed then
    wiki.find_all_links(bufnr)
  end

  if linkLines then
    for i = cursor[1] + 1, #linkLines do
      if linkLines[i].linenr then
        nextLinkLine = linkLines[i].linenr
        nextLinkCol = linkLines[i].colnr
        vim.api.nvim_win_set_cursor(winnr, { nextLinkLine, nextLinkCol })
        utils.clear_text_link_table()
        return
      end
    end
    if not nextLinkLine then
      print "No more links in the buffer"
      return
    end
  else
    print "There are no link in the buffer"
    return
  end
end

--- Find the the previous link closest to the cursor
--- Jump the cursot to the link
function wiki.gotoPrev()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local nextLinkLine, nextLinkCol

  if not isIndexed then
    wiki.find_all_links(bufnr)
  end

  if linkLines then
    for i = cursor[1] - 1, 1, -1 do
      if linkLines[i].linenr then
        nextLinkLine = linkLines[i].linenr
        nextLinkCol = linkLines[i].colnr
        vim.api.nvim_win_set_cursor(winnr, { nextLinkLine, nextLinkCol })
        utils.clear_text_link_table()
        return
      end
    end
    if not nextLinkLine then
      print "No more links in the buffer"
      return
    end
  else
    print "There are no link in the buffer"
    return
  end
end

---Find link under cursor and extract path for previewing
---Open floating preview. If preview already exists, focus floating win
function wiki.hover()
  local line = vim.api.nvim_get_current_line()
  local output = utils.find_link_string(line)
  if not output then
    print "No link under cursor"
    return
  end

  output = utils.find_path(output)
  if not output then
    print "Broken or non-existant hyperlink"
    return
  end

  require("orgWiki.preview").open_or_focus(output)
end

function wiki.find_all_links(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for index, line in ipairs(lines) do
    local linetab = {
      line = "",
      linenr = nil,
      colnr = nil,
    }
    local newline = utils.find_link_string(line)
    if newline then
      linetab.colnr = line:find "%["
      linetab.line = newline
      linetab.linenr = index
    end
    table.insert(linkLines, linetab)
  end
  isIndexed = true
end

return wiki
