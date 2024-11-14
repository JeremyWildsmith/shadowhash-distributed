defmodule ShadowClientTest do
  use ExUnit.Case
  doctest ShadowClient

  test "greets the world" do
    assert ShadowClient.hello() == :world
  end
end
