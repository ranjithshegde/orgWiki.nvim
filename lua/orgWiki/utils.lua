local utils = {}
local exec = vim.api.nvim_command
local wiki_path = vim.g.orgwiki_path
local current_wiki = ""
utils.stack = {}

utils.not_links = { has_before = false, has_after = false, before = "", after = "", full = "" }

local links = {
  pre = "(.*)%[%[",
  post = "%]%](.*)",
  pattern_capture = "%[%[(.*)%]%[(.*)%]%]",
}

utils.link_types = {
  file = "file:",
  http = "http://",
  https = "https://",
  doi = "doi:",
  attachment = "attachment:",
}

utils.has_win = function(tab, val)
  for index, sub in ipairs(tab) do
    if sub["winid"] == val then
      return true, index
    end
  end
  return false
end

utils.has_buf = function(tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return true, index
    end
  end
  return false
end

function utils.new_stack(winnr)
  return {
    winid = winnr,
    buffers = {},
  }
end

---Parses the link string and maps the text before and after the link into a table
---@param line string Line to parse
function utils.text_in_link(line)
  local before = line:match(links.pre)
  if before ~= nil and before ~= "" then
    utils.not_links.has_before = true
    utils.not_links.before = before
  end
  local after = line:match(links.post)
  if after ~= nil and after ~= "" then
    utils.not_links.has_after = true
    utils.not_links.after = after
    table.insert(utils.not_links, after)
  end
end

---Parses the string and maps the text before and after the <cWORD> into a table
---@param line string Line to parse
function utils.text_around_cword(line, word)
  local before = line:match("(.*)" .. word)
  if before ~= nil and before ~= "" then
    utils.not_links.has_before = true
    utils.not_links.before = before
  end
  local after = line:match(word .. "(.*)")
  if after ~= nil and after ~= "" then
    utils.not_links.has_after = true
    utils.not_links.after = after
    table.insert(utils.not_links, after)
  end
end

---Clear the contents of the table that stores text around links/<cWORD>
function utils.clear_text_link_table()
  utils.not_links.has_before = false
  utils.not_links.before = ""
  utils.not_links.has_after = false
  utils.not_links.after = ""
  utils.not_links.full = ""
end

---This function takes the input string and parses it for different possibilites of links
---If the string contains a path separator, it considers that string as the link path, the user is prompted to input the name of the tag
---If the string contains %s.%s format then it considers it a link file and the above is continued
---If no such patterns are found, the user is asked to enter both the file to link and name of the tag
---@param words string word or line to parse
---@return string A new string with link format
function utils.create_link(words)
  if words:match "/" then
    local path = vim.fn.fnamemodify(words, ":p:h")
    exec("!mkdir -p " .. path)
    local current_path = current_wiki or wiki_path[1]

    if vim.loop.fs_stat(current_path .. ".gitignore") then
      exec("!cp " .. current_path .. ".gitignore " .. path)
    end

    local tag = vim.fn.input "Enter link name: "
    local link = string.format("[[%s%s][%s]]", utils.link_types.file, words, tag)
    return link
  elseif not words:match "%." then
    local filetype = vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "filetype")
    if vim.tbl_contains(vim.g.orgwiki_filetypes, filetype) then
      local link = string.format("[[%s%s.%s][%s]]", utils.link_types.file, words, filetype, words)
      return link
    else
      local ext = vim.fn.input "Enter filetype extension to use: "
      local link = string.format("[[%s%s.%s][%s]]", utils.link_types.file, words, ext, words)
      return link
    end
  else
    local tag = vim.fn.fnamemodify(words, ":r")
    local link = string.format("[[%s%s][%s]]", utils.link_types.file, words, tag)
    return link
  end
end

---This function accepts a link and navigates to the link.
---If the link referes to a file, the buffer stack is updated. If file,  both the Window and buffer stack is updated
---@param link string Line to be parsed
function utils.follow_link(link)
  local winnr = vim.api.nvim_get_current_win()
  local newwin
  local ok, index = utils.has_win(utils.stack, winnr)

  if not ok then
    newwin = utils.new_stack(winnr)
  end

  local fs = vim.loop.fs_stat(link)

  if fs and fs.type ~= "directory" then
    vim.cmd("e " .. link)
    vim.cmd "lcd %:h:t"

    local bufnr = vim.api.nvim_get_current_buf()
    if not ok then
      table.insert(newwin.buffers, bufnr)
      table.insert(utils.stack, newwin)
    else
      table.insert(utils.stack[index].buffers, bufnr)
    end
  else
    vim.cmd("lcd " .. vim.fn.expand "%:p:h")
    vim.cmd("e " .. link)

    local bufnr = vim.api.nvim_get_current_buf()

    if not ok then
      table.insert(newwin.buffers, bufnr)
      table.insert(utils.stack, newwin)
    else
      table.insert(utils.stack[index].buffers, bufnr)
    end
  end
end

---Parse the input line for link-format string
---@param line string Line to be parsed
---@return string|nil nil if no link, url if link exists
function utils.find_link_string(line)
  local uri, tag = line:match(links.pattern_capture)
  if not (uri and tag) then
    return nil
  end

  utils.text_in_link(line)
  return uri
end

---Parse the input line for the file_path of link
---@param link string Line to be parsed
---@return string nil if no link, path if exists
function utils.find_path(link)
  if link:match(utils.link_types.file) then
    link = link:gsub(utils.link_types.file, "")
  end
  return link
end

---Creates the hyperlink for the word
---@param word string The word to be turned into hyperlink, and used as the link tag
function utils.create_path(word)
  vim.notify "Link does not point to file"
  vim.ui.select({ "yes", "no" }, { prompt = "Create link? " }, function(choice)
    if choice == "yes" then
      local link = utils.create_link(word)
      if utils.not_links.has_before then
        utils.not_links.full = utils.not_links.before
        utils.not_links.has_before = false
        utils.not_links.before = ""
      end
      utils.not_links.full = utils.not_links.full .. link
      if utils.not_links.has_after then
        utils.not_links.full = utils.not_links.full .. utils.not_links.after
        utils.not_links.has_after = false
        utils.not_links.after = ""
      end
      vim.api.nvim_set_current_line(utils.not_links.full)
      utils.not_links.full = ""
      require("orgWiki.wiki").followOrCreate()
    else
      utils.clear_text_link_table()
    end
  end)
end

return utils
