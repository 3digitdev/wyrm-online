defmodule WyrmOnline.Game do
  @moduledoc """
  Pure functions over the game state map. `WyrmOnline.Games` stores the state
  in a room and broadcasts every revision; nothing here touches processes.
  """

  alias WyrmOnline.Card
  alias WyrmOnline.Player

  # A room: the game state plus the bookkeeping `WyrmOnline.Games` needs to
  # serialize writes (revision) and expire it (expires_at, timer).
  @enforce_keys [:revision, :expires_at, :timer, :state]
  defstruct [:revision, :expires_at, :timer, :state]

  @type state() :: %{
          players: %{String.t() => Player.t()},
          started: boolean(),
          room_id: String.t() | nil,
          host_id: String.t() | nil,
          player_deck: [Card.t()],
          gm_deck: [Card.t()],
          mode: :crawl | :challenge | :camp | :city
        }

  @type t :: %__MODULE__{
          revision: non_neg_integer(),
          expires_at: integer(),
          timer: reference(),
          state: state()
        }

  @spec new_game() :: state()
  def new_game() do
    %{
      deck: [],
      players: %{},
      started: false,
      room_id: nil,
      host_id: nil
    }
  end

  @doc """
  Moves the lobby into play. Build the deck, shuffle it and deal to
  `state.players` here.
  """
  @spec start(state()) :: state()
  def start(state) do
    %{state | started: true}
  end

  @doc """
  A fresh game for the same room and the same players, already started.
  """
  @spec rematch(state()) :: state()
  def rematch(state) do
    players = Map.new(state.players, fn {id, _player} -> {id, %Player{id: id}} end)

    %{new_game() | room_id: state.room_id, host_id: state.host_id, players: players}
    |> start()
  end

  @spec add_player(state()) :: {state(), String.t()}
  def add_player(state) do
    player = Player.new()
    # The first player to join is the host
    state = if state.players == %{}, do: %{state | host_id: player.id}, else: state
    {%{state | players: Map.put(state.players, player.id, player)}, player.id}
  end

  @spec remove_player(state(), String.t()) :: state()
  def remove_player(state, player_id) do
    %{state | players: Map.delete(state.players, player_id)}
  end
end
