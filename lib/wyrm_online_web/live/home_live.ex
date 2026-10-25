defmodule WyrmOnlineWeb.HomeLive do
  use WyrmOnlineWeb, :live_view

  alias WyrmOnline.Games

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "WyrmOnline")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="flex flex-col items-center m-4 text-center">
        <h1 class="mb-0">Start a game of WyrmOnline</h1>
        <p class="italic mb-0">No account needed!</p>
        <p class="italic mt-0">Games last up to 24 hours and are deleted when ended.</p>
        <div class="flex flex-col gap-2 w-fit items-center">
          <.button id="create-game" phx-click="create" text="Create game" />
        </div>
      </main>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("create", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/lobby/#{create_game()}")}
  end

  # Room ids are random names, so retry on the rare collision.
  defp create_game do
    case Games.create() do
      {:error, :conflict} -> create_game()
      id -> id
    end
  end
end
