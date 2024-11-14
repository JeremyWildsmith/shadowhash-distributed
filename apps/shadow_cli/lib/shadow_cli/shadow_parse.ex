defmodule ShadowCli.ShadowParse do
  def extract_passwords(source, username) do
    for [_, user, pwd] <- Regex.scan(~r/^\s*([^:]+):([^:]+)/m, source),
        user == username or username == "*",
        do: {
          user,
          pwd
        }
  end
end
