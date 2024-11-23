defmodule ShadowData.WorkUnitParser do
  alias ShadowData.DictionaryStreamWorkUnit
  alias ShadowData.DictionaryWorkUnit
  alias ShadowData.BruteforceWorkUnit

  @chunk_size 500

  defp skip_if_empty(nil, remaining, chunk_by), do: take_work(remaining, chunk_by)
  defp skip_if_empty({current, next}, remaining, _chunk_by), do: {current, [next] ++ remaining}

  def take_work(jobs, chunk_by \\ @chunk_size)
  def take_work([], _chunk_by), do: :empty
  def take_work([h | remaining], chunk_by), do: take_unit(h, chunk_by) |> skip_if_empty(remaining, chunk_by)

  defp take_unit(%DictionaryStreamWorkUnit{stream: stream, id: id}, chunk_by) do
    stream
    |> Stream.take(chunk_by)
    |> Enum.to_list()
    |> case do
      [] ->
        nil

      names ->
        {
          %DictionaryWorkUnit{names: names, id: id + 1},
          %DictionaryStreamWorkUnit{stream: stream |> Stream.drop(chunk_by), id: id + 2}
        }
    end
  end

  defp take_unit(%DictionaryWorkUnit{names: []}, _chunk_by) do
    nil
  end

  defp take_unit(%DictionaryWorkUnit{names: names, id: id}, chunk_by) do
    {
      %DictionaryWorkUnit{names: names |> Enum.take(chunk_by), id: id + 1},
      %DictionaryWorkUnit{names: names |> Enum.drop(chunk_by), id: id + 2}
    }
  end

  defp take_unit(%BruteforceWorkUnit{begin: begin, last: :inf, charset: charset, id: id}, chunk_by) do
    {
      %BruteforceWorkUnit{begin: begin, last: begin + chunk_by - 1, charset: charset, id: id + 1},
      %BruteforceWorkUnit{begin: begin + chunk_by, last: :inf, charset: charset, id: id + 2}
    }
  end

  defp take_unit(%BruteforceWorkUnit{begin: begin, last: last}, _chunk_by) when last < begin do
    nil
  end

  defp take_unit(%BruteforceWorkUnit{begin: begin, last: last, charset: charset, id: id}, chunk_by) do
    {
      %BruteforceWorkUnit{begin: begin, last: min(begin + chunk_by - 1, last), charset: charset, id: id + 1},
      %BruteforceWorkUnit{begin: begin + chunk_by, last: last, charset: charset, id: id + 2}
    }
  end
end
