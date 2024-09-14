defmodule Transaction do
  defstruct level: 0, log: %{}
end

defmodule Database do
  defstruct [:database_file, database_table: %{}, transactions: [%Transaction{}]]

  defmodule DatabaseCommandResponse do
    @enforce_keys [:result, :message, :database]
    defstruct [:result, :message, :database]
  end

  defp handle_command_internal(
         %Command{} = command,
         %Database{} = database
       ) do
    case command do
      %Command{command: "SET", key: key, value: value} when key != nil and value != nil ->
        handle_set(key, value, database)

      %Command{command: "GET", key: key} when key != nil ->
        handle_get(key, database)

      %Command{command: "BEGIN", key: nil, value: nil} ->
        handle_begin(database)

      %Command{command: "ROLLBACK", key: nil, value: nil} ->
        handle_rollback(database)

      %Command{command: "COMMIT", key: nil, value: nil} ->
        handle_commit(database)

      _ ->
        %DatabaseCommandResponse{
          result: :err,
          database: database,
          message: "Can't understand this command. Commands available are: 
          - SET <key> <value>
          - GET <key>
          - BEGIN
          - ROLLBACK
          - COMMIT"
        }
    end
  end

  def handle_command(command, %Database{} = database) do
    parsed_command = Commands.parse(command)

    case parsed_command do
      {:ok, command} -> handle_command_internal(command, database)
      {:err, err} -> %DatabaseCommandResponse{result: :err, message: err, database: database}
    end
  end

  defp handle_set(
         key,
         value,
         %Database{database_table: db_table, transactions: transactions} = database
       ) do
    {%Transaction{log: log} = trasaction, remaining_transactions} =
      List.pop_at(transactions, -1, %Transaction{})

    message = if(Map.has_key?(db_table, key), do: "TRUE", else: "FALSE") <> " #{value}"

    transaction_rollback_value = Map.get(db_table, key)

    updated_transaction = %Transaction{
      trasaction
      | log: Map.put_new(log, key, transaction_rollback_value)
    }

    updated_database = %Database{
      database
      | database_table: Map.put(db_table, key, value),
        transactions: remaining_transactions ++ [updated_transaction]
    }

    %DatabaseCommandResponse{result: :ok, message: message, database: updated_database}
  end

  defp handle_get(key, %Database{database_table: database_table} = database) do
    message =
      case Map.get(database_table, key) do
        nil ->
          "NIL"

        result ->
          result
      end

    %DatabaseCommandResponse{result: :ok, message: message, database: database}
  end

  defp handle_begin(%Database{transactions: transactions} = database) do
    new_level = length(transactions)
    updated_transactions = List.insert_at(transactions, -1, %Transaction{level: new_level})
    updated_database = %Database{database | transactions: updated_transactions}

    %DatabaseCommandResponse{result: :ok, message: "#{new_level}", database: updated_database}
  end

  defp handle_rollback(
         %Database{database_table: database_table, transactions: transactions} = database
       ) do
    {poped_transaction, updated_transactions} = List.pop_at(transactions, -1)

    case poped_transaction do
      nil ->
        exit("what the fuck just happend, where are the transactions???")

      %Transaction{level: 0} ->
        %DatabaseCommandResponse{
          result: :err,
          message: "You can't rollback a transaction without even starting one",
          database: database
        }

      %Transaction{} ->
        database_restored_table = Map.merge(database_table, poped_transaction.log)

        %DatabaseCommandResponse{
          result: :ok,
          message: "#{poped_transaction.level - 1}",
          database: %Database{
            database
            | database_table: database_restored_table,
              transactions: updated_transactions
          }
        }

      _ ->
        exit("should never get to this point")
    end
  end

  defp handle_commit(%Database{transactions: transactions} = database) do
    {transaction, l} = List.pop_at(transactions, -1)
    commit_to = List.last(l, transaction)

    case {transaction, commit_to} do
      {nil, _} ->
        exit("Wtf again")

      {%Transaction{level: 0}, %Transaction{level: 0}} ->
        %DatabaseCommandResponse{result: :ok, message: "0", database: database}

      {%Transaction{log: log1}, %Transaction{level: level, log: log0}} ->
        new_commit_to_transaction_log = Map.merge(log1, log0)

        updated_transactions =
          List.replace_at(l, -1, %Transaction{level: level, log: new_commit_to_transaction_log})

        %DatabaseCommandResponse{
          result: :ok,
          message: "#{level}",
          database: %Database{database | transactions: updated_transactions}
        }
    end
  end

  def new() do
    %Database{}
  end
end
