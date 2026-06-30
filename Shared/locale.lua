--- locale.lua — Localization (i18n) system for Nanos World.
---
--- Goals:
---   * PER-SCRIPT locales: every package declares its translations under its own
---     "namespace" (`Locale.Namespace("my-package")`), with no key collision
---     between packages.
---   * SHARED locales: a reserved namespace (`Locale.SHARED`) reachable from all
---     packages. A key missing in a namespace automatically falls back to the
---     shared namespace.
---   * Lua AND Web compatible: the exact same translation tables are usable from
---     Lua (server/client) AND from the WebUI (see `Client/web/locale.js`). The
---     client pushes the store + active language to every attached WebUI through
---     `Locale.Attach(webui)`.
---
--- Realms: server and client are separate Lua VMs. `Shared/` runs in BOTH, so
--- translations registered there exist in each realm. The active language is a
--- PER-PLAYER, CLIENT-SIDE value driven by `Client.GetLanguage()` /
--- `Client.Subscribe("LanguageChange")` (see Client/Index.lua); it cannot be
--- chosen on the server. Server-side code translates for a given player by
--- passing the player's language explicitly to `Locale.Translate(ns, key, params, language)`.
---
--- Key resolution (most specific to broadest), each language also tried by its
--- base code (e.g. "en-US" -> "en"):
---   namespace[language] -> namespace[fallback] -> shared[language] -> shared[fallback]
---   -> the key itself (to spot missing translations in game).
---
--- Authority legend (on each public method below):
---   [Both]        — safe to call on server AND client.
---   [Client Side] — client only; a no-op on the server.
---   [Server Side] — server only.

---@class Locale
---@field SHARED string Reserved shared namespace name ("shared").
---@field language LocaleLanguage Active language (client-driven).
---@field fallback LocaleLanguage Fallback language (realm-wide).
---@field Shared LocaleNamespace Ready-to-use shared namespace.
---@field Languages table<LocaleLanguage, string> Supported codes -> native display name.
---@field private _store table<string, table<LocaleLanguage, table<string, string>>> Translation store: _store[namespace][language] = { ["flat.key"] = "text" }.
---@field private _listeners fun(language: LocaleLanguage)[] Language-change listeners.
---@field private _namespaces table<string, LocaleNamespace> Cached namespace objects.
Locale = Locale or {};

--- Reserved namespace for translations shared between all scripts.
Locale.SHARED = "shared";

--- Active language and fallback language.
--- On the client, `language` is set from `Client.GetLanguage()` (see Client/Index.lua).
--- On the server it stays at the fallback (server translates per-player explicitly).
Locale.language = Locale.language or "en";
Locale.fallback = Locale.fallback or "en";

--- Supported language codes mapped to their native display name. Handy to build
--- a language selector. See the `LocaleLanguage` alias in locale.types.lua.
--- This is a suggested set: any ISO 639-1 code works at runtime via Register().
---@type table<LocaleLanguage, string>
Locale.Languages = Locale.Languages or {
    en      = "English",
    fr      = "Français",
    de      = "Deutsch",
    es      = "Español",
    it      = "Italiano",
    pt      = "Português",
    ["pt-BR"] = "Português (Brasil)",
    ru      = "Русский",
    pl      = "Polski",
    tr      = "Türkçe",
    nl      = "Nederlands",
    sv      = "Svenska",
    da      = "Dansk",
    fi      = "Suomi",
    no      = "Norsk",
    cs      = "Čeština",
    hu      = "Magyar",
    ro      = "Română",
    el      = "Ελληνικά",
    uk      = "Українська",
    ja      = "日本語",
    ko      = "한국어",
    ["zh-CN"] = "简体中文",
    ["zh-TW"] = "繁體中文",
    ar      = "العربية",
    th      = "ไทย",
    vi      = "Tiếng Việt",
    id      = "Bahasa Indonesia",
};

--- Store: _store[namespace][language] = { ["flat.key"] = "text", ... }
Locale._store = Locale._store or {};

--- Language-change listeners (Lua) and attached WebUIs (client).
Locale._listeners = Locale._listeners or {};
Locale._namespaces = Locale._namespaces or {};

local type <const> = type;
local pairs <const> = pairs;
local tostring <const> = tostring;
local tonumber <const> = tonumber;
local setmetatable <const> = setmetatable;
local table_remove <const> = table.remove;
local string_gsub <const> = string.gsub;
local string_match <const> = string.match;

--- Attached WebUIs (client only).
local _webuis <const> = {}; ---@type WebUI[]

--- Flattens a nested translation table into dotted keys.
--- `{ menu = { title = "Hi" } }` -> `{ ["menu.title"] = "Hi" }`.
---@param tbl table
---@param prefix string|nil
---@param out table<string, string>
---@return table<string, string>
local function flatten(tbl, prefix, out)
    for k, v in pairs(tbl) do
        local key <const> = prefix and (prefix .. "." .. tostring(k)) or tostring(k);
        if (type(v) == "table") then
            flatten(v, key, out);
        else
            out[key] = tostring(v);
        end
    end
    return out;
