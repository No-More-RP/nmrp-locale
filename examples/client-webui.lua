--- Example (NOT loaded) — client-side, bind a WebUI to the locale store.
--- Put this in your OWN package's Client/ and require it. Copy nanos-locale's
--- Client/web/locale.js next to your page (here: Client/web/index.html), since a
--- WebUI resolves file:/// paths relative to the calling package's folder.

local ui <const> = WebUI(
    "ShopUI",                       -- debug name
    "file:///web/index.html",       -- Client/web/index.html (loads locale.js)
    WidgetVisibility.Visible,
    true,                           -- transparent overlay
    true                            -- auto-resize
);

--- Pushes the whole store + active language to the page, answers its handshake,
--- and forwards future Register/SetLanguage updates. The page translates on its
--- own via window.Locale (see web/index.html).
Locale.Attach(ui);

--- The active language already follows the player automatically (nanos-locale wires
--- Client.GetLanguage() + "LanguageChange"); no need to set it here. React to it if
--- you keep some Lua-side state in sync:
Locale.OnChange(function(language)
    print("[shop] UI language is now " .. language);
end);

return ui;
