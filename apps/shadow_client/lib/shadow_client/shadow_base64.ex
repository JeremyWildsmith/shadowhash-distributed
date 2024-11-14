defmodule ShadowClient.ShadowBase64 do
  @moduledoc """
  Linux shadow file uses a custom variation of Base64 encoding for storing hashes.
  This module includes functions to decode the custom Base64 encoding.
  """

  @ito_index_lookup {
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    0,
    0,
    0,
    0,
    0,
    0,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    62,
    63
  }

  @detranspose_map {12, 6, 0, 13, 7, 1, 14, 8, 2, 15, 9, 3, 5, 10, 4, 11}

  defp decode_b64_hash_pair(p) do
    r =
      p
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        Bitwise.bsl(elem(@ito_index_lookup, v - 46), 6 * i)
      end)
      |> Enum.reduce(0, fn e, acc -> Bitwise.bor(e, acc) end)

    [
      r |> Bitwise.band(0xFF),
      r |> Bitwise.bsr(8) |> Bitwise.band(0xFF),
      r |> Bitwise.bsr(16) |> Bitwise.band(0xFF)
    ]
  end

  def decode_b64_hash(h) do
    h
    |> Enum.chunk_every(4)
    |> Enum.map(fn chunk ->
      chunk |> decode_b64_hash_pair
    end)
    |> List.flatten()
    |> Enum.take(16)
    |> Enum.with_index()
    |> Enum.sort(fn {_, i}, {_, i2} ->
      elem(@detranspose_map, i) < elem(@detranspose_map, i2)
    end)
    |> Enum.map(fn {v, _} -> v end)
  end
end
