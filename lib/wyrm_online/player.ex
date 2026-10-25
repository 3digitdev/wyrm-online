defmodule WyrmOnline.Player do
  @moduledoc """
  A player in a game. Add per-player state (hand, score, ...) as struct fields.
  """

  @enforce_keys [:id]
  defstruct [:id]

  @type t :: %__MODULE__{id: String.t()}

  @spec new() :: t()
  def new() do
    %__MODULE__{
      id: UniqueNamesGenerator.generate([:adjectives, :names], %{style: :capital, separator: ""})
    }
  end
end
