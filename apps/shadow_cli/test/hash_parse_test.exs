defmodule ShadowClient.HashParseTest do
  use ExUnit.Case

  test "Parse Hash yescrypt" do
    r =
      ShadowCli.PasswordParse.parse(
        "$gy$j9T$W2Cj6u7yqrjUKD9Cbhi3I0$g4iyWjOZRbmKxEXh0BvFtZUXUPgCo0cy9d4gPIQmt5D"
      )

    assert %{algo: %{method: :gost_yescrypt, config: "$gy$j9T$W2Cj6u7yqrjUKD9Cbhi3I0"}} = r
  end

  test "Parse Hash gost-yescrypt" do
    r =
      ShadowCli.PasswordParse.parse(
        "$y$j9T$wi.UQKUsG0cTzYN/XoIXz1$IOtdTMHFbtJdfXrEXqjkZEme64ES2GL9pTNTd4cbrmB"
      )

    assert %{algo: %{method: :yescrypt, config: "$y$j9T$wi.UQKUsG0cTzYN/XoIXz1"}} = r
  end

  test "Parse Hash bcrypt a" do
    r =
      ShadowCli.PasswordParse.parse(
        "$2a$05$xKW7x2RfaBhzW7Eg5B6FMuNqxAorNMXpiLEhagjk3Fi8YYC7tJVNe"
      )

    assert %{algo: %{method: :bcrypt_a, config: "$2a$05$xKW7x2RfaBhzW7Eg5B6FMu"}} = r
  end

  test "Parse Hash bcrypt b" do
    r =
      ShadowCli.PasswordParse.parse(
        "$2b$05$R/zfFNqEn3vRM.dTUepsbeyZZOfRBrU7LOJDhx9ANuVhy1WkAwDPy"
      )

    assert %{algo: %{method: :bcrypt_b, config: "$2b$05$R/zfFNqEn3vRM.dTUepsbe"}} = r
  end

  test "Parse Hash sha512" do
    r =
      ShadowCli.PasswordParse.parse(
        "$6$RWBYzBG3gcPf1knH$tkZMJGB4/LPH09g2YODLI5w3JqFc7Qh9kw.5ZYLBHqqSupzdqXdDPhrAfBaHRQbv.jfcsCijuHB53g.7dYtVr0"
      )

    assert %{algo: %{method: :sha512, config: "$6$RWBYzBG3gcPf1knH"}} = r
  end

  test "Parse Hash sha256" do
    r =
      ShadowCli.PasswordParse.parse(
        "$5$zeDOAERRV2Omwn0x$UIeNQe1tm.LSBz3SJt7hOYfQj.6AToFEm5/JbKDtFiA"
      )

    assert %{algo: %{method: :sha256, config: "$5$zeDOAERRV2Omwn0x"}} = r
  end

  test "Parse Hash descrypt" do
    r = ShadowCli.PasswordParse.parse("QCGyw25v5w.yk")
    assert %{algo: %{method: :descrypt, config: "QC"}} = r
  end

  test "Parse Hash scrypt" do
    r =
      ShadowCli.PasswordParse.parse(
        "$7$CU..../....fYmOUQItcMPFnSFHh57MV.$nLiY/9444kA5rcp/E9IPWQnEEUOrM3WNuKmDE9Qz2B8"
      )

    assert %{algo: %{method: :scrypt, config: "$7$CU..../....fYmOUQItcMPFnSFHh57MV."}} = r
  end

  test "Parse Hash sunmd5" do
    r = ShadowCli.PasswordParse.parse("$md5,rounds=36912$KxfrRqqx$$LovNKd30ubFzeTvc2ZtfK1")
    assert %{algo: %{method: :sunmd5, config: "$md5,rounds=36912$KxfrRqqx$$"}} = r
  end

  test "Parse Hash md5crypt" do
    r = ShadowCli.PasswordParse.parse("$1$cobKo5Ks$RbB0fGCC2BvollDSnOS9p1")
    assert %{algo: %{method: :md5crypt, config: "$1$cobKo5Ks"}} = r
  end

  test "Parse Hash NT" do
    r = ShadowCli.PasswordParse.parse("$3$$8e98570c3a7511785726a13ffed5f8d5")
    assert %{algo: %{method: :nt, config: "$3$$"}} = r
  end
end
