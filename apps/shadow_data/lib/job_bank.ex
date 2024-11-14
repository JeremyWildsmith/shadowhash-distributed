defmodule ShadowData.JobBank do
  use Agent

  alias ShadowData.Job
  alias ShadowData.JobUpdate

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: {:global, :job_bank})
  end

  def commit(%Job{name: name} = job) do
    Agent.update({:global, :job_bank}, fn map ->
      Map.update(map, name, job, fn _ -> job end)
    end)
  end

  def commit(%JobUpdate{name: name} = job_update) do
    Agent.update({:global, :job_bank}, fn map ->
      Map.update!(map, name, fn current ->
        JobUpdate.apply(current, job_update)
      end)
    end)
  end

  def list_jobs() do
    Agent.get({:global, :job_bank}, fn m ->
      Map.values(m)
    end)
  end

  def get_job(except) do
    Agent.get({:global, :job_bank}, fn m ->
      m
      |> Enum.filter(fn {k, %{disabled: disabled}} -> k not in except and not disabled end)
      |> Enum.map(fn {_, v} -> v end)
      |> List.first()
    end)
  end

  defp set_disabled(name, is_disabled) do
    Agent.update({:global, :job_bank}, fn map ->
      Map.get_and_update(map, name, fn current_job ->
        case current_job do
          j when not is_nil(j) -> {
            j,
            %{j | disabled: is_disabled}
          }
          _ -> :pop
        end
      end)
    end)
  end

  def disable(name), do: set_disabled(name, true)
  def enable(name), do: set_disabled(name, false)

  def drop(name) do
    Agent.update({:global, :job_bank}, fn map ->
      Map.delete(map, name)
    end)
  end
end
