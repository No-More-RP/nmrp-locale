--- Index.lua — curated SHARED locale pack. Registers each language file into the
--- shared namespace (`Locale.SHARED`) so every package can fall back to these keys
--- (e.g. `Locale.Shared:t("common.yes")`).
---
--- Contribute a language: add `<code>.lua` next to this file (returning a
--- `LocaleTranslations` table) and one `load(...)` line below. Keep keys universal
--- and prefixed (common.*, time.*, unit.*) — the shared namespace is global to all
--- packages, so it must stay small and uncontroversial.

local register <const> = Locale.Register;

--- Registers a same-folder language file into the shared namespace.
---@param language LocaleLanguage
---@param file string Path relative to this folder (e.g. "en.lua").
local function load(language, file)
    register(Locale.SHARED, language, require(file));
end

load("en", "en.lua");
load("fr", "fr.lua");
