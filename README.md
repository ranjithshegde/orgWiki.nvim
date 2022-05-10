# orgWiki.nvim

This plugin implements a subset of features from the popular vimwiki plugin for org filetype.
Written in pure lua

_Note: This plugin is still experimental. Would be grateful for any bug reports or suggestions for improvement where necessary_

## Features

- Create hyperlink for `<cWORD>` and easily navigate between links
- Create and maintain wikis
- Switch between Wikis
- Create diary entries
- Autogenerate and update diary index

## Configuration

Install the plugin using your favourite plugin manager
Example for `packer.nvim`

```lua
use {"ranjithshegde/orgWiki.nvim"}
```

The plugin follows similar method of configuration like many other lua plugins
via calling the setup function with a opts table

This function initializes orgWiki by setting keymaps and defining path variables
opts as a table that must include the following

**wiki_path**: A list of directories to be recognized as orgWiki

**diary_path**: A string containing the path to the direcotry where diary entries must be stored

if you do not wish for the plugin to create the mappings you can use this option
**disable_mappings** = true

**keys**: optional table with values to set up keybindings. When any of the keys are omitted, default mappings are used. Below shows the list of key options with its default mappings

- _create_or_follow_ = `"<CR>"`, -- Follow hyperlink under cursor
- _traverse_back_ = `"<BS>"`, -- Return to the parent file or top of the link stack
- _goto_next_ = `]w`, -- Go to next hyperlink in the file
- _goto_prev_ = `"[w"`, -- Go to prevvious hyperlink in the file
- _open_index_ = `"<leader>ww"`, -- Open the default orgWiki index file
- _open_index_tab_ = `"<leader>wt"`, -- Open the default wiki in a new tab
- _open_choice_index_ = `"<leader>wc"`, -- Open a wiki from list
- _open_next_index_ = `"<leader>wn"`, -- Switch to the next wiki if available
- _open_diary_index_ = `"<leader>wi"`, -- Open the diary index file
- _diary_update_ = `"<leader>w<leader>i"`, -- Update the diary index files with new available entries
- _diary_today_ = `"<leader>w<leader>w"`, -- Open a new diary entry ("Today")
- _diary_tomorrow_ = `"<leader>w<leader>t"`, -- Open a new diary entry ("Tomorrow")
- _diary_yesterday_ = `"<leader>w<leader>y"`, -- Open yesterday's diary entry

example

```lua
    use {
        "ranjithshegde/orgWiki.nvim",
        config = function()
            require("orgWiki").setup {
                wiki_path = { "~/Documents/Orgs/" },
                diary_path = "~/Documents/Orgs/diary/",
            }
        end,
    }
```

## TODO

- Add a proper todo with roadmap!
