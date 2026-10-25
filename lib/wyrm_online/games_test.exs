defmodule WyrmOnline.GamesTest do
  use ExUnit.Case, async: true

  alias WyrmOnline.Game
  alias WyrmOnline.Games

  setup do
    id = Games.create()
    on_exit(fn -> Games.finish(id) end)
    %{id: id}
  end

  test "new rooms start with an empty, unstarted game", %{id: id} do
    assert {:ok, %{revision: 0, state: state}} = Games.get(id)
    assert state == %{Game.new_game() | room_id: id}
  end

  test "broadcasts state and retains it for late joiners", %{id: id} do
    Games.subscribe(id)
    {:ok, %{state: state}} = Games.get(id)
    {state, player_id} = Game.add_player(state)

    assert {:ok, %{revision: 1}} = Games.publish(id, 0, state)
    assert_receive {:game_state, %{revision: 1, state: %{host_id: ^player_id}}}
    assert {:ok, %{revision: 1, state: %{players: %{^player_id => _}}}} = Games.get(id)
  end

  test "rejects stale writes without changing state", %{id: id} do
    {:ok, %{state: state}} = Games.get(id)
    assert {:ok, _} = Games.publish(id, 0, Game.start(state))
    assert {:error, :conflict} = Games.publish(id, 0, state)
    assert {:ok, %{revision: 1, state: %{started: true}}} = Games.get(id)
  end

  test "isolates rooms and deletes ended state", %{id: id} do
    other = Games.create()
    on_exit(fn -> Games.finish(other) end)
    Games.subscribe(id)
    {:ok, %{state: state}} = Games.get(other)
    Games.publish(other, 0, Game.start(state))
    refute_receive {:game_state, _}
    Games.finish(id)
    assert_receive :game_ended
    assert {:error, :not_found} = Games.get(id)
    assert {:error, :not_found} = Games.publish(id, 0, state)
    assert {:ok, _} = Games.get(other)
  end

  test "expiry deletes state and tells subscribers", %{id: id} do
    Games.subscribe(id)
    send(Games, {:expire, id})
    assert {:error, :not_found} = Games.get(id)
    assert_receive :game_ended
  end
end
