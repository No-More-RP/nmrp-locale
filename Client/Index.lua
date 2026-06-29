-- Adopt the client's current language as the active one.
Locale.SetLanguage(Client.GetLanguage());

-- Follow the player's language preference live (also re-syncs attached WebUIs).
Client.Subscribe("LanguageChange", Locale.SetLanguage);
