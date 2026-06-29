/**
 * locale.js — WebUI-side localization bridge (vanilla, no dependency).
 *
 * Authority: [Client Side]. WebUIs only exist on the client, so every function
 * exposed here runs client side.
 *
 * Web mirror of Shared/locale.lua: same store, same resolution rules
 * (namespace -> shared -> language -> fallback -> key, each language also tried
 * by its base code, e.g. "en-US" -> "en"). Data arrives from Lua through
 * `Locale.Attach(webui)` (event "locale:load"); language changes through
 * "locale:language".
 *
 * Loading inside a WebUI page:
 *     <script src="locale.js"></script>
 *     <script>
 *       const L = window.Locale.namespace("my-package");
 *       window.Locale.onChange(() => render());
 *       // L.t("menu.title")  /  window.Locale.t("common.yes")  (shared)
 *     </script>
 *
 * The `window.Events` bridge is injected by the Nanos World runtime in game.
 * Out of game (plain browser) it is absent: the lib still works, just call
 * `window.Locale.load({ language, fallback, data })` manually.
 */
(function () {
  "use strict";

  var SHARED = "shared";

  // Supported language codes -> native display name (mirror of Lua Locale.Languages).
  // Handy to build a language selector. Any ISO 639-1 code works at runtime anyway.
  var LANGUAGES = {
    en: "English",
    fr: "Français",
    de: "Deutsch",
    es: "Español",
    it: "Italiano",
    pt: "Português",
    "pt-BR": "Português (Brasil)",
    ru: "Русский",
    pl: "Polski",
    tr: "Türkçe",
    nl: "Nederlands",
    sv: "Svenska",
    da: "Dansk",
    fi: "Suomi",
    no: "Norsk",
    cs: "Čeština",
    hu: "Magyar",
    ro: "Română",
    el: "Ελληνικά",
    uk: "Українська",
    ja: "日本語",
    ko: "한국어",
    "zh-CN": "简体中文",
    "zh-TW": "繁體中文",
    ar: "العربية",
    th: "ไทย",
    vi: "Tiếng Việt",
    id: "Bahasa Indonesia",
  };

  var state = {
    language: "en",
    fallback: "en",
    data: {}, // data[namespace][language] = { "flat.key": "text" }
  };

  var listeners = new Set();

  function emitChange() {
    listeners.forEach(function (cb) {
      try {
        cb(state.language);
      } catch (e) {
        console.error("[locale] listener error", e);
      }
    });
  }

  // Base language code without region suffix: "en-US" / "en_US" -> "en".
  function baseOf(language) {
    var m = /^[^-_]+/.exec(language);
    return m ? m[0] : language;
  }

  // Ordered, de-duplicated list of candidate languages to try.
  function candidateLanguages(language) {
    var seen = {};
    var out = [];
    [language, baseOf(language), state.fallback, baseOf(state.fallback)].forEach(
      function (lang) {
        if (lang && !seen[lang]) {
          seen[lang] = true;
          out.push(lang);
        }
      }
    );
    return out;
  }

  function rawLookup(namespace, language, key) {
    var ns = state.data[namespace];
    if (!ns) return undefined;
    var lang = ns[language];
    if (!lang) return undefined;
    return lang[key];
  }

  // Resolves a key against a namespace then the shared namespace, across all
  // candidate languages. Returns the raw value or undefined.
  function resolve(namespace, key) {
    var langs = candidateLanguages(state.language);
    var i;
    for (i = 0; i < langs.length; i++) {
      var value = rawLookup(namespace, langs[i], key);
      if (value !== undefined) return value;
    }
    if (namespace !== SHARED) {
      for (i = 0; i < langs.length; i++) {
        var shared = rawLookup(SHARED, langs[i], key);
        if (shared !== undefined) return shared;
      }
    }
    return undefined;
  }

  function interpolate(str, params) {
    if (!params) return str;
    return str.replace(/\{(.+?)\}/g, function (match, name) {
      var value = params[name];
      if (value === undefined || value === null) return match;
      return String(value);
    });
  }

  /**
   * Translates a key. Optional `params` for `{name}` interpolation.
   * @param {string} namespace
   * @param {string} key
   * @param {object} [params]
   * @returns {string}
   */
  function translate(namespace, key, params) {
    var value = resolve(namespace, key);
    if (value === undefined) return key;
    return interpolate(value, params);
  }

  /** Shortcut on the shared namespace: `Locale.t("common.yes")`. */
  function t(key, params) {
    return translate(SHARED, key, params);
  }

  function has(namespace, key) {
    return resolve(namespace, key) !== undefined;
  }

  /**
   * Loads a full store (payload of the Lua "locale:load" event, or a manual
   * call in a plain browser for dev).
   * @param {{language?: string, fallback?: string, data?: object}} payload
   */
  function load(payload) {
    if (!payload) return;
    if (payload.data) state.data = payload.data;
    if (payload.fallback) state.fallback = payload.fallback;
    if (payload.language) state.language = payload.language;
    emitChange();
  }

  /** Changes the displayed language and tells Lua (UI language selector). */
  function setLanguage(language) {
    if (state.language === language) return;
    state.language = language;
    emitChange();
    if (window.Events && typeof window.Events.Call === "function") {
      window.Events.Call("locale:set-language", language);
    }
  }

  function getLanguage() {
    return state.language;
  }

  /** Subscribes a callback to changes (load / language). Returns the unsubscribe. */
  function onChange(callback) {
    listeners.add(callback);
    return function () {
      listeners.delete(callback);
    };
  }

  /** Namespace object: `const L = Locale.namespace("my-package"); L.t("menu.title")`. */
  function namespace(name) {
    return {
      name: name,
      t: function (key, params) {
        return translate(name, key, params);
      },
      get: function (key, params) {
        return translate(name, key, params);
      },
      has: function (key) {
        return has(name, key);
      },
    };
  }

  var Locale = {
    SHARED: SHARED,
    languages: LANGUAGES,
    t: t,
    translate: translate,
    has: has,
    load: load,
    setLanguage: setLanguage,
    getLanguage: getLanguage,
    onChange: onChange,
    namespace: namespace,
  };

  window.Locale = Locale;

  // Auto-wiring to the Nanos bridge (present in game only).
  if (window.Events && typeof window.Events.Subscribe === "function") {
    window.Events.Subscribe("locale:load", load);
    window.Events.Subscribe("locale:language", setLanguage);
    // Handshake: request the store as soon as the page is ready (see Locale.Attach).
    if (typeof window.Events.Call === "function") {
      window.Events.Call("locale:request");
    }
  }
})();
