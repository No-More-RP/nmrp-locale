--- Index.lua — shared entry point. Defines the global `Locale`, available on
--- both server AND client (and exposed to other packages via the shared Lua state).
require 'locale.types.lua'; -- LuaCATS aliases (LocaleLanguage, LocaleTranslations...)
require 'locale.lua';
require 'locales/Index.lua'; -- curated SHARED locale pack (common.*, time.*)

Package.Export("Locale", Locale);
