defmodule ShadowHash.GpuTest do
  use ExUnit.Case
  import ShadowClient.Gpu.Md5
  import ShadowClient.Gpu.Strutil
  import ShadowClient.Gpu.Md5crypt
  import ShadowClient.ShadowBase64

  test "GPU MD5 Test" do
    md5_jit = Nx.Defn.jit(&calc_md5_as_string/1)

    result =
      [
        ~c"hello",
        ~c"world"
      ]
      |> create_set()
      |> build_m32b
      |> md5_jit.()
      |> Nx.to_list()
      |> Enum.map(fn e -> e |> Enum.take(17) end)

    expected = [
      [16, 93, 65, 64, 42, 188, 75, 42, 118, 185, 113, 157, 145, 16, 23, 197, 146],
      [16, 125, 121, 48, 55, 160, 118, 1, 134, 87, 75, 2, 130, 242, 244, 53, 231]
    ]

    assert result == expected
  end

  @tag timeout: :infinity
  test "GPU MD5Crypt" do
    md5crypt_jit = Nx.Defn.jit(&md5crypt/2)

    r =
      [
        ~c"test"
      ]
      |> create_set()
      |> md5crypt_jit.(create(~c"01234567"))
      |> Nx.to_list()

    expected = [[205, 221, 26, 54, 89, 226, 178, 89, 195, 165, 225, 197, 144, 19, 212, 232]]

    assert r == expected
  end

  test "Decode Custom Base64 Test" do
    r =
      ~c"RbB0fGCC2BvollDSnOS9p1"
      |> decode_b64_hash()

    assert r == [8, 56, 211, 120, 45, 179, 217, 228, 179, 252, 230, 245, 221, 171, 68, 113]
  end
end
