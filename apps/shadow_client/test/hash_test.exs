defmodule ShadowClient.HashTest do
  use ExUnit.Case
  alias ShadowClient.ErlexecBootstrap
  alias ShadowClient.Hash

  test "Hash gost-yescrypt" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :gost_yescrypt, config: "$gy$j9T$W2Cj6u7yqrjUKD9Cbhi3I0"}

    assert Hash.generate(algo, "tp") == "g4iyWjOZRbmKxEXh0BvFtZUXUPgCo0cy9d4gPIQmt5D"
  end

  test "Hash yescrypt" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :yescrypt, config: "$y$j9T$wi.UQKUsG0cTzYN/XoIXz1"}

    assert Hash.generate(algo, "tp") == "IOtdTMHFbtJdfXrEXqjkZEme64ES2GL9pTNTd4cbrmB"
  end

  test "Hash bcrypt a" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :bcrypt_a, config: "$2a$05$xKW7x2RfaBhzW7Eg5B6FMu"}

    assert Hash.generate(algo, "tp") == "NqxAorNMXpiLEhagjk3Fi8YYC7tJVNe"
  end

  test "Hash bcrypt b" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :bcrypt_b, config: "$2b$05$R/zfFNqEn3vRM.dTUepsbe"}

    assert Hash.generate(algo, "tp") == "yZZOfRBrU7LOJDhx9ANuVhy1WkAwDPy"
  end

  test "Hash sha512" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :sha512, config: "$6$RWBYzBG3gcPf1knH"}

    assert Hash.generate(algo, "tp") ==
             "tkZMJGB4/LPH09g2YODLI5w3JqFc7Qh9kw.5ZYLBHqqSupzdqXdDPhrAfBaHRQbv.jfcsCijuHB53g.7dYtVr0"
  end

  test "Hash sha256" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :sha256, config: "$5$zeDOAERRV2Omwn0x"}

    assert Hash.generate(algo, "tp") == "UIeNQe1tm.LSBz3SJt7hOYfQj.6AToFEm5/JbKDtFiA"
  end

  test "Hash descrypt" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :descrypt, config: "QC"}

    assert Hash.generate(algo, "tp") == "Gyw25v5w.yk"
  end

  test "Hash scrypt" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :scrypt, config: "$7$CU..../....fYmOUQItcMPFnSFHh57MV."}

    assert Hash.generate(algo, "tp") == "nLiY/9444kA5rcp/E9IPWQnEEUOrM3WNuKmDE9Qz2B8"
  end

  test "Hash sunmd5" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :sunmd5, config: "$md5,rounds=36912$KxfrRqqx$$"}

    assert Hash.generate(algo, "tp") == "LovNKd30ubFzeTvc2ZtfK1"
  end

  test "Hash md5crypt" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :md5crypt, config: "$1$cobKo5Ks"}

    assert Hash.generate(algo, "tp") == "RbB0fGCC2BvollDSnOS9p1"
  end

  test "Hash NT" do
    ErlexecBootstrap.prepare_port()
    algo = %{method: :nt, config: "$3$$"}

    assert Hash.generate(algo, "tp") == "8e98570c3a7511785726a13ffed5f8d5"
  end
end