end

--- Base language code without region suffix: "en-US" / "en_US" -> "en".
---@param language string
---@return string
local function base_of(language)
    return string_match(language, "^[^-_]+") or language;
end

--- Replaces `{name}` tokens with values from `params`.
--- Supports named keys (`{name}`) and positional ones (`{1}`).
--- A token without a matching value is left as-is (debugging aid).
---@param str string
---@param params LocaleParams|nil
---@return string
local function interpolate(str, params)
    if (not params) then return str; end
    return (string_gsub(str, "{(.-)}", function(name)
        local value = params[name];
        if (value == nil) then value = params[tonumber(name)]; end
        if (value == nil) then return "{" .. name .. "}"; end
        return tostring(value);
    end));
end

--- Raw read of a key for a given namespace/language.
---@param namespace string
---@param language string
---@param key string
---@return string|nil
local function raw_lookup(namespace, language, key)
    local ns_data <const> = Locale._store[namespace];
    if (not ns_data) then return nil; end
    local lang_data <const> = ns_data[language];
    if (not lang_data) then return nil; end
    return lang_data[key];
end

--- Builds the ordered, de-duplicated list of candidate languages to try.
--- e.g. language = "en-US", fallback = "fr" -> { "en-US", "en", "fr" }.
---@param language string
---@return string[]
local function candidate_languages(language)
    local fallback <const> = Locale.fallback;
    local seen <const> = {};
    local out <const> = {};
    local function push(lang)
        if (lang and not seen[lang]) then
            seen[lang] = true;
            out[#out + 1] = lang;
        end
    end
    push(language);
    push(base_of(language));
    push(fallback);
    push(base_of(fallback));
    return out;
end

--- Resolves a key against a namespace then the shared namespace, across all
--- candidate languages. Returns the raw (non-interpolated) value or nil.
---@param namespace string
---@param key string
---@param language string
---@return string|nil
local function resolve(namespace, key, language)
    local langs <const> = candidate_languages(language);
    for i = 1, #langs do
        local value <const> = raw_lookup(namespace, langs[i], key);
        if (value ~= nil) then return value; end
    end
    if (namespace ~= Locale.SHARED) then
        for i = 1, #langs do
            local value <const> = raw_lookup(Locale.SHARED, langs[i], key);
            if (value ~= nil) then return value; end
        end
    end
    return nil;
end

--- Pushes the whole store + language to a WebUI (client only).
---@param webui WebUI
local function push_full(webui)
    webui:CallEvent("locale:load", {
        language = Locale.language,
        fallback = Locale.fallback,
        data = Locale._store,
    });
end

--- Re-syncs every attached WebUI (after a Register or SetLanguage).
local function sync_webuis()
    if (not Client) then return; end
    local webuis <const> = _webuis;
    for i = 1, #webuis do
        push_full(webuis[i]);
    end
end

--- [Both] Registers (merges) translations for a namespace + language.
--- Callable many times: keys accumulate, duplicates are overwritten.
--- On the client it also re-syncs attached WebUIs.
---@param namespace string Namespace name (`Locale.SHARED` for the shared one).
---@param language LocaleLanguage Language code (e.g. "en", "fr").
---@param translations LocaleTranslations Translation table (nesting allowed) key -> text.
---@return Locale
function Locale.Register(namespace, language, translations)
    if (type(translations) ~= "table") then
        error("Locale.Register: 'translations' must be a table", 2);
    end

    local ns_data = Locale._store[namespace];
    if (not ns_data) then
        ns_data = {};
        Locale._store[namespace] = ns_data;
    end

    local lang_data = ns_data[language];
    if (not lang_data) then
        lang_data = {};
        ns_data[language] = lang_data;
    end

    flatten(translations, nil, lang_data);
    sync_webuis(); -- propagate late registrations to already-mounted WebUIs
    return Locale;
end

--- [Both] Translates a key, following namespace -> shared and language -> fallback.
--- Returns the key itself when no translation is found. On the server, pass
--- `language` explicitly to translate for a specific player.
---@param namespace string
---@param key string
---@param params LocaleParams|nil Interpolation values (`{ name = "Bob", count = 3 }`).
---@param language LocaleLanguage|nil Explicit language (server-side per-player); defaults to `Locale.language`.
---@return string
function Locale.Translate(namespace, key, params, language)
    local value <const> = resolve(namespace, key, language or Locale.language);
    if (value == nil) then return key; end
    return interpolate(value, params);
end

--- [Both] Whether a key exists (in the namespace or the shared one, language/fallback).
---@param namespace string
---@param key string
---@param language LocaleLanguage|nil Explicit language; defaults to `Locale.language`.
---@return boolean
function Locale.Has(namespace, key, language)
    return resolve(namespace, key, language or Locale.language) ~= nil;
end

--- [Both] Sets the active language and notifies Lua listeners + WebUIs.
--- Mostly a client-side concept (each player has their own language, driven by
--- `Client.GetLanguage()`). On the server this only moves the realm-wide default
--- used by translations without an explicit `language` argument.
---@param language LocaleLanguage
---@return Locale
function Locale.SetLanguage(language)
    if (Locale.language == language) then return Locale; end
    Locale.language = language;

    local listeners <const> = Locale._listeners;
    for i = 1, #listeners do
        listeners[i](language);
    end

    if (Client) then
        local webuis <const> = _webuis;
        for i = 1, #webuis do
            webuis[i]:CallEvent("locale:language", language);
        end
    end
    return Locale;
end

--- [Both] Returns the active language.
---@return LocaleLanguage
function Locale.GetLanguage()
    return Locale.language;
end

--- [Both] Sets the fallback language (used when a key is missing in the active language).
---@param language LocaleLanguage
---@return Locale
function Locale.SetFallback(language)
    Locale.fallback = language;
    sync_webuis();
    return Locale;
end

--- [Both] Subscribes a callback to language changes. Returns an unsubscribe function.
---@param callback fun(language: LocaleLanguage)
---@return fun() unsubscribe
function Locale.OnChange(callback)
    local listeners <const> = Locale._listeners;
    listeners[#listeners + 1] = callback;
    return function()
        for i = #listeners, 1, -1 do
            if (listeners[i] == callback) then
                table_remove(listeners, i);
                break;
            end
        end
    end
end

---@class LocaleNamespace
---@field name string Namespace name (usually the package name).
local namespace_proto = {};
local namespace_meta <const> = { __index = namespace_proto };

--- [Both] Registers translations into this namespace.
---@param language LocaleLanguage
---@param translations LocaleTranslations
---@return LocaleNamespace
function namespace_proto:Register(language, translations)
    Locale.Register(self.name, language, translations);
    return self;
end

--- [Both] Alias of `Register`.
---@type fun(self: LocaleNamespace, language: LocaleLanguage, translations: LocaleTranslations): LocaleNamespace
namespace_proto.Set = namespace_proto.Register;

--- [Both] Translates a key within this namespace (with fallback to the shared one).
---@param key string
---@param params? LocaleParams
---@param language? LocaleLanguage Explicit language (server-side per-player).
---@return string
function namespace_proto:Get(key, params, language)
    return Locale.Translate(self.name, key, params, language);
end

--- [Both] Short alias of `Get`.
---@type fun(self: LocaleNamespace, key: string, params?: LocaleParams, language?: LocaleLanguage): string
namespace_proto.t = namespace_proto.Get;

--- [Both] Whether a key exists in this namespace (or the shared one).
---@param key string
---@param language LocaleLanguage|nil
---@return boolean
function namespace_proto:Has(key, language)
    return Locale.Has(self.name, key, language);
end

--- [Both] Gets (or creates) the namespace object of a script. Cached.
---@param name string Namespace name (typically the package name).
---@return LocaleNamespace
function Locale.Namespace(name)
    local existing <const> = Locale._namespaces[name];
    if (existing) then return existing; end

    local ns <const> = setmetatable({ name = name }, namespace_meta);
    Locale._namespaces[name] = ns;
    return ns;
end

--- Ready-to-use shared namespace: `Locale.Shared:Register("fr", { ... })`.
---@type LocaleNamespace
Locale.Shared = Locale.Namespace(Locale.SHARED);

--- [Client Side] Attaches a WebUI: immediately pushes the store + language,
--- answers its requests ("locale:request" emitted by locale.js on load) and
--- forwards future updates (Register / SetLanguage).
---
--- On the server this is a no-op (returns the WebUI unchanged): handy to write
--- shared code without an `if (Client)` guard.
---@param webui WebUI
---@return WebUI
function Locale.Attach(webui)
    if (not Client) then return webui; end

    _webuis[#_webuis + 1] = webui;
    webui:Subscribe("locale:request", function() push_full(webui); end);
    -- The UI may also drive the language from JS (language selector).
    webui:Subscribe("locale:set-language", function(language) Locale.SetLanguage(language); end);
    push_full(webui); -- in case the UI is already ready
    return webui;
end

--- [Client Side] Detaches a WebUI (e.g. before destroying it).
---@param webui WebUI
---@return Locale
function Locale.Detach(webui)
    local webuis <const> = _webuis;
    for i = #webuis, 1, -1 do
        if (webuis[i] == webui) then
            table_remove(webuis, i);
            break;
        end
    end
    return Locale;
end

if (Client) then
    WebUI.Subscribe("Destroy", Locale.Detach);
end

return Locale;
