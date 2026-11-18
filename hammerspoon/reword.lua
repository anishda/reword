-- reword.lua : raccourcis de reformulation via le CLI `reword` (Apple Intelligence, local).
-- Installation : copier dans ~/.hammerspoon/ puis ajouter  require("reword")  à init.lua
local M = {}

local REWORD = os.getenv("HOME") .. "/.local/bin/reword"
local TIMEOUT = 20
local hyper = { "ctrl", "alt" }
local BINDINGS = {
  { key = "f", mode = "fix" },
  { key = "r", mode = "rephrase" },
  { key = "s", mode = "shorten" },
  { key = "t", mode = "formal" },
  { key = "e", mode = "translate" },
}

local busy = false
local last = nil -- { original = string, result = string }

local function log(msg)
  if os.getenv("REWORD_DEBUG") or hs.settings.get("reword.debug") then
    local f = io.open("/tmp/reword-hs.log", "a")
    if f then f:write(os.date("%H:%M:%S ") .. msg .. "\n"); f:close() end
  end
end

local function notify(msg)
  log("notify: " .. msg)
  hs.notify.new({ title = "reword", informativeText = msg, withdrawAfter = 3 }):send()
end

local MESSAGES = {
  [3]  = "Aucun texte sélectionné.",
  [10] = "Modèle indisponible : ",
  [11] = "Langue non prise en charge.",
  [12] = "Refusé par les garde-fous d'Apple. Texte inchangé.",
  [13] = "Texte trop long pour ce mode.",
  [14] = "Délai dépassé. Texte inchangé.",
  [16] = "Résultat inexploitable. Texte inchangé.",
}

local function friendly(code, err)
  local base = MESSAGES[code] or "Erreur reword (code " .. tostring(code) .. ")."
  if code == 10 or code == 15 then base = base .. " " .. (err or "") end
  return base
end

local function snapshot()
  local ok, data = pcall(hs.pasteboard.readAllData)
  return ok and data or nil
end

local function restore(saved)
  hs.pasteboard.clearContents()
  if saved and #saved > 0 then pcall(hs.pasteboard.writeAllData, saved) end
end

-- Attend que predicate() soit vrai (poll 20 ms), max `timeout` secondes.
local function waitFor(predicate, timeout, done)
  local waited = 0
  local t
  t = hs.timer.doEvery(0.02, function()
    waited = waited + 0.02
    if predicate() then t:stop(); done(true)
    elseif waited >= timeout then t:stop(); done(false) end
  end)
end

local function pasteResult(text, saved, app)
  hs.pasteboard.setContents(text)
  -- NB : writeDataForUTI remplace tout le contenu du presse-papiers ; on ne marque donc pas
  -- le contenu "transitoire" (à revoir si un gestionnaire de presse-papiers pose problème).
  hs.eventtap.keyStroke({ "cmd" }, "v", 0)
  hs.timer.doAfter(0.25, function() restore(saved); busy = false end)
end

function M.run(mode)
  if busy then return end
  busy = true
  local app = hs.application.frontmostApplication()
  local saved = snapshot()
  local count = hs.pasteboard.changeCount()
  hs.pasteboard.clearContents()
  local cleared = hs.pasteboard.changeCount()
  hs.eventtap.keyStroke({ "cmd" }, "c", 0)

  waitFor(function() return hs.pasteboard.changeCount() ~= cleared end, 0.5, function(ok)
    local text = ok and hs.pasteboard.readString() or nil
    if not text or text == "" then
      restore(saved); busy = false; notify(MESSAGES[3]); return
    end
    hs.alert.show("Reformulation…", 1)
    local task = hs.task.new(REWORD, function(code, out, err)
      log("task done code=" .. tostring(code) .. " out=" .. tostring(out) .. " err=" .. tostring(err))
      if code ~= 0 then
        restore(saved); busy = false; notify(friendly(code, err)); return
      end
      local front = hs.application.frontmostApplication()
      if front ~= app then
        -- l'utilisateur a changé d'appli : on ne colle pas, le résultat reste dans le presse-papiers
        hs.pasteboard.setContents(out); busy = false
        notify("Résultat copié (l'application active a changé).")
        return
      end
      log("pasting")
      last = { original = text, result = out }
      pasteResult(out, saved, app)
    end, { mode, "--timeout", tostring(TIMEOUT) })
    task:setInput(text)
    task:start()
  end)
end

function M.undo()
  if not last or busy then return end
  busy = true
  local saved = snapshot()
  hs.pasteboard.setContents(last.original)
  hs.eventtap.keyStroke({ "cmd" }, "v", 0)
  last = nil
  hs.timer.doAfter(0.25, function() restore(saved); busy = false end)
end

local function modeNames()
  local out = hs.execute(REWORD .. " --list-modes")
  local names = {}
  for n in (out or ""):gmatch("[^\r\n]+") do names[#names + 1] = { text = n, mode = n } end
  return names
end

local chooser = hs.chooser.new(function(choice) if choice then M.run(choice.mode) end end)

function M.start()
  if not hs.fs.attributes(REWORD) then
    hs.alert.show("reword introuvable : " .. REWORD, 4); return
  end
  local _, ok = hs.execute(REWORD .. " --check")
  if not ok then notify("Modèle Apple Intelligence indisponible (reword --check).") end
  for _, b in ipairs(BINDINGS) do
    hs.hotkey.bind(hyper, b.key, function() M.run(b.mode) end)
  end
  hs.hotkey.bind(hyper, "z", M.undo)
  hs.hotkey.bind(hyper, "space", function() chooser:choices(modeNames()); chooser:show() end)
end

M.start()
return M
