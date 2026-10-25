defmodule WyrmOnlineWeb.GameLive do
  use WyrmOnlineWeb, :live_view

  alias WyrmOnline.Game
  alias WyrmOnline.Games

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    case Games.get(id) do
      {:ok, snapshot} ->
        socket =
          assign(
            socket,
            Map.merge(snapshot, %{
              page_title: "WyrmOnline",
              room_id: id,
              player_id: nil,
              player: nil
            })
          )

        if connected?(socket) do
          Games.subscribe(id)
          player_id = get_connect_params(socket)["player_id"]

          # Only players who joined through the lobby may watch or play.
          cond do
            !(player_id && snapshot.state.players[player_id]) ->
              {:ok, push_navigate(unavailable(socket), to: ~p"/")}

            !snapshot.state.started ->
              {:ok, push_navigate(socket, to: ~p"/lobby/#{id}")}

            true ->
              {:ok,
               assign(socket, player_id: player_id, player: snapshot.state.players[player_id])}
          end
        else
          {:ok, socket}
        end

      {:error, :not_found} ->
        {:ok, push_navigate(unavailable(socket), to: ~p"/")}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%= if is_nil(@player) do %>
        <div class="flex items-center justify-center mt-12 text-lg">Loading game...</div>
      <% else %>
        <main class="flex flex-col items-center gap-4 m-4">
          <h1 class="mb-0">WyrmOnline</h1>
          <p id="deck-count" class="mt-0">Deck: {length(@state.deck)} cards</p>
          <div id="players" class="flex flex-col gap-2">
            <span
              :for={{id, _player} <- @state.players}
              id={"player-#{id}"}
              class={["flex gap-1 items-center", id == @player_id && "font-bold"]}
            >
              <Heroicons.user aria-hidden="true" class="size-5" />
              {id}{if id == @player_id, do: " (you)"}
            </span>
          </div>
          <%!-- Render the table, hands and controls here. --%>
          <div class="flex gap-4">
            <.button id="rematch" phx-click="rematch" text="Rematch" />
            <.button id="end-game" phx-click="end_game" text="End game" />
          </div>
        </main>
      <% end %>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("end_game", _, socket) do
    Games.finish(socket.assigns.room_id)
    {:noreply, socket}
  end

  def handle_event("rematch", _, socket) do
    {:noreply, publish_or_apply(socket, Game.rematch(socket.assigns.state))}
  end

  # Every move goes through here: build a new state from `socket.assigns.state`
  # and publish it against the revision it was built from. Our own copy updates
  # when the `{:game_state, snapshot}` broadcast arrives. A `:conflict` means
  # another player moved first, so the move must be rebuilt from the latest state.
  defp publish_or_apply(socket, new_state) do
    case Games.publish(socket.assigns.room_id, socket.assigns.revision, new_state) do
      {:ok, _snapshot} -> socket
      {:error, :conflict} -> put_flash(socket, :error, "Another player moved first, try again.")
      {:error, _} -> push_navigate(unavailable(socket), to: ~p"/")
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:game_state, snapshot}, socket) do
    player = socket.assigns.player_id && snapshot.state.players[socket.assigns.player_id]
    {:noreply, socket |> assign(snapshot) |> assign(:player, player)}
  end

  def handle_info(:game_ended, socket) do
    {:noreply, push_navigate(unavailable(socket), to: ~p"/")}
  end

  defp unavailable(socket),
    do: put_flash(socket, :error, "This game has ended or expired. Create a new one above.")
end
