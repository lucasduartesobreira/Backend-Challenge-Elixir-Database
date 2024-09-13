defmodule DatabaseTest do
  alias Database.DatabaseCommandResponse
  use ExUnit.Case
  doctest DesafioCli

  def get_first_transaction(%Database{transactions: transactions}) do
    List.last(transactions)
  end

  defp do_command(%Database{} = database, command) do
    Database.handle_command(command, database)
  end

  defp do_command(%DatabaseCommandResponse{database: database}, command) do
    do_command(database, command)
  end

  defp check_result(%DatabaseCommandResponse{result: result} = response, expected_result) do
    assert result == expected_result
    response
  end

  defp check_message(%DatabaseCommandResponse{message: message} = response, expected_message) do
    assert message == expected_message
    response
  end

  defp check_database(%DatabaseCommandResponse{database: database} = response, expected_database) do
    assert database == expected_database
    response
  end

  test "Set command" do
    database = Database.new()

    do_command(database, "SET some value")
    |> check_database(%Database{
      database_table: %{"some" => "value"},
      transactions: [%Transaction{log: %{"some" => nil}}]
    })
    |> check_message("FALSE value")
    |> check_result(:ok)
    |> do_command("SET another another")
    |> check_database(%Database{
      database_table: %{"another" => "another", "some" => "value"},
      transactions: [%Transaction{log: %{"some" => nil, "another" => nil}}]
    })
    |> check_message("FALSE another")
    |> check_result(:ok)
    |> do_command("SET some value2")
    |> check_database(%Database{
      database_table: %{"another" => "another", "some" => "value2"},
      transactions: [%Transaction{log: %{"some" => nil, "another" => nil}}]
    })
    |> check_message("TRUE value2")
    |> check_result(:ok)

    database_with_multi_transactions = %Database{
      transactions: [%Transaction{}, %Transaction{level: 1}]
    }

    database_with_multi_transactions
    |> do_command("SET some another_value")
    |> check_result(:ok)
    |> check_message("FALSE another_value")
    |> check_database(%Database{
      database_table: %{"some" => "another_value"},
      transactions: [
        %Transaction{},
        %Transaction{level: 1, log: %{"some" => nil}}
      ]
    })
    |> do_command("SET some another_another_value")
    |> check_result(:ok)
    |> check_message("TRUE another_another_value")
    |> check_database(%Database{
      database_table: %{"some" => "another_another_value"},
      transactions: [
        %Transaction{},
        %Transaction{level: 1, log: %{"some" => nil}}
      ]
    })
    |> do_command("SET another another")
    |> check_result(:ok)
    |> check_message("FALSE another")
    |> check_database(%Database{
      database_table: %{"some" => "another_another_value", "another" => "another"},
      transactions: [
        %Transaction{},
        %Transaction{level: 1, log: %{"some" => nil, "another" => nil}}
      ]
    })
  end

  test "Get command" do
    database = Database.new()

    database
    |> do_command("SET some value")
    |> do_command("GET some")
    |> check_database(%Database{
      database_table: %{"some" => "value"},
      transactions: [%Transaction{log: %{"some" => nil}}]
    })
    |> check_message("value")
    |> check_result(:ok)

    database_with_multi_transactions = %Database{
      database_table: %{"some" => "value", "another" => "another"},
      transactions: [
        %Transaction{log: %{"some" => nil, "another" => nil}},
        %Transaction{level: 1, log: %{"another" => "another_value"}}
      ]
    }

    database_with_multi_transactions
    |> do_command("GET some")
    |> check_result(:ok)
    |> check_database(database_with_multi_transactions)
    |> check_message("value")
    |> do_command("GET another")
    |> check_result(:ok)
    |> check_database(database_with_multi_transactions)
    |> check_message("another")
  end

  test "Begin command" do
    database = Database.new()

    database
    |> do_command("SET some value")
    |> do_command("BEGIn")
    |> check_database(%Database{
      database_table: %{"some" => "value"},
      transactions: [%Transaction{log: %{"some" => nil}}, %Transaction{level: 1, log: %{}}]
    })
    |> check_result(:ok)
    |> check_message("1")
    |> do_command("SET another another")
    |> do_command("SET some value2")
    |> do_command("BEGIN")
    |> check_database(%Database{
      database_table: %{"some" => "value2", "another" => "another"},
      transactions: [
        %Transaction{log: %{"some" => nil}},
        %Transaction{level: 1, log: %{"another" => nil, "some" => "value"}},
        %Transaction{level: 2}
      ]
    })
    |> check_result(:ok)
    |> check_message("2")
  end

  test "Rollback command" do
    database = Database.new()

    %DatabaseCommandResponse{database: database} =
      Database.handle_command(%Command{command: "SET", key: "some", value: "value"}, database)

    assert database == %Database{
             database_table: %{"some" => "value"},
             transactions: [%Transaction{log: %{"some" => nil}}]
           }

    result_first_begin = Database.handle_command(%Command{command: "BEGIN"}, database)

    assert result_first_begin ==
             %DatabaseCommandResponse{
               result: :ok,
               message: "1",
               database: %Database{
                 database_table: %{"some" => "value"},
                 transactions: database.transactions ++ [%Transaction{level: 1, log: %{}}]
               }
             }

    result_second_begin =
      Database.handle_command(%Command{command: "BEGIN"}, result_first_begin.database)

    assert result_second_begin == %DatabaseCommandResponse{
             result: :ok,
             message: "2",
             database: %Database{
               database_table: %{"some" => "value"},
               transactions:
                 result_first_begin.database.transactions ++ [%Transaction{level: 2, log: %{}}]
             }
           }

    result_first_rollback =
      Database.handle_command(%Command{command: "ROLLBACK"}, result_second_begin.database)

    assert result_first_rollback == %DatabaseCommandResponse{
             result: :ok,
             message: "1",
             database: result_first_begin.database
           }

    result_second_rollback =
      Database.handle_command(%Command{command: "ROLLBACK"}, result_first_rollback.database)

    assert result_second_rollback == %DatabaseCommandResponse{
             result: :ok,
             message: "0",
             database: database
           }

    result_third_rollback =
      Database.handle_command(%Command{command: "ROLLBACK"}, result_second_rollback.database)

    assert result_third_rollback == %DatabaseCommandResponse{
             result: :err,
             message: "You can't rollback a transaction without even starting one",
             database: database
           }
  end

  test "Commit command" do
    database = Database.new()

    %DatabaseCommandResponse{database: database} =
      Database.handle_command(%Command{command: "SET", key: "some", value: "value"}, database)

    assert database == %Database{
             database_table: %{"some" => "value"},
             transactions: [%Transaction{log: %{"some" => nil}}]
           }

    result_first_commit = Database.handle_command(%Command{command: "COMMIT"}, database)

    assert result_first_commit == %DatabaseCommandResponse{
             result: :ok,
             message: "0",
             database: database
           }

    %DatabaseCommandResponse{database: result_first_begin} =
      Database.handle_command(%Command{command: "BEGIN"}, database)

    %DatabaseCommandResponse{database: result_second_set} =
      Database.handle_command(
        %Command{command: "SET", key: "another", value: "value"},
        result_first_begin
      )

    %DatabaseCommandResponse{database: result_second_begin} =
      Database.handle_command(%Command{command: "BEGIN"}, result_second_set)

    %DatabaseCommandResponse{database: result_third_set} =
      Database.handle_command(
        %Command{command: "SET", key: "third", value: "third"},
        result_second_begin
      )

    result_second_commit =
      Database.handle_command(%Command{command: "COMMIT"}, result_third_set)

    assert result_second_commit == %DatabaseCommandResponse{
             result: :ok,
             message: "1",
             database: %Database{
               database_table: %{"some" => "value", "third" => "third", "another" => "value"},
               transactions: [
                 %Transaction{log: %{"some" => nil}},
                 %Transaction{level: 1, log: %{"another" => nil, "third" => nil}}
               ]
             }
           }

    result_third_commit =
      Database.handle_command(%Command{command: "COMMIT"}, result_second_commit.database)

    assert result_third_commit == %DatabaseCommandResponse{
             result: :ok,
             message: "0",
             database: %Database{
               database
               | database_table: %{"some" => "value", "third" => "third", "another" => "value"},
                 transactions: [
                   %Transaction{
                     log: %{"some" => nil, "another" => nil, "third" => nil}
                   }
                 ]
             }
           }
  end

  test "Start database" do
    database = Database.new()

    assert database ==
             %Database{transactions: [%Transaction{}]}
  end
end
