defmodule ShadowData.PasswordGraph do
  def generate_combinations(range \\ 255, anchor \\ 0, min_length \\ 1, max_length \\ 100) do
    min_length..max_length
    |> Stream.flat_map(fn len ->
      0..(range ** len - 1)
      |> Stream.map(fn index ->
        1..len
        |> Enum.map(fn char_offset ->
          rem(div(index, range ** (len - char_offset)), range) + anchor
        end)
      end)
      |> Enum.map(fn charlist -> "#{charlist}" end)
    end)
  end

  def from_index(index, mapping) do
    range = tuple_size(mapping)

    pwd =
      Stream.unfold(index, fn
        n when n < 0 -> nil
        n -> {elem(mapping, rem(n, range)), div(n, range) - 1}
      end)
      |> Enum.reverse()
      |> Enum.to_list()

    "#{pwd}"
  end
end
