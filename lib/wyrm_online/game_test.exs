defmodule WyrmOnline.GameTest do
  use ExUnit.Case, async: true

  alias WyrmOnline.Game

  test "the first player to join becomes the host" do
    {state, first} = Game.add_player(Game.new_game())
    {state, second} = Game.add_player(state)

    assert state.host_id == first
    assert Map.keys(state.players) |> Enum.sort() == Enum.sort([first, second])
  end

  test "players can be removed" do
    {state, id} = Game.add_player(Game.new_game())
    assert Game.remove_player(state, id).players == %{}
  end

  test "start marks the game as started" do
    refute Game.new_game().started
    assert Game.start(Game.new_game()).started
  end

  test "a rematch keeps the room, host and players but resets the game" do
    {state, host} = Game.add_player(%{Game.new_game() | room_id: "room"})
    {state, guest} = Game.add_player(state)
    state = %{Game.start(state) | deck: [%WyrmOnline.Card{value: 1, name: "The Fool"}]}

    rematch = Game.rematch(state)

    assert rematch.started
    assert rematch.deck == []
    assert rematch.room_id == "room"
    assert rematch.host_id == host
    assert Map.keys(rematch.players) |> Enum.sort() == Enum.sort([host, guest])
  end
end
