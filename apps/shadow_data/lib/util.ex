defmodule ShadowData.Util do
  def unique_name(name \\ "") do
    guid =
      "#{:erlang.ref_to_list(:erlang.make_ref())}"
      |> String.split_at(5)
      |> elem(1)
      |> String.split(~r">")
      |> List.first()
      |> String.split(~r"\.")
      |> Enum.join("")
      |> String.to_integer()
      |> Integer.to_string(36)

    "#{name}_#{guid}"
  end
end
