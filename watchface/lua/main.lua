-- 设备侧加载 app/lua/main.lua
local lvgl = require("lvgl")

local ok_cfg, cfg = pcall(require, "config")
local config = ok_cfg and cfg or {}
local project_name = config.project_name or "LuaDevTemplate"
local watchface_id = tostring(config.watchface_id or "167210065")

local DEST_ROOT = "/data/app/watchface/market/" .. watchface_id
local STAMP_DIR = DEST_ROOT .. "/.hotreload"
local APP_MODULE = "app"
local APP_NS = APP_MODULE:match("^[^%.]+") or APP_MODULE

local MODE_ALIGN, MODE_TICK = 1, 2
local ALIGN_FAST, ALIGN_SLOW = 25, 200

local os_time = os.time
local pcall = pcall
local xpcall = xpcall
local tostring = tostring
local collectgarbage = collectgarbage

local Timer = lvgl.Timer
local fs_open_dir = lvgl.fs.open_dir

-- 保证 app/lua 在 package.path
local function get_this_dir()
  local src = ""
  if debug and debug.getinfo then
    local info = debug.getinfo(1, "S")
    src = (info and info.source) or ""
  end

  if type(src) ~= "string" then
    src = ""
  end

  if src:sub(1, 1) == "@" then
    src = src:sub(2)
  end

  src = src:gsub("\\", "/")
  return src:match("^(.*)/[^/]+$") or "."
end

local function ensure_project_lua_path()
  if not package or type(package.path) ~= "string" then
    return nil
  end

  local dir = get_this_dir()
  local project_lua = dir .. "/app/lua"
  local p1 = project_lua .. "/?.lua"
  local p2 = project_lua .. "/?/init.lua"

  if not package.path:find(p1, 1, true) then
    package.path = p1 .. ";" .. p2 .. ";" .. package.path
  end

  return project_lua
end

local function load_inner_main()
  local project_lua = ensure_project_lua_path() or (get_this_dir() .. "/app/lua")
  local main_path = project_lua .. "/main.lua"

  if loadfile then
    local chunk, err = loadfile(main_path)
    if not chunk then
      error("load inner main failed: " .. tostring(err))
    end
    return chunk()
  end

  if dofile then
    local ok, res = pcall(dofile, main_path)
    if not ok then
      error("dofile inner main failed: " .. tostring(res))
    end
    return res
  end
  error("loadfile/dofile not available to load inner main")
end

local function build_app(api)
  ensure_project_lua_path()

  package.loaded.main = nil

  local app_or_err = load_inner_main()

  local root = nil
  if type(app_or_err) == "table" then
    root = app_or_err.root
  elseif type(app_or_err) == "userdata" then
    root = app_or_err
  end

  return root
end

package.preload[APP_MODULE] = function()
  return { build = build_app }
end

local app_root = nil
local in_reload = false
local GEN = 0
local BIND_GEN = 0

local OWN_TIMERS = {}
local function register_timer(t) OWN_TIMERS[t] = true end
local function unregister_timer(t) OWN_TIMERS[t] = nil end
local function cancel_owned_timers()
  for t in pairs(OWN_TIMERS) do
    pcall(function() t:pause() end)
    pcall(function() t:delete() end)
    OWN_TIMERS[t] = nil
  end
end

local hooks = { per_sec = nil, on_align = nil }
local function reset_hooks() hooks.per_sec, hooks.on_align = nil, nil end

local function tb(err)
  local tr = (debug and debug.traceback and debug.traceback("", 2)) or ""
  return tostring(err) .. (tr ~= "" and ("\n" .. tr) or "")
end

local function log_error(msg)
  print("[" .. project_name .. "][hotreload] " .. tostring(msg))
end

local function make_guarded(cb, bind_gen)
  local my_gen = bind_gen or BIND_GEN
  return function(epoch)
    if in_reload or my_gen ~= GEN then return end
    local ok, err = xpcall(cb, tb, epoch)
    if not ok then log_error("hook error:\n" .. err) end
  end
end

local api = {
  on_tick = function(cb)
    hooks.per_sec = (type(cb) == "function") and make_guarded(cb, BIND_GEN) or nil
  end,
  on_align = function(cb)
    hooks.on_align = (type(cb) == "function") and make_guarded(cb, BIND_GEN) or nil
  end,
  now = function() return os_time() end,
  generation = function() return GEN end,
  schedule = function(delay_ms, fn)
    local my_gen = BIND_GEN
    local t = Timer({
      period = delay_ms, repeat_count = 1,
      cb = function(self)
        if in_reload or my_gen ~= GEN then unregister_timer(self); return end
        pcall(fn)
        unregister_timer(self)
      end
    })
    register_timer(t); t:resume()
    return t
  end,
}

local function safe_delete(o)
  if o and o.delete then pcall(function() o:delete() end) end
end

local function read_token(dir)
  local d = select(1, fs_open_dir(dir))
  if not d then return nil end
  local ok, name = pcall(function()
    local latest = nil
    while true do
      local n = d:read()
      if not n then break end
      if n ~= "." and n ~= ".." then
        if not latest or n > latest then
          latest = n
        end
      end
    end
    return latest
  end)
  pcall(function() d:close() end)
  return ok and name or nil
