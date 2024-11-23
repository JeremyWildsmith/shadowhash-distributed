defmodule ShadowData.WorkPool do
  use GenServer, restart: :transient

  require Logger

  alias ShadowData.JobBank
  alias ShadowData.WorkUnitParser
  alias ShadowData.Scheduler
  alias ShadowData.ResultBank
  alias ShadowData.ResultBank.Result

  @worker_timeout 90
  @task_life 90000
  @commit_interval 3000
  @work_pool_response_timeout 1000

  # , current_jobs, target, algo, chunk_size}) do
  def start_link([
        chunk_size,
        %ShadowData.Job{
          name: name,
          current_work: current_work,
          target: target,
          algo: algo,
          life_time: life_time,
          results_reported: results_reported,
          elapsed: elapsed
        }
      ]) do
    GenServer.start_link(__MODULE__, %{
      name: name,
      current_work: current_work,
      target: target,
      algo: algo,
      chunk_size: chunk_size,
      heartbeat: %{},
      task_life: %{},
      tasks: %{},
      life_time: life_time,
      results_reported: results_reported,
      initial_elapsed: elapsed,
      start_time: System.os_time(:microsecond)
    })
  end

  def init(state) do
    Process.flag(:trap_exit, true)

    Process.send_after(self(), :heartbeat, 5000)
    Process.send_after(self(), :commit, @commit_interval)
    {:ok, state}
  end

  def terminate(_reason, state) do
    commit(state)

    :normal
  end

  defp take_new_work(
         %{current_work: current_work, chunk_size: chunk_size} =
           state,
         sender
       ) do
    current_work
    |> WorkUnitParser.take_work(chunk_size)
    |> case do
      {current, next} ->
        {
          current,
          state
          |> Map.put(:current_work, next)
          |> put_in([:heartbeat, sender], System.os_time(:second))
        }

      :empty ->
        :empty
    end
  end

  defp take_work(%{task_life: task_life, tasks: tasks} = current_state, sender) do
    task_life
    |> Enum.filter(fn {_, life} -> System.os_time(:second) - life > @task_life end)
    |> List.first()
    |> case do
      {job_id, _} ->
        {
          Map.get(tasks, job_id),
          put_in(current_state, [:task_life, job_id], System.os_time(:second))
          |> put_in([:heartbeat, sender], System.os_time(:second))
        }

      nil ->
        take_new_work(current_state, sender)
    end
  end

  defp done_job(current_state, job_id, time_cost) do
    current_state
    |> Map.update!(:life_time, fn t -> t + time_cost end)
    |> Map.update!(:results_reported, fn t -> t + 1 end)
    |> Map.put(:task_life, Map.delete(current_state.task_life, job_id))
    |> Map.put(:tasks, Map.delete(current_state.tasks, job_id))
  end

  def commit(%{
        tasks: tasks,
        current_work: current_work,
        name: name,
        life_time: life_time,
        results_reported: results_reported,
        initial_elapsed: elapsed,
        start_time: start_time
      }) do
    if current_work == [] do
      JobBank.drop(name)
    else
      JobBank.commit(%ShadowData.JobUpdate{
        name: name,
        current_work: Map.values(tasks) ++ current_work,
        life_time: life_time,
        results_reported: results_reported,
        elapsed: elapsed + (System.os_time(:microsecond) - start_time)
      })
    end
  end

  def handle_info(:commit, state) do
    Process.send_after(self(), :commit, @commit_interval)
    commit(state)

    {:noreply, state}
  end

  def handle_info(:heartbeat, state) do
    Process.send_after(self(), :heartbeat, 5000)

    next_heartbeat =
      state.heartbeat
      |> Enum.filter(fn {_, v} -> System.os_time(:second) - v < @worker_timeout end)
      |> Map.new()

    {:noreply, Map.put(state, :heartbeat, next_heartbeat)}
  end

  def handle_info({:ready, sender}, state) do
    Logger.info("Receieved ready, dispatching a job.")

    case take_work(state, sender) do
      {work_unit, next_state} ->
        send(sender, {
          :work,
          state.algo,
          state.target,
          work_unit
        })

        {
          :noreply,
          next_state
        }

      :empty ->
        send(sender, :empty)
        {:noreply, state}
    end
  end

  def handle_cast(
        {:ok, ciphertext, plain},
        %{
          name: name,
          life_time: life_time,
          results_reported: results_reported,
          start_time: start_time,
          initial_elapsed: elapsed
        } = state
      ) do
    if ciphertext == state.target do
      IO.puts("Post result to result bank: #{state.name} = #{plain}")

      ResultBank.commit(%Result{
        name: name,
        source: ciphertext,
        result: plain,
        life_time: life_time,
        results_reported: results_reported,
        elapsed: elapsed + (System.os_time(:microsecond) - start_time)
      })

      Scheduler.shutdown_job(name)

      {
        :noreply,
        state
        |> Map.put(:current_work, [])
      }
    else
      {:noreply, state}
    end
  end

  def handle_cast({:done, job_id, time_cost}, state) do
    # IO.puts("Done job. Remove from task alive and tasks list")

    {:noreply, done_job(state, job_id, time_cost)}
  end

  def handle_call(:poll_active_workers, _senders, state) do
    {:reply, Map.keys(state.heartbeat), state}
  end

  def handle_call({:accept, worker}, _sender, state) do
    {
      :reply,
      :accepted,
      put_in(state, [:heartbeat, worker], System.os_time(:second))
    }
  end

  def process(work_pool, handler) do
    Logger.info("Letting work_pool know I am ready.")

    send(work_pool, {:ready, self()})

    receive do
      {:work, algo, target, job} ->
        Logger.info("Received a job. Processing the job.")

        {elapsed, result} = :timer.tc(handler, [algo, target, job])

        GenServer.cast(work_pool, {:done, job.id, elapsed})

        with {:ok, plaintext} <- result do
          GenServer.cast(work_pool, {:ok, target, plaintext})
        end

        Logger.info("Done assigned job.")
        process(work_pool, handler)

      :empty ->
        :empty
    after
      @work_pool_response_timeout ->
        :empty
    end
  end

  def poll_active_workers(work_pool) do
    GenServer.call(work_pool, :poll_active_workers)
  end

  def accept(work_pool, worker) do
    GenServer.call(work_pool, {:accept, worker})
  end
end
