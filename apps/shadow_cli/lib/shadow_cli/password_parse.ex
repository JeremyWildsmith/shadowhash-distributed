defmodule ShadowCli.PasswordParse do
  alias ShadowData.HashAlgorithm

  def parse(line),
    do:
      String.split(line, "$")
      |> _parse

  # Descrypt
  defp _parse_descrypt(salthash) do
    {salt, hash} = String.split_at(salthash, 2)

    %{
      algo: %HashAlgorithm{
        method: :descrypt,
        config: salt
      },
      hash: hash
    }
  end

  # yescrypt
  defp _parse(["", "y", params, salt, hash]) do
    %{
      algo: %HashAlgorithm{
        method: :yescrypt,
        config: "$y$#{params}$#{salt}"
      },
      hash: hash
    }
  end

  defp _parse(["", "gy", params, salt, hash]) do
    %{
      algo: %HashAlgorithm{
        method: :gost_yescrypt,
        config: "$gy$#{params}$#{salt}"
      },
      hash: hash
    }
  end

  # Bcrypt
  defp _parse(["", "2b", cost, salthash]) do
    {salt, hash} = String.split_at(salthash, 22)

    %{
      algo: %HashAlgorithm{
        method: :bcrypt_b,
        config: "$2b$#{cost}$#{salt}"
      },
      hash: hash
    }
  end

  # Bcrypt
  defp _parse(["", "2a", cost, salthash]) do
    {salt, hash} = String.split_at(salthash, 22)

    %{
      algo: %HashAlgorithm{
        method: :bcrypt_a,
        config: "$2a$#{cost}$#{salt}"
      },
      hash: hash
    }
  end

  defp _parse(["", "6", salt, hash]) do
    %{
      algo: %HashAlgorithm{
        method: :sha512,
        config: "$6$#{salt}"
      },
      hash: hash
    }
  end

  defp _parse(["", "5", salt, hash]) do
    %{
      algo: %HashAlgorithm{
        method: :sha256,
        config: "$5$#{salt}"
      },
      hash: hash
    }
  end

  defp _parse(["", "7", salt, hash]) do
    %{
      algo: %HashAlgorithm{
        method: :scrypt,
        config: "$7$#{salt}"
      },
      hash: hash
    }
  end

  defp _parse(["", "3", "", hash]) do
    %{
      algo: %HashAlgorithm{
        method: :nt,
        config: "$3$$"
      },
      hash: hash
    }
  end

  # PUT NT HERE

  defp _parse(["", "1", salt, hash]) do
    %{
      algo: %HashAlgorithm{
        method: :md5crypt,
        config: "$1$#{salt}"
      },
      hash: hash
    }
  end

  defp _parse(["", mt, salt, opt, hash]) do
    %{
      algo: %HashAlgorithm{
        method: :sunmd5,
        config: "$#{mt}$#{salt}$#{opt}$"
      },
      hash: hash
    }
  end

  defp _parse([salthash]) do
    case String.length(salthash) do
      13 -> _parse_descrypt(salthash)
      _ -> raise("Unknown hash type.")
    end
  end

  defp _parse(unk), do: raise("Unknown password type. #{unk}")
end
