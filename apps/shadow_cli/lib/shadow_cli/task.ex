defmodule Mix.Tasks.ShadowCli do
  def run(args) do
    #Mix.Task.run("app.start")
    ShadowCli.Cli.main(args)
  end
end
