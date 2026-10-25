defmodule WyrmOnlineWeb.LobbyLive do
  use WyrmOnlineWeb, :live_view

  alias WyrmOnline.Game
  alias WyrmOnline.Games

  @max_players 5
  @min_players 2

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    socket =
      assign(socket,
        page_title: "WyrmOnline",
        room_id: id,
        state: Game.new_game(),
        revision: 0,
        player_id: nil,
        lobby_full: false
      )

    case Games.get(id) do
      {:ok, snapshot} ->
        socket = assign(socket, snapshot)

        if connected?(socket) do
          Games.subscribe(id)
          join(socket, snapshot, get_connect_params(socket)["player_id"])
        else
          {:ok, socket}
        end

      {:error, :not_found} ->
        {:ok, push_navigate(unavailable(socket), to: ~p"/")}
    end
  end

  # A returning player (id remembered by the browser) rejoins as themselves.
  defp join(socket, snapshot, stored_player_id) do
    cond do
      stored_player_id && snapshot.state.players[stored_player_id] ->
        socket = assign(socket, :player_id, stored_player_id)

        if snapshot.state.started,
          do: {:ok, push_navigate(socket, to: ~p"/games/#{socket.assigns.room_id}")},
          else: {:ok, socket}

      snapshot.state.started ->
        {:ok, push_navigate(unavailable(socket), to: ~p"/")}

      map_size(snapshot.state.players) >= @max_players ->
        {:ok, assign(socket, :lobby_full, true)}

      true ->
        add_player(socket, snapshot)
    end
  end

  # Another player may join between our read and our write, in which case the
  # publish is rejected as stale: reload the latest snapshot and try again.
  defp add_player(socket, snapshot) do
    {new_state, player_id} = Game.add_player(snapshot.state)

    case Games.publish(socket.assigns.room_id, snapshot.revision, new_state) do
      {:ok, updated} ->
        {:ok,
         socket
         |> assign(updated)
         |> assign(:player_id, player_id)
         |> push_event("store_player", %{room_id: socket.assigns.room_id, player_id: player_id})}

      {:error, :conflict} ->
        case Games.get(socket.assigns.room_id) do
          {:ok, latest} -> join(assign(socket, latest), latest, nil)
          {:error, :not_found} -> {:ok, push_navigate(unavailable(socket), to: ~p"/")}
        end

      {:error, _} ->
        {:ok, push_navigate(unavailable(socket), to: ~p"/")}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%= if @lobby_full do %>
        <main class="flex flex-col items-center gap-6 mt-12">
          <h1>This lobby is full, sorry!</h1>
          <.button id="go-home" phx-click="go_home" text="Back to home" />
        </main>
      <% else %>
        <main class="flex flex-col items-center gap-2 m-4">
          <h1 class="mb-0">Game Lobby</h1>
          <span>Invite players with this link:</span>
          <span id="invite-link" class="text-sm break-all text-center">
            {url(~p"/lobby/#{@room_id}")}
          </span>
          <div class="flex gap-2">
            <.button id="copy-link" class="w-fit gap-1" phx-click="copy_link" text="Copy Link" />
            <div
              id="share-link"
              phx-hook=".ShareLink"
              phx-update="ignore"
              data-url={url(~p"/lobby/#{@room_id}")}
              data-title="Join my WyrmOnline game!"
            >
            </div>
          </div>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".ShareLink">
            export default {
              mounted() {
                if (navigator.share) {
                  const btn = document.createElement("button")
                  btn.className = "h-8 rounded-sm bg-amber-500 text-amber-900 font-bold px-3 cursor-pointer text-lg [box-shadow:inset_0_2px_0_rgba(255,255,255,0.35),inset_0_-2px_0_rgba(0,0,0,0.15)] [text-shadow:0_-1px_0_rgba(0,0,0,0.3),0_1px_0_rgba(255,255,255,0.2)] active:translate-y-0.5 active:[box-shadow:inset_0_2px_0_rgba(255,255,255,0.35),inset_0_-2px_0_rgba(0,0,0,0.15)]"
                  btn.textContent = "Share"
                  btn.addEventListener("click", () => {
                    navigator.share({
                      title: this.el.dataset.title,
                      url: this.el.dataset.url
                    })
                  })
                  this.el.appendChild(btn)
                }
              }
            }
          </script>
          <p class="mb-0 font-bold">Players:</p>
          <div id="player-list" class="flex flex-col gap-2 ml-2 mb-4 mt-2">
            <span
              :for={{player_id, _player} <- @state.players}
              id={"player-#{player_id}"}
              class="flex gap-1 items-center"
            >
              <Heroicons.user aria-hidden="true" class="size-5" />
              {player_id}
            </span>
          </div>
          <%= cond do %>
            <% map_size(@state.players) < min_players() -> %>
              <span id="waiting" class="border border-gray-400 rounded px-3 py-1 text-gray-500">
                Waiting for players...
              </span>
            <% @state.host_id != @player_id -> %>
              <span id="waiting" class="border border-gray-400 rounded px-3 py-1 text-gray-500">
                Waiting for host to start...
              </span>
            <% true -> %>
              <.button id="start-game" phx-click="start_game" text="Start game">
                <Heroicons.arrow_right_circle aria-hidden="true" class="size-5" />
              </.button>
          <% end %>
        </main>
      <% end %>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("start_game", _, %{assigns: %{player_id: player_id, state: state}} = socket)
      when player_id == state.host_id and map_size(state.players) >= @min_players do
    case Games.publish(socket.assigns.room_id, socket.assigns.revision, Game.start(state)) do
      {:ok, _snapshot} ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{socket.assigns.room_id}")}

      {:error, :conflict} ->
        {:noreply, put_flash(socket, :error, "The lobby just changed, try again.")}

      {:error, _} ->
        {:noreply, push_navigate(unavailable(socket), to: ~p"/")}
    end
  end

  def handle_event("start_game", _, socket), do: {:noreply, socket}

  def handle_event("go_home", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("copy_link", _, socket) do
    {:noreply,
     socket
     |> push_event("clipboard", %{text: url(~p"/lobby/#{socket.assigns.room_id}")})
     |> put_flash(:info, "Link copied!")}
  end

  @impl Phoenix.LiveView
  def handle_info({:game_state, snapshot}, socket) do
    if snapshot.state.started do
      {:noreply, push_navigate(socket, to: ~p"/games/#{socket.assigns.room_id}")}
    else
      {:noreply, assign(socket, snapshot)}
    end
  end

  def handle_info(:game_ended, socket) do
    {:noreply, push_navigate(unavailable(socket), to: ~p"/")}
  end

  # Module attributes aren't available in templates (`@foo` reads assigns).
  defp min_players, do: @min_players

  defp unavailable(socket),
    do: put_flash(socket, :error, "This game has ended or expired. Create a new one above.")
end
