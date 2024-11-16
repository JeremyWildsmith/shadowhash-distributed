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

  def connect_datanode(name_hint, data_node, interface, cookie) do
    IO.puts("Connecting to datanode (#{data_node})")

    unless Node.alive?() do
      Node.start(String.to_atom("#{ShadowData.Util.unique_name(name_hint)}@#{interface}"))
    end

    if cookie !== nil, do: Node.set_cookie(String.to_atom(cookie))

    data_node_name = String.to_atom(data_node)

    r = Node.connect(data_node_name)

    if r !== true do
      IO.puts("Could not connect to data node...")
      exit(0)
    end

    :global.sync()
  end
end
