defmodule ShadowClient.Job.BruteforceClient do
  require Logger

  alias ShadowData.WorkPool
  alias ShadowData.Scheduler
  alias ShadowData.DictionaryWorkUnit
  alias ShadowData.BruteforceWorkUnit
  alias ShadowData.PasswordGraph
  alias ShadowClient.Hash
  alias ShadowClient.Gpu.Strutil
  alias ShadowClient.ShadowBase64

  def start_link(gpu_hashers) do
    Logger.info("* Bruteforce Client Starting")

    :sleeplocks.new(1, name: :gpu_lock)

    {pid, _} = spawn_monitor(__MODULE__, :process, [gpu_hashers])

    pid
  end

  def process(gpu_hashers) do
    receive do
      :shutdown ->
        Logger.info("Bruteforce client shutting down per request.")
    after
      200 ->
        Logger.info("Enlisting from scheduler...")

        with work_pool when not is_nil(work_pool) <- Scheduler.enlist(self()) do
          Logger.info("Bruteforce client assigned to work_pool.")
          process_job(gpu_hashers, work_pool)
        end

        process(gpu_hashers)
    end
  end

  def shutdown(process) do
    send(process, :shutdown)
  end

  defp process_job(gpu_hashers, work_pool) do
    WorkPool.process(work_pool, fn algo, target, job ->
      handle_job(gpu_hashers, algo, target, job)
    end)
  end

  defp generate_hashes(stream, algo) do
    stream
    |> Stream.map(&{Hash.generate(algo, &1), &1})
  end

  defp crack(stream, algo, hash) do
    generate_hashes(stream, algo)
    |> Stream.filter(fn {cipher, _} -> cipher === hash end)
    |> Stream.map(fn {_, plain} -> plain end)
    |> Enum.take(1)
    |> List.first()
    |> case do
      nil -> nil
      plain -> {:ok, plain}
    end
  end

  defp handle_generic_cpu(_gpu_hashers, algo, target, %BruteforceWorkUnit{
         begin: start,
         last: last,
         charset: charset
       }) do

    start..last
    |> Stream.map(&PasswordGraph.from_index(&1, charset))
    |> crack(algo, target)
  end

  defp handle_md5crypt_gpu(gpu_hashers, %{config: config}, target, %BruteforceWorkUnit{
         begin: start,
         last: last,
         charset: charset
       }) do
    salt =
      config
      |> :binary.bin_to_list()
      |> Enum.drop(3)
      |> Strutil.create()

    passwords =
      start..last
      |> Stream.map(&(PasswordGraph.from_index(&1, charset) |> :binary.bin_to_list()))
      |> Enum.to_list()
      |> Strutil.create_set()

    needle =
      target
      |> :binary.bin_to_list()
      |> ShadowBase64.decode_b64_hash()
      |> Nx.tensor(type: {:u, 8})

    Logger.info("Tensor data constructed for GPU hashing. Waiting for lock...")
    Logger.info("Lock acquired. Applying GPU accelerated hashing")

    try do
      :sleeplocks.acquire(:gpu_lock)
      Map.get(gpu_hashers, :md5crypt).(
        passwords,
        salt,
        needle
      )
      |> Nx.to_number()
      |> case do
        -1 -> nil
        n -> {:ok, PasswordGraph.from_index(n + start, charset)}
      end
    rescue
      r ->
        Logger.error("GPU Hasher failed. Dumping information to IO.Inspect...")
        r |> IO.inspect()
    after
      Logger.info("Releasing GPU lock")
      :sleeplocks.release(:gpu_lock)
    end
  end

  defp handle_job(_gpu_hashers, algo, target, %DictionaryWorkUnit{names: names}) do
    names
    |> crack(algo, target)
  end

  defp handle_job(gpu_hashers, algo = %{method: :md5crypt}, target, %BruteforceWorkUnit{} = job) do
    unless Map.has_key?(gpu_hashers, :md5crypt) do
      Logger.info("No md5crypt GPU hasher loaded. Falling back to CPU hasher.")
      handle_generic_cpu(gpu_hashers, algo, target, job)
    else
      Logger.info("Md5crypt gpu hasher is available. Using GPU Hasher")
      handle_md5crypt_gpu(gpu_hashers, algo, target, job)
    end
  end

  defp handle_job(gpu_hashers, algo, target, %BruteforceWorkUnit{} = job) do
    handle_generic_cpu(gpu_hashers, algo, target, job)
  end
end
