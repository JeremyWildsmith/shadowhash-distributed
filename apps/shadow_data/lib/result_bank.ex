defmodule ShadowData.ResultBank do
  use Agent

  defmodule Result do
    defstruct name: "", source: "", result: "", results_reported: 0, life_time: 0, elapsed: 0
  end

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: {:global, :result_bank})
  end

  def commit(%Result{name: name} = result) do
    Agent.update({:global, :result_bank}, fn map ->
      Map.update(map, name, result, fn _ -> result end)
    end)
  end

  def get_results() do
    Agent.get({:global, :result_bank}, fn m ->
      Map.values(m)
    end)
  end

  def drop(name) do
    Agent.update({:global, :job_bank}, fn map ->
      Map.delete(map, name)
    end)
  end

  def fetch(name) do
    Agent.get({:global, :result_bank}, fn m ->
      Map.get(m, name)
    end)
  end
end
