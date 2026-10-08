require "import"
import "android.widget.*"
import "android.content.*"
import "android.view.*"
import "android.graphics.drawable.*"
import "android.net.Uri"
import "android.text.*"
import "java.io.*"
import "android.database.sqlite.SQLiteDatabase"
local dlg = LuaDialog()
dlg.setTitle("Tournament Schedule Manager")
local appContext = activity or service or this
local APP_VERSION = 1
local UPDATE_URL = "https://raw.githubusercontent.com/umarofficial786/Cricket/refs/heads/main/main.lua"
-- ===== Helpers =====
local function getShape(color, radius)
 local s = GradientDrawable()
 s.setColor(tonumber(color)); s.setCornerRadius(radius or 15)
 return s
end
local function btn(id, text, color, radius, extra)
 local t = { Button; id = id; text = text; textColor = "#FFFFFF"; background = getShape(color, radius or 20); layout_width = "-1" }
 if extra then for k, v in pairs(extra) do t[k] = v end end
 return t
end
local function trim(s) return (tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")) end
local function toast(msg, long) Toast.makeText(appContext, msg, long and 1 or 0).show() end
local function safe(fn, fallback)
 return function(...)
  local r = {pcall(fn, ...)}
  if r[1] then return r[2] end
  pcall(function() Toast.makeText(appContext, "Something went wrong: " .. tostring(r[2]):sub(1, 140), 1).show() end)
  return fallback
 end
end
local RealAdapterView, RealDialogInterface = AdapterView, DialogInterface
local AdapterView = {
 OnItemClickListener = function(t) return RealAdapterView.OnItemClickListener({ onItemClick = safe(t.onItemClick) }) end,
 OnItemLongClickListener = function(t) return RealAdapterView.OnItemLongClickListener({ onItemLongClick = safe(t.onItemLongClick, true) }) end,
}
local DialogInterface = {
 OnClickListener = function(t) return RealDialogInterface.OnClickListener({ onClick = safe(t.onClick) }) end,
}
local function onTap(v, fn) v.setOnClickListener(View.OnClickListener({ onClick = safe(fn) })) end
local function say(msg, view)
 if view and pcall(function() view.announceForAccessibility(msg) end) then return end
 toast(msg)
end
local function cleanName(s) return trim((tostring(s or ""):gsub("%s*%(imported%)", ""))) end
local function safeName(s)
 local n = cleanName(s):gsub("[^%w]", "")
 return n ~= "" and n or "Tournament"
end
local function copyText(t, extra)
 local ok = pcall(function() service.copy(t) end)
 if not ok then
  ok = pcall(function() appContext.getSystemService(Context.CLIPBOARD_SERVICE).setPrimaryClip(ClipData.newPlainText("text", t)) end)
 end
 toast(ok and ("Copied!" .. (extra or "")) or "Could not copy - the text may be too large. Use Export to File instead.", not ok)
end
local function parseLines(text)
 local out = {}
 for line in tostring(text or ""):gmatch("[^\r\n]+") do
  local t = trim(line)
  if t ~= "" then out[#out + 1] = t end
 end
 return out
end
local dialogStack, dialogSeq, flowMark = {}, 0, 0
local function track(d)
 pcall(function() d.getWindow().setSoftInputMode(16) end)
 dialogSeq = dialogSeq + 1
 if #dialogStack > 40 then for _ = 1, 20 do table.remove(dialogStack, 1) end end
 dialogStack[#dialogStack + 1] = {d = d, seq = dialogSeq}
end
local function closeAll() -- close every window of the plugin (Exit, and after sharing)
 for _, e in ipairs(dialogStack) do pcall(function() e.d.dismiss() end) end
 dialogStack = {}
 pcall(function() dlg.dismiss() end)
end
local function closeToHome(d) -- back to the main screen
 pcall(function() d.dismiss() end)
 for _, e in ipairs(dialogStack) do pcall(function() e.d.dismiss() end) end
 dialogStack = {}
end
local function startFlow() flowMark = dialogSeq end
local function endFlow() -- wizard finished: close every step that is still open
 for i = #dialogStack, 1, -1 do
  local e = dialogStack[i]
  if e.seq > flowMark then
   pcall(function() e.d.dismiss() end)
   table.remove(dialogStack, i)
  end
 end
end
local noMenu
pcall(function()
 noMenu = ActionMode.Callback({
  onCreateActionMode = function() return false end,
  onPrepareActionMode = function() return false end,
  onActionItemClicked = function() return false end,
  onDestroyActionMode = function() end,
 })
end)
local function hardenEdit(e)
 pcall(function() e.setLongClickable(false) end)
 if noMenu then
  pcall(function() e.setCustomSelectionActionModeCallback(noMenu) end)
  pcall(function() e.setCustomInsertionActionModeCallback(noMenu) end)
 end
 pcall(function() e.setImportantForAutofill(2) end)
 pcall(function() e.setTextClassifier(luajava.bindClass("android.view.textclassifier.TextClassifier").NO_OP) end)
end
local function readClipboard()
 local text
 pcall(function()
  local cm = appContext.getSystemService(Context.CLIPBOARD_SERVICE)
  local clip = cm.getPrimaryClip()
  if clip and clip.getItemCount() > 0 then text = tostring(clip.getItemAt(0).coerceToText(appContext)) end
 end)
 return text
end
local function linkLabel(label, field)
 pcall(function()
  local id = field.getId()
  if id == nil or id <= 0 then id = View.generateViewId(); field.setId(id) end
  label.setLabelFor(id)
 end)
end
local function navRow(d)
 local row = LinearLayout(appContext)
 row.setOrientation(LinearLayout.HORIZONTAL)
 row.setPadding(8, 10, 8, 8)
 local defs = {
  {"Home", "0xFF3F51B5", "Home. Return to the main screen.", function() closeToHome(d) end},
  {"Back", "0xFF607D8B", "Back. Return to the previous screen.", function() pcall(function() d.dismiss() end) end},
  {"Exit", "0xFFD32F2F", "Exit. Close the plugin.", function() pcall(function() d.dismiss() end); closeAll() end},
 }
 for _, df in ipairs(defs) do
  local b = Button(appContext)
  b.setText(df[1]); b.setTextColor(0xFFFFFFFF); b.setTextSize(13)
  b.setBackground(getShape(df[2], 24))
  pcall(function() b.setContentDescription(df[3]) end)
  local lp = LinearLayout.LayoutParams(0, -2, 1)
  pcall(function() lp.setMargins(4, 0, 4, 0) end)
  b.setLayoutParams(lp)
  onTap(b, df[4])
  row.addView(b)
 end
 return row
end
local function navWrap(d, view, fill, primaryText, primaryColor)
 local box = LinearLayout(appContext)
 box.setOrientation(LinearLayout.VERTICAL)
 pcall(function() box.setBackgroundColor(0xFFF5F7FA) end)
 if fill then
  box.addView(view, LinearLayout.LayoutParams(-1, 0, 1))
 else
  local sv = ScrollView(appContext)
  sv.addView(view)
  box.addView(sv, LinearLayout.LayoutParams(-1, 0, 1))
 end
 local pbtn
 if primaryText then
  pbtn = Button(appContext)
  pbtn.setText(primaryText); pbtn.setTextColor(0xFFFFFFFF); pbtn.setTextSize(15)
  pbtn.setBackground(getShape(primaryColor or "0xFF00C853", 24))
  local lp = LinearLayout.LayoutParams(-1, -2)
  pcall(function() lp.setMargins(12, 8, 12, 2) end)
  pbtn.setLayoutParams(lp)
  box.addView(pbtn)
 end
 box.addView(navRow(d), LinearLayout.LayoutParams(-1, -2))
 return box, pbtn
end
local function makeDialog(title, layout)
 local d = LuaDialog()
 d.setTitle(title)
 local views = {}
 local root = loadlayout(layout, views)
 for _, id in ipairs({"closeBtn", "cancelBtn"}) do -- Back replaces Close / Cancel
  if views[id] then pcall(function() views[id].setVisibility(8) end) end
 end
 d.setView((navWrap(d, root, layout.layout_height == "-1")))
 d.show()
 track(d)
 return d, views
end
local function promptInput(title, initialValue, hint, onSave, keep)
 local d = LuaDialog()
 d.setTitle(title)
 local views = {}
 local box, pbtn = navWrap(d, loadlayout({
  LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1";
  { TextView; id = "lbl"; text = title; textSize = "14sp"; layout_marginBottom = "6dp"; layout_width = "-1"; };
  { EditText; id = "inp"; layout_width = "-1"; };
 }, views), false, keep and "Next" or "Save", "0xFF00C853")
 d.setView(box)
 local inp = views.inp
 hardenEdit(inp)
 if hint then inp.setHint(hint) end
 if initialValue then inp.setText(initialValue) end
 linkLabel(views.lbl, inp)
 track(d)
 onTap(pbtn, function()
  local val = trim(inp.getText())
  if val == "" then toast("Please enter a value.") return end
  if not keep then d.dismiss() end
  onSave(val)
 end)
 d.show()
end
local function confirmDialog(title, message, confirmLabel, onConfirm)
 local d = LuaDialog()
 d.setTitle(title); d.setMessage(message)
 d.setButton(confirmLabel, DialogInterface.OnClickListener({ onClick = onConfirm }))
 d.setButton2("Cancel", nil)
 d.show()
end
local function showListDialog(title, items, onSelect, onLong, keep)
 local d = LuaDialog()
 d.setTitle(title)
 local lv = ListView(appContext)
 lv.setAdapter(ArrayAdapter(appContext, android.R.layout.simple_list_item_1, items))
 pcall(function() lv.setDividerHeight(2) end)
 d.setView((navWrap(d, lv, true)))
 track(d)
 local di = d.show()
 lv.setOnItemClickListener(AdapterView.OnItemClickListener({ onItemClick = function(_, _, pos, _)
  if not keep and di then di.dismiss() end
  onSelect(pos)
 end}))
 if onLong then
  lv.setOnItemLongClickListener(AdapterView.OnItemLongClickListener({ onItemLongClick = function(_, _, pos, _)
   return onLong(pos, di)
  end}))
 end
end
local function showMultilineInputStep(title, hint, minCount, onSaved, keep, btnLabel)
 local d = LuaDialog()
 d.setTitle(title)
 local views = {}
 local box, pbtn = navWrap(d, loadlayout({
  LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1";
  { TextView; id = "lbl"; text = hint; textSize = "13sp"; layout_marginBottom = "6dp"; layout_width = "-1"; };
  btn("pasteBtn", "Paste Names from Clipboard", "0xFF00796B", 20, {layout_marginBottom = "6dp"});
  { EditText; id = "linesInput"; hint = "Lahore Qalandars\nKarachi Kings\nPeshawar Zalmi"; inputType = "textMultiLine"; minLines = 5; layout_width = "-1"; };
 }, views), false, btnLabel or (keep and "Next" or "Add"), "0xFF00C853")
 d.setView(box)
 hardenEdit(views.linesInput)
 linkLabel(views.lbl, views.linesInput)
 track(d)
 onTap(views.pasteBtn, function()
  local text = readClipboard()
  if not text or trim(text) == "" then toast("The clipboard is empty. Copy the team names first.") return end
  local lines = parseLines(text)
  local maxLines = 500
  if #lines > maxLines then
   for i = #lines, maxLines + 1, -1 do lines[i] = nil end
   toast("Only the first " .. maxLines .. " names were used.", true)
  end
  local all = parseLines(views.linesInput.getText())
  for _, l in ipairs(lines) do all[#all + 1] = l end
  views.linesInput.setText(table.concat(all, "\n"))
  say(#lines .. " names pasted.", views.pasteBtn)
 end)
 onTap(pbtn, function()
  local items = parseLines(views.linesInput.getText())
  if #items < minCount then toast("Please enter at least " .. minCount .. " item(s).") return end
  local seen = {}
  for _, it in ipairs(items) do
   if seen[it:lower()] then toast("Duplicate name: " .. it) return end
   seen[it:lower()] = true
  end
  if not keep then d.dismiss() end
  onSaved(items)
 end)
 d.show()
end
local function shareText(text, pkg)
 local sent = pcall(function()
  local i = Intent(Intent.ACTION_SEND)
  i.setType("text/plain"); i.putExtra(Intent.EXTRA_TEXT, text)
  if pkg then i.setPackage(pkg) end
  pcall(function() i.addFlags(268435456) end)
  appContext.startActivity(i)
 end)
 if not sent then
  pcall(function()
   local i2 = Intent(Intent.ACTION_SEND)
   i2.setType("text/plain"); i2.putExtra(Intent.EXTRA_TEXT, text)
   local ch = Intent.createChooser(i2, "Share")
   pcall(function() ch.addFlags(268435456) end)
   appContext.startActivity(ch)
  end)
 end
end
local LINK_TELEGRAM   = "https://t.me/UmarjaanPro"
local LINK_WA_CONTACT = "https://wa.me/923089162797"
local LINK_YOUTUBE    = "https://www.youtube.com/@UmarofficialPro"
local FLAG_PK = "\240\159\135\181\240\159\135\176" -- Pakistan flag (escaped so the file encoding never matters)
local function waFeedbackLink()
 local msg = FLAG_PK .. " Assalam-o-Alaikum! " .. FLAG_PK .. "\n\nI am using your Tournament Schedule plugin and I would like to share my feedback:\n\n"
 local ok, enc = pcall(function() return Uri.encode(msg) end)
 return ok and (LINK_WA_CONTACT .. "?text=" .. enc) or LINK_WA_CONTACT
end
local weekDays = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
local monthNames = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
local liveCapLabels = {"None", "1", "2", "3", "4"}
local groupCountLabels = {}
for i = 2, 10 do groupCountLabels[#groupCountLabels + 1] = i .. " groups" end
-- ===== Venues =====
local venueData = {
 Pakistan = { "Gaddafi Stadium, Lahore", "National Stadium, Karachi", "Rawalpindi Cricket Stadium", "Multan Cricket Stadium", "Iqbal Stadium, Faisalabad", "Arbab Niaz Stadium, Peshawar", "Bugti Stadium, Quetta", "Sheikhupura Stadium" },
 India = { "Wankhede Stadium, Mumbai", "Eden Gardens, Kolkata", "Arun Jaitley Stadium, Delhi", "M. Chinnaswamy Stadium, Bengaluru", "MA Chidambaram Stadium, Chennai", "Rajiv Gandhi International Stadium, Hyderabad", "PCA Stadium, Mohali", "Sawai Mansingh Stadium, Jaipur" },
 Bangladesh = { "Sher-e-Bangla National Stadium, Dhaka", "Zahur Ahmed Chowdhury Stadium, Chattogram", "Sylhet International Cricket Stadium", "Khulna Divisional Stadium", "Rajshahi Divisional Stadium" },
 UAE = { "Dubai International Cricket Stadium", "Sheikh Zayed Stadium, Abu Dhabi", "Sharjah Cricket Stadium" },
 Australia = { "Melbourne Cricket Ground", "Sydney Cricket Ground", "The Gabba, Brisbane", "Adelaide Oval", "Optus Stadium, Perth", "Bellerive Oval, Hobart" },
 England = { "Lord's, London", "The Oval, London", "Old Trafford, Manchester", "Edgbaston, Birmingham", "Headingley, Leeds", "Trent Bridge, Nottingham", "Rose Bowl, Southampton", "Riverside Ground, Chester-le-Street" },
 ["New Zealand"] = { "Eden Park, Auckland", "Basin Reserve, Wellington", "Hagley Oval, Christchurch", "Seddon Park, Hamilton", "Bay Oval, Mount Maunganui", "University Oval, Dunedin" },
 ["South Africa"] = { "Newlands, Cape Town", "The Wanderers, Johannesburg", "SuperSport Park, Centurion", "Kingsmead, Durban", "St George's Park, Gqeberha", "Boland Park, Paarl" },
 ["West Indies"] = { "Kensington Oval, Barbados", "Sabina Park, Jamaica", "Queen's Park Oval, Trinidad", "Providence Stadium, Guyana", "Sir Vivian Richards Stadium, Antigua", "Daren Sammy Cricket Ground, Saint Lucia", "Brian Lara Stadium, Trinidad", "Arnos Vale Ground, Saint Vincent" },
 Ireland = { "Malahide Cricket Club Ground, Dublin", "Stormont, Belfast", "Bready Cricket Club" },
 Zimbabwe = { "Harare Sports Club", "Queens Sports Club, Bulawayo", "Takashinga Cricket Club, Harare" },
 Afghanistan = { "Kabul International Cricket Stadium", "Kandahar International Cricket Stadium", "Ghazi Amanullah Khan Stadium, Jalalabad" },
 ["Sri Lanka"] = { "R. Premadasa Stadium, Colombo", "Galle International Stadium", "Pallekele International Cricket Stadium, Kandy", "Rangiri Dambulla International Stadium", "Sinhalese Sports Club, Colombo", "Mahinda Rajapaksa Stadium, Hambantota" },
 USA = { "Grand Prairie Stadium, Texas", "Nassau County International Cricket Stadium, New York", "Central Broward Regional Park, Florida", "Church Street Park, North Carolina" },
}
local venueCountryOrder = { "None", "World", "Pakistan", "India", "Bangladesh" }
local worldOrder = { "Pakistan", "India", "Bangladesh", "UAE", "Australia", "England", "New Zealand", "South Africa", "West Indies", "Ireland", "Zimbabwe", "Afghanistan", "Sri Lanka", "USA" }
local function getVenueList(country)
 if country == "None" then return {} end
 if country ~= "World" and venueData[country] then return venueData[country] end
 local all = {}
 for idx = 1, 8 do
  for _, c in ipairs(worldOrder) do
   if venueData[c] and venueData[c][idx] then all[#all + 1] = venueData[c][idx] end
  end
 end
 return all
end
-- ===== Dates =====
local function dateTs(s)
 local y, m, d = s:match("(%d+)-(%d+)-(%d+)")
 return os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12})
end
local function addDaysToDate(s, n) return os.date("%Y-%m-%d", dateTs(s) + n * 86400) end
local function weekdayIndex(s) return tonumber(os.date("%w", dateTs(s))) + 1 end
local function formatDateDisplay(s)
 local y, m, d = (s or ""):match("(%d+)-(%d+)-(%d+)")
 if not y then return s or "" end
 return weekDays[weekdayIndex(s)] .. ", " .. tonumber(d) .. " " .. (monthNames[tonumber(m)] or m) .. " " .. y
end
local function groupTitle(g) -- old single-letter groups are shown as "Group A"
 g = tostring(g or "")
 return (#g == 1) and ("Group " .. g) or g
end
local advanceInfo = {
 ["Playoffs|Qualifier"] = "Winner goes to the Final, loser plays Eliminator 2",
 ["Playoffs|Eliminator 1"] = "Winner plays Eliminator 2, loser is out",
 ["Playoffs|Eliminator 2"] = "Winner goes to the Final, loser is out",
 ["Playoff Super Six|Playoff 1"] = "Winner goes to the Semi Final, loser plays Eliminator 1",
 ["Playoff Super Six|Playoff 2"] = "Winner goes to the Semi Final, loser plays Eliminator 2",
 ["Playoff Super Six|Eliminator 1"] = "Winner goes to the Semi Final, loser is out",
 ["Playoff Super Six|Eliminator 2"] = "Winner goes to the Semi Final, loser is out",
}
local function advanceTag(group, label)
 local base = tostring(label or ""):gsub(" #%d+$", "")
 local note = advanceInfo[tostring(group or "") .. "|" .. base]
 return note and ("  -  " .. note) or ""
end
local function matchTag(group, label)
 local tag = groupTitle(group)
 label = tostring(label or "")
 if label ~= "" and label ~= tostring(group or "") then tag = (tag ~= "" and (tag .. " - ") or "") .. label end
 return tag
end
local function venueTag(v)
 v = tostring(v or "")
 return (v == "" or v == "TBD") and "" or ("  -  " .. v)
end
local function pickDate(_, onPicked, keep)
 showListDialog("Select Month", monthNames, function(mpos)
  local month = mpos + 1
  local todayY, todayM = tonumber(os.date("%Y")), tonumber(os.date("%m"))
  local year = (month < todayM) and (todayY + 1) or todayY
  local dim = os.date("*t", os.time({year = year, month = month + 1, day = 0})).day
  local items = {}
  for day = 1, dim do
   items[day] = day .. " - " .. weekDays[tonumber(os.date("%w", os.time({year = year, month = month, day = day, hour = 12}))) + 1]
  end
  showListDialog("Select Day", items, function(dpos)
   onPicked(string.format("%04d-%02d-%02d", year, month, dpos + 1))
  end, nil, keep)
 end, nil, keep)
end
-- ===== Round-robin generator (circle method) =====
local function generateRounds(teams, isDouble)
 local list = {}
 for _, t in ipairs(teams) do list[#list + 1] = t end
 if #list % 2 == 1 then list[#list + 1] = "__BYE__" end
 local n, rounds = #list, {}
 for _ = 1, n - 1 do
  local rm = {}
  for i = 1, math.floor(n / 2) do
   local home, away = list[i], list[n + 1 - i]
   if home ~= "__BYE__" and away ~= "__BYE__" then rm[#rm + 1] = {team1 = home, team2 = away, leg = 1} end
  end
  rounds[#rounds + 1] = rm
  local last = list[n]
  for i = n, 3, -1 do list[i] = list[i - 1] end
  list[2] = last
 end
 if isDouble then
  local base = #rounds
  for r = 1, base do
   local sw = {}
   for _, m in ipairs(rounds[r]) do sw[#sw + 1] = {team1 = m.team2, team2 = m.team1, leg = 2} end
   rounds[#rounds + 1] = sw
  end
 end
 return rounds
end
-- ===== Database =====
local db
pcall(function()
 db = SQLiteDatabase.openOrCreateDatabase(appContext.getFilesDir().getPath() .. "/squads.db", nil)
 db.execSQL("CREATE TABLE IF NOT EXISTS settings (k TEXT PRIMARY KEY, v TEXT);")
 db.execSQL("CREATE TABLE IF NOT EXISTS backups (id INTEGER PRIMARY KEY AUTOINCREMENT, filename TEXT, filepath TEXT, created_at TEXT, restored_at TEXT);")
 db.execSQL("CREATE TABLE IF NOT EXISTS tournaments (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, venue_country TEXT, start_date TEXT, format TEXT, round_type TEXT, created_at TEXT);")
 db.execSQL("CREATE TABLE IF NOT EXISTS tournament_matches (id INTEGER PRIMARY KEY AUTOINCREMENT, tournament_id INTEGER, group_name TEXT, match_no INTEGER, team1 TEXT, team2 TEXT, match_date TEXT, venue TEXT, leg INTEGER);")
 db.execSQL("CREATE TABLE IF NOT EXISTS official_log (id INTEGER PRIMARY KEY AUTOINCREMENT, match_id INTEGER, name TEXT, role TEXT);")
 db.execSQL("CREATE TABLE IF NOT EXISTS points_table (id INTEGER PRIMARY KEY AUTOINCREMENT, tournament_id INTEGER, name TEXT, points REAL);")
end)
if db then
 for _, sql in ipairs({
  "backups ADD COLUMN restored_at TEXT",
  "tournaments ADD COLUMN matches_per_day INTEGER", "tournaments ADD COLUMN live_per_day INTEGER", "tournaments ADD COLUMN room_link_buffer INTEGER", "tournaments ADD COLUMN time_zone TEXT",
  "tournament_matches ADD COLUMN is_live INTEGER", "tournament_matches ADD COLUMN umpire1 TEXT",
  "tournament_matches ADD COLUMN umpire2 TEXT", "tournament_matches ADD COLUMN commentator1 TEXT",
  "tournament_matches ADD COLUMN commentator2 TEXT", "tournament_matches ADD COLUMN organizer TEXT",
  "tournament_matches ADD COLUMN match_referee TEXT", "tournament_matches ADD COLUMN extra_note TEXT",
  "tournament_matches ADD COLUMN match_time TEXT", "points_table ADD COLUMN role TEXT", "points_table ADD COLUMN bonus_points REAL", "tournament_matches ADD COLUMN label TEXT", "tournament_matches ADD COLUMN winner TEXT", "tournament_matches ADD COLUMN ph1 TEXT", "tournament_matches ADD COLUMN ph2 TEXT",
 }) do pcall(function() db.execSQL("ALTER TABLE " .. sql .. ";") end) end
end
local function exec(sql, ...)
 local a, cnt, id = {...}, select("#", ...), nil
 pcall(function()
  local st = db.compileStatement(sql)
  for i = 1, cnt do
   local v = a[i]
   if type(v) == "number" then
    if v == math.floor(v) then st.bindLong(i, v) else st.bindDouble(i, v) end
   else
    st.bindString(i, tostring(v or ""))
   end
  end
  if sql:match("^%s*INSERT") then
   id = st.executeInsert()
   if id == -1 then id = nil end
  else
   id = st.executeUpdateDelete()
  end
  st.close()
 end)
 return id
end
local function query(sql, fn)
 pcall(function()
  local c = db.rawQuery(sql, nil)
  if c then while c.moveToNext() do fn(c) end c.close() end
 end)
end
local function inTransaction(fn)
 local started = pcall(function() db.beginTransaction() end)
 local ok = pcall(fn)
 if started then
  if ok then pcall(function() db.setTransactionSuccessful() end) end
  pcall(function() db.endTransaction() end)
 end
end
-- ===== Files / Backup =====
local function backupDirs()
 local dirs = {}
 local function add(d)
  if not d.exists() then d.mkdirs() end
  if d.exists() then dirs[#dirs + 1] = d end
 end
 pcall(function()
  local d = File(luajava.bindClass("android.os.Environment").getExternalStorageDirectory(), "TournamentSchedule/Backups")
  add(d)
  if #dirs > 0 and not d.canWrite() then dirs = {} end
 end)
 pcall(function()
  local base = appContext.getExternalFilesDir(nil)
  if base then add(File(base, "CricketSquadManager/Backups")) end
 end)
 pcall(function() add(File(appContext.getFilesDir(), "Backups")) end)
 return dirs
end
local function writeFile(fileName, text)
 for _, dir in ipairs(backupDirs()) do
  local ok, p = pcall(function()
   local f = File(dir, fileName)
   local w = OutputStreamWriter(FileOutputStream(f), "UTF-8")
   w.write(text); w.flush(); w.close()
   return f.getAbsolutePath()
  end)
  if ok and p then return p end
 end
end
local function exportFile(fileName, text, label)
 local path = writeFile(fileName, text)
 toast(path and (label .. ":\n" .. path) or "Could not save the file on this device.", true)
 return path
end
local function readFileText(path)
 local content
 pcall(function()
  local br = BufferedReader(InputStreamReader(FileInputStream(File(path)), "UTF-8"))
  local lines, line = {}, br.readLine()
  while line ~= nil do lines[#lines + 1] = line; line = br.readLine() end
  br.close(); content = table.concat(lines, "\n")
 end)
 return content
end
local function escapeField(s)
 s = tostring(s or "")
 s = s:gsub("\\", "\\\\"); s = s:gsub("\n", "\\n"); s = s:gsub("|", "\\p")
 return s
end
local function unescapeField(s)
 s = s:gsub("\\p", "|"); s = s:gsub("\\n", "\n"); s = s:gsub("\\\\", "\\")
 return s
end
local function splitFields(line, n)
 local fields, start = {}, 1
 for _ = 1, n - 1 do
  local idx = line:find("|", start, true)
  if not idx then break end
  fields[#fields + 1] = unescapeField(line:sub(start, idx - 1))
  start = idx + 1
 end
 fields[#fields + 1] = unescapeField(line:sub(start))
 return fields
end
local function rowLine(tag, c, n, ints)
 local f = {}
 for i = 0, n - 1 do f[#f + 1] = ints[i] and tostring(c.getInt(i)) or escapeField(c.getString(i)) end
 return tag .. "|" .. table.concat(f, "|")
end
local function buildBackupText(tid)
 local L, t = {}, tid and tostring(tid)
 local function where(col) return t and (" WHERE " .. col .. " = " .. t) or "" end
 query("SELECT id, name, venue_country, start_date, format, round_type, matches_per_day, live_per_day, room_link_buffer, time_zone FROM tournaments" .. where("id") .. " ORDER BY id ASC",
  function(c) L[#L + 1] = rowLine("TN", c, 10, {[0] = 1, [6] = 1, [7] = 1, [8] = 1}) end)
 query("SELECT tournament_id, group_name, match_no, team1, team2, match_date, venue, leg, is_live, umpire1, umpire2, commentator1, commentator2, organizer, match_referee, extra_note, match_time, id, label, winner, ph1, ph2 FROM tournament_matches" .. where("tournament_id") .. " ORDER BY id ASC",
  function(c) L[#L + 1] = rowLine("TM", c, 22, {[0] = 1, [2] = 1, [7] = 1, [8] = 1, [17] = 1}) end)
 query("SELECT tournament_id, name, points, role, bonus_points FROM points_table" .. where("tournament_id") .. " ORDER BY id ASC",
  function(c) L[#L + 1] = rowLine("PT", c, 5, {[0] = 1}) end)
 query("SELECT match_id, name, role FROM official_log" .. (t and (" WHERE match_id IN (SELECT id FROM tournament_matches WHERE tournament_id = " .. t .. ")") or "") .. " ORDER BY id ASC",
  function(c) L[#L + 1] = rowLine("OL", c, 3, {[0] = 1}) end)
 return table.concat(L, "\n")
end
local function nameExists(name)
 local found = false
 query("SELECT id FROM tournaments WHERE name = '" .. name:gsub("'", "''") .. "'", function() found = true end)
 return found
end
local function restoreBackupText(text)
 local tmap, mmap, n = {}, {}, {t = 0, m = 0, p = 0}
 inTransaction(function()
 for line in ((text or "") .. "\n"):gmatch("(.-)\n") do
  line = trim(line)
  local tag, rest = line:sub(1, 2), line:sub(4)
  if tag == "TN" then
   local f = splitFields(rest, 10)
   local name = nameExists(f[2]) and (f[2] .. " (imported)") or f[2]
   local id = exec("INSERT INTO tournaments (name, venue_country, start_date, format, round_type, matches_per_day, live_per_day, room_link_buffer, time_zone, created_at) VALUES (?,?,?,?,?,?,?,?,?,?);",
    name, f[3], f[4], f[5], f[6], tonumber(f[7]) or 1, tonumber(f[8]) or 0, tonumber(f[9]) or 0, f[10], os.date("%Y-%m-%d %H:%M"))
   if id then tmap[tonumber(f[1])] = id; n.t = n.t + 1 end
  elseif tag == "TM" then
   local f = splitFields(rest, 22)
   local tid = tmap[tonumber(f[1])]
   if tid then
    local id = exec("INSERT INTO tournament_matches (tournament_id, group_name, match_no, team1, team2, match_date, venue, leg, is_live, umpire1, umpire2, commentator1, commentator2, organizer, match_referee, extra_note, match_time, label, winner, ph1, ph2) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
     tid, f[2], tonumber(f[3]) or 0, f[4], f[5], f[6], f[7], tonumber(f[8]) or 1, tonumber(f[9]) or 0, f[10], f[11], f[12], f[13], f[14], f[15], f[16], f[17], f[19], f[20], f[21], f[22])
    if id then
     n.m = n.m + 1
     if tonumber(f[18]) then mmap[tonumber(f[18])] = id end
    end
   end
  elseif tag == "PT" then
   local f = splitFields(rest, 5)
   local tid = tmap[tonumber(f[1])]
   if tid and exec("INSERT INTO points_table (tournament_id, name, points, role, bonus_points) VALUES (?,?,?,?,?);", tid, f[2], tonumber(f[3]) or 0, f[4], tonumber(f[5]) or 0) then n.p = n.p + 1 end
  elseif tag == "OL" then
   local f = splitFields(rest, 3)
   local mid = mmap[tonumber(f[1])]
   if mid then exec("INSERT INTO official_log (match_id, name, role) VALUES (?,?,?);", mid, f[2], f[3]) end
  end
 end
 end)
 return n
end
-- One safety copy of a brand-new tournament, saved automatically right after it is created.
local function autoSaveTournament(tid, name)
 local text = buildBackupText(tid)
 if text == "" then return nil end
 return writeFile(safeName(name) .. "_Backup_Auto.txt", text)
end
local function exportBackup(tid, name)
 local text = buildBackupText(tid)
 if text == "" then toast("There's no data to backup yet.") return end
 exportFile((tid and (safeName(name) .. "_Backup_") or "AllTournaments_Backup_") .. os.date("%Y%m%d_%H%M%S") .. ".txt", text, "Backup saved")
end
local function showImportDialog(refreshFn)
 local files, seenPath = {}, {}
 for _, dir in ipairs(backupDirs()) do
  pcall(function()
   local arr = dir.listFiles()
   if not arr then return end
   local ok, len = pcall(function() return arr.length end)
   for i = 0, ((ok and len) or #arr) - 1 do
    local f = arr[i]
    local n, path = f.getName(), f.getAbsolutePath()
    if not seenPath[path] and n:find("Backup", 1, true) and n:sub(-4) == ".txt" then
     seenPath[path] = true
     files[#files + 1] = {name = n, path = path, mod = f.lastModified()}
    end
   end
  end)
 end
 table.sort(files, function(x, y) return x.mod > y.mod end)
 if #files == 0 then toast("No backup files found. Export a backup first.", true) return end
 local names = {}
 for i, r in ipairs(files) do
  query("SELECT restored_at FROM backups WHERE filepath = '" .. r.path:gsub("'", "''") .. "'", function(c) r.restored = c.getString(0) end)
  names[i] = r.name .. "  -  " .. os.date("%Y-%m-%d %H:%M", math.floor(r.mod / 1000)) .. (r.restored and "  [restored]" or "")
 end
 local function performImport(r)
  local content = readFileText(r.path)
  if not content or trim(content) == "" then toast("Could not read that backup file.", true) return end
  local n = restoreBackupText(content)
  local now = os.date("%Y-%m-%d %H:%M")
  exec("DELETE FROM backups WHERE filepath = ?;", r.path)
  exec("INSERT INTO backups (filename, filepath, created_at, restored_at) VALUES (?, ?, ?, ?);", r.name, r.path, now, now)
  toast(n.t .. " tournament(s), " .. n.m .. " matches, " .. n.p .. " points entries restored.", true)
  if refreshFn then pcall(refreshFn) end
 end
 showListDialog("Select a Backup (long press to delete)", names, function(pos)
  local r = files[pos + 1]
  if r.restored then
   confirmDialog("Already Restored", "You already restored this backup on " .. r.restored .. ".\n\nImporting again will add a second copy. Continue?", "Yes, Import Again", function() performImport(r) end)
  else
   performImport(r)
  end
 end, function(pos, di)
  local r = files[pos + 1]
  confirmDialog("Delete Backup", "Delete " .. r.name .. "? This cannot be undone.", "Yes, Delete", function()
   pcall(function() File(r.path).delete() end)
   exec("DELETE FROM backups WHERE filepath = ?;", r.path)
   toast("Backup deleted.")
   if di then di.dismiss() end
   showImportDialog(refreshFn)
  end)
  return true
 end)
end
-- ===== Help =====
local function getSetting(k)
 local val
 query("SELECT v FROM settings WHERE k = '" .. k .. "'", function(c) val = c.getString(0) end)
 return val
end
local function setSetting(k, v) exec("INSERT OR REPLACE INTO settings (k, v) VALUES (?, ?);", k, v) end
local function writeTextFile(path, text)
 return (pcall(function()
  local w = OutputStreamWriter(FileOutputStream(File(path)), "UTF-8")
  w.write(text); w.flush(); w.close()
 end))
end
-- Downloads a web page on a background thread; cb(code, text) runs on the screen (UI) thread.
local function httpGet(url, cb)
 local ok = pcall(function()
  local handler = luajava.newInstance("android.os.Handler", luajava.bindClass("android.os.Looper").getMainLooper())
  local worker = luajava.createProxy("java.lang.Runnable", { run = function()
   local code, body = 0, nil
   pcall(function()
    local conn = luajava.newInstance("java.net.URL", url).openConnection()
    conn.setConnectTimeout(8000); conn.setReadTimeout(20000); conn.setUseCaches(false)
    pcall(function() conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Android)") end)
    pcall(function() conn.setRequestProperty("Cache-Control", "no-cache") end)
    code = conn.getResponseCode()
    if code == 200 then
     local br = BufferedReader(InputStreamReader(conn.getInputStream(), "UTF-8"))
     local lines, line = {}, br.readLine()
     while line ~= nil do lines[#lines + 1] = line; line = br.readLine() end
     br.close(); body = table.concat(lines, "\n")
    end
   end)
   handler.post(luajava.createProxy("java.lang.Runnable", { run = safe(function() cb(code, body) end) }))
  end })
  luajava.newInstance("java.lang.Thread", worker).start()
 end)
 if not ok then cb(0, nil) end
end
-- Where this plugin's own main.lua lives.
local function scriptPath()
 local cands = {}
 pcall(function() if luapath then cands[#cands + 1] = luapath end end)
 pcall(function() if luadir then cands[#cands + 1] = luadir .. "/main.lua" end end)
 pcall(function()
  local src = debug.getinfo(1, "S").source
  if src and src:sub(1, 1) == "@" then cands[#cands + 1] = src:sub(2) end
 end)
 local folder = "\232\167\163\232\175\180"
 cands[#cands + 1] = "/sdcard/" .. folder .. "/Plugins/tournament/main.lua"
 cands[#cands + 1] = "/storage/emulated/0/" .. folder .. "/Plugins/tournament/main.lua"
 for _, path in ipairs(cands) do
  local ok, found = pcall(function() return File(path).exists() end)
  if ok and found then return path end
 end
end
-- Checks the new file is a complete, valid plugin before touching the old one; the old one is kept as main.lua.bak.
local function installUpdate(body, remote)
 body = tostring(body)
 local compile = loadstring or load
 local valid = body:find("Tournament Schedule Manager", 1, true) and (not compile or pcall(function()
  local f, err = compile(body)
  if not f then error(err) end
 end))
 if not valid then toast("The downloaded update is not valid, so nothing was changed.", true) return end
 local path = scriptPath()
 if not path then
  local saved = writeFile("main.lua", body)
  toast("Update downloaded" .. (saved and (" to:\n" .. saved .. "\nCopy it into the plugin folder.") or ", but it could not be saved."), true)
  return
 end
 pcall(function()
  local old = readFileText(path)
  if old and old ~= "" then writeTextFile(path .. ".bak", old) end
 end)
 local tmp = path .. ".new"
 local ok = writeTextFile(tmp, body) and File(tmp).renameTo(File(path))
 if not ok then ok = writeTextFile(path, body) end
 pcall(function() File(tmp).delete() end)
 if ok then
  toast("Updated to version " .. remote .. ". Please close the plugin and open it again.", true)
  closeAll()
 else
  toast("The update could not be saved. Your old version is unchanged.", true)
 end
end
-- manual = true: the user asked, so say the result even when nothing is new.
local function checkForUpdate(manual)
 if manual then toast("Checking for updates...") end
 httpGet(UPDATE_URL .. "?t=" .. os.time(), function(code, body)
  if code ~= 200 or not body or #body < 1000 then
   if manual then toast("Could not check for updates. Please check your internet connection.", true) end
   return
  end
  setSetting("lastUpdateCheck", tostring(os.time()))
  local remote = tonumber(tostring(body):match("local APP_VERSION = (%d+)"))
  if not remote then
   if manual then toast("The online file has no version number.", true) end
  elseif remote <= APP_VERSION then
   if manual then toast("You already have the latest version (" .. APP_VERSION .. ").") end
  else
   confirmDialog("Update available", "Version " .. remote .. " is available (you have version " .. APP_VERSION .. "). Your tournaments are not affected. Update now?", "Update", function() installUpdate(body, remote) end)
  end
 end)
end
local function showHelpDialog()
 local hd, v = makeDialog("Help & Feedback", {
  LinearLayout; orientation = "vertical"; padding = "20dp"; layout_width = "-1";
  btn("aboutBtn", "About & User Guide", "0xFF3F51B5", 10, {layout_marginBottom = "10dp"});
  btn("updBtn", "Check for Updates (version " .. APP_VERSION .. ")", "0xFF00796B", 10, {layout_marginBottom = "10dp"});
  btn("waBtn", "Send Feedback on WhatsApp", "0xFF128C7E", 10, {layout_marginBottom = "10dp"});
  btn("tgBtn", "Join Telegram Channel", "0xFF0088CC", 10, {layout_marginBottom = "10dp"});
  btn("ytBtn", "Subscribe on YouTube", "0xFFFF0000", 10, {layout_marginBottom = "15dp"});
  btn("closeBtn", "Close Menu", "0xFFD32F2F", 10);
 })
 onTap(v.aboutBtn, function()
  local d = LuaDialog()
  d.setTitle("About & User Guide")
  d.setMessage(
   "ABOUT\n" ..
   "Tournament Schedule Manager - developed by Umar Jan. Version " .. APP_VERSION .. ".\n" ..
   "Plan a whole cricket tournament in minutes: balanced fixtures, live matches, officials and reminders, points table and backups, all on your phone.\n\n" ..
   "GETTING STARTED\n" ..
   "Open Tournament Schedule from the home screen. Tap + New Tournament to create one, or tap a tournament in the list to open its schedule. Press and hold a tournament to rename or delete it.\n\n" ..
   "CREATING A TOURNAMENT\n" ..
   "1. Enter the name, choose a venue (None, World, Pakistan, India or Bangladesh) and the start date.\n" ..
   "2. Weekly Match Pattern: tap a day to choose 1 to 4 matches or a rest day. Set the time of the first match and every match gets it; change any match afterwards if you wish. Choose how many matches are live each day, how many minutes before the match the room link is sent, and the time zone (PKT, IST or BST).\n" ..
   "3. Choose Round Robin or Group Wise (pick the number of groups from the list), then Single or Double rounds.\n" ..
   "4. Type the team names one per line, or copy them and tap Paste Names from Clipboard.\n" ..
   "Every team plays at even gaps and never twice in a day. Live matches are shared equally between teams, with no back-to-back live matches whenever possible. In Group Wise tournaments each day takes its matches from different groups whenever that keeps the schedule fair.\n\n" ..
   "THE TOURNAMENT SCREEN\n" ..
   "Tap a match to change its date or time, mark it live or not live, set its reminder and officials (for one match or for every match of that day), set its teams when they are not decided yet, or delete it.\n" ..
   "More Options: Set Reminder & Officials, Points Table, Next Round, copy the full schedule, by group or round, or by team, export the schedule, and Tournament Overview with the teams, groups and a fairness report.\n\n" ..
   "REMINDERS & OFFICIALS\n" ..
   "Fill in the umpires, commentators, organizer, match referee and an extra note. Tap Pick to reuse names already used in this tournament. Empty fields are left out. If you select several matches (for example a double header), a separate form opens for each match, one after another. Copy the reminder, or share it on WhatsApp Messenger or WhatsApp Business. The reminder shows the tournament name and, for every match, its number, group, date, time, room link time and venue. Each named official earns 2 points in the Points Table every time.\n\n" ..
   "NEXT ROUND\n" ..
   "Playoffs (Qualifier, Eliminator 1, Eliminator 2), Playoff Super Six (6 teams: Playoff 1 and 2, then Eliminator 1 and 2 for the losers), Super Four, Six, Eight or Ten, single stages (Quarter Final, Semi Final, Qualifier, Final) and Custom Round (Round Robin or Group Wise with any teams). Each round has its own weekly pattern and start date. Playoff matches show where the winner and the loser go next.\n\n" ..
   "POINTS TABLE\n" ..
   "Tap an entry to edit its points and bonus, press and hold to delete it. Copy the ranked list or one category, or export it to a file.\n\n" ..
   "BACKUP & RESTORE\n" ..
   "Tournament Schedule > More Options: Export All Tournaments, Export Single Tournament, Import from File and Delete All. Backups include fixtures, points tables and officials. They are saved in the TournamentSchedule/Backups folder of your phone storage, which stays even if you delete the plugin. When you create a new tournament its backup is saved automatically (TournamentName_Backup_Auto) and a message confirms it; after that you can export whenever you like. Restore it with Import.\n\n" ..
   "UPDATES\n" ..
   "The plugin looks online for a new version about twice a day and always asks before updating. You can also tap Check for Updates in Help. An update never touches your tournaments, and the previous version is kept next to it as main.lua.bak.\n\n" ..
   "NAVIGATION\n" ..
   "Every screen has Home, Back and Exit at the bottom. In a wizard, Back returns to the previous step and keeps what you entered.\n\n" ..
   "TIP\n" ..
   "Use Paste Names from Clipboard for long team lists, and check Tournament Overview after creating a tournament to see how fair the schedule is."
  )
  d.setButton("OK", nil)
  d.show()
 end)
 local function openLink(url)
  pcall(function() hd.dismiss() end)
  pcall(function() dlg.dismiss() end)
  pcall(function() appContext.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) end)
 end
 onTap(v.updBtn, function() checkForUpdate(true) end)
 onTap(v.waBtn, function() openLink(waFeedbackLink()) end)
 onTap(v.tgBtn, function() openLink(LINK_TELEGRAM) end)
 onTap(v.ytBtn, function() openLink(LINK_YOUTUBE) end)
 onTap(v.closeBtn, function() hd.dismiss() end)
end
-- ===== Weekly pattern =====
local hourCycle = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"}
local minuteCycle = {"00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55"}
local cycles = {hourCycle, minuteCycle, {"AM", "PM"}}
local partNames = {"Hour", "Minute", "AM or PM"}
local function nextInCycle(cycle, current)
 for i, v in ipairs(cycle) do
  if v == current then return cycle[(i % #cycle) + 1] end
 end
 return cycle[1]
end
local function parseTimeStr(t)
 local h, m, ap = (t or ""):match("(%d+):(%d+)%s*(%a%a)")
 if h then return h, m, ap:upper() end
 return "6", "00", "PM"
end
local function describe(b, k, slot, val)
 pcall(function() b.setContentDescription(partNames[k] .. " for match " .. slot .. ", currently " .. val .. ". Tap to change.") end)
end
local function shiftTime(t, minutes)
 local h, m, ap = parseTimeStr(t)
 local tot = ((tonumber(h) % 12) * 60 + tonumber(m) + (ap == "PM" and 720 or 0) - minutes) % 1440
 local nh = math.floor(tot / 60)
 return string.format("%d:%02d %s", (nh % 12 == 0) and 12 or (nh % 12), tot % 60, nh >= 12 and "PM" or "AM")
end
local roomLabels = {"None", "10 minutes", "15 minutes", "20 minutes"}
local roomValues = {0, 10, 15, 20}
local tzLabels = {"Pakistan (PKT)", "India (IST)", "Bangladesh (BST)"}
local tzCodes = {"PKT", "IST", "BST"}
local function showWeeklyScheduleDialog(onDone, opts)
 local pattern, liveCap, roomBuf, master, tz = {}, 0, 0, "6:00 PM", "PKT"
 for i = 1, 7 do pattern[i] = {count = 1, times = {master}, manual = {}, btns = {}} end
 local d, v = makeDialog("Weekly Match Pattern", {
  LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1"; layout_height = "-1";
  { TextView; text = "Tap a day to cycle 1-4 matches or Rest Day. Set the time of the very first match - it applies to all matches. After that you can change any match's time by hand."; textSize = "12sp"; layout_marginBottom = "8dp"; layout_width = "-1"; };
  { ScrollView; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp";
   { LinearLayout; id = "dayContainer"; orientation = "vertical"; };
  };
  btn("liveBtn", "Live Matches Per Day: None", "0xFF00796B", 20, {layout_marginBottom = "8dp"});
  btn("roomBtn", "Room Link Before Match: None", "0xFF00838F", 20, {layout_marginBottom = "8dp"});
  btn("tzBtn", "Time Zone: Pakistan (PKT)", "0xFF6A1B9A", 20, {layout_marginBottom = "8dp"});
  btn("nextBtn", "Next", "0xFF00C853", 20, {layout_marginBottom = "8dp"});
  btn("cancelBtn", "Cancel", "0xFFD32F2F", 20);
 })
 if opts and opts.next then -- room link and time zone stay as set for the tournament
  v.roomBtn.setVisibility(8); v.tzBtn.setVisibility(8)
 end
 local function setTime(i, slot, t)
  pattern[i].times[slot] = t
  local bs = pattern[i].btns[slot]
  if bs then
   local vals = {parseTimeStr(t)}
   for k = 1, 3 do bs[k].setText(vals[k]); describe(bs[k], k, slot, vals[k]) end
  end
 end
 local function rebuildRows(i, box)
  box.removeAllViews()
  pattern[i].btns = {}
  for slot = 1, pattern[i].count do
   local h, m, ap = parseTimeStr(pattern[i].times[slot])
   pattern[i].times[slot] = h .. ":" .. m .. " " .. ap
   local row = LinearLayout(appContext)
   row.setOrientation(LinearLayout.HORIZONTAL)
   row.setPadding(20, 2, 0, 2)
   local lbl = TextView(appContext)
   lbl.setText("Match " .. slot .. ": "); lbl.setTextSize(11)
   row.addView(lbl)
   local vals, bs = {h, m, ap}, {}
   for k = 1, 3 do
    local b = Button(appContext)
    b.setText(vals[k]); b.setTextSize(11); b.setTextColor(0xFFFFFFFF)
    b.setBackground(getShape(k == 3 and "0xFF795548" or "0xFF00796B", 6))
    describe(b, k, slot, vals[k])
    bs[k] = b
    onTap(b, function()
     local parts = {parseTimeStr(pattern[i].times[slot])}
     parts[k] = nextInCycle(cycles[k], parts[k])
     local t = parts[1] .. ":" .. parts[2] .. " " .. parts[3]
     local first = (slot == 1)
     for j = 1, i - 1 do if pattern[j].count > 0 then first = false end end
     setTime(i, slot, t)
     if first then
      master = t
      for j = 1, 7 do
       for s = 1, pattern[j].count do
        if not (j == i and s == 1) and not pattern[j].manual[s] then setTime(j, s, t) end
       end
      end
      say("First match " .. partNames[k] .. " " .. parts[k] .. ". All matches set to " .. t, b)
     else
      pattern[i].manual[slot] = true
      say("Match " .. slot .. " " .. partNames[k] .. " " .. parts[k], b)
     end
    end)
    row.addView(b)
   end
   pattern[i].btns[slot] = bs
   box.addView(row)
  end
 end
 local cycleCounts = {1, 2, 3, 4, 0}
 for i = 1, 7 do
  local block = LinearLayout(appContext)
  block.setOrientation(LinearLayout.VERTICAL)
  block.setPadding(0, 4, 0, 10)
  local dayBtn = Button(appContext)
  dayBtn.setText(weekDays[i] .. ": 1 match(es)")
  dayBtn.setTextColor(0xFFFFFFFF); dayBtn.setTextSize(12)
  dayBtn.setBackground(getShape("0xFF3F51B5", 10))
  dayBtn.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
  local box = LinearLayout(appContext)
  box.setOrientation(LinearLayout.VERTICAL)
  block.addView(dayBtn); block.addView(box)
  v.dayContainer.addView(block)
  rebuildRows(i, box)
  onTap(dayBtn, function()
   local idx = 1
   for k, c in ipairs(cycleCounts) do if c == pattern[i].count then idx = k end end
   local n = cycleCounts[(idx % #cycleCounts) + 1]
   local times = {}
   for s = 1, n do times[s] = pattern[i].times[s] or master end
   pattern[i].count, pattern[i].times = n, times
   local label = (n == 0) and (weekDays[i] .. ": Rest Day") or (weekDays[i] .. ": " .. n .. " match(es)")
   dayBtn.setText(label)
   rebuildRows(i, box)
   say(label, dayBtn)
  end)
 end
 onTap(v.liveBtn, function()
  showListDialog("Live Matches Per Day", liveCapLabels, function(pos)
   liveCap = pos
   v.liveBtn.setText("Live Matches Per Day: " .. liveCapLabels[pos + 1])
   say("Live matches per day: " .. liveCapLabels[pos + 1], v.liveBtn)
  end)
 end)
 onTap(v.roomBtn, function()
  showListDialog("Room Link Before Match", roomLabels, function(pos)
   roomBuf = roomValues[pos + 1]
   v.roomBtn.setText("Room Link Before Match: " .. roomLabels[pos + 1])
   say("Room link before match: " .. roomLabels[pos + 1], v.roomBtn)
  end)
 end)
 onTap(v.tzBtn, function()
  showListDialog("Select Time Zone", tzLabels, function(pos)
   tz = tzCodes[pos + 1]
   v.tzBtn.setText("Time Zone: " .. tzLabels[pos + 1])
   say("Time zone: " .. tzLabels[pos + 1], v.tzBtn)
  end)
 end)
 onTap(v.nextBtn, function()
  local total = 0
  for i = 1, 7 do total = total + pattern[i].count end
  if total == 0 then say("Please set at least one match for at least one day.") return end
  local maxPerDay = 0
  for i = 1, 7 do if pattern[i].count > maxPerDay then maxPerDay = pattern[i].count end end
  if liveCap > maxPerDay then
   say("Live matches per day (" .. liveCap .. ") cannot be more than the most matches in one day (" .. maxPerDay .. ").")
   return
  end
  pattern.roomBuf = roomBuf; pattern.tz = tz
  onDone(pattern, liveCap)
 end)
 onTap(v.cancelBtn, function() d.dismiss() end)
end
-- ===== Balanced scheduler =====
local function lessKey(ka, kb)
 for i = 1, 3 do
  if ka[i] ~= kb[i] then return ka[i] < kb[i] end
 end
 return ka[4] < kb[4]
end
local function scheduleOnce(queue, pattern, startDate, liveCap, jitter, groupMode)
 local total, played, last, lc, prev, rem, teams, leg1 = {}, {}, {}, {}, {}, {}, {}, {}
 local tg, gTotal, gPlayed, gLive, gLeft, gTeams, gOrder, gIdx = {}, {}, {}, {}, {}, {}, {}, {}
 for _, q in ipairs(queue) do
  local m = {team1 = q.team1, team2 = q.team2, leg = q.leg or 1, group = q.group}
  local g = m.group or ""
  if not gTotal[g] then
   gTotal[g], gPlayed[g], gLive[g], gLeft[g], gTeams[g] = 0, 0, 0, 0, {}
   gOrder[#gOrder + 1] = g; gIdx[g] = #gOrder
  end
  gTotal[g] = gTotal[g] + 1; gLeft[g] = gLeft[g] + 1
  for _, t in ipairs({m.team1, m.team2}) do
   if not total[t] then
    total[t], played[t], last[t], lc[t], prev[t], rem[t] = 0, 0, 0, 0, false, {}
    teams[#teams + 1] = t
   end
   total[t] = total[t] + 1
   tg[t] = g; gTeams[g][t] = true
  end
  local list = rem[m.team1][m.team2]
  if not list then list = {}; rem[m.team1][m.team2] = list; rem[m.team2][m.team1] = list end
  list[#list + 1] = m
  if m.leg == 1 then leg1[m.group or ""] = (leg1[m.group or ""] or 0) + 1 end
 end
 local gSize = {}
 for g, set in pairs(gTeams) do
  local n = 0
  for _ in pairs(set) do n = n + 1 end
  gSize[g] = n
 end
 groupMode = groupMode and #gOrder > 1 -- every day takes its matches from different groups, in turn
 local scheduled, slotNo, dayIndex, left, safety = {}, 0, 0, #queue, 0
 while left > 0 and safety < 6000 do
  safety = safety + 1
  local date = addDaysToDate(startDate, dayIndex)
  local wd = weekdayIndex(date)
  local cap = pattern[wd].count
  local k = (liveCap > 0) and math.min(liveCap, cap) or 0
  local enforce = k > 0 and k < cap
  local used = {}
  for s = 1, cap do
   local isLive = s <= k
   local key = {}
   for _, t in ipairs(teams) do
    if not used[t] then
     local x = isLive and lc[t] or (prev[t] and 0 or 1)
     key[t] = {played[t] / total[t], x + math.random() * jitter * 0.5, last[t] + math.random() * jitter * 2, t}
    end
   end
   local function pickMatch(restrict, allowed)
    local cand = {}
    for _, t in ipairs(teams) do
     if not used[t] and not (restrict and prev[t]) and (not allowed or allowed[t]) then cand[#cand + 1] = t end
    end
    table.sort(cand, function(x, y) return lessKey(key[x], key[y]) end)
    for _, t in ipairs(cand) do
     local bestO
     for o, list in pairs(rem[t]) do
      if #list > 0 and not used[o] and not (restrict and prev[o]) then
       local f = list[1]
       if f.leg == 1 or (leg1[f.group or ""] or 0) == 0 then
        if not bestO or lessKey(key[o], key[bestO]) then bestO = o end
       end
      end
     end
     if bestO then return t, bestO end
    end
    return nil
   end
   local function pickAny(restrict)
    if not groupMode then return pickMatch(restrict) end
    local order, gk = {}, {}
    for _, g in ipairs(gOrder) do
     if gLeft[g] > 0 then
      order[#order + 1] = g
      gk[g] = {gPlayed[g] / gTotal[g], (gLive[g] / gSize[g]) * (isLive and 1 or -1), gIdx[g], 0}
     end
    end
    table.sort(order, function(a, b) return lessKey(gk[a], gk[b]) end)
    for _, g in ipairs(order) do
     local t, o = pickMatch(restrict, gTeams[g])
     if t then return t, o end
    end
    return nil
   end
   local t, o = pickAny(isLive and enforce)
   if not t and isLive and enforce then t, o = pickAny(false) end
   if not t then break end
   local f = table.remove(rem[t][o], 1)
   slotNo = slotNo + 1
   for _, x in ipairs({t, o}) do
    played[x] = played[x] + 1; last[x] = slotNo; used[x] = true
    if isLive then lc[x] = lc[x] + 1 end
    prev[x] = isLive
   end
   left = left - 1
   local g = tg[t]
   gPlayed[g] = gPlayed[g] + 1; gLeft[g] = gLeft[g] - 1
   if isLive then gLive[g] = gLive[g] + 1 end
   if f.leg == 1 then leg1[f.group or ""] = leg1[f.group or ""] - 1 end
   f.match_date = date; f.match_time = pattern[wd].times[s] or ""
   f.is_live = isLive and 1 or 0; f.dayIndex = dayIndex
   scheduled[#scheduled + 1] = f
  end
  dayIndex = dayIndex + 1
 end
 return scheduled
end
local function evaluateSchedule(scheduled)
 local seq = {}
 for i, m in ipairs(scheduled) do
  for _, t in ipairs({m.team1, m.team2}) do
   seq[t] = seq[t] or {}
   seq[t][#seq[t] + 1] = i
  end
 end
 local dayInfo, nGroups, seenG = {}, 0, {}
 for _, m in ipairs(scheduled) do
  local g = m.group or ""
  if not seenG[g] then seenG[g] = true; nGroups = nGroups + 1 end
  local di = dayInfo[m.dayIndex]
  if not di then di = {n = 0, g = {}, d = 0}; dayInfo[m.dayIndex] = di end
  di.n = di.n + 1
  if not di.g[g] then di.g[g] = true; di.d = di.d + 1 end
 end
 local unmixed = 0
 if nGroups > 1 then
  for _, di in pairs(dayInfo) do
   if di.n > 1 and di.d < math.min(di.n, nGroups) then unmixed = unmixed + 1 end
  end
 end
 local b2b, lo, hi, gLo, gHi = 0, nil, nil, nil, nil
 for _, list in pairs(seq) do
  local live, prev, prevDay = 0, false, nil
  for _, i in ipairs(list) do
   local m = scheduled[i]
   local l = m.is_live == 1
   if l then live = live + 1; if prev then b2b = b2b + 1 end end
   prev = l
   if prevDay then
    local g = m.dayIndex - prevDay
    if not gLo or g < gLo then gLo = g end
    if not gHi or g > gHi then gHi = g end
   end
   prevDay = m.dayIndex
  end
  if not lo or live < lo then lo = live end
  if not hi or live > hi then hi = live end
 end
 local spread, gapSpread = (hi or 0) - (lo or 0), (gHi or 0) - (gLo or 0)
 return b2b * 1000 + spread * 100 + gapSpread * 10 + unmixed * 5, b2b, spread, seq
end
local function polishLive(scheduled, seq)
 local days, order = {}, {}
 for i, m in ipairs(scheduled) do
  if not days[m.dayIndex] then days[m.dayIndex] = {}; order[#order + 1] = m.dayIndex end
  table.insert(days[m.dayIndex], i)
 end
 local function teamCost(t)
  local live, b2b, prev = 0, 0, false
  for _, i in ipairs(seq[t]) do
   local l = scheduled[i].is_live == 1
   if l then live = live + 1; if prev then b2b = b2b + 1 end end
   prev = l
  end
  return live * live + 1000 * b2b
 end
 for _ = 1, 30 do
  local improved = false
  for _, d in ipairs(order) do
   local idxs = days[d]
   for _, a in ipairs(idxs) do
    for _, b in ipairs(idxs) do
     if scheduled[a].is_live == 1 and scheduled[b].is_live == 0 then
      local ts, seen = {}, {}
      for _, i in ipairs({a, b}) do
       for _, t in ipairs({scheduled[i].team1, scheduled[i].team2}) do
        if not seen[t] then seen[t] = true; ts[#ts + 1] = t end
       end
      end
      local before = 0
      for _, t in ipairs(ts) do before = before + teamCost(t) end
      scheduled[a].is_live, scheduled[b].is_live = 0, 1
      local after = 0
      for _, t in ipairs(ts) do after = after + teamCost(t) end
      if after < before then improved = true
      else scheduled[a].is_live, scheduled[b].is_live = 1, 0 end
     end
    end
   end
  end
  if not improved then break end
 end
end
local function scheduleBalanced(queue, pattern, startDate, liveCap)
 math.randomseed(os.time())
 local best, bestCost, bestB2B, bestSpread
 local tries = math.max(1, math.min(60, math.floor(60000 / math.max(1, #queue))) + 1)
 local t0 = os.clock()
 for attempt = 1, tries do
  local sch = scheduleOnce(queue, pattern, startDate, liveCap, attempt <= 2 and 0 or 1, attempt % 2 == 0)
  local cost, b2b, spread, seq = evaluateSchedule(sch)
  if liveCap > 0 then
   polishLive(sch, seq)
   cost, b2b, spread = evaluateSchedule(sch)
  end
  if not best or cost < bestCost then best, bestCost, bestB2B, bestSpread = sch, cost, b2b, spread end
  if (bestCost <= 120 and attempt >= 2) or os.clock() - t0 > 2 then break end
 end
 return best, bestB2B, bestSpread
end
-- ===== Officials / Reminders / Points =====
local function pickSavedName(role, tid, onPicked)
 local names = {}
 query("SELECT DISTINCT name FROM official_log WHERE role = '" .. role:gsub("'", "''") .. "' AND match_id IN (SELECT id FROM tournament_matches WHERE tournament_id = " .. tostring(tid) .. ") ORDER BY name ASC", function(c) names[#names + 1] = c.getString(0) end)
 if #names == 0 then toast("No saved " .. role .. " names in this tournament yet.") return end
 showListDialog("Saved " .. role .. " Names (press and hold to delete)", names, function(pos) onPicked(names[pos + 1]) end, function(pos, di)
  local nm = names[pos + 1]
  confirmDialog("Delete Name", "Remove " .. nm .. " from the saved " .. role .. " names of this tournament?", "Yes, Delete", function()
   exec("DELETE FROM official_log WHERE role = ? AND name = ? AND match_id IN (SELECT id FROM tournament_matches WHERE tournament_id = ?);", role, nm, tid)
   toast("Deleted.")
   if di then di.dismiss() end
   pickSavedName(role, tid, onPicked)
  end)
  return true
 end)
end
local function addPointsForOfficial(tid, name, role)
 if name == "" or not tid then return end
 local existing
 query("SELECT id FROM points_table WHERE tournament_id = " .. tostring(tid) .. " AND name = '" .. name:gsub("'", "''") .. "' AND role = '" .. role .. "'", function(c) existing = c.getInt(0) end)
 if existing then exec("UPDATE points_table SET points = points + 2 WHERE id = ?;", existing)
 else exec("INSERT INTO points_table (tournament_id, name, points, role) VALUES (?, ?, 2, ?);", tid, name, role) end
end
local officialFields = {
 {"u1", "First Umpire", "Umpire", "1st Umpire", "Umar Jan"}, {"u2", "Second Umpire", "Umpire", "2nd Umpire", "S.N. Attari"},
 {"c1", "First Commentator", "Commentator", "1st Commentator", "Syed Murtaza Gillani"}, {"c2", "Second Commentator", "Commentator", "2nd Commentator", "Taimur Khan"},
 {"org", "Organizer", "Organizer", "Organizer", "Syed Mujtaba Gillani"}, {"ref", "Match Referee", "Match Referee", "Match Referee", "Jam Ahmed Razzaq"},
}
local function showMatchOfficialsDialog(recs, tournamentId)
 local n = #recs
 local tzName, tName, roomBuf = "", "", 0
 query("SELECT time_zone, name, room_link_buffer FROM tournaments WHERE id = " .. tostring(tournamentId), function(c) tzName = c.getString(0) or ""; tName = cleanName(c.getString(1)); roomBuf = c.getInt(2) end)
 local collected = {}
 local function matchLine(rec)
  local tag = matchTag(rec.group_name, rec.label)
  local mt = rec.match_time or ""
  local z = (tzName ~= "") and (" " .. tzName) or ""
  local timeText = ""
  if mt ~= "" then
   timeText = (roomBuf > 0) and ("  -  Match Room Link " .. shiftTime(mt, roomBuf) .. z .. " - Match Start " .. mt .. z) or (" " .. mt .. z)
  end
  return "Match " .. tostring(rec.match_no or "") .. (tag ~= "" and (" [" .. tag .. "]") or "") .. ": " .. rec.team1 .. " vs " .. rec.team2 ..
   "  -  " .. formatDateDisplay(rec.match_date) .. timeText .. venueTag(rec.venue)
 end
 local function readForm(v)
  local vals, seen = {}, {}
  for _, f in ipairs(officialFields) do
   local val = trim(v[f[1]].getText())
   vals[f[1]] = val
   if val ~= "" then
    if seen[val:lower()] then toast(val .. " is entered more than once for this match.", true) return nil end
    seen[val:lower()] = true
   end
  end
  return {vals = vals, note = trim(v.note.getText())}
 end
 -- saves every match with its own officials and builds one reminder text
 local function finish(action)
  local ids, blocks, warn = {}, {}, {}
  for _, rec in ipairs(recs) do ids[#ids + 1] = tostring(rec.id) end
  for i, rec in ipairs(recs) do
   local vals, note = collected[i].vals, collected[i].note
   exec("UPDATE tournament_matches SET umpire1=?, umpire2=?, commentator1=?, commentator2=?, organizer=?, match_referee=?, extra_note=? WHERE id=?;",
    vals.u1, vals.u2, vals.c1, vals.c2, vals.org, vals.ref, note, rec.id)
   exec("DELETE FROM official_log WHERE match_id = ?;", rec.id)
   local lines = {matchLine(rec)}
   for _, f in ipairs(officialFields) do
    local nm = vals[f[1]]
    if nm ~= "" then
     exec("INSERT INTO official_log (match_id, name, role) VALUES (?, ?, ?);", rec.id, nm, f[3])
     addPointsForOfficial(tournamentId, nm, f[3])
     lines[#lines + 1] = f[4] .. ": " .. nm
     if (rec.match_time or "") ~= "" then
      query("SELECT team1, team2 FROM tournament_matches WHERE tournament_id = " .. tostring(tournamentId) .. " AND match_date = '" .. rec.match_date .. "' AND match_time = '" .. rec.match_time .. "' AND id NOT IN (" .. table.concat(ids, ",") .. ") AND '" .. nm:gsub("'", "''") .. "' IN (umpire1, umpire2, commentator1, commentator2, organizer, match_referee)",
       function(c) warn[#warn + 1] = nm .. " is also assigned to " .. (c.getString(0) or "?") .. " vs " .. (c.getString(1) or "?") .. " at the same time." end)
     end
    end
   end
   if note ~= "" then
    exec("INSERT INTO official_log (match_id, name, role) VALUES (?, ?, ?);", rec.id, note, "Extra Note")
    lines[#lines + 1] = "Note: " .. note
   end
   blocks[#blocks + 1] = table.concat(lines, "\n")
  end
  for i = 1, n - 1 do -- the same person in two selected matches at the same time
   for j = i + 1, n do
    local a, b = recs[i], recs[j]
    if (a.match_time or "") ~= "" and a.match_date == b.match_date and a.match_time == b.match_time then
     for _, f in ipairs(officialFields) do
      local nm = collected[i].vals[f[1]]
      if nm ~= "" then
       for _, g in ipairs(officialFields) do
        if collected[j].vals[g[1]]:lower() == nm:lower() then
         warn[#warn + 1] = nm .. " is in both " .. a.team1 .. " vs " .. a.team2 .. " and " .. b.team1 .. " vs " .. b.team2 .. " at the same time."
        end
       end
      end
     end
    end
   end
  end
  if #warn > 0 then toast("Warning:\n" .. table.concat(warn, "\n"), true) end
  action("Match Reminder" .. (tName ~= "" and (" - " .. tName) or "") .. "\n\n" .. table.concat(blocks, "\n\n"))
 end
 local function showForm(i)
  local rec, last = recs[i], (i == n)
  local lay = { LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1";
   { TextView; id = "hdr"; text = ((n > 1) and ("Officials for match " .. i .. " of " .. n .. "\n") or "") .. matchLine(rec); textSize = "14sp"; textColor = "#1A237E"; style = "bold"; layout_marginBottom = "8dp"; layout_width = "-1"; };
  }
  for _, f in ipairs(officialFields) do
   lay[#lay + 1] = { TextView; id = f[1] .. "Lbl"; text = f[2]; textSize = "13sp"; textColor = "#37474F"; layout_width = "-1"; }
   lay[#lay + 1] = { LinearLayout; orientation = "horizontal"; layout_marginBottom = "6dp"; layout_width = "-1";
    { EditText; id = f[1]; hint = f[5]; layout_weight = 1; };
    { Button; id = f[1] .. "Pick"; text = "Pick"; textColor = "#FFFFFF"; background = getShape("0xFF3F51B5", 8); layout_marginLeft = "4dp"; };
   }
  end
  lay[#lay + 1] = { TextView; id = "noteLbl"; text = "Extra Note"; textSize = "13sp"; textColor = "#37474F"; layout_width = "-1"; }
  lay[#lay + 1] = { LinearLayout; orientation = "horizontal"; layout_marginBottom = "8dp"; layout_width = "-1";
   { EditText; id = "note"; hint = "Add a note for this match"; inputType = "textMultiLine"; minLines = 2; layout_weight = 1; };
   { Button; id = "notePick"; text = "Pick"; textColor = "#FFFFFF"; background = getShape("0xFF3F51B5", 8); layout_marginLeft = "4dp"; };
  }
  if last then
   lay[#lay + 1] = { LinearLayout; orientation = "horizontal"; layout_width = "-1";
    { Button; id = "copyBtn"; text = "Copy"; layout_weight = 1; textColor = "#FFFFFF"; background = getShape("0xFF00C853", 10); layout_marginRight = "4dp"; };
    { Button; id = "msgBtn"; text = "WA Messenger"; layout_weight = 1; textColor = "#FFFFFF"; background = getShape("0xFF25D366", 10); layout_marginRight = "4dp"; };
    { Button; id = "bizBtn"; text = "WA Business"; layout_weight = 1; textColor = "#FFFFFF"; background = getShape("0xFF1FAF38", 10); };
   }
  end
  local d = LuaDialog()
  d.setTitle("Match Officials" .. ((n > 1) and (" " .. i .. "/" .. n) or ""))
  local v = {}
  local box, pbtn = navWrap(d, loadlayout(lay, v), false, (not last) and "Next Match" or nil, "0xFF00C853")
  d.setView(box)
  track(d)
  for _, f in ipairs(officialFields) do hardenEdit(v[f[1]]) end
  hardenEdit(v.note)
  for _, f in ipairs(officialFields) do linkLabel(v[f[1] .. "Lbl"], v[f[1]]) end
  linkLabel(v.noteLbl, v.note)
  pcall(function() v.hdr.setAccessibilityHeading(true) end)
  pcall(function() v.notePick.setContentDescription("Pick a saved extra note") end)
  onTap(v.notePick, function() pickSavedName("Extra Note", tournamentId, function(name) v.note.setText(name) end) end)
  for _, f in ipairs(officialFields) do
   pcall(function() v[f[1] .. "Pick"].setContentDescription("Pick a saved " .. f[2] .. " name") end)
   onTap(v[f[1] .. "Pick"], function() pickSavedName(f[3], tournamentId, function(name) v[f[1]].setText(name) end) end)
  end
  if not last then
   onTap(pbtn, function()
    local e = readForm(v)
    if not e then return end
    collected[i] = e
    showForm(i + 1)
   end)
  else
   local function act(action)
    local e = readForm(v)
    if not e then return end
    collected[i] = e
    finish(action)
   end
   local function shareAndExit(pkg)
    act(function(text)
     closeAll()
     pcall(function() d.dismiss() end)
     shareText(text, pkg)
    end)
   end
   pcall(function() v.msgBtn.setContentDescription("Share on WhatsApp Messenger") end)
   pcall(function() v.bizBtn.setContentDescription("Share on WhatsApp Business") end)
   onTap(v.copyBtn, function() act(function(text) copyText(text, " Names saved to Points Table.") end) end)
   onTap(v.msgBtn, function() shareAndExit("com.whatsapp") end)
   onTap(v.bizBtn, function() shareAndExit("com.whatsapp.w4b") end)
  end
  d.show()
 end
 showForm(1)
end
local function showReminderSelectDialog(tournamentId)
 local matches = {}
 query("SELECT id, team1, team2, match_date, venue, match_time, match_no, group_name, label FROM tournament_matches WHERE tournament_id = " .. tostring(tournamentId) .. " ORDER BY match_no ASC", function(c)
  matches[#matches + 1] = {id = c.getInt(0), team1 = c.getString(1), team2 = c.getString(2), match_date = c.getString(3), venue = c.getString(4), match_time = c.getString(5) or "", match_no = c.getInt(6), group_name = c.getString(7) or "", label = c.getString(8) or ""}
 end)
 if #matches == 0 then toast("No matches in this tournament yet.") return end
 local today = os.date("%Y-%m-%d")
 local d, v = makeDialog("Select Match(es) for Reminder", {
  LinearLayout; orientation = "vertical"; padding = "12dp"; layout_width = "-1"; layout_height = "-1";
  { LinearLayout; orientation = "horizontal"; layout_marginBottom = "8dp"; layout_width = "-1";
   btn("incomingTab", "Incoming", "0xFF3F51B5", 10, {layout_weight = 1, layout_marginRight = "4dp"});
   btn("completedTab", "Completed", "0xFF795548", 10, {layout_weight = 1});
  };
  { ListView; id = "matchList"; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp"; };
  btn("nextBtn", "Next", "0xFF00C853", 20);
 })
 v.matchList.setChoiceMode(2) -- multiple choice
 local selected, shown, tab = {}, {}, "incoming"
 local function renderChecks()
  for i, e in ipairs(shown) do
   local checked
   if e.match then
    checked = selected[e.match.id] ~= nil
   else
    checked = true
    for _, m in ipairs(e.group) do if not selected[m.id] then checked = false end end
   end
   v.matchList.setItemChecked(i - 1, checked)
  end
 end
 local function renderTab()
  local inc, comp, items = 0, 0, {}
  local byDate, order = {}, {}
  shown = {}
  for _, m in ipairs(matches) do
   local done = m.match_date < today
   if done then comp = comp + 1 else inc = inc + 1 end
   if (tab == "completed") == done then
    if not byDate[m.match_date] then byDate[m.match_date] = {}; order[#order + 1] = m.match_date end
    table.insert(byDate[m.match_date], m)
   end
  end
  for _, date in ipairs(order) do
   local list = byDate[date]
   if #list > 1 then -- double header: one row selects every match of that day
    shown[#shown + 1] = {group = list}
    items[#items + 1] = "Select all " .. #list .. " matches of " .. formatDateDisplay(date)
   end
   for _, m in ipairs(list) do
    shown[#shown + 1] = {match = m}
    items[#items + 1] = m.team1 .. " vs " .. m.team2 .. (m.match_time ~= "" and ("  " .. m.match_time) or "") .. "  (" .. formatDateDisplay(m.match_date) .. ")"
   end
  end
  v.incomingTab.setText("Incoming (" .. inc .. ")")
  v.completedTab.setText("Completed (" .. comp .. ")")
  v.matchList.setAdapter(ArrayAdapter(appContext, android.R.layout.simple_list_item_multiple_choice, items))
  renderChecks()
 end
 renderTab()
 v.matchList.setOnItemClickListener(AdapterView.OnItemClickListener({ onItemClick = function(_, _, pos, _)
  local e = shown[pos + 1]
  if not e then return end
  local on = v.matchList.isItemChecked(pos)
  if e.match then
   selected[e.match.id] = on and e.match or nil
  else
   for _, m in ipairs(e.group) do selected[m.id] = on and m or nil end
  end
  renderChecks()
 end}))
 onTap(v.incomingTab, function() tab = "incoming"; renderTab() end)
 onTap(v.completedTab, function() tab = "completed"; renderTab() end)
 onTap(v.nextBtn, function()
  local chosen = {}
  for _, m in ipairs(matches) do if selected[m.id] then chosen[#chosen + 1] = m end end
  if #chosen == 0 then toast("Select at least one match.") return end
  showMatchOfficialsDialog(chosen, tournamentId)
 end)
end
local function fmtNum(n)
 n = tonumber(n) or 0
 return (n == math.floor(n)) and string.format("%d", n) or tostring(n)
end
local function pointsText(r) return "Points " .. fmtNum(r.points) .. ", Bonus " .. fmtNum(r.bonus) .. ", Total " .. fmtNum(r.total) end
local function showPointsTableDialog(tournamentId, tournamentName)
 local pd, v = makeDialog(tournamentName .. " - Points Table", {
  LinearLayout; orientation = "vertical"; padding = "12dp"; layout_width = "-1"; layout_height = "-1";
  btn("addBtn", "+ Add Name", "0xFF3F51B5", 20, {layout_marginBottom = "8dp"});
  { ListView; id = "ptList"; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp"; };
  btn("moreBtn", "More Options", "0xFF795548", 20, {layout_marginBottom = "8dp"});
  btn("closeBtn", "Close", "0xFFD32F2F", 20);
 })
 tournamentName = cleanName(tournamentName)
 local rows = {}
 local function roleTag(r) return (r.role ~= "") and (" (" .. r.role .. ")") or "" end
 local function loadRows()
  local texts = {}
  rows = {}
  query("SELECT id, name, points, role, IFNULL(bonus_points, 0) FROM points_table WHERE tournament_id = " .. tostring(tournamentId) .. " ORDER BY (points + IFNULL(bonus_points, 0)) DESC", function(c)
   local r = {id = c.getInt(0), name = c.getString(1) or "", points = c.getDouble(2), role = c.getString(3) or "", bonus = c.getDouble(4)}
   r.total = r.points + r.bonus
   rows[#rows + 1] = r
   texts[#texts + 1] = r.name .. roleTag(r) .. "  -  " .. pointsText(r)
  end)
  v.ptList.setAdapter(ArrayAdapter(appContext, android.R.layout.simple_list_item_1, texts))
 end
 loadRows()
 onTap(v.addBtn, function()
  promptInput("Name", nil, "e.g. Umar Jan", function(name)
   promptInput("Points", "0", "e.g. 2.5", function(ptStr)
    exec("INSERT INTO points_table (tournament_id, name, points, role) VALUES (?, ?, ?, 'Manual');", tournamentId, name, tonumber(ptStr) or 0)
    loadRows()
   end)
  end)
 end)
 v.ptList.setOnItemClickListener(AdapterView.OnItemClickListener({ onItemClick = function(_, _, pos, _)
  local row = rows[pos + 1]
  if not row then return end
  local d = LuaDialog()
  d.setTitle(row.name .. roleTag(row))
  local v2 = {}
  local box2, pbtn2 = navWrap(d, loadlayout({ LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1";
   { TextView; id = "setLbl"; text = "Points"; textSize = "13sp"; layout_width = "-1"; };
   { EditText; id = "setInput"; hint = "2"; inputType = "numberDecimal"; layout_marginBottom = "8dp"; layout_width = "-1"; };
   { TextView; id = "bonusLbl"; text = "Bonus Points (optional)"; textSize = "13sp"; layout_width = "-1"; };
   { EditText; id = "bonusInput"; hint = "0"; inputType = "numberDecimal"; layout_width = "-1"; };
  }, v2), false, "Save", "0xFF00C853")
  d.setView(box2)
  hardenEdit(v2.setInput); hardenEdit(v2.bonusInput)
  linkLabel(v2.setLbl, v2.setInput); linkLabel(v2.bonusLbl, v2.bonusInput)
  track(d)
  v2.setInput.setText(fmtNum(row.points)); v2.bonusInput.setText(fmtNum(row.bonus))
  onTap(pbtn2, function()
   local pts = tonumber(trim(v2.setInput.getText())) or row.points
   local bonus = tonumber(trim(v2.bonusInput.getText())) or row.bonus
   exec("UPDATE points_table SET points = ?, bonus_points = ? WHERE id = ?;", pts, bonus, row.id)
   toast("Updated! Total: " .. fmtNum(pts + bonus))
   d.dismiss()
   loadRows()
  end)
  d.show()
 end}))
 v.ptList.setOnItemLongClickListener(AdapterView.OnItemLongClickListener({ onItemLongClick = function(_, _, pos, _)
  local row = rows[pos + 1]
  if row then
   confirmDialog("Delete Entry", "Remove " .. row.name .. " from the points table?", "Yes, Delete", function()
    exec("DELETE FROM points_table WHERE id = ?;", row.id)
    loadRows()
   end)
  end
  return true
 end}))
 local roleOrder = {{"Umpire", "UMPIRES"}, {"Commentator", "COMMENTATORS"}, {"Organizer", "ORGANIZERS"}, {"Match Referee", "MATCH REFEREES"}}
 local function ranked(title, filterRole)
  local lines, total = {title, "------------------------"}, 0
  local function section(heading, pick)
   local rank = 0
   for _, r in ipairs(rows) do
    if pick(r) then
     if heading and rank == 0 then lines[#lines + 1] = ""; lines[#lines + 1] = heading end
     rank = rank + 1; total = total + 1
     lines[#lines + 1] = rank .. ". " .. r.name .. "  -  " .. pointsText(r)
    end
   end
  end
  if filterRole then
   section(nil, function(r) return r.role == filterRole end)
  else
   local known = {}
   for _, ro in ipairs(roleOrder) do
    known[ro[1]] = true
    section(ro[2], function(r) return r.role == ro[1] end)
   end
   section("OTHERS", function(r) return not known[r.role] end)
  end
  return total > 0 and table.concat(lines, "\n") or nil
 end
 local function copyRole(suffix, role)
  local text = ranked(tournamentName .. " - " .. suffix, role)
  if text then copyText(text) else toast("No entries for this category.") end
 end
 onTap(v.moreBtn, function()
  local opts = {
   {"Copy All (Ranked)", function() copyRole("Points Table (Ranked)", nil) end},
   {"Copy Umpires Only", function() copyRole("Umpires", "Umpire") end},
   {"Copy Commentators Only", function() copyRole("Commentators", "Commentator") end},
   {"Copy Organizers Only", function() copyRole("Organizers", "Organizer") end},
   {"Copy Match Referees Only", function() copyRole("Match Referees", "Match Referee") end},
   {"Export to File", function()
    local text = ranked(tournamentName .. " - Points Table", nil)
    if not text then toast("No entries to export.") return end
    exportFile(safeName(tournamentName) .. "_PointsTable_" .. os.date("%Y%m%d_%H%M%S") .. ".txt", text, "Points Table saved")
   end},
  }
  local labels = {}
  for i, o in ipairs(opts) do labels[i] = o[1] end
  showListDialog("More Options", labels, function(pos) opts[pos + 1][2]() end, nil, true)
 end)
 onTap(v.closeBtn, function() pd.dismiss() end)
end
-- ===== Next round =====
local function isPlaceholder(name)
 name = tostring(name or "")
 return name:match("^Winner of ") ~= nil or name:match("^Loser of ") ~= nil
end
local function copyList(t)
 local o = {}
 for i, x in ipairs(t) do o[i] = x end
 return o
end
local function labelSuffix(tid, labels)
 local used = {}
 query("SELECT DISTINCT label FROM tournament_matches WHERE tournament_id = " .. tostring(tid), function(c) used[c.getString(0) or ""] = true end)
 local n = 1
 while true do
  local suf = (n == 1) and "" or (" #" .. n)
  local clash = false
  for _, l in ipairs(labels) do if used[l .. suf] then clash = true end end
  if not clash then return suf end
  n = n + 1
 end
end
local function labelsOf(defs)
 local l = {}
 for _, d in ipairs(defs) do l[#l + 1] = d.label end
 return l
end
local function buildEntries(defs, suffix)
 local out = {}
 for _, d in ipairs(defs) do
  local function ph(p) return p and (p.kind .. " of " .. p.label .. suffix) or "" end
  local e = {label = d.label .. suffix, group = d.group, leg = 1, deps = {}, ph1 = ph(d.p1), ph2 = ph(d.p2)}
  e.team1 = d.t1 or e.ph1
  e.team2 = d.t2 or e.ph2
  if d.p1 then e.deps[#e.deps + 1] = d.p1.label .. suffix end
  if d.p2 then e.deps[#e.deps + 1] = d.p2.label .. suffix end
  out[#out + 1] = e
 end
 return out
end
local function pairDefs(T, stage)
 local defs, n = {}, math.floor(#T / 2)
 for i = 1, n do
  defs[#defs + 1] = {label = (n == 1) and stage or (stage .. " " .. i), group = stage, t1 = T[2 * i - 1], t2 = T[2 * i]}
 end
 return defs
end
local function playoffDefs(T)
 return {
  {label = "Qualifier", group = "Playoffs", t1 = T[1], t2 = T[2]},
  {label = "Eliminator 1", group = "Playoffs", t1 = T[3], t2 = T[4]},
  {label = "Eliminator 2", group = "Playoffs", p1 = {kind = "Loser", label = "Qualifier"}, p2 = {kind = "Winner", label = "Eliminator 1"}},
 }
end
local function superSixPlayoffDefs(T)
 local G = "Playoff Super Six"
 return {
  {label = "Playoff 1", group = G, t1 = T[1], t2 = T[2]},
  {label = "Playoff 2", group = G, t1 = T[3], t2 = T[4]},
  {label = "Eliminator 1", group = G, p1 = {kind = "Loser", label = "Playoff 1"}, t2 = T[5]},
  {label = "Eliminator 2", group = G, p1 = {kind = "Loser", label = "Playoff 2"}, t2 = T[6]},
 }
end
local function scheduleBracket(entries, pattern, startDate, liveCap)
 local dayOf, done, left, dayIndex, safety, out = {}, {}, #entries, 0, 0, {}
 while left > 0 and safety < 3000 do
  safety = safety + 1
  local date = addDaysToDate(startDate, dayIndex)
  local wd = weekdayIndex(date)
  local cap, picked = pattern[wd].count, 0
  if cap > 0 then
   for i, e in ipairs(entries) do
    if picked >= cap then break end
    if not done[i] then
     local ready = true
     for _, dep in ipairs(e.deps) do
      if not (dayOf[dep] and dayOf[dep] < dayIndex) then ready = false end
     end
     if ready then
      picked = picked + 1; done[i] = true; left = left - 1
      dayOf[e.label] = dayIndex
      e.match_date = date
      e.match_time = pattern[wd].times[picked] or ""
      e.is_live = (picked <= liveCap) and 1 or 0
      out[#out + 1] = e
     end
    end
   end
  end
  dayIndex = dayIndex + 1
 end
 return out
end
local function chooseStartDate(tid, onPicked)
 local lastDate
 query("SELECT MAX(match_date) FROM tournament_matches WHERE tournament_id = " .. tostring(tid), function(c) lastDate = c.getString(0) end)
 if lastDate and lastDate:match("^%d+-%d+-%d+$") then
  local nextDay = addDaysToDate(lastDate, 1)
  showListDialog("Start Date", {"Day after the last match: " .. formatDateDisplay(nextDay), "Pick a date"}, function(pos)
   if pos == 0 then onPicked(nextDay) else pickDate(nil, onPicked, true) end
  end, nil, true)
 else
  pickDate(nil, onPicked, true)
 end
end
local function appendEntries(tid, venueCountry, entries, refreshFn)
 if #entries == 0 then toast("No matches were created.") return end
 local matchNo = 0
 query("SELECT MAX(match_no) FROM tournament_matches WHERE tournament_id = " .. tostring(tid), function(c) matchNo = c.getInt(0) or 0 end)
 local venues = getVenueList(venueCountry)
 inTransaction(function()
  for _, e in ipairs(entries) do
   matchNo = matchNo + 1
   local venue = (#venues > 0) and venues[((matchNo - 1) % #venues) + 1] or ""
   exec("INSERT INTO tournament_matches (tournament_id, group_name, match_no, team1, team2, match_date, match_time, venue, leg, is_live, label, ph1, ph2) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);",
    tid, e.group or "", matchNo, e.team1, e.team2, e.match_date, e.match_time or "", venue, e.leg or 1, e.is_live or 0, e.label or "", e.ph1 or "", e.ph2 or "")
  end
 end)
 endFlow()
 toast(#entries .. " match(es) added to the schedule.", true)
 if refreshFn then pcall(refreshFn) end
end
local function showTeamCheckboxDialog(teams, exactCount, onDone, allowAdd, title)
 local lay = { LinearLayout; orientation = "vertical"; padding = "12dp"; layout_width = "-1"; layout_height = "-1";
  { ScrollView; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp";
   { LinearLayout; id = "teamContainer"; orientation = "vertical"; };
  };
 }
 if allowAdd then lay[#lay + 1] = btn("addBtn", "+ Add Team(s)", "0xFF3F51B5", 20, {layout_marginBottom = "8dp"}) end
 lay[#lay + 1] = btn("nextBtn", "Next", "0xFF00C853", 20)
 local d, v = makeDialog(title or ("Select Teams" .. (exactCount and (" (exactly " .. exactCount .. ")") or "")), lay)
 local order, known = {}, {}
 local function addBox(t)
  known[t:lower()] = true
  local cb = CheckBox(appContext)
  cb.setText(t)
  cb.setOnCheckedChangeListener({ onCheckedChanged = safe(function(_, checked)
   if checked then
    if exactCount and #order >= exactCount then
     toast("You can select at most " .. exactCount .. " team(s).")
     cb.setChecked(false)
     return
    end
    order[#order + 1] = t
   else
    for idx, tn in ipairs(order) do if tn == t then table.remove(order, idx) break end end
   end
  end)})
  v.teamContainer.addView(cb)
  return cb
 end
 for _, t in ipairs(teams) do addBox(t) end
 if allowAdd then
  onTap(v.addBtn, function()
   showMultilineInputStep("Add Teams", "Enter team names (one per line)", 1, function(names)
    for _, nm in ipairs(names) do
     if known[nm:lower()] then toast(nm .. " is already in the list.") else addBox(nm).setChecked(true) end
    end
   end)
  end)
 end
 onTap(v.nextBtn, function()
  if #order < 2 then toast("Please select at least 2 teams.") return end
  if exactCount and #order ~= exactCount then toast("Please select exactly " .. exactCount .. " team(s).") return end
  onDone(copyList(order))
 end)
end
local function askRoundType(onChosen)
 showListDialog("Round Type", {"Single Round (each team plays once)", "Double Round (each team plays twice)"}, function(pos) onChosen(pos == 1) end, nil, true)
end
local function finishNextRound(tid, venueCountry, refreshFn, build)
 showWeeklyScheduleDialog(function(pattern, liveCap)
  chooseStartDate(tid, function(dateStr)
   local ok, entries = pcall(build, pattern, liveCap, dateStr)
   if ok then appendEntries(tid, venueCountry, entries, refreshFn) else toast("Could not create this round.", true) end
  end)
 end, {next = true})
end
local function showNextRoundDialog(tid, venueCountry, refreshFn)
 startFlow()
 local baseList, basePrompt = showListDialog, promptInput
 local function showListDialog(title, items, onSelect, onLong) return baseList(title, items, onSelect, onLong, true) end
 local function promptInput(title, initial, hint, onSave) return basePrompt(title, initial, hint, onSave, true) end
 local teams, seen = {}, {}
 query("SELECT team1, team2 FROM tournament_matches WHERE tournament_id = " .. tostring(tid) .. " ORDER BY match_no ASC", function(c)
  for i = 0, 1 do
   local t = c.getString(i)
   if t and not seen[t] and not isPlaceholder(t) then seen[t] = true; teams[#teams + 1] = t end
  end
 end)
 local function withSuffix(defs) return buildEntries(defs, labelSuffix(tid, labelsOf(defs))) end
 local function finishBracket(entries)
  finishNextRound(tid, venueCountry, refreshFn, function(pattern, liveCap, dateStr) return scheduleBracket(entries, pattern, dateStr, liveCap) end)
 end
 local function finishQueue(queue)
  finishNextRound(tid, venueCountry, refreshFn, function(pattern, liveCap, dateStr) return (scheduleBalanced(queue, pattern, dateStr, liveCap)) end)
 end
 local function rrQueue(sel, isDouble, group)
  local queue = {}
  for _, round in ipairs(generateRounds(sel, isDouble)) do
   for _, m in ipairs(round) do queue[#queue + 1] = {team1 = m.team1, team2 = m.team2, leg = m.leg, group = group} end
  end
  return queue
 end
 local function playoff(defsFn, n)
  showTeamCheckboxDialog(copyList(teams), n, function(sel) finishBracket(withSuffix(defsFn(sel))) end, true,
   "Select " .. n .. " teams in order of rank (1st = top seed)")
 end
 local function superStage(name, count)
  showTeamCheckboxDialog(copyList(teams), count, function(sel)
   askRoundType(function(isDouble) finishQueue(rrQueue(sel, isDouble, name)) end)
  end, true)
 end
 local function qualifier()
  local counts = {}
  for n = 2, 10 do counts[#counts + 1] = n .. " teams" end
  showListDialog("Qualifier - How many teams?", counts, function(pos)
   local n = pos + 2
   showTeamCheckboxDialog(copyList(teams), n, function(sel)
    if n == 2 then finishBracket(withSuffix(pairDefs(sel, "Qualifier"))) return end
    showListDialog("Qualifier Format", {"Knockout (1st vs 2nd, 3rd vs 4th ...)", "Round Robin - Single"}, function(fpos)
     if fpos == 0 then
      if n % 2 == 1 then toast("Odd number of teams: the last team gets a bye (no match).", true) end
      finishBracket(withSuffix(pairDefs(sel, "Qualifier")))
     else
      finishQueue(rrQueue(sel, false, "Qualifier"))
     end
    end)
   end, true, "Select " .. n .. " teams for the Qualifier")
  end)
 end
 local function singleStage()
  local stages = {{"Quarter Final", 8}, {"Semi Final", 4}, {"Qualifier", 0}, {"Final", 2}}
  local labels = {}
  for i, st in ipairs(stages) do
   labels[i] = (st[2] > 0) and (st[1] .. " (" .. st[2] .. " teams)") or (st[1] .. " (choose the number of teams)")
  end
  showListDialog("Single Stage", labels, function(pos)
   local st = stages[pos + 1]
   if st[2] == 0 then qualifier() return end
   showTeamCheckboxDialog(copyList(teams), st[2], function(sel) finishBracket(withSuffix(pairDefs(sel, st[1]))) end, true)
  end)
 end
 local function customRound()
  promptInput("Round Name", nil, "Super League", function(name)
   showListDialog("Round Format", {"Round Robin", "Group Wise"}, function(fpos)
    if fpos == 0 then
     showTeamCheckboxDialog(copyList(teams), nil, function(sel)
      askRoundType(function(isDouble) finishQueue(rrQueue(sel, isDouble, name)) end)
     end, true, "Select the teams for " .. name)
    else
     showListDialog("Number of Groups", groupCountLabels, function(gpos)
      local g = gpos + 2
      local available, groups = copyList(teams), {}
      local function pickGroup(i)
       if i > g then
        askRoundType(function(isDouble)
         local queue = {}
         for gi, list in ipairs(groups) do
          for _, m in ipairs(rrQueue(list, isDouble, name .. " - Group " .. string.char(64 + gi))) do queue[#queue + 1] = m end
         end
         finishQueue(queue)
        end)
        return
       end
       showTeamCheckboxDialog(copyList(available), nil, function(sel)
        groups[i] = sel
        local picked, rest = {}, {}
        for _, t in ipairs(sel) do picked[t:lower()] = true end
        for _, t in ipairs(available) do if not picked[t:lower()] then rest[#rest + 1] = t end end
        available = rest
        pickGroup(i + 1)
       end, true, "Group " .. string.char(64 + i) .. " - select its teams")
      end
      pickGroup(1)
     end)
    end
   end)
  end)
 end
 local menu = {
  {"Playoffs (Qualifier, Eliminator 1, Eliminator 2)", function() playoff(playoffDefs, 4) end},
  {"Playoff Super Six (Playoff 1 & 2, Eliminator 1 & 2)", function() playoff(superSixPlayoffDefs, 6) end},
  {"Super Four (round robin)", function() superStage("Super Four", 4) end},
  {"Super Six (round robin)", function() superStage("Super Six", 6) end},
  {"Super Eight (round robin)", function() superStage("Super Eight", 8) end},
  {"Super Ten (round robin)", function() superStage("Super Ten", 10) end},
  {"Single Stage (Quarter Final, Semi Final, Final ...)", singleStage},
  {"Custom Round (any teams: knockout, round robin or groups)", customRound},
 }
 local labels = {}
 for i, m in ipairs(menu) do labels[i] = m[1] end
 showListDialog("Next Round", labels, function(pos) menu[pos + 1][2]() end)
end
local function pickTime(onPicked)
 showListDialog("Select Hour", hourCycle, function(hp)
  showListDialog("Select Minute", minuteCycle, function(mp)
   showListDialog("AM or PM", {"AM", "PM"}, function(ap)
    onPicked(hourCycle[hp + 1] .. ":" .. minuteCycle[mp + 1] .. " " .. (ap == 0 and "AM" or "PM"))
   end)
  end)
 end)
end
-- ===== Fixtures =====
local function showFixtureListDialog(tid, tournamentName, venueCountry)
 local fd, fv = makeDialog(tournamentName .. " - Fixtures", {
  LinearLayout; orientation = "vertical"; padding = "12dp"; layout_width = "-1"; layout_height = "-1";
  { ListView; id = "fixtureList"; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp"; };
  btn("moreBtn", "More Options", "0xFF795548", 20, {layout_marginBottom = "8dp"});
  btn("closeBtn", "Close", "0xFFD32F2F", 20);
 })
 tournamentName = cleanName(tournamentName)
 local matches, texts, plains = {}, {}, {}
 local liveCap, roomBuf, tz = 0, 0, ""
 query("SELECT live_per_day, room_link_buffer, time_zone FROM tournaments WHERE id = " .. tostring(tid), function(c) liveCap = c.getInt(0); roomBuf = c.getInt(1); tz = c.getString(2) or "" end)
 local function loadMatches()
  matches, texts, plains = {}, {}, {}
  query("SELECT id, group_name, match_no, team1, team2, match_date, match_time, venue, leg, is_live, label, winner, ph1, ph2 FROM tournament_matches WHERE tournament_id = " .. tostring(tid) .. " ORDER BY match_no ASC", function(c)
   local r = {
    id = c.getInt(0), group_name = c.getString(1) or "", match_no = c.getInt(2), team1 = c.getString(3) or "", team2 = c.getString(4) or "",
    match_date = c.getString(5) or "", match_time = c.getString(6) or "", venue = c.getString(7) or "", leg = c.getInt(8), is_live = c.getInt(9),
    label = c.getString(10) or "", winner = c.getString(11) or "", ph1 = c.getString(12) or "", ph2 = c.getString(13) or "",
   }
   matches[#matches + 1] = r
   local status = (r.is_live == 1) and "Status: LIVE - " or ((liveCap > 0) and "Status: NOT LIVE - " or "")
   local timeTag = ""
   if r.match_time ~= "" then
    local z = (tz ~= "") and (" " .. tz) or ""
    timeTag = (roomBuf > 0) and ("  -  Match Room Link " .. shiftTime(r.match_time, roomBuf) .. z .. " - Match Start " .. r.match_time .. z) or (" " .. r.match_time .. z)
   end
   local tag = matchTag(r.group_name, r.label)
   local plain = status .. "Match " .. r.match_no .. ": " .. (tag ~= "" and ("[" .. tag .. "] ") or "") .. r.team1 .. " vs " .. r.team2 ..
    (r.leg == 2 and " (Leg 2)" or "") .. "  -  " .. formatDateDisplay(r.match_date) .. timeTag .. venueTag(r.venue) .. advanceTag(r.group_name, r.label)
   plains[#plains + 1] = plain
   texts[#texts + 1] = (r.match_date == os.date("%Y-%m-%d") and "TODAY - " or "") .. plain
  end)
  fv.fixtureList.setAdapter(ArrayAdapter(appContext, android.R.layout.simple_list_item_1, texts))
 end
 loadMatches()
 local function copyMatches(title, filterFn)
  local lines = {title, "------------------------"}
  for i, t in ipairs(plains) do if not filterFn or filterFn(matches[i]) then lines[#lines + 1] = t end end
  copyText(table.concat(lines, "\n"))
 end
 local function fullText() return "Tournament Fixtures - " .. tournamentName .. "\n------------------------\n" .. table.concat(plains, "\n") end
 local function uniq(getter)
  local list, seen = {}, {}
  for _, m in ipairs(matches) do
   for _, g in ipairs(getter(m)) do
    if g ~= "" and not seen[g] then seen[g] = true; list[#list + 1] = g end
   end
  end
  return list
 end
 local function overview()
  local teams = uniq(function(m) return {isPlaceholder(m.team1) and "" or m.team1, isPlaceholder(m.team2) and "" or m.team2} end)
  local groups = uniq(function(m) return {m.group_name} end)
  local cnt, today, done = {}, os.date("%Y-%m-%d"), 0
  for _, m in ipairs(matches) do
   if not isPlaceholder(m.team1) then cnt[m.team1] = (cnt[m.team1] or 0) + 1 end
   if not isPlaceholder(m.team2) then cnt[m.team2] = (cnt[m.team2] or 0) + 1 end
   if m.match_date < today then done = done + 1 end
  end
  local lo, hi
  for _, c in pairs(cnt) do
   if not lo or c < lo then lo = c end
   if not hi or c > hi then hi = c end
  end
  local seq = {}
  for _, m in ipairs(matches) do
   for _, t in ipairs({m.team1, m.team2}) do
    if not isPlaceholder(t) then
     seq[t] = seq[t] or {}
     seq[t][#seq[t] + 1] = m
    end
   end
  end
  local lLo, lHi, gLo, gHi, b2b = nil, nil, nil, nil, 0
  for _, list in pairs(seq) do
   table.sort(list, function(x, y)
    if x.match_date ~= y.match_date then return x.match_date < y.match_date end
    return x.match_no < y.match_no
   end)
   local live, prevLive, prevTs = 0, false, nil
   for _, m in ipairs(list) do
    local l = m.is_live == 1
    if l then live = live + 1; if prevLive then b2b = b2b + 1 end end
    prevLive = l
    if m.match_date:match("^%d+-%d+-%d+$") then
     local ts = dateTs(m.match_date)
     if prevTs then
      local g = math.floor((ts - prevTs) / 86400 + 0.5)
      if not gLo or g < gLo then gLo = g end
      if not gHi or g > gHi then gHi = g end
     end
     prevTs = ts
    end
   end
   if not lLo or live < lLo then lLo = live end
   if not lHi or live > lHi then lHi = live end
  end
  local report = ""
  if gLo then report = report .. "\nDays between a team's matches: " .. gLo .. " to " .. gHi end
  if liveCap > 0 and lLo then
   report = report .. "\nLive matches per team: " .. lLo .. " to " .. lHi .. "\nBack-to-back live matches: " .. b2b
  end
  local d = LuaDialog()
  d.setTitle(tournamentName .. " - Overview")
  local groupLines = ""
  for _, g in ipairs(groups) do
   local gt, seenG = {}, {}
   for _, m in ipairs(matches) do
    if m.group_name == g then
     for _, t in ipairs({m.team1, m.team2}) do
      if not isPlaceholder(t) and not seenG[t] then seenG[t] = true; gt[#gt + 1] = t end
     end
    end
   end
   groupLines = groupLines .. "\n" .. groupTitle(g) .. " (" .. #gt .. "): " .. table.concat(gt, ", ")
  end
  d.setMessage("Teams: " .. #teams .. " (" .. table.concat(teams, ", ") .. ")\nTotal Matches: " .. #matches .. "\nGroups/Rounds: " .. #groups .. groupLines ..
   "\nCompleted: " .. done .. "\nUpcoming: " .. (#matches - done) .. report ..
   ((lo and hi - lo > 1) and ("\nNote: match counts are uneven across teams (" .. lo .. " to " .. hi .. ").") or ""))
  d.setButton("OK", nil)
  d.show()
 end
 onTap(fv.moreBtn, function()
  local function copyPicker(title, list, fn)
   if #list == 0 then toast("Nothing to pick.") return end
   showListDialog(title, list, function(pos) fn(list[pos + 1]) end, nil, true)
  end
  local opts = {
   {"Set Reminder & Officials", function() showReminderSelectDialog(tid) end},
   {"Points Table", function() showPointsTableDialog(tid, tournamentName) end},
   {"Next Round", function() showNextRoundDialog(tid, venueCountry, loadMatches) end},
   {"Copy Full Tournament", function() copyMatches("Tournament Fixtures - " .. tournamentName, nil) end},
   {"Copy By Group/Round", function()
    copyPicker("Copy By Group/Round", uniq(function(m) return {m.group_name} end), function(g)
     copyMatches(g .. " - " .. tournamentName, function(m) return m.group_name == g end)
    end)
   end},
   {"Copy By Team", function()
    local scopes, keys, seenG = {"All Rounds"}, {false}, {}
    for _, m in ipairs(matches) do
     if not seenG[m.group_name] then
      seenG[m.group_name] = true
      scopes[#scopes + 1] = (m.group_name ~= "") and m.group_name or "Main Schedule"
      keys[#keys + 1] = m.group_name
     end
    end
    local function teamPicker(si)
     local key = keys[si]
     local function inScope(m) return key == false or m.group_name == key end
     local list, seen = {}, {}
     for _, m in ipairs(matches) do
      if inScope(m) then
       for _, t in ipairs({m.team1, m.team2}) do
        if not seen[t] and not isPlaceholder(t) then seen[t] = true; list[#list + 1] = t end
       end
      end
     end
     copyPicker("Copy By Team - " .. scopes[si], list, function(t)
      copyMatches(t .. " - " .. tournamentName .. " - " .. (key == false and "Matches" or scopes[si]),
       function(m) return inScope(m) and (m.team1 == t or m.team2 == t) end)
     end)
    end
    if #scopes <= 2 then teamPicker(1)
    else showListDialog("Copy By Team - Which Round?", scopes, function(pos) teamPicker(pos + 1) end, nil, true) end
   end},
   {"Export Schedule to File", function()
    exportFile(safeName(tournamentName) .. "_Schedule_" .. os.date("%Y%m%d_%H%M%S") .. ".txt", fullText(), "Schedule saved")
   end},
   {"Tournament Overview", overview},
  }
  local labels = {}
  for i, o in ipairs(opts) do labels[i] = o[1] end
  showListDialog("More Options", labels, function(pos) opts[pos + 1][2]() end, nil, true)
 end)
 fv.fixtureList.setOnItemClickListener(AdapterView.OnItemClickListener({ onItemClick = function(_, _, pos, _)
  local r = matches[pos + 1]
  if not r then return end
  local function update(col, val, msg)
   exec("UPDATE tournament_matches SET " .. col .. " = ? WHERE id = ?;", val, r.id)
   loadMatches(); toast(msg)
  end
  local opts = {
   {"Change Date", function() pickDate(nil, function(dt) update("match_date", dt, "Date: " .. formatDateDisplay(dt)) end) end},
   {"Change Time", function() pickTime(function(t) update("match_time", t, "Time: " .. t) end) end},
   {r.is_live == 1 and "Mark Not Live" or "Mark Live", function()
    update("is_live", r.is_live == 1 and 0 or 1, r.is_live == 1 and "Marked not live." or "Marked live.")
   end},
   {"Set Reminder & Officials", function() showMatchOfficialsDialog({r}, tid) end},
   {"Delete Match", function()
    confirmDialog("Delete Match", "Delete " .. r.team1 .. " vs " .. r.team2 .. "?", "Yes, Delete", function()
     exec("DELETE FROM official_log WHERE match_id = ?;", r.id)
     exec("DELETE FROM tournament_matches WHERE id = ?;", r.id)
     loadMatches(); toast("Match deleted.")
    end)
   end},
  }
  local sameDay = {}
  for _, m in ipairs(matches) do
   if m.match_date == r.match_date then sameDay[#sameDay + 1] = m end
  end
  if #sameDay > 1 then -- double header
   table.insert(opts, 1, {"Reminder & Officials - all " .. #sameDay .. " matches of this day", function() showMatchOfficialsDialog(sameDay, tid) end})
  end
  if isPlaceholder(r.team1) or isPlaceholder(r.team2) then
   table.insert(opts, 1, {"Set Teams", function()
    local function collect(sameGroup)
     local list, seenT = {}, {}
     for _, m in ipairs(matches) do
      if not sameGroup or m.group_name == r.group_name then
       for _, t in ipairs({m.team1, m.team2}) do
        if not isPlaceholder(t) and not seenT[t] then seenT[t] = true; list[#list + 1] = t end
       end
      end
     end
     return list
    end
    local list = collect(true)
    if #list < 2 then list = collect(false) end
    showListDialog("Select Team 1", list, function(p1)
     local t1, rest = list[p1 + 1], {}
     for _, t in ipairs(list) do if t ~= t1 then rest[#rest + 1] = t end end
     showListDialog("Select Team 2", rest, function(p2)
      local t2 = rest[p2 + 1]
      exec("UPDATE tournament_matches SET team1 = ?, team2 = ?, ph1 = '', ph2 = '' WHERE id = ?;", t1, t2, r.id)
      loadMatches()
      toast(t1 .. " vs " .. t2)
     end)
    end)
   end})
  end
  local labels = {}
  for i, o in ipairs(opts) do labels[i] = o[1] end
  showListDialog("Match " .. r.match_no .. ": " .. r.team1 .. " vs " .. r.team2, labels, function(p2) opts[p2 + 1][2]() end)
 end}))
 onTap(fv.closeBtn, function() fd.dismiss() end)
end
-- ===== Create tournament =====
local function saveTournamentAndShow(name, venueCountry, startDate, format, roundType, pattern, liveCap, groupRoundsList, refreshFn)
 local tid = exec("INSERT INTO tournaments (name, venue_country, start_date, format, round_type, matches_per_day, live_per_day, room_link_buffer, time_zone, created_at) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?);",
  name, venueCountry, startDate, format, roundType, liveCap, pattern.roomBuf or 0, pattern.tz or "PKT", os.date("%Y-%m-%d %H:%M"))
 if not tid then toast("Could not create tournament.", true) return end
 local queue = {}
 for _, grp in ipairs(groupRoundsList) do
  for _, round in ipairs(grp.rounds) do
   for _, m in ipairs(round) do queue[#queue + 1] = {team1 = m.team1, team2 = m.team2, leg = m.leg, group = grp.group} end
  end
 end
 local venues = getVenueList(venueCountry)
 local matchNo = 0
 local scheduled, b2b, spread = scheduleBalanced(queue, pattern, startDate, liveCap)
 inTransaction(function()
 for _, m in ipairs(scheduled) do
  matchNo = matchNo + 1
  local isLive = m.is_live or 0
  local venue = (#venues > 0) and venues[((matchNo - 1) % #venues) + 1] or ""
  exec("INSERT INTO tournament_matches (tournament_id, group_name, match_no, team1, team2, match_date, match_time, venue, leg, is_live) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
   tid, m.group or "", matchNo, m.team1, m.team2, m.match_date, m.match_time or "", venue, m.leg or 1, isLive)
 end
 end)
 local okB, backupPath = pcall(autoSaveTournament, tid, name)
 toast("Tournament schedule created! " .. matchNo .. " matches." .. ((#scheduled < #queue) and (" " .. (#queue - #scheduled) .. " could not be scheduled.") or "") ..
  ((liveCap > 0 and b2b > 0) and ("\nNote: " .. b2b .. " back-to-back live match(es) could not be avoided with this pattern.") or "") ..
  ((liveCap > 0 and spread > 1) and ("\nNote: live matches per team differ by " .. spread .. ".") or "") ..
  ((okB and backupPath) and ("\nBackup saved automatically:\n" .. backupPath) or ""), true)
 endFlow()
 if refreshFn then pcall(refreshFn) end
 showFixtureListDialog(tid, name, venueCountry)
end
local function startRoundRobinFlow(name, venue, date, pattern, liveCap, refreshFn)
 askRoundType(function(isDouble)
  showMultilineInputStep("Round Robin - Teams", "Enter team names (one per line)", 2, function(teams)
   saveTournamentAndShow(name, venue, date, "round_robin", isDouble and "double" or "single", pattern, liveCap, {{group = nil, rounds = generateRounds(teams, isDouble)}}, refreshFn)
  end, true, "Create")
 end)
end
local function startGroupWiseFlow(name, venue, date, pattern, liveCap, refreshFn)
 showListDialog("Number of Groups", groupCountLabels, function(gpos)
  local numGroups = gpos + 2
  askRoundType(function(isDouble)
   local groups = {}
   local function collectGroup(idx)
    local label = "Group " .. string.char(64 + idx)
    showMultilineInputStep(label .. " - Teams", "Enter team names (one per line)", 2, function(teams)
     for gi, g in ipairs(groups) do
      if gi ~= idx then
       for _, t1 in ipairs(g.teams) do
        for _, t2 in ipairs(teams) do
         if t1:lower() == t2:lower() then
          toast(t2 .. " is already in " .. g.label .. ".", true)
          return
         end
        end
       end
      end
     end
     groups[idx] = {label = label, teams = teams}
     if idx < numGroups then
      collectGroup(idx + 1)
     else
      local list = {}
      for _, g in ipairs(groups) do list[#list + 1] = {group = g.label, rounds = generateRounds(g.teams, isDouble)} end
      saveTournamentAndShow(name, venue, date, "group_wise", isDouble and "double" or "single", pattern, liveCap, list, refreshFn)
     end
    end, true, (idx == numGroups) and "Create" or "Next")
   end
   collectGroup(1)
  end)
 end, nil, true)
end
local function showNewTournamentWizard(refreshFn)
 startFlow()
 local d = LuaDialog()
 d.setTitle("New Tournament")
 local v = {}
 local box, pbtn = navWrap(d, loadlayout({
  LinearLayout; orientation = "vertical"; padding = "16dp"; layout_width = "-1";
  { TextView; id = "nameLbl"; text = "Tournament Name"; textSize = "14sp"; layout_marginBottom = "4dp"; layout_width = "-1"; };
  { EditText; id = "nameInput"; hint = "Champions Trophy"; layout_marginBottom = "10dp"; layout_width = "-1"; };
  btn("venueBtn", "Venue: None", "0xFF3F51B5", 10, {layout_marginBottom = "10dp"});
  btn("dateBtn", "Date: --", "0xFF00796B", 10);
 }, v), false, "Next", "0xFF00C853")
 d.setView(box)
 hardenEdit(v.nameInput)
 linkLabel(v.nameLbl, v.nameInput)
 track(d)
 local venue, date = "None", os.date("%Y-%m-%d")
 v.dateBtn.setText("Date: " .. formatDateDisplay(date))
 onTap(v.venueBtn, function()
  showListDialog("Select Venue", venueCountryOrder, function(pos)
   venue = venueCountryOrder[pos + 1]; v.venueBtn.setText("Venue: " .. venue); say("Venue: " .. venue, v.venueBtn)
  end)
 end)
 onTap(v.dateBtn, function()
  pickDate(nil, function(nd) date = nd; v.dateBtn.setText("Date: " .. formatDateDisplay(date)); say("Date: " .. formatDateDisplay(date), v.dateBtn) end)
 end)
 onTap(pbtn, function()
  local name = trim(v.nameInput.getText())
  if name == "" then toast("Please enter a tournament name.") return end
  if nameExists(name) then toast("A tournament with this name already exists.") return end
  showWeeklyScheduleDialog(function(pattern, liveCap)
   showListDialog("Tournament Format", {"Round Robin", "Group Wise"}, function(pos)
    if pos == 0 then startRoundRobinFlow(name, venue, date, pattern, liveCap, refreshFn)
    else startGroupWiseFlow(name, venue, date, pattern, liveCap, refreshFn) end
   end, nil, true)
  end)
 end)
 d.show()
end
local function showTournamentListDialog()
 if not db then toast("Database could not be opened.", true) return end
 local d, v = makeDialog("Tournament Schedules", {
  LinearLayout; orientation = "vertical"; padding = "16dp"; backgroundColor = "#F5F7FA"; layout_width = "-1"; layout_height = "-1";
  btn("newBtn", "+ New Tournament", "0xFF3F51B5", 20, {layout_marginBottom = "8dp"});
  btn("moreBtn", "More Options", "0xFF795548", 20, {layout_marginBottom = "8dp"});
  { TextView; id = "hintTxt"; text = ""; textSize = "13sp"; textColor = "#455A64"; layout_marginBottom = "8dp"; layout_width = "-1"; };
  { ListView; id = "listView"; layout_width = "-1"; layout_height = "0dp"; layout_weight = 1; layout_marginBottom = "8dp"; };
  btn("closeBtn", "Close", "0xFFD32F2F", 20);
 })
 local records = {}
 local function loadList()
  records = {}
  local items = {}
  query("SELECT id, name, venue_country, start_date, format, round_type FROM tournaments ORDER BY id DESC", function(c)
   local r = {id = c.getInt(0), name = c.getString(1) or "", venue = c.getString(2) or "World"}
   records[#records + 1] = r
   items[#items + 1] = r.name .. " - " .. (c.getString(4) == "group_wise" and "Group Wise" or "Round Robin") ..
    " (" .. (c.getString(5) == "double" and "Double" or "Single") .. ") - " .. r.venue .. " - Starts " .. formatDateDisplay(c.getString(3))
  end)
  v.listView.setAdapter(ArrayAdapter(appContext, android.R.layout.simple_list_item_1, items))
  v.hintTxt.setText((#records == 0) and "No tournaments yet. Tap + New Tournament to create your first tournament."
   or "Tap + New Tournament to create a new tournament, or tap an existing tournament to open it. Press and hold a tournament to rename or delete it.")
 end
 loadList()
 local function deleteTournament(r)
  confirmDialog("Delete Tournament", "Delete \"" .. r.name .. "\" with its fixtures, points table and officials? This cannot be undone.", "Yes, Delete", function()
   exec("DELETE FROM official_log WHERE match_id IN (SELECT id FROM tournament_matches WHERE tournament_id = ?);", r.id)
   exec("DELETE FROM points_table WHERE tournament_id = ?;", r.id)
   exec("DELETE FROM tournament_matches WHERE tournament_id = ?;", r.id)
   exec("DELETE FROM tournaments WHERE id = ?;", r.id)
   toast("Tournament deleted.")
   loadList()
  end)
 end
 onTap(v.newBtn, function() showNewTournamentWizard(loadList) end)
 onTap(v.moreBtn, function()
  local opts = {
   {"Export All Tournaments", function() exportBackup(nil) end},
   {"Export Single Tournament", function()
    if #records == 0 then toast("No tournaments yet.") return end
    local names = {}
    for i, r in ipairs(records) do names[i] = r.name end
    showListDialog("Export Which Tournament?", names, function(pos) exportBackup(records[pos + 1].id, records[pos + 1].name) end)
   end},
   {"Import (Restore) from File", function() showImportDialog(loadList) end},
   {"Delete All Tournaments", function()
    confirmDialog("Delete All Tournaments", "This will permanently delete ALL tournaments with their fixtures, points tables and officials. This cannot be undone. Continue?", "Yes, Delete All", function()
     for _, t in ipairs({"tournaments", "tournament_matches", "points_table", "official_log"}) do
      pcall(function() db.execSQL("DELETE FROM " .. t .. ";") end)
     end
     toast("All tournaments deleted.")
     loadList()
    end)
   end},
  }
  local labels = {}
  for i, o in ipairs(opts) do labels[i] = o[1] end
  showListDialog("More Options", labels, function(pos) opts[pos + 1][2]() end)
 end)
 v.listView.setOnItemClickListener(AdapterView.OnItemClickListener({ onItemClick = function(_, _, pos, _)
  local r = records[pos + 1]
  if r then showFixtureListDialog(r.id, r.name, r.venue) end
 end}))
 v.listView.setOnItemLongClickListener(AdapterView.OnItemLongClickListener({ onItemLongClick = function(_, _, pos, _)
  local r = records[pos + 1]
  if not r then return true end
  showListDialog(r.name, {"Rename", "Delete"}, function(p2)
   if p2 == 0 then
    promptInput("Rename Tournament", r.name, "Champions Trophy", function(val)
     if val ~= r.name and nameExists(val) then toast("A tournament with this name already exists.") return end
     exec("UPDATE tournaments SET name = ? WHERE id = ?;", val, r.id)
     loadList()
    end)
   else
    deleteTournament(r)
   end
  end)
  return true
 end}))
 onTap(v.closeBtn, function() d.dismiss() end)
end
-- ===== Home =====
local mv = {}
local BAT = "\240\159\143\143"      -- cricket bat and ball
local DOT = "\226\128\162 "         -- bullet
local homeInfo = DOT .. "Balanced fixtures: every team plays at even gaps\n" ..
 DOT .. "Live matches shared equally, room link times and time zones\n" ..
 DOT .. "Officials, reminders and points table\n" ..
 DOT .. "Playoffs, Super stages, groups and custom rounds\n" ..
 DOT .. "Backup and restore of every tournament"
dlg.setView(loadlayout({
 ScrollView; layout_width = "-1"; layout_height = "-1"; backgroundColor = "#F5F7FA";
 { LinearLayout; orientation = "vertical"; padding = "20dp"; layout_width = "-1";
  { TextView; id = "homeName"; text = "Umar Jan"; textSize = "28sp"; textColor = "#B71C1C"; style = "bold"; gravity = "center"; layout_marginBottom = "2dp"; layout_width = "-1"; };
  { TextView; id = "homeTitle"; text = BAT .. " Tournament Schedule Manager"; textSize = "22sp"; textColor = "#1A237E"; style = "bold"; gravity = "center"; layout_marginBottom = "6dp"; layout_width = "-1"; };
  { TextView; text = "Plan cricket tournaments in minutes"; textSize = "14sp"; textColor = "#455A64"; gravity = "center"; layout_marginBottom = "14dp"; layout_width = "-1"; };
  { TextView; text = homeInfo; textSize = "13sp"; textColor = "#37474F"; layout_marginBottom = "20dp"; layout_width = "-1"; };
  btn("tourBtn", "Tournament Schedule", "0xFF9C27B0", 20, {layout_marginBottom = "10dp"});
  btn("helpBtn", "Help & Feedback", "0xFF607D8B", 20, {layout_marginBottom = "10dp"});
  btn("exitBtn", "Exit", "0xFFD32F2F", 20);
 };
}, mv))
pcall(function() mv.tourBtn.setContentDescription("Tournament Schedule. Create and manage tournaments, fixtures, officials and points tables.") end)
pcall(function() mv.helpBtn.setContentDescription("Help and feedback. User guide and contact links.") end)
pcall(function() mv.exitBtn.setContentDescription("Exit. Close the plugin.") end)
pcall(function() mv.homeName.setAccessibilityHeading(true) end)
pcall(function() mv.homeTitle.setAccessibilityHeading(true) end)
onTap(mv.tourBtn, showTournamentListDialog)
onTap(mv.helpBtn, showHelpDialog)
onTap(mv.exitBtn, closeAll)
dlg.show()
pcall(function()
 if db and os.time() - (tonumber(getSetting("lastUpdateCheck")) or 0) > 43200 then checkForUpdate(false) end
end)r