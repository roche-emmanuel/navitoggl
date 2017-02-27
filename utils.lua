-- cf. http://stackoverflow.com/questions/11201262/how-to-read-data-from-a-file-in-lua

local writtenTables = {};
local currentLevel = 0;
local maxLevel = 4;
local indentStr="  ";
local indent=0;

function pushIndent()
	indent = indent+1
end

function popIndent()
	indent = math.max(0,indent-1)
end

function incrementLevel()
	currentLevel = math.min(currentLevel+1,maxLevel)
	return currentLevel~=maxLevel; -- return false if we are on the max level.
end

function decrementLevel()
	currentLevel = math.max(currentLevel-1,0)
end

--- Write a table to the log stream.
function writeTable(t)
	local msg = "" -- we do not add the indent on the first line as this would 
	-- be a duplication of what we already have inthe write function.
	
	local id = tostring(t);
	
	if writtenTables[t] then
		msg = id .. " (already written)"
	else
		msg = id .. " {\n"
		
		-- add the table into the set:
		writtenTables[t] = true
		
		pushIndent()
		if incrementLevel() then
			local quote = ""
			for k,v in pairs(t) do
				quote = type(v)=="string" and not tonumber(v) and '"' or ""
				msg = msg .. string.rep(indentStr,indent) .. tostring(k) .. " = ".. quote .. writeItem(v) .. quote .. ",\n" -- 
			end
			decrementLevel()
		else
			msg = msg .. string.rep(indentStr,indent) .. "(too many levels)";
		end
		popIndent()
		msg = msg .. string.rep(indentStr,indent) .. "}"
	end
	
	return msg;
end

--- Write a single item as a string.
function writeItem(item)
	if type(item) == "table" then
		-- concatenate table:
		return item.__tostring and tostring(item) or writeTable(item)
	elseif item==false then
		return "false";
	else
		-- simple concatenation:
		return tostring(item);
	end
end

--- Write input arguments as a string.
function write(...)
	writtenTables = {};
	currentLevel = 0
	
	local msg = string.rep(indentStr,indent);	
	local num = select('#', ...)
	for i=1,num do
		local v = select(i, ...)
		msg = msg .. (v~=nil and writeItem(v) or "nil")
	end
	
	return msg;
end

_G.log = function(...)
  print(write(...))
end

