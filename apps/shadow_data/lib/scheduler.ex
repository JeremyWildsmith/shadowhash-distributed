defmodule ShadowData.Scheduler do
  require Logger
  alias ShadowData.WorkPool
  alias ShadowData.JobBank
  use GenServer

  @max_concurrent 4
  @worker_timeout 90

  def start_link(chunk_size) do
    GenServer.start_link(__MODULE__, chunk_size, name: {:global, :scheduler})
  end

  # Genserver impl
  def init([chunk_size | _]) do
    Process.send_after(self(), :poll_for_job, 0)
    Process.send_after(self(), :heartbeat, 5000)

    {:ok, %{
      work_pools: %{},
      heartbeat: %{},
      chunk_size: chunk_size
    }}
  end

  defp start_workpool(%{chunk_size: chunk_size} = current, %ShadowData.Job{name: name} = job) do
    case map_size(current) do
      y when y >= @max_concurrent ->
        current

      _ ->
        IO.puts("Starting workpool for #{name}")

        {:ok, pid} =
          DynamicSupervisor.start_child(
            ShadowData.Scheduler.WorkPoolSupervisor,
            {ShadowData.WorkPool, [chunk_size, job]}
          )

        put_in(current, [:work_pools, name], pid)
    end
  end

  def handle_info(:heartbeat, %{heartbeat: heartbeat} = state) do
    Process.send_after(self(), :heartbeat, 5000)

    next_heartbeat =
      heartbeat
      |> Enum.filter(fn {_, v} -> System.os_time(:second) - v < @worker_timeout end)
      |> Map.new()

    {:noreply, Map.put(state, :heartbeat, next_heartbeat)}
  end

  def handle_info(:poll_for_job, %{work_pools: work_pools} = state) do
    Process.send_after(self(), :poll_for_job, 1000)

    state =
      case JobBank.get_job(Map.keys(work_pools)) do
        nil -> state
        next -> start_workpool(state, next)
      end

    {:noreply, state}
  end

  defp prioritize_workpools(work_pools) do
    work_pools
    |> Enum.sort_by(fn e -> WorkPool.poll_active_workers(e) |> Enum.count() end)
  end

  defp get_workers(work_pools, heartbeat_workers) do
    work_pools
    |> Enum.map(fn e -> WorkPool.poll_active_workers(e) end)
    |> List.flatten()
    |> Enum.concat(heartbeat_workers)
    |> Enum.uniq()
    |> Enum.group_by(fn v -> node(v) end)
    |> Enum.filter(fn {k, _} -> k in Node.list() end)
    |> Map.new()
  end

  defp truncate_clients(all_workers, limit) when map_size(all_workers) <= limit do
    map_size(all_workers)
  end

  defp truncate_clients(all_workers, limit) when map_size(all_workers) > limit do
    k = all_workers |> Map.keys() |> hd()

    for c <- Map.get(all_workers, k) do
      IO.puts("Removing...")
      send(c, :empty)
      send(c, :shutdown)
    end

    truncate_clients(all_workers |> Map.delete(k), limit)
  end

  def handle_call({:enlist, worker}, _from, %{work_pools: work_pools} = state) do

    state.heartbeat
    {
      :reply,
      work_pools
      |> Map.values()
      |> prioritize_workpools
      |> Stream.filter(fn work_pool ->
        WorkPool.accept(work_pool, worker) == :accepted
      end)
      |> Enum.take(1)
      |> List.first(),
      put_in(state, [:heartbeat, worker], System.os_time(:second))
    }
  end

  def handle_call({:truncate_clients, limit}, _from, %{work_pools: work_pools, heartbeat: heartbeat} = state) do
    {
      :reply,
      work_pools
      |> Map.values()
      |> get_workers(Map.keys(heartbeat))
      |> truncate_clients(limit),
      state
    }
  end

  def handle_call(:list_active, _from, %{work_pools: work_pools} = state) do
    active =
      work_pools
      |> Enum.map(fn {k, v} -> {k, WorkPool.poll_active_workers(v) |> Enum.count()} end)
      |> Map.new()

    {:reply, active, state}
  end

  # def handle_cast({:submit_job, workpool_pid}, current_jobs),
  #  do: {:noreply, current_jobs ++ [workpool_pid]}

  def handle_cast({:shutdown, job_name}, %{work_pools: work_pools} = state) do
    with pid when not is_nil(pid) <- Map.get(work_pools, job_name),
         do: DynamicSupervisor.terminate_child(ShadowData.Scheduler.WorkPoolSupervisor, pid)

    {:noreply, Map.put(state, :work_pools, Map.delete(work_pools, job_name))}
  end

  # def submit_job(workpool_pid) do
  #  GenServer.cast(__MODULE__, {:submit_job, workpool_pid})
  # end

  def shutdown_job(job_name) do
    GenServer.cast({:global, :scheduler}, {:shutdown, job_name})
  end

  def enlist(worker) do
    GenServer.call({:global, :scheduler}, {:enlist, worker})
  end

  def list_active() do
    GenServer.call({:global, :scheduler}, :list_active)
  end

  def truncate_clients(limit) do
    GenServer.call({:global, :scheduler}, {:truncate_clients, limit})
  end
end
