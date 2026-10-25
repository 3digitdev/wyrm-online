defmodule WyrmOnline.Card do
  @enforce_keys [:value]
  defstruct [:value, :suit, :name]

  @type t :: %__MODULE__{
          value: non_neg_integer(),
          suit: :swords | :wands | :cups | :pentacles | nil,
          name: String.t()
        }
end
