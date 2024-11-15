defmodule ShadowCli.Cli do
  alias ShadowCli.Shadow

  # Entry point for escripts
  def main(argv) do
    parse_args(argv)
    |> Shadow.process()
  end

  def parse_args(argv),
    do:
      argv
      # In-case pasting from document.
      |> Enum.map(fn e -> e |> String.replace("–", "-") end)
      |> OptionParser.parse(
        strict: [
          data_node: :string,
          password: :string,
          user: :string,
          all_chars: :boolean,
          verbose: :boolean,
          dictionary: :string,
          workers: :integer,
          show_all: :boolean,
          interface: :string,
          cookie: :string,
          get_results: :boolean
        ]
      )
      |> _parse_args

  defp _parse_args({[], ["submit", shadow], []}),
    do: _parse_args({%{}, ["submit", shadow], []})

  defp _parse_args({[{:password, _} | _] = opt, ["submit"], []}) do
    _parse_args({opt, ["submit", nil], []})
  end

  defp _parse_args({optional, ["submit", shadow], []}) do
    cfg =
      for(
        {k, v} <- optional,
        into: %{shadow: shadow},
        do: {k, v}
      )
      |> Map.put_new(:dictionary, nil)
      |> Map.put_new(:all_chars, false)
      |> Map.put_new(:verbose, false)
      |> Map.put_new(:user, "*")
      |> Map.put_new(:password, nil)
      |> Map.put_new(:workers, :infinity)
      |> Map.put_new(:data_node, "shadow_data@127.0.0.1")
      |> Map.put_new(:interface, "127.0.0.1")
      |> Map.put_new(:get_results, false)
      |> Map.put_new(:cookie, nil)

    {:submit, cfg}
  end

  defp _parse_args({optional, ["status" | _], []}) do
    cfg =
      for(
        {k, v} <- optional,
        into: %{},
        do: {k, v}
      )
      |> Map.put_new(:data_node, "shadow_data@127.0.0.1")
      |> Map.put_new(:show_all, false)
      |> Map.put_new(:interface, "127.0.0.1")
      |> Map.put_new(:cookie, nil)

    {:status, cfg}
  end

  defp _parse_args({optional, ["truncate-clients", limit | _], []}) do
    cfg =
      for(
        {k, v} <- optional,
        into: %{
          limit: String.to_integer(limit)
        },
        do: {k, v}
      )
      |> Map.put_new(:data_node, "shadow_data@127.0.0.1")
      |> Map.put_new(:interface, "127.0.0.1")
      |> Map.put_new(:cookie, nil)

    {:trunc_clients, cfg}
  end

  defp _parse_args(_args) do
    _args |> IO.inspect()
    exit(0)
    {:help}
  end
end
