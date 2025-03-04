local diary = {}
local exec = vim.api.nvim_command
local diaryPath = vim.fn.expand(vim.g.orgwiki_diary_path)
local diaryFileName = vim.fn.expand(vim.g.orgwiki_diary_index_filename)
local diaryIndex = diaryPath .. diaryFileName

local diaryHeader = [[#+:TITLE: OrgWiki Diary index file

* Index

]]

local date

local weeks = {
  "Sun",
  "Mon",
  "Tue",
  "Wed",
  "Thu",
  "Fri",
  "Sat",
}

local months = {
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
}

local getDate = function(day)
  if day == -1 then
    date = os.date("!*t", os.time() - 86400)
  elseif day == 1 then
    date = os.date("!*t", os.time() + 86400)
  elseif day == 0 then
    date = os.date "!*t"
  end
  if #tostring(date["day"]) == 1 then
    date["day"] = 0 .. date["day"]
  end
  if #tostring(date["month"]) == 1 then
    date["month"] = 0 .. date["month"]
  end

  return string.format("%s-%s-%s %s.org", date["year"], date["month"], date["day"], weeks[date["wday"]])
end

local getDiaryfiles = function()
  local dirs = vim.fn.system("ls " .. diaryPath)
  local list = vim.split(dirs, "\n")
  local result = {}

  for _, data in ipairs(list) do
    if not string.find(data, "index") then
      if data ~= "" then
        local ext = vim.fn.fnamemodify(data, ":e")
        if ext and ext == "org" then
          table.insert(
            result,
            string.format(
              "+ [[%s%s][%s]]",
              require("orgWiki.utils").link_types.file,
              data,
              vim.fn.fnamemodify(tostring(data), ":r")
            )
          )
        end
      end
    end
  end
  return result
end

local insertDiarySep = function(list)
  for index, value in ipairs(list) do
    if type(value) == "string" then
      if index == 1 then
        local year = string.gsub(string.match(value, "%d*-"), "-", "")
        local curMonth = string.match(value, "-%d*-")
        curMonth = string.gsub(curMonth, "-", "")
        curMonth = tonumber(curMonth)
        curMonth = months[curMonth]
        table.insert(list, index, string.format("*** *%s*\n", curMonth))
        table.insert(list, index, string.format("** *%s*\n", year))
      end
      local previous = list[index - 1]
      if type(previous) == "string" then
        local curMonth = string.match(value, "-%d*-")
        local prevMonth = string.match(previous, "-%d*-")
        if curMonth and prevMonth then
          curMonth = string.gsub(curMonth, "-", "")
          prevMonth = string.gsub(prevMonth, "-", "")
          prevMonth = tonumber(prevMonth)
          curMonth = tonumber(curMonth)
          if curMonth - prevMonth ~= 0 then
            if curMonth - prevMonth <= 0 then
              local year = string.gsub(string.match(value, "%d*-"), "-", "")
              curMonth = months[curMonth]
              table.insert(list, index, string.format("*** *%s*\n", curMonth))
              table.insert(list, index, string.format("\n** *%s*\n", year))
            else
              curMonth = months[curMonth]
              table.insert(list, index, string.format("\n*** *%s*\n", curMonth))
            end
          end
        end
      end
    end
  end
end

---This function scans the diary_path for all files and creates or updates an index file
---The index is categorized into months and years automatically
function diary.diaryGenerateIndex()
  local files = getDiaryfiles()
  insertDiarySep(files)
  local output = io.open(diaryIndex, "w+")
  output:write(diaryHeader)
  for _, file in ipairs(files) do
    file = file .. "\n"
    output:write(file)
  end
  output:close()
  pcall(vim.cmd, "redraw | e")
end

---Create or open current day's diary entry
---@param editcmd string eg: "vs","e","tabnew"
function diary.diaryTodayOpen(editcmd)
  local name = getDate(0)
  local opencmd = editcmd and editcmd .. " " or "e "
  exec("cd " .. diaryPath)
  vim.cmd(opencmd .. name)
end

---Open yesterday's diary entry
---@param editcmd string eg: "vs","e","tabnew"
function diary.diaryYesterdayOpen(editcmd)
  local name = getDate(-1)
  local opencmd = editcmd and editcmd .. " " or "e "
  exec("cd " .. diaryPath)
  vim.cmd(opencmd .. name)
end

---Create or open tomorrow's diary entry
---@param editcmd string eg: "vs","e","tabnew"
function diary.diaryTomorrowOpen(editcmd)
  local name = getDate(1)
  local opencmd = editcmd and editcmd .. " " or "e "
  exec("cd " .. diaryPath)
  vim.cmd(opencmd .. name)
end

---Open diary index file
---@param editcmd string eg: "vs","e","tabnew"
function diary.diaryIndexOpen(editcmd)
  local opencmd = editcmd and editcmd .. " " or "e "
  exec("cd " .. diaryPath)
  vim.cmd(opencmd .. diaryFileName)
end

return diary
