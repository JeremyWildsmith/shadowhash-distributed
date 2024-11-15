defmodule ShadowClient.Cli do

  alias ShadowClient.Shadow

  # Entry point for escripts
  def main(argv) do
    parse_args(argv)
    |> Shadow.process()
  end

  def parse_args(argv),
    do:
      argv
      |> Enum.map(fn e -> e |> String.replace("–", "-") end) #In-case pasting from document.
      |> OptionParser.parse(
        strict: [
          workers: :integer,
          verbose: :boolean,
          gpu: :boolean,
          gpu_warmup: :boolean,
          data_node: :string,
          interface: :string,
          cookie: :string
        ]
      )
      |> _parse_args

  defp _parse_args({optional, [], []}) do
    for(
      {k, v} <- optional,
      into: %{},
      do: {k, v}
    )
    |> Map.put_new(:workers, :erlang.system_info(:logical_processors_available))
    |> Map.put_new(:verbose, false)
    |> Map.put_new(:gpu, false)
    |> Map.put_new(:gpu_warmup, false)
    |> Map.put_new(:data_node, "shadow_data@127.0.0.1")
    |> Map.put_new(:interface, "127.0.0.1")
    |> Map.put_new(:cookie, nil)
  end

  defp _parse_args(_args) do
    :help
  end
end
