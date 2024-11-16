defmodule ShadowClient.Shadow do
  require Logger
  alias ShadowClient.ErlexecBootstrap
  alias ShadowClient.Job.BruteforceClient
  alias ShadowClient.Gpu.Md5crypt
  alias ShadowClient.Gpu.Strutil
  alias ShadowData.Util

  def process(:help) do
    IO.puts("Shadow file password cracker client (job processing module.)")

    IO.puts("Usage is: mix shadow_client")

    IO.puts(" --data-node    : Name of the data node where the scheduler, job and result bank are available")
    IO.puts(" --cookie       : Security cookie to use when connecting to the data-node.")
    IO.puts(" --interface    : IP Address to advertise to register with as a node (IP Datanode can address you by)")
    IO.puts(" --verbose       : Print verbose logging")

    IO.puts(" --gpu           : Supported for md5crypt, will execute the hash algorithm")
    IO.puts("                   on the GPU. There is initial overhead to JIT compile to CUDA")
    IO.puts("                   but after JIT compiling, significantly faster.")
    IO.puts(" --gpu-warmup    : Warm-up GPU bruteforce algorithm. Useful when capturing")
    IO.puts("                   timing metrics and you don't want to include start-up overhead")
    IO.puts(" --workers <num> : Number of workers to process bruteforce requests. Defaults")

    IO.puts(
      "                   to number of available CPU cores. Be mindful of the memory constraint "
    )

    IO.puts("                   of GPU if using GPU acceleration")
    IO.puts(" --verbose       : Print verbose logging")
  end

  def process(%{
        workers: num_workers,
        verbose: verbose,
        gpu: gpu_acceleration,
        gpu_warmup: gpu_warmup,
        data_node: data_node,
        interface: interface,
        cookie: cookie
      }) do
    unless verbose do
      Logger.configure(level: :none)
    end

    connect_datanode(data_node, interface, cookie)

    ErlexecBootstrap.prepare_port()

    gpu_hashers = create_gpu_hashers(gpu_acceleration, gpu_warmup)

    non_worker = num_workers <= 0

    workers =
      unless non_worker do
        1..num_workers
        |> Enum.map(fn _ -> BruteforceClient.start_link(gpu_hashers) end)
      else
        IO.puts(
          " !!! WARNING: Started as non-worker. No workers on this node will be spawned to process bruteforce jobs."
        )

        []
      end

    if gpu_acceleration do
      IO.puts(" *** GPU Acceleration is enabled.")
    else
      IO.puts(" !!! GPU Acceleration is disabled.")
    end

    IO.puts(" *** Using #{num_workers} worker processes ")

    IO.puts("Clients have been started. To shutdown client, type exit")

    wait_workers(workers)

    # wait_exit_command()

    IO.puts("Terminating workers...")

    # for {:ok, w} <- workers, do: BruteforceClient.shutdown(w)
  end

  defp wait_workers([]), do: nil

  defp wait_workers(workers) do
    receive do
      {:DOWN, _, :process, pid, _reason} ->
        List.delete(workers, pid)
        |> wait_workers()
    end
  end

  defp connect_datanode(data_node, interface, cookie) do
    Util.connect_datanode("shadow_client", data_node, interface, cookie)
  end

  defp warmup_gpu(gpu_hasher) do
    passwords =
      Stream.duplicate(~c"wu", chunk_size(:md5crypt, true))
      |> Enum.to_list()
      |> Strutil.create_set()

    needle =
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      |> Nx.tensor(type: {:u, 8})

    salt =
      ~c"01234567"
      |> Strutil.create()

    gpu_hasher.(
      passwords,
      salt,
      needle
    )
  end

  defp create_gpu_hashers(enable_acceleration, warmup) do
    if enable_acceleration do
      md5crypt_jit = Nx.Defn.jit(&Md5crypt.md5crypt_find/3, compiler: EXLA)

      if warmup do
        IO.puts("Warming up GPU JIT compile.")
        warmup_gpu(md5crypt_jit)
        IO.puts("Warmup done.")
      end

      %{
        md5crypt: md5crypt_jit
      }
    else
      %{}
    end
  end

  def chunk_size(:md5crypt, gpu_accelerated) do
    if gpu_accelerated do
      11000
    else
      500
    end
  end

  def chunk_size(_algo, _gpu_accelerated) do
    500
  end
end
