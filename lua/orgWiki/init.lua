local orgwiki = {}

local function set_keys(t)
  local orgwiki_au = vim.api.nvim_create_augroup("OrgWiko", { clear = true })

  vim.keymap.set("n", t.open_index, require("orgWiki.wiki").openIndex, { desc = "Open orgWiki Index file" })
  vim.keymap.set("n", t.open_index_tab, function()
    require("orgWiki.wiki").openIndex "tabnew"
  end, { desc = "Open orgWiki Index in a new tab" })

  vim.keymap.set("n", t.open_next_index, function()
    require("orgWiki.wiki").nextWiki "tabnew"
  end, { desc = "Open next available wiki a new tab" })

  vim.keymap.set("n", t.open_next_index, function()
    require("orgWiki.wiki").select "tabnew"
  end, { desc = "Open selected wiki a new tab" })

  vim.keymap.set(
    "n",
    t.open_diary_index,
    require("orgWiki.diary").diaryIndexOpen,
    { desc = "Open orgWiki Diary index file" }
  )
  vim.keymap.set("n", t.diary_today, require("orgWiki.diary").diaryTodayOpen, {
    desc = "Open today's orgWiki Diary",
  })
  vim.keymap.set(
    "n",
    t.diary_tomorrow,
    require("orgWiki.diary").diaryTomorrowOpen,
    { desc = "Open tomorrow's orgWiki Diary" }
  )
  vim.keymap.set(
    "n",
    t.diary_yesterday,
    require("orgWiki.diary").diaryYesterdayOpen,
    { desc = "Open tomorrow's orgWiki Diary" }
  )
  vim.keymap.set(
    "n",
    t.diary_update,
    require("orgWiki.diary").diaryGenerateIndex,
    { desc = "Update orgWiki Diary index" }
  )

  vim.api.nvim_create_autocmd("FileType", {
    group = orgwiki_au,
    pattern = "org",
    callback = function()
      vim.keymap.set(
        "n",
        t.create_or_follow,
        require("orgWiki.wiki").followOrCreate,
        { buffer = true, desc = "create/follow link under cursor" }
      )
      vim.keymap.set("n", t.traverse_back, require("orgWiki.wiki").back, { buffer = true, desc = "Go to parent link" })
      vim.keymap.set("n", t.goto_next, require("orgWiki.wiki").gotoNext, { buffer = true, desc = "Go to next link" })
      vim.keymap.set(
        "n",
        t.goto_prev,
        require("orgWiki.wiki").gotoPrev,
        { buffer = true, desc = "Go to previous link" }
      )
    end,
  })
end

local keys = {
  create_or_follow = "<CR>",
  traverse_back = "<BS>",
  goto_next = "]w",
  goto_prev = "[w",
  open_index = "<leader>ww",
  open_next_index = "<leader>wn",
  open_choice_index = "<leader>wc",
  open_index_tab = "<leader>wt",
  open_diary_index = "<leader>wi",
  diary_today = "<leader>w<leader>w",
  diary_tomorrow = "<leader>w<leader>t",
  diary_yesterday = "<leader>w<leader>y",
  diary_update = "<leader>w<leader>i",
}

---This function initializes orgWiki by setting keymaps and defining path variables
---opts is a table that must include the following
---   wiki_path: A list of directories to be recognized as orgWiki
---   diary_path: A string containing the path to the direcotry where diary entries must be stored
---   keys: optional table with values to set up keybindings. When any of the keys are omitted, default mappings are used
---         create_or_follow = "<CR>", --  Follow hyperlink under cursor
---         traverse_back = "<BS>", -- Return to the parent file or top of the link stack
---         goto_next = "]w", --  Go to next hyperlink in the file
---         goto_prev = "[w", -- Go to prevvious hyperlink in the file
---         open_index = "<leader>ww", --  Open the default orgWiki index file
---         open_index_tab = "<leader>wt", -- Open the default wiki in a new tab
---         open_choice_index = "<leader>wc", --  Open a wiki from list
---         open_next_index = "<leader>wn", -- Switch to the next wiki if available
---         open_diary_index = "<leader>wi", -- Open the diary index file
---         diary_update = "<leader>w<leader>i", -- Update the diary index files with new available entries
---         diary_today = "<leader>w<leader>w", -- Open a new diary entry ("Today")
---         diary_tomorrow = "<leader>w<leader>t", -- Open a new diary entry ("Tomorrow")
---         diary_yesterday = "<leader>w<leader>y", -- Open yesterday's diary entry
---@param opts table
function orgwiki.setup(opts)
  assert(type(opts) == "table", "The setup function requires a table of arguments")
  if opts.wiki_path then
    vim.g.orgwiki_path = opts.wiki_path
  else
    print "Wiki path not set"
  end
  if opts.diary_path then
    vim.g.orgwiki_diary_path = opts.diary_path
  else
    print "Diary path not set"
  end

  if not opts.disable_mappings then
    if opts.keys then
      for key, _ in pairs(keys) do
        if vim.fn.has_key(opts.keys, key) then
          keys[key] = opts.keys[key]
        end
      end
      pcall(set_keys, keys)
    else
      set_keys(keys)
    end
  end
end

return orgwiki
