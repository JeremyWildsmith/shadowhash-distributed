defmodule ShadowClient.ErlexecBootstrap do
  @exec_port_binary_path Application.app_dir(:erlexec, [
                           "priv",
                           :erlang.system_info(:system_architecture),
                           "exec-port"
                         ])

  @execport_binary File.read!(@exec_port_binary_path)

  def prepare_port() do
    port_exe_path =
      "./"
      |> Path.join("shadow_hash.exec-port")
      |> String.to_charlist()

    unless File.exists?(port_exe_path) do
      File.write!(port_exe_path, @execport_binary)
      File.chmod!(port_exe_path, 0o700)
    end

    :exec.start(portexe: port_exe_path)
  end
end
