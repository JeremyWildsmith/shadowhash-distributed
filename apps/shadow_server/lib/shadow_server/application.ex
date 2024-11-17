defmodule ShadowServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    chunk_size = System.get_env("WORKPOOL_CHUNK_SIZE", "1500") |> String.to_integer()

    IO.puts("Worker chunk size is configured to #{chunk_size}; can be adjusted by setting the WORKPOOL_CHUNK_SIZE variable.")

    children = [
      # Starts a worker by calling: ShadowServer.Worker.start_link(arg)
      # {ShadowServer.Worker, arg}
      {DynamicSupervisor, name: ShadowData.Scheduler.WorkPoolSupervisor, strategy: :one_for_one},
      {ShadowData.JobBank, []},
      {ShadowData.Scheduler, [chunk_size]},
      {ShadowData.ResultBank, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShadowServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
