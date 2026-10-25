defmodule WyrmOnlineWeb.GameLiveTest do
  use WyrmOnlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias WyrmOnline.Games

  setup do
    id = Games.create()
    on_exit(fn -> Games.finish(id) end)
    %{id: id}
  end

  defp connect_as(conn, player_id), do: put_connect_params(conn, %{"player_id" => player_id})

  defp join_lobby(conn, id) do
    {:ok, view, _} = conn |> connect_as(nil) |> live(~p"/lobby/#{id}")
    {:ok, %{state: %{players: players}}} = Games.get(id)
    {view, players |> Map.keys() |> List.last()}
  end

  test "creates a room from the home page", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/")
    view |> element("#create-game") |> render_click()
    {path, _} = assert_redirect(view)
    assert "/lobby/" <> id = path
    Games.finish(id)
  end

  test "missing games redirect home", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/lobby/missing")
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/games/missing")
  end

  test "players join the lobby and the host starts the game", %{conn: conn, id: id} do
    {host, host_id} = join_lobby(conn, id)
    assert has_element?(host, "#waiting")
    refute has_element?(host, "#start-game")

    {guest, guest_id} = join_lobby(build_conn(), id)
    assert has_element?(host, "#player-#{guest_id}")
    assert has_element?(guest, "#player-#{host_id}")
    assert has_element?(guest, "#waiting")
    assert has_element?(host, "#start-game")

    host |> element("#start-game") |> render_click()
    assert_redirect(host, ~p"/games/#{id}")
    assert_redirect(guest, ~p"/games/#{id}")
  end

  test "a returning player keeps their identity", %{conn: conn, id: id} do
    {_view, player_id} = join_lobby(conn, id)
    {:ok, _view, _} = build_conn() |> connect_as(player_id) |> live(~p"/lobby/#{id}")
    assert {:ok, %{state: %{players: players}}} = Games.get(id)
    assert map_size(players) == 1
  end

  test "lobbies cap the number of players", %{conn: conn, id: id} do
    for _ <- 1..5, do: join_lobby(build_conn(), id)
    {:ok, view, _} = conn |> connect_as(nil) |> live(~p"/lobby/#{id}")
    assert has_element?(view, "#go-home")
  end

  test "players see the game and ending it sends everyone home", %{conn: conn, id: id} do
    {host, host_id} = join_lobby(conn, id)
    {_guest, guest_id} = join_lobby(build_conn(), id)
    host |> element("#start-game") |> render_click()

    {:ok, game, _} = build_conn() |> connect_as(host_id) |> live(~p"/games/#{id}")
    {:ok, other, _} = build_conn() |> connect_as(guest_id) |> live(~p"/games/#{id}")
    assert has_element?(game, "#player-#{host_id}")
    assert has_element?(game, "#deck-count")

    game |> element("#end-game") |> render_click()
    assert_redirect(game, "/")
    assert_redirect(other, "/")
    assert {:error, :not_found} = Games.get(id)
  end

  test "a rematch publishes a fresh started state to every player", %{conn: conn, id: id} do
    {host, host_id} = join_lobby(conn, id)
    join_lobby(build_conn(), id)
    host |> element("#start-game") |> render_click()
    {:ok, game, _} = build_conn() |> connect_as(host_id) |> live(~p"/games/#{id}")
    assert {:ok, %{revision: 3}} = Games.get(id)

    game |> element("#rematch") |> render_click()

    assert {:ok, %{revision: 4, state: %{started: true, players: players}}} = Games.get(id)
    assert map_size(players) == 2
  end

  test "strangers cannot enter a running game", %{conn: conn, id: id} do
    {host, _} = join_lobby(conn, id)
    join_lobby(build_conn(), id)
    host |> element("#start-game") |> render_click()

    assert {:error, {:live_redirect, %{to: "/"}}} =
             build_conn() |> connect_as("Nobody") |> live(~p"/games/#{id}")
  end
end
