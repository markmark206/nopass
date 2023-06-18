defmodule NopassTest do
  use ExUnit.Case
  doctest Nopass

  test "greets the world" do
    assert Nopass.hello() == :world
  end
end
