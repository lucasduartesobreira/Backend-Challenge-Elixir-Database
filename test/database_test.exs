defmodule DatabaseTest do
  alias Database.DatabaseCommandResponse
  use ExUnit.Case
  doctest DesafioCli

  def get_first_transaction(%Database{transactions: transactions}) do
    List.last(transactions)
  end

  test "Set command" do
    database = Database.new()

    %DatabaseCommandResponse{database: database_with_some} =
      Database.handle_command(%Command{command: "SET", key: "some", value: "value"}, database)

    %DatabaseCommandResponse{database: database_with_another} =
      Database.handle_command(
        %Command{command: "SET", key: "another", value: "another"},
        database
      )

    %DatabaseCommandResponse{database: database_with_some_and_another} =
      Database.handle_command(
        %Command{command: "SET", key: "another", value: "another"},
        database_with_some
      )

    %DatabaseCommandResponse{database: database_rewrite_some} =
      Database.handle_command(
        %Command{command: "SET", key: "some", value: "another_value"},
        database_with_some
      )

    assert database == Database.new()

    assert database_with_some ==
             %Database{transactions: [%Transaction{level: 0, log: %{"some" => "value"}}]}

    assert database_with_another ==
             %Database{transactions: [%Transaction{level: 0, log: %{"another" => "another"}}]}

    assert database_with_some_and_another ==
             %Database{
               transactions: [
                 %Transaction{level: 0, log: %{"another" => "another", "some" => "value"}}
               ]
             }

    assert database_rewrite_some == %Database{
             transactions: [%Transaction{level: 0, log: %{"some" => "another_value"}}]
           }
  end

  test "Get command" do
    database = Database.new()

    %DatabaseCommandResponse{database: database} =
      Database.handle_command(%Command{command: "SET", key: "some", value: "value"}, database)

    assert database == %Database{transactions: [%Transaction{log: %{"some" => "value"}}]}

    assert Database.handle_command(%Command{command: "GET", key: "some"}, database) ==
             %DatabaseCommandResponse{result: :ok, message: "value", database: database}
  end

  test "Start database" do
    database = Database.new()

    assert database ==
             %Database{transactions: [%Transaction{}]}
  end
end
