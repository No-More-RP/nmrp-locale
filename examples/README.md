# Examples (not loaded)

Reference snippets showing how to **consume** nanos-locale. They live at the package
root, **outside the require chain and outside `Client/`/`Shared/`**, so nanos never
loads them and never ships them to clients. Copy the relevant bits into your own
package.

| File | Realm | Shows |
|---|---|---|
| `per-script.lua` | Any | Declare and use your package's own namespace; fall back to the shared pack. |
| `server-per-player.lua` | Server | Translate per player (explicit language) + a `/lang` command. |
| `client-webui.lua` | Client | Create a WebUI and bind it to the store with `Locale.Attach`. |
| `web/index.html` | WebUI | Language selector + live translation via `locale.js`. |

For the web example, copy both `web/index.html` and `Client/web/locale.js` into your
package's `Client/web/` folder — a WebUI resolves `file:///` paths relative to the
calling package's own folder.
