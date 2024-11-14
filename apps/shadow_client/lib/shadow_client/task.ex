defmodule Mix.Tasks.ShadowClient do
  def run(args) do
    Mix.Task.run("app.start")
    ShadowClient.Cli.main(args)
  end

end