end

local APP_DEPS = {}

local RELOAD_BLOCKLIST = {
  lvgl    = true,
  package = true,
  dataman = true,
  topic   = true,
  activity = true,
  animengine = true,
  navigator = true,
  screen = true,
  vibrator = true,
  coroutine = true,
  debug = true,
  io = true,
  math = true,
  os = true,
  string = true,
  table = true,
  _G = true,
}

local RELOAD_WHITELIST_PREFIX = {
}

local function in_whitelist(name)
  if name == APP_NS or name:sub(1, #APP_NS + 1) == (APP_NS .. ".") then
    return true
  end
  for _, p in ipairs(RELOAD_WHITELIST_PREFIX) do
    if name == p or name:sub(1, #p) == p then return true end
  end
  return false
end

local function unload_deps(deps)
  for name, _ in pairs(deps) do
    if not RELOAD_BLOCKLIST[name] and in_whitelist(name) then
      package.loaded[name] = nil
      rawset(_G, name, nil)
    end
  end
end

local main_timer = nil

-- 重新加载 app，并跟踪依赖
local function reload_app()
  in_reload = true
  if main_timer then pcall(function() main_timer:pause() end) end

  safe_delete(app_root); app_root = nil
  reset_hooks()
  cancel_owned_timers()

  unload_deps(APP_DEPS)
  package.loaded[APP_MODULE] = nil
  rawset(_G, APP_MODULE, nil)
  collectgarbage("collect")

  local recorded = {}
  local old_require = require
  local function tracking_require(name)
    recorded[name] = true
    return old_require(name)
  end

  local proposed_gen = GEN + 1
  BIND_GEN = proposed_gen

  local ok_mod, mod_or_err
  _G.require = tracking_require
  ok_mod, mod_or_err = xpcall(function()
    return tracking_require(APP_MODULE)
  end, tb)
  _G.require = old_require

  if not ok_mod then
    BIND_GEN = GEN
    log_error("reload app failed: " .. mod_or_err)
    in_reload = false
    if main_timer then pcall(function() main_timer:resume() end) end
    return false
  end

  local builder = (type(mod_or_err) == "table" and mod_or_err.build) or mod_or_err
  if type(builder) ~= "function" then
    BIND_GEN = GEN
    log_error("reload app failed: app module has no build()")
    in_reload = false
    if main_timer then pcall(function() main_timer:resume() end) end
    return false
  end

  local ok_build, root_or_err
  _G.require = tracking_require
  ok_build, root_or_err = xpcall(function()
    return builder(api)
  end, tb)
  _G.require = old_require

  if not ok_build then
    BIND_GEN = GEN
    log_error("reload app failed: app.build() failed:\n" .. root_or_err)
    in_reload = false
    if main_timer then pcall(function() main_timer:resume() end) end
    return false
  end

  app_root = root_or_err
  APP_DEPS = recorded
  GEN = proposed_gen

  in_reload = false
  if main_timer then pcall(function() main_timer:resume() end) end
  return true
end

reload_app()

local last_token, last_token_check_epoch = nil, -1
local function maybe_check_token(epoch)
  if epoch == last_token_check_epoch then return end
  last_token_check_epoch = epoch
  local token = read_token(STAMP_DIR)
  if token and token ~= last_token then
    if reload_app() then last_token = token end
  end
end

-- 主循环：对齐秒级并检查热更标记
local mode, current_period = MODE_ALIGN, 200
local last_epoch, ticks = os_time(), 0
local near_secs = { [58] = true, [59] = true, [0] = true }

main_timer = Timer({
  period = current_period,
  cb = function(self)
    if in_reload then return end

    local epoch = os_time()

    if mode == MODE_ALIGN then
      if epoch ~= last_epoch then
        local on_align = hooks.on_align; if on_align then on_align(epoch) end
        local per_sec  = hooks.per_sec;  if per_sec  then per_sec(epoch)  end

        maybe_check_token(epoch)

        mode, ticks = MODE_TICK, 0
        current_period = 1000
        pcall(function() self:set({ period = 1000 }) end)
      else
        local s = epoch % 60
        local target = near_secs[s] and ALIGN_FAST or ALIGN_SLOW
        if target ~= current_period then
          current_period = target
          pcall(function() self:set({ period = target }) end)
        end
        maybe_check_token(epoch)
      end

    else
      local per_sec = hooks.per_sec; if per_sec then per_sec(epoch) end
      maybe_check_token(epoch)

      ticks = ticks + 1
      if ticks >= 60 or (epoch % 60) == 0 then
        mode, ticks = MODE_ALIGN, 0
        if current_period ~= ALIGN_SLOW then
          current_period = ALIGN_SLOW
          pcall(function() self:set({ period = ALIGN_SLOW }) end)
        end
      end
    end

    last_epoch = epoch
  end
})
main_timer:resume()
