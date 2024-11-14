defmodule ShadowClient.Hash do
  @passwod_timeout 10000

  defp _generate(method, salt, pwd) do
    {:ok, pd, ospid} =
      :exec.run("mkpasswd -S '#{salt}' --method=#{method} --stdin", [:stdin, {:stdout, self()}])

    :exec.send(pd, pwd)
    :exec.send(pd, :eof)

    receive do
      {:stdout, ^ospid, result} -> String.trim(result)
      _ -> raise "Error processing password output"
    after
      @passwod_timeout ->
        raise "Timeout processing password."
    end
  end

  def generate(algo = %{method: :bcrypt_b}, data),
    do:
      _generate("bcrypt", algo.config, data)
      |> String.split("$")
      |> Enum.drop(3)
      |> List.first()
      |> String.split_at(22)
      |> elem(1)

  def generate(algo = %{method: :bcrypt_a}, data),
    do:
      _generate("bcrypt-a", algo.config, data)
      |> String.split("$")
      |> Enum.drop(3)
      |> List.first()
      |> String.split_at(22)
      |> elem(1)

  def generate(algo = %{method: :yescrypt}, data),
    do:
      _generate("yescrypt", algo.config, data)
      |> String.split("$")
      |> Enum.drop(4)
      |> List.first()

  def generate(algo = %{method: :gost_yescrypt}, data),
    do:
      _generate("gost-yescrypt", algo.config, data)
      |> String.split("$")
      |> Enum.drop(4)
      |> List.first()

  def generate(algo = %{method: :sha512}, data),
    do:
      _generate("sha512crypt", algo.config, data)
      |> String.split("$")
      |> Enum.drop(3)
      |> List.first()

  def generate(algo = %{method: :sha256}, data),
    do:
      _generate("sha512crypt", algo.config, data)
      |> String.split("$")
      |> Enum.drop(3)
      |> List.first()

  def generate(algo = %{method: :descrypt}, data),
    do:
      _generate("descrypt", algo.config, data)
      |> String.split_at(2)
      |> elem(1)

  def generate(algo = %{method: :scrypt}, data),
    do:
      _generate("scrypt", algo.config, data)
      |> String.split("$")
      |> Enum.drop(3)
      |> List.first()

  def generate(algo = %{method: :sunmd5}, data),
    do:
      _generate("sunmd5", algo.config, data)
      |> String.split("$")
      |> Enum.drop(4)
      |> List.first()

  def generate(algo = %{method: :md5crypt}, data),
    do:
      _generate("md5crypt", algo.config, data)
      |> String.split("$")
      |> Enum.drop(3)
      |> List.first()

  def generate(algo = %{method: :nt}, data),
    do:
      _generate("nt", algo.config, data)
      |> String.split("$")
      |> Enum.drop(3)
      |> List.first()
end