-- see if the file exists
function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function lines_from(file)
  if not file_exists(file) then return {} end
  lines = {}
  for line in io.lines(file) do 
    lines[#lines + 1] = line
  end
  return lines
end

-- cf. http://lua-users.org/wiki/LuaCsv
function ParseCSVLine(line,sep) 
	local res = {}
	local pos = 1
	sep = sep or ','
	while true do 
		local c = string.sub(line,pos,pos)
		if (c == "") then break end
		if (c == '"') then
			-- quoted value (ignore separator within)
			local txt = ""
			repeat
				local startp,endp = string.find(line,'^%b""',pos)
				txt = txt..string.sub(line,startp+1,endp-1)
				pos = endp + 1
				c = string.sub(line,pos,pos) 
				if (c == '"') then txt = txt..'"' end 
				-- check first char AFTER quoted string, if it is another
				-- quoted string without separator, then append it
				-- this is the way to "escape" the quote char in a quote. example:
				--   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
			until (c ~= '"')
			table.insert(res,txt)
			assert(c == sep or c == "")
			pos = pos + 1
		else	
			-- no quotes used, just look for the first separator
			local startp,endp = string.find(line,sep,pos)
			if (startp) then 
				table.insert(res,string.sub(line,pos,startp-1))
				pos = endp + 1
			else
				-- no separator found -> use rest of string and terminate
				table.insert(res,string.sub(line,pos))
				break
			end 
		end
	end
	return res
end

-- Helper function used to load a CSV file:
local loadCSV = function(fname, offset)
  local lines = lines_from(fname)
  
  -- Start position:
  local pos = 1 + (offset or 0)
  local num = #lines;
  log("Parsing ",num," CSV lines...");

  local data = {}
  for i=pos,num do 
    table.insert(data,ParseCSVLine(lines[i]))
  end

  return data
end

local convDate = function(dstr)
  return dstr:sub(9,10).."/"..dstr:sub(6,7).."/"..dstr:sub(1,4)
end

local convDuration = function(tstr)
  -- log("tstr: ", tstr)
  local nhs = tonumber(tstr:sub(1,2))
  local nmins = tonumber(tstr:sub(4,5))
  local nsecs = tonumber(tstr:sub(7,8))

  -- Return total number of seconds:
  return nhs*3600+nmins*60+nsecs
end

-- helper method used to load toggl entries
local loadTogglEntries = function(fname)
  local data = loadCSV(fname, 1)

  local entries = {}

  local num = #data;

  for i=1,num do
    local entry = {}
    entry.user = data[i][1]
    entry.client = data[i][3]
    entry.project = data[i][4]
    entry.task = data[i][5]
    entry.desc = data[i][6]
    entry.date = convDate(data[i][8])
    entry.duration = convDuration(data[i][12])
    entry.tags = data[i][13]

    table.insert(entries, entry)
  end

  return entries
end

-- Method used to append navision entries 
-- Applying project collapsing in the process if applicable:
local addNaviEntry = function(list, ent)
  local num = #list
  for i=1,num do 
    if(list[i].date == ent.date and list[i].job == ent.job and list[i].phase == ent.phase) then
      -- we should collapse this entry, so we just add the time:
      list[i].duration = list[i].duration + ent.duration
      return;
    end
  end

  -- Could not collapse the entry so we append it:
  table.insert(list, ent)
end

-- Method used to round the navision durations:
local roundDuration = function(dur)
  -- Compute the number of quarter of hours ceiled:
  local nq = math.ceil(dur/(60*15));

  -- Compute the number of hours and return this:
  return nq/4
end

-- Function used to round times:
local roundWorkDuration = function(list, cfg)
  local num = #list
  for i=1,num do
    list[i].duration = roundDuration(list[i].duration)
  end
end

-- Get the first date on the given entries:
local getStartTime = function(list)
  local num = #list
  local tval = nil
  for i=1,num do
    local d = list[i].date
    local val = os.time{year=d:sub(7,10), month=d:sub(4,5), day=d:sub(1,2)}
    if(tval==nil or val<tval) then
      tval = val
    end
  end

  return tval
end

-- Get the last date on the given entries:
local getEndTime = function(list)
  local num = #list
  local tval = nil
  for i=1,num do
    local d = list[i].date
    local val = os.time{year=d:sub(7,10), month=d:sub(4,5), day=d:sub(1,2)}
    if(tval==nil or val>tval) then
      tval = val
    end
  end

  return tval
end

-- Return all the entries corresponding to a given day:
local getDayEntries = function(list, day)
  local res = {}
  local num = #list
  for i=1,num do
    if(list[i].date == day) then
      table.insert(res, list[i])
    end
  end

  return res;
end

-- Get the total number of worked hours in a given list:
local getTotalWorkDuration = function(list)
  local total = 0;
  local num = #list
  for i=1,num do
    total = total + list[i].duration
  end

  return total
end

-- function used to convert from toggl entries to navision entries:
local togglToNavi = function(entries, cfg)
  local res = {}
  local num = #entries
  for i=1,num do 
    local ent = {}
    ent.date = entries[i].date
    ent.duration = entries[i].duration
    ent.job = cfg.jobFunc(entries[i])
    ent.phase = cfg.phaseFunc(entries[i], ent.job)

    addNaviEntry(res, ent)
  end

  roundWorkDuration(res, cfg)

  -- Get the first day:
  local startTime = getStartTime(res);
  local endTime = getEndTime(res);

  local final = {};

  local ndays = (endTime-startTime)/(3600*24)
  log("Number of days covered: ", ndays+1)

  local dayTime = startTime;
  local dayName = {
    "Sunday", "Monday", "Tuesday","Wednesday", "Thursday", "Friday", "Saturday"
  }
  
  -- Start from the start time and collect the required entries:
  for nd=0,ndays do
    -- get the date string:
    local d = os.date("*t",dayTime)
    if(d.wday~=1 and d.wday~=7) then
      local dayStr = string.format("%02d/%02d/%04d", d.day, d.month,d.year)
      log("Processing week day: ", dayStr, " (",dayName[d.wday],")")

      local sublist = getDayEntries(res, dayStr)
      for i=1,#sublist do
        table.insert(final, sublist[i])
      end

      -- Get the total work duration for that day:
      local workHours = getTotalWorkDuration(sublist)

      if(workHours < cfg.work_hours) then
        local compDur = cfg.work_hours - workHours
        log("Adding compensation of ",compDur," hours on ", dayStr)
        table.insert(final,{
          date=dayStr,
          duration=compDur,
          job="XABPDPA-GER",
          phase="COMPENSATE"
        })
      end
    end

    dayTime = dayTime + 3600*24
  end

  return final
end

-- Method used to write navision entries to output csv file
local writeNaviEntries = function(entries, cfg)
  -- First check if we should backup into the archive file
  if(cfg.archive_csv) then
    -- Read the content of the output csv file:
  
    local f = io.open(cfg.output_csv, "r")
    local str = f:read("*a")
    f:close();
    if(str~="") then
      log("Archiving previous entries...")
      f = io.open(cfg.archive_csv, "a")
      f:write(str)
      f:close();
    end

    local f = io.open(cfg.output_csv, "w")

    local num = #entries
    for i=1,num do
      -- Write each entry line by line:
      local ent = entries[i]
      local tt = {ent.date, ent.duration, ent.job, ent.phase}
      f:write(table.concat(tt,";") .."\n")
    end
    f:close()
  end
end

return {
  loadCSV = loadCSV,
  loadTogglEntries = loadTogglEntries,
  togglToNavi = togglToNavi,
  writeNaviEntries = writeNaviEntries
}

