--- Example (NOT loaded) — per-script locales for a hypothetical "shop" package.
--- Drop something like this in your OWN package's Shared/ and require it; it relies
--- on the global `Locale` provided by nanos-locale.

local L <const> = Locale.Namespace("shop"); ---@type LocaleNamespace

L:Register("en", {
    title      = "General Store",
    buy        = "Buy for {price}$",
    sold       = "You bought {item}.",
    not_enough = "Not enough money.",
});

L:Register("fr", {
    title      = "Magasin général",
    buy        = "Acheter pour {price}$",
    sold       = "Vous avez acheté {item}.",
    not_enough = "Fonds insuffisants.",
});

-- Namespace keys
print(L:t("title"));
print(L:t("buy", { price = 250 }));        -- interpolation -> "Buy for 250$"
print(L:t("sold", { item = "Apple" }));

-- Missing keys fall back to the curated shared pack (common.*, time.*)
print(L:t("common.cancel"));               -- "Cancel" / "Annuler"
print(L:t("time.today"));

return L;
