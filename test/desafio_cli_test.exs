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
    assert Commands.parse("Set \"key\" value") == {:ok, "SET", "\"key\"", "value"}
    assert Commands.parse("SET \"key\" value") == {:ok, "SET", "\"key\"", "value"}
  end

  test "Parse string" do
    assert ParseArgs.next_token("\"teste\" \"algo depois\"") ==
             {:ok, "\"teste\"", "\"algo depois\"", :string}

    assert ParseArgs.next_token("teste") == {:ok, "teste", "", :string}
    assert ParseArgs.next_token("teste value") == {:ok, "teste", "value", :string}
  end

  test "Parse number" do
    assert ParseArgs.next_token("123") == {:ok, "123", "", :number}
    assert ParseArgs.next_token("123456") == {:ok, "123456", "", :number}
    assert ParseArgs.next_token("123abc") == {:ok, "123abc", "", :string}
    assert ParseArgs.next_token("1a2b3c") == {:ok, "1a2b3c", "", :string}
  end

  test "Parse boolean" do
    assert ParseArgs.next_token("TRUE") == {:ok, "TRUE", "", :boolean}
    assert ParseArgs.next_token("FALSE") == {:ok, "FALSE", "", :boolean}
    assert ParseArgs.next_token("\"TRUE\"") == {:ok, "\"TRUE\"", "", :string}
    assert ParseArgs.next_token("\"FALSE\"") == {:ok, "\"FALSE\"", "", :string}
    assert ParseArgs.next_token("true") == {:ok, "true", "", :string}
    assert ParseArgs.next_token("false") == {:ok, "false", "", :string}
  end
end
