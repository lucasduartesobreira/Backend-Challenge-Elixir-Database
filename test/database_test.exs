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

    database_with_multi_transactions = %Database{
      transactions: [%Transaction{}, %Transaction{level: 1}]
    }

    set_on_multi_transaction =
      Database.handle_command(
        %Command{command: "SET", key: "some", value: "another_value"},
        database_with_multi_transactions
      )

    assert set_on_multi_transaction == %DatabaseCommandResponse{
             result: :ok,
             message: "FALSE another_value",
             database: %Database{
               transactions: [
                 %Transaction{},
                 %Transaction{level: 1, log: %{"some" => "another_value"}}
               ]
             }
           }
  end

  test "Get command" do
    database = Database.new()

    %DatabaseCommandResponse{database: database} =
      Database.handle_command(%Command{command: "SET", key: "some", value: "value"}, database)

    assert database == %Database{transactions: [%Transaction{log: %{"some" => "value"}}]}

    assert Database.handle_command(%Command{command: "GET", key: "some"}, database) ==
             %DatabaseCommandResponse{result: :ok, message: "value", database: database}

    database_with_multi_transactions = %Database{
      transactions: [
        %Transaction{log: %{"some" => "value", "another" => "another_value"}},
        %Transaction{level: 1, log: %{"another" => "another"}}
      ]
    }

    get_on_multi_transactions =
      Database.handle_command(
        %Command{command: "GET", key: "some"},
        database_with_multi_transactions
      )

    assert get_on_multi_transactions == %DatabaseCommandResponse{
             result: :ok,
             database: database_with_multi_transactions,
             message: "value"
           }

    get_on_multi_transactions =
      Database.handle_command(
        %Command{command: "GET", key: "another"},
        database_with_multi_transactions
      )

    assert get_on_multi_transactions == %DatabaseCommandResponse{
             result: :ok,
             database: database_with_multi_transactions,
             message: "another"
           }
  end

  test "Begin command" do
    database = Database.new()

    %DatabaseCommandResponse{database: database} =
      Database.handle_command(%Command{command: "SET", key: "some", value: "value"}, database)

    assert database == %Database{transactions: [%Transaction{log: %{"some" => "value"}}]}

    result_first_begin = Database.handle_command(%Command{command: "BEGIN"}, database)

    assert result_first_begin ==
             %DatabaseCommandResponse{
               result: :ok,
               message: "1",
               database: %Database{
                 transactions: database.transactions ++ [%Transaction{level: 1, log: %{}}]
               }
             }

    result_second_begin =
      Database.handle_command(%Command{command: "BEGIN"}, result_first_begin.database)

    assert result_second_begin == %DatabaseCommandResponse{
             result: :ok,
             message: "2",
             database: %Database{
               transactions:
                 result_first_begin.database.transactions ++ [%Transaction{level: 2, log: %{}}]
             }
           }
  end

  test "Rollback command" do
    database = Database.new()

    %DatabaseCommandResponse{database: database} =
      Database.handle_command(%Command{command: "SET", key: "some", value: "value"}, database)

    assert database == %Database{transactions: [%Transaction{log: %{"some" => "value"}}]}

    result_first_begin = Database.handle_command(%Command{command: "BEGIN"}, database)

    assert result_first_begin ==
             %DatabaseCommandResponse{
               result: :ok,
               message: "1",
               database: %Database{
                 transactions: database.transactions ++ [%Transaction{level: 1, log: %{}}]
               }
             }

    result_second_begin =
      Database.handle_command(%Command{command: "BEGIN"}, result_first_begin.database)

    assert result_second_begin == %DatabaseCommandResponse{
             result: :ok,
             message: "2",
             database: %Database{
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

    assert database == %Database{transactions: [%Transaction{log: %{"some" => "value"}}]}

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
               transactions: [
                 %Transaction{log: %{"some" => "value"}},
                 %Transaction{level: 1, log: %{"another" => "value", "third" => "third"}}
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
               | transactions: [
                   %Transaction{
                     log: %{"some" => "value", "another" => "value", "third" => "third"}
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
