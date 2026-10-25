# WyrmOnline

Skeleton for a multiplayer card game: Phoenix 1.8 / LiveView 1.2 over Phoenix
sockets, Tailwind CSS 4, no database, authentication or Node install. It handles
creating a game, a shareable lobby, joining players and starting the game. The
game itself is yours to build.

## Run

Use the Elixir/Erlang versions in `.tool-versions`, then:

```sh
mix setup
mix phx.server
```

Open http://localhost:4000, create a game, and open its lobby link in another
window. With two players in the lobby the host can start the game.

For phones and tablets on your network, change the HTTP IP in `config/dev.exs` to
`{0, 0, 0, 0}` and open `http://YOUR_COMPUTER_LAN_IP:4000`.

## Layout

- `lib/wyrm_online/game.ex`: pure functions over the game state map
  (`new_game/0`, `start/1`, `add_player/1`, `remove_player/2`). The state holds
  only `players`, `deck`, `started`, `room_id` and `host_id`. Deal the deck in
  `start/1`.
- `lib/wyrm_online/card.ex`, `player.ex`: placeholder structs to extend.
- `lib/wyrm_online/games.ex`: supervised in-memory room store. `create/0`,
  `get/1`, `publish/3`, `finish/1`, `subscribe/1`. `publish/3` takes the revision
  the new state was built from and returns `{:error, :conflict}` if someone else
  moved first. Each accepted state is broadcast on the `game:<room_id>` PubSub
  topic as `{:game_state, snapshot}`.
- `lib/wyrm_online_web/live/`: `HomeLive` (create), `LobbyLive` (join, start),
  `GameLive` (placeholder table showing players and deck size, plus End game).
- `assets/js/player_store.js`: remembers each room's player id in `localStorage`
  so a refresh rejoins as the same player.

Rooms expire 24 hours after creation, are deleted when a game is ended, and are
lost on restart. This is a single-node design; running several instances needs
shared room storage first. Anyone with the invite link can join, until the game
starts or the lobby holds 5 players.

## Checks

```sh
mix precommit
mix assets.deploy
```

Elixir tests live next to their modules under `lib/`; shared test support is in
`test/support`. See `DEPLOY.md` for Google Cloud Run deployment.
