defmodule ShadowClient.Gpu.Md5crypt do
  import Nx.Defn
  import ShadowClient.Gpu.Constants
  import ShadowClient.Gpu.Md5
  import ShadowClient.Gpu.Strutil

  defn create_a_tail(pwd_len, even_char) do
    calc_len =
      pwd_len
      |> Nx.log()
      |> Nx.divide(Nx.log(2))
      |> Nx.add(1)
      |> Nx.as_type({:s, 32})

    pow_counter = Nx.iota({150}) |> Nx.min(20)
    divisors = Nx.broadcast(Nx.tensor([2]), {150}) |> Nx.pow(pow_counter) |> Nx.as_type({:u, 32})

    tw =
      Nx.broadcast(pwd_len, {150})
      |> Nx.as_type({:u, 32})
      |> Nx.divide(divisors)
      |> Nx.as_type({:u, 32})
      |> Nx.remainder(2)

    map = create_simple_map(calc_len)

    encoded =
      Nx.tensor([1])
      |> Nx.subtract(tw)
      |> Nx.multiply(even_char)
      |> Nx.multiply(map)
      |> Nx.as_type({:u, 8})
      |> Nx.slice([0], [max_str_size() - 1])

    Nx.concatenate([calc_len, encoded])
  end

  defn create_next_da(i, current_da, passwords, salt) do
    [salt, _] = Nx.broadcast_vectors([salt, passwords])

    msg_a_choice = Nx.remainder(i, 2)
    msg_b_choice = Nx.remainder(i, 3) |> Nx.min(1)
    msg_c_choice = Nx.remainder(i, 7) |> Nx.min(1)
    msg_d_choice = Nx.remainder(i, 2)

    msg =
      Nx.add(
        msg_a_choice |> Nx.multiply(passwords),
        1 |> Nx.subtract(msg_a_choice) |> Nx.multiply(current_da)
      )

    msg_b_eval = concat(msg, salt)

    msg =
      Nx.add(
        msg_b_choice |> Nx.multiply(msg_b_eval),
        1 |> Nx.subtract(msg_b_choice) |> Nx.multiply(msg)
      )

    msg_c_eval = concat(msg, passwords)

    msg =
      Nx.add(
        msg_c_choice |> Nx.multiply(msg_c_eval),
        1 |> Nx.subtract(msg_c_choice) |> Nx.multiply(msg)
      )

    msg_d_eval_a = concat(msg, current_da)
    msg_d_eval_b = concat(msg, passwords)

    msg =
      Nx.add(
        msg_d_choice |> Nx.multiply(msg_d_eval_a),
        1 |> Nx.subtract(msg_d_choice) |> Nx.multiply(msg_d_eval_b)
      )

    msg
    |> build_m32b()
    |> calc_md5_as_string()
  end

  defn md5crypt(passwords, salt) do
    [salt, magic, _] = Nx.broadcast_vectors([salt, str_magic(), passwords])

    db =
      passwords
      |> concat(salt)
      |> concat(passwords)
      |> build_m32b()
      |> calc_md5_as_string()

    a_message =
      passwords
      |> concat(magic)
      |> concat(salt)
      |> concat(repeatedly(db, passwords[0]))
      |> concat(create_a_tail(passwords[0], passwords[1]))

    da =
      a_message
      |> build_m32b()
      |> calc_md5_as_string()

    {_, _, _, r} =
      while {x = 0, passwords, salt, da}, Nx.less(x, 1000) do
        da = create_next_da(x, da, passwords, salt)
        {x + 1, passwords, salt, da}
      end

    r |> Nx.slice([1], [16])
  end

  defn md5crypt_find(passwords, salt, search) do
    w =
      md5crypt(passwords, salt)
      |> Nx.subtract(search)
      |> Nx.any()

    r =
      Nx.subtract(1, w)
      |> Nx.devectorize()
      |> Nx.multiply(2)

    Nx.concatenate([Nx.tensor([1]), r])
    |> Nx.argmax()
    |> Nx.subtract(1)
  end
end
