local exec = vim.api.nvim_command
local stack = {}
local notLinks = { hasBefore = false, hasAfter = false, before = "", after = "", full = "" }
local linkLines = {}
local isIndexed = false

local wikiPath = vim.g.orgwiki_path

local current_wiki = ""
local current_index

local haswin = function(tab, val)
  for index, sub in ipairs(tab) do
    if sub["winid"] == val then
      return true, index
    end
  end
  return false
end

local hasbuf = function(tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return true, index
    end
  end
  return false
end

local newstack = function(winnr)
  return {
    winid = winnr,
    buffers = {},
  }
end

local textInLink = function(line)
  if line:find ".*%[%[" then
    local before = line:match ".*%[%["
    before = before:gsub("%[%[", "")
    notLinks.hasBefore = true
    notLinks.before = before
  end
  if line:find "%]%].*" then
    local after = line:match "%]%].*"
    after = after:gsub("%]%]", "")
    notLinks.hasAfter = true
    notLinks.after = after
    table.insert(notLinks, after)
  end
end

local textWithoutLink = function(line, word)
  if line:find(".*" .. word) then
    local before = line:match(".*" .. word)
    before = before:gsub(word, "")
    notLinks.hasBefore = true
    notLinks.before = before
  end
  if line:find(word .. ".*") then
    local after = line:match(word .. ".*")
    after = after:gsub(word, "")
    notLinks.hasAfter = true
    notLinks.after = after
    table.insert(notLinks, after)
  end
end

local clearTextLink = function()
  notLinks.hasBefore = false
  notLinks.before = ""
  notLinks.hasAfter = false
  notLinks.after = ""
  notLinks.full = ""
end

local createLink = function(words)
  if words:match "/" then
    local path = vim.fn.fnamemodify(words, ":p:h")
    exec("!mkdir -p " .. path)
    local current_path = current_wiki or wikiPath[1]
    pcall(exec("!cp " .. current_path .. ".gitignore " .. path))
    local tag = vim.fn.input "Enter link name: "
    local link = string.format("[[%s][%s]]", words, tag)
    return link
  elseif not words:match "%." then
    local filetype = vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "filetype")
    if vim.tbl_contains(vim.g.orgwiki_filetypes, filetype) then
      local link = string.format("[[%s.%s][%s]]", words, filetype, words)
      return link
    else
      local ext = vim.fn.input "Enter filetype extension to use: "
      local link = string.format("[[%s.%s][%s]]", words, ext, words)
      return link
    end
  else
    local tag = vim.fn.fnamemodify(words, ":r")
    local link = string.format("[[%s][%s]]", words, tag)
    return link
  end
end

local followLink = function(link)
  local winnr = vim.api.nvim_get_current_win()
  local newwin
  local ok, index = haswin(stack, winnr)

  if not ok then
    newwin = newstack(winnr)
  end

  if vim.loop.fs_stat(link) then
    vim.cmd("e " .. link)
    vim.cmd "lcd %:h:t"

    local bufnr = vim.api.nvim_get_current_buf()
    if not ok then
      table.insert(newwin.buffers, bufnr)
      table.insert(stack, newwin)
    else
      table.insert(stack[index].buffers, bufnr)
    end
  else
    vim.cmd("lcd " .. vim.fn.expand "%:p:h")
    vim.cmd("e " .. link)

    local bufnr = vim.api.nvim_get_current_buf()

    if not ok then
      table.insert(newwin.buffers, bufnr)
      table.insert(stack, newwin)
    else
      table.insert(stack[index].buffers, bufnr)
    end
  end
end

local findLinkString = function(line)
  local output = line:match "%[.*%]%[.*%]"
  if not output then
    return nil
  end

  textInLink(line)
  return output
end

local findPath = function(link)
  link = link:gsub("%[%[", "")
  if not link then
    print "Link does not follow proper syntax"
    return nil
  end

  link = link:gsub("%]%[.*", "")
  if not link then
    print "Syntax error: Wrong formatting of link"
    return nil
  end
  return link
end

