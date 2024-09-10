defmodule DesafioCliTest do
  use ExUnit.Case
  doctest DesafioCli

  test "Parse unknown commands" do
    assert Commands.parse("TRY") == {:err, "No command TRY"}
    assert Commands.parse("SOMETHING") == {:err, "No command SOMETHING"}
    assert Commands.parse("ANOTHERCOMMAND") == {:err, "No command ANOTHERCOMMAND"}
  end

  test "Parse SET" do
    assert Commands.parse("Set key value") == {:ok, "SET", "key", "value"}
    assert Commands.parse("SET key value") == {:ok, "SET", "key", "value"}
    assert Commands.parse("Set \"key\" value") == {:ok, "SET", "key", "value"}
    assert Commands.parse("SET \"key\" value") == {:ok, "SET", "key", "value"}
  end
end
