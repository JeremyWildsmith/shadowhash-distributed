defmodule ShadowClient.Gpu.Strutil do
  import Nx.Defn
  import ShadowClient.Gpu.Constants

  def create_set(names) when is_list(names) do
    names
    |> Enum.map(fn n ->
      l = length(n)
      padding = max_str_size() - l - 1

      Enum.concat([length(n)], n)
      |> Nx.tensor(type: {:u, 8})
      |> Nx.pad(0, [{0, padding, 0}])
    end)
    |> Nx.stack()
    |> Nx.vectorize(:rows)
  end

  def create(name) do
    Nx.devectorize(create_set([name]))[0]
  end

  defn create_password_map(source, threshold) do
    max_password_length =
      source[0]
      |> Nx.devectorize(keep_names: false)
      |> Nx.reduce_max()

    [working, _] = Nx.broadcast_vectors([zero(), source])

    working = working |> Nx.as_type({:s, 32})

    {_, _, _, working} =
      while {x = 0, threshold, max_password_length, working}, Nx.less(x, max_password_length) do
        working =
          working
          |> Nx.indexed_put(
            Nx.reshape(x, {1}),
            threshold |> Nx.subtract(x)
          )

        {x + 1, threshold, max_password_length, working}
      end

    working |> Nx.max(0) |> Nx.min(1)
  end

  defn create_simple_map(threshold) do
    max_password_length =
      threshold
      |> Nx.devectorize(keep_names: false)
      |> Nx.reduce_max()

    [working, _] = Nx.broadcast_vectors([zero(), threshold])

    working = working |> Nx.as_type({:s, 32})

    {_, _, _, working} =
      while {x = 0, threshold, max_password_length, working}, Nx.less(x, max_password_length) do
        working =
          working
          |> Nx.indexed_put(
            Nx.reshape(x, {1}),
            threshold |> Nx.subtract(x)
          )

        {x + 1, threshold, max_password_length, working}
      end

    working |> Nx.max(0) |> Nx.min(1)
  end

  defn repeatedly(source, count) do
    [counter, _] = Nx.broadcast_vectors([counter(), source])

    m = create_password_map(source, count)
    zero = Nx.tensor([1]) |> Nx.subtract(m) |> Nx.multiply(max_str_size() - 1)

    index =
      counter
      |> Nx.remainder(source[0])
      |> Nx.add(1)
      |> Nx.multiply(m)
      |> Nx.add(zero)
      |> Nx.slice([0], [max_str_size() - 1])

    Nx.concatenate([count, Nx.take(source, index)])
  end

  defn concat(a, b) do
    a_len = a[0]

    b
    |> Nx.as_type({:u, 8})
    |> Nx.take(right_shift_vectors()[a_len])
    |> Nx.add(a)
  end
end
