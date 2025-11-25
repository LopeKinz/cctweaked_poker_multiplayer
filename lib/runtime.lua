-- runtime.lua - shared runtime helpers (logging, config handling)

local runtime = {}

local function formatMessage(level, msg)
    local timeStr = "00:00"
    if textutils and textutils.formatTime then
        timeStr = textutils.formatTime(os.time(), true)
    end
    return string.format("[%s][%s] %s", timeStr, level, msg)
end

local function stringify(...)
    local parts = {}
    for i = 1, select("#", ...) do
        table.insert(parts, tostring(select(i, ...)))
    end
    return table.concat(parts, " ")
end

function runtime.log(level, ...)
    print(formatMessage(level, stringify(...)))
end

function runtime.info(...)
    runtime.log("INFO", ...)
end

function runtime.warn(...)
    runtime.log("WARN", ...)
end

function runtime.error(...)
    runtime.log("ERROR", ...)
end

function runtime.debug(enabled, ...)
    if enabled then
        runtime.log("DEBUG", ...)
    end
end

-- Shallow merge defaults with overrides from a Lua table returned by path
function runtime.loadConfig(defaults, path)
    local merged = {}
    for k, v in pairs(defaults or {}) do
        merged[k] = v
    end

    if path and fs and fs.exists and fs.exists(path) then
        local ok, result = pcall(dofile, path)
        if ok and type(result) == "table" then
            for k, v in pairs(result) do
                merged[k] = v
            end
        else
            runtime.warn("Konfiguration konnte nicht geladen werden aus", path, "- verwende Standardwerte")
            if not ok then
                runtime.debug(true, "Config error:", tostring(result))
            end
        end
    end

    return merged
end

-- Executes fn in protected mode and logs on failure. Returns ok, result.
function runtime.safeCall(context, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        runtime.error(context or "runtime", tostring(result))
    end
    return ok, result
end

return runtime
