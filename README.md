# Brainrot Bazaar — roblox-brainrot-01 (round 1)

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/RaynaldyRyan/brainrot-bazaar-game/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/RaynaldyRyan/brainrot-bazaar-game/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

A 3D Roblox brainrot game in the Steal a Brainrot genre, built with Rojo for
make.fun's "Make the best AI Roblox brainrot game" bounty (roblox-brainrot-01,
$1,000 total, 50 paid places).

## The game

You walk a 3D bazaar in third person. Absurd meme brainrots parade down the
central conveyor — Noodle Nessie, DJ Pickle, Captain Croissant, Turbo Toilet,
Disco Durian, Wizard Watermelon, Sushi Samurai, Galaxy Gummy Bear and more.
Click one to buy it, then dash home to your teal base and place it on a slot.
Every placed brainrot earns money per second at its own rate. Climb the
rarity ladder (Common, Rare, Epic, Legendary, Mythic, Secret), chase Golden,
Diamond and Rainbow mutations, lock your base against Sneaky Steve the rival
stealer, and rebirth for a permanent +25% income bonus. Every two minutes a
tsunami warning sounds: get back on your base before the wave sweeps the
plaza, or lose the brainrot you are carrying.

## How it is built

- `default.project.json` — the static 3D world: plaza, conveyor, four bases,
  stalls, lamps, trees, fences, fountain and the tsunami gate.
- `src/shared/BrainrotData.luau` — the cast of 12, the rarity ladder, the
  mutations, and every economy number (prices, rates, rebirth, lock).
- `src/server/BrainrotWorld.luau` — builds the moving 3D pieces at run time:
  brainrot character models, base slot pads, the stealer, the tsunami wave.
- `src/server/init.server.luau` — the game loop: conveyor spawns, buying and
  catching, placing, the money tick, the tsunami cycle, the stealer, locks
  and rebirths. All money and ownership live on the server.
- `src/client/Game.client.luau` — the ScreenGui HUD over the 3D world: money
  and income, shop list, base panel, tsunami banner, carried-brainrot bar,
  lock and rebirth buttons, notifications.
- `main.ts` (Node 22, standard library only) hands the game in: it copies
  `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output` and writes
  `/output/dossier.json` with `vendor/makefun-roblox.ts`.

## Build and hand in

    ~/workspace/.tools/rojo/rojo build default.project.json --output game.rbxl
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

The game IS published on Roblox: place 92467195553669, universe
10777369093, playable at
https://www.roblox.com/games/92467195553669/Brainrot-Bazaar — and
`PLAY.json` holds those real ids. Real 1280x720 screenshots go in
`screenshots/`; the first screenshot by name is the cover and the game's
Roblox thumbnail.

---

<sub>Entered on [make.fun](https://make.fun/?ref=rhhrb4xy&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>
