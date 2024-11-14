defmodule ShadowServerTest do
  use ExUnit.Case
  doctest ShadowServer

  test "greets the world" do
    assert ShadowServer.hello() == :world
  end
end
