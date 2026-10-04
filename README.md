<p align="center">
  <img src="marketing/game_icon.png" width="160" alt="Grow a Gem Garden icon">
</p>

<h1 align="center">Grow a Gem Garden 💎</h1>

<p align="center">
  A Roblox garden simulator where your plants grow <b>gems</b>.<br>
  <a href="https://www.roblox.com/games/118191458070589/Grow-a-Gem-Garden"><b>▶ Play on Roblox</b></a>
</p>

<p align="center">
  <img src="marketing/thumb_1.png" width="32%">
  <img src="marketing/thumb_2.png" width="32%">
  <img src="marketing/thumb_3.png" width="32%">
</p>

---

## The game

Plant magical seeds, harvest the gems they grow, sell them at the Gem Trader, and buy rarer seeds. Every gem rolls its own size, and weather can mutate gems on your plants for huge multipliers.

- **15 plants** from Common to Prismatic, from Quartz Sprout to Prism Lotus. Some give one big gem; others keep regrowing.
- **8 mutations**: Golden ×20 and Rainbow ×50 roll naturally. Weather adds Glimmering ×2, Frozen ×8, Molten ×15, Charged ×30, Cosmic ×60 and Celestial ×100, and they stack.
- **6 server-wide weather events**: Glimmer Rain, Blizzard, Heatwave, Thunderstorm (lightning strikes plants), Meteor Shower (meteors hit gardens) and Aurora.
- **Personal shop stock** that restocks every 5 minutes, so rare seeds really are rare.
- **Gear**: watering cans, three kinds of sprinklers and a shovel.
- **8 gardens per server.** Your garden keeps growing while you're offline.
- **Retention**: tutorial, 7-day login streak, playtime gifts, promo codes, a collection index, global leaderboards, a friend sell bonus and invite rewards.
- **Look**: faceted CSG gems, procedural plants, an island built from terrain, gnome shopkeepers, and quiet licensed music (APM library).

## Monetization

| Type | Items |
|---|---|
| Game passes | VIP (249), Lucky Gardener (199), Speedy Growth (299), Super Garden (149), Big Bag (99), Sell Anywhere (149) |
| Coin packs | 25 / 99 / 399 / 1499 Robux. Amounts scale with the most expensive seed the player has bought. |
| Boosts | Grow Everything (79), Luck Potion 30 min (49), Restock Shops (29) |
| Weather | Any event for the whole server (49 to 399) |
| Seeds and gear | Any seed or gear for Robux, priced by rarity (15 to 799). The server records which item was clicked, so the receipt always grants that exact item. |
| Private servers | 99 Robux / month |
| Ads | Opt-in rewarded video ("watch an ad for a free 10-minute Lucky Boost") and two immersive ad billboards in the plaza. Both only start earning once the eligibility requirements below are met. |

Receipts are idempotent: every purchase ID is written to the player's save before Roblox is told it was granted. Product IDs live in [`src/ReplicatedStorage/Shared/Products.luau`](src/ReplicatedStorage/Shared/Products.luau).

## Owner checklist (things only the account owner can do)

1. **ID verification and 2-step verification**: [Publishing permissions](https://create.roblox.com/settings/eligibility/publishing-permissions). Until both are done, Roblox only shows the game to **players 16+ and trusted friends**, and most Roblox players are younger. Both are also required for ad earnings.
2. **Promote it.** New games get their first players from [Roblox Ads](https://create.roblox.com/dashboard/advertising) (sponsored experiences) and short clips on TikTok, YouTube Shorts and Reels. Good clips to film: a Meteor Shower hitting a garden, a Rainbow or Celestial gem being harvested, a Diamond Tree loaded with gems.
3. **Run live events.** In-game chat commands work for the game owner (see below). For example, `/weather meteor_shower` or `/sellboost 50 15` during a livestream.
4. **Ship updates.** New seeds, codes and weather keep players coming back. Each one is a small change (see below).

## Admin commands (owner only)

```
/coins 1000            /seed ruby 5            /gear sprinkler 2
/weather aurora        /restock                /growall
/announce text...      /sellboost 50 10        (percent, minutes)
```

## Making changes

**Add a seed:** add an entry to [`Species.luau`](src/ReplicatedStorage/Shared/Species.luau) using an existing `style`, or add a new one in [`PlantBuilder.luau`](src/ReplicatedStorage/Shared/Visuals/PlantBuilder.luau).
**Add a promo code:** edit `RewardsService.Codes` in [`RewardsService.luau`](src/ServerScriptService/Server/RewardsService.luau).
**Balance:** [`Config.luau`](src/ReplicatedStorage/Shared/Config.luau), `Species.luau`, `Mutations.luau`, `Weather.luau` and `Gear.luau` hold all the numbers.

## Project layout

```
src/                         Rojo-style source of truth
  ReplicatedStorage/Shared/  game data, value math, plant + gem builders, remotes
  ServerScriptService/       server services (data, gardens, shops, weather, monetization, ...)
  StarterPlayer/...          client: UI, garden renderer, tools, weather FX, tutorial, ads
build/                       edit-time builders run inside Studio
  gems.luau, shapes.luau     CSG gem and shape assets -> ReplicatedStorage.Assets
  world.luau                 island terrain, plaza, shops, gnomes, 8 gardens, lighting
  ads.luau                   immersive ad billboards (run after world.luau)
tools/                       Node tools that drive Studio over its built-in MCP server
  studio.mjs                 tiny MCP client for StudioMCP.exe
  sync.mjs                   pushes src/ into the open place (with syntax checks)
  run.mjs                    runs a Luau file / snippet in Studio (Edit, Server or Client)
  make_icon.py, make_icons.py, make_thumbs.py   store art
marketing/                   icon, thumbnails, pass/product icons
```

### Dev loop

1. Open the place in Roblox Studio and turn on **Assistant → ⋯ → Settings → MCP Servers → Enable Studio as MCP server**.
2. `node tools/sync.mjs` pushes every script under `src/` into Studio.
3. If world or assets changed, run `node tools/run.mjs build/<file>.luau`.
4. Playtest in Studio. In Studio a `ServerStorage.DevHook` BindableFunction lets scripts drive any server service, for example `DevHook:Invoke("GardenService", "growAll", player)`.
5. Publish with **File → Publish to Roblox**.

Save data uses DataStore `GemGarden_Live_1` with session locking, autosave and a final save on shutdown.
