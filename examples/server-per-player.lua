--- Example (NOT loaded) — server-side translation, per player.
--- The server has no single active language (each player has their own), so always
--- pass the player's language explicitly as the 4th argument.

local L <const> = Locale.Namespace("shop"); ---@type LocaleNamespace

--- Resolve a player's language however you persist it (preference, DB, ...),
--- falling back to the realm-wide default.
---@param player Player
---@return LocaleLanguage
local function language_of(player)
    return player:GetValue("language") or Locale.fallback;
end

--- Tell a player they bought an item, in their own language.
---@param player Player
---@param item string
local function notify_purchase(player, item)
    local lang <const> = language_of(player);
    Chat.SendMessage(player, L:t("sold", { item = item }, lang));
end

--- Let players pick their language with a chat command, e.g. "/lang fr".
Chat.Subscribe("PlayerSubmit", function(text, _sender, player)
    local code <const> = text:match("^/lang%s+(%S+)$");
    if (not code) then return; end

    player:SetValue("language", code, true); -- replicated so the client can read it
    Chat.SendMessage(player, L:t("common.success", nil, code));
end);

return notify_purchase;