local createPath = function(word)
  print "Link does not point to file"
  local line
  vim.ui.select({ "yes", "no" }, { prompt = "Create link? " }, function(choice)
    if choice == "yes" then
      local link = createLink(word)
      if notLinks.hasBefore then
        notLinks.full = notLinks.before
        notLinks.hasBefore = false
        notLinks.before = ""
      end
      line = link
      notLinks.full = notLinks.full .. link
      if notLinks.hasAfter then
        notLinks.full = notLinks.full .. notLinks.after

        notLinks.hasAfter = false
        notLinks.after = ""
      end
    else
      clearTextLink()
      return nil
    end
  end)
  return line
end

local findAllLinks = function(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for index, line in ipairs(lines) do
    local linetab = {
      line = "",
      linenr = nil,
      colnr = nil,
    }
    local newline = findLinkString(line)
    if newline then
      linetab.colnr = line:find "%["
      linetab.line = newline
      linetab.linenr = index
    end
    table.insert(linkLines, linetab)
  end
  isIndexed = true
end

local wiki = {}

---Open the default wiki
---@param editcmd string eg: "vs","e","tabnew"
function wiki.openIndex(editcmd)
  local opencmd = editcmd and editcmd .. " " or "e "
  local current_path = current_wiki ~= "" and current_wiki or wikiPath[1]
  current_wiki = current_path
  exec("cd " .. current_path)
  exec(opencmd .. "Index.org")
end

---If <cWORD> is not a hyperlink, create hyperlink interactively and jump to the link
function wiki.followOrCreate()
  local line = vim.api.nvim_get_current_line()
  local word = vim.fn.expand "<cWORD>"

  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()
  local newwin

  local output = findLinkString(line)

  if not output then
    textWithoutLink(line, word)
    output = createPath(word)
    if not output then
      return
    else
      vim.api.nvim_set_current_line(notLinks.full)
      notLinks.full = ""
    end
  end

  output = findPath(output)
  if not output then
    return
  end

  local ok, index = haswin(stack, winnr)

  if not ok then
    newwin = newstack(winnr)
    table.insert(newwin.buffers, bufnr)
    table.insert(stack, newwin)
  else
    table.insert(stack[index].buffers, bufnr)
  end

  followLink(output)
end

---Delete hyperlink under cursor
function wiki.deleteLink()
  local line = vim.api.nvim_get_current_line()
  line = findLinkString(line)

  if not line then
    return
  end
  local newline

  if notLinks.hasBefore then
    newline = notLinks.before
  end
  if notLinks.hasAfter then
    if newline then
      newline = newline .. " " .. notLinks.after
    else
      newline = notLinks.after
    end
  end

  if newline then
    vim.api.nvim_set_current_line(newline)
  else
    vim.api.nvim_del_current_line()
  end

  findAllLinks(vim.api.nvim_get_current_buf())
  clearTextLink()
end

---Jump back one step in the hyperlink jump-stack
function wiki.back()
  local newBuf
  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()
  local w_ok, windex = haswin(stack, winnr)

  if w_ok then
    local b_ok, bindex = hasbuf(stack[windex].buffers, bufnr)
    if b_ok then
      if stack[windex].buffers[bufnr] == 1 then
        print "Bottom of the move stack"
        return
      end

      table.remove(stack[windex].buffers, bindex)
      if stack[windex].buffers[bindex - 1] then
        newBuf = stack[windex].buffers[bindex - 1]
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
    findAllLinks(bufnr)
  end

  if linkLines then
    for i = cursor[1] + 1, #linkLines do
      if linkLines[i].linenr then
        nextLinkLine = linkLines[i].linenr
        nextLinkCol = linkLines[i].colnr
        vim.api.nvim_win_set_cursor(winnr, { nextLinkLine, nextLinkCol })
        clearTextLink()
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
    findAllLinks(bufnr)
  end

  if linkLines then
    for i = cursor[1] - 1, 1, -1 do
      if linkLines[i].linenr then
        nextLinkLine = linkLines[i].linenr
        nextLinkCol = linkLines[i].colnr
        vim.api.nvim_win_set_cursor(winnr, { nextLinkLine, nextLinkCol })
        clearTextLink()
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

function wiki.hover()
  local line = vim.api.nvim_get_current_line()
  local output = findLinkString(line)
  if not output then
    print "No link under cursor"
    return
  end

  output = findPath(output)
  if not output then
    print "Broken or non-existant hyperlink"
    return
  end

  require("orgWiki.preview").open_or_focus(output)
end

return wiki
