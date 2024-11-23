defmodule ShadowData.Job do
  defstruct name: "",
            algo: %{},
            target: "",
            current_work: [],
            life_time: 0,
            results_reported: 0,
            elapsed: 0
end

defmodule ShadowData.JobUpdate do
  defstruct name: "", current_work: [], life_time: 0, results_reported: 0, elapsed: 0

  def apply(job, %ShadowData.JobUpdate{
        current_work: current_work,
        life_time: life_time,
        results_reported: results_reported,
        elapsed: elapsed
      }) do
    job
    |> Map.put(:current_work, current_work)
    |> Map.put(:life_time, life_time)
    |> Map.put(:results_reported, results_reported)
    |> Map.put(:elapsed, elapsed)
  end
end
