defmodule Transaction do
  defstruct level: 0, log: %{}
end

# defmodule Database do
# end

defmodule Database do
  defstruct [:database_file, transactions: [%Transaction{}]]

  defmodule DatabaseCommandResponse do
    @enforce_keys [:result, :message, :database]
    defstruct [:result, :message, :database]
  end

  defmodule RollbackError do
    defexception message: "Can't rollback on level 0"
  end

  def handle_command(
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
        {:err, database}
    end
  end

  def handle_set(key, value, %Database{transactions: transactions} = database) do
    {%Transaction{level: level, log: log}, remaining_transactions} =
      List.pop_at(transactions, -1, %Transaction{})

    message = if(Map.has_key?(log, key), do: "TRUE", else: "FALSE") <> " #{value}"

    updated_transaction = %Transaction{level: level, log: Map.put(log, key, value)}

    updated_database = %Database{
      transactions: remaining_transactions ++ [updated_transaction]
    }

    %DatabaseCommandResponse{result: :ok, message: message, database: updated_database}
  end

  def handle_get(key, %Database{transactions: transactions} = database) do
    %Transaction{log: log} = List.last(transactions, %Transaction{})

    message =
      case log[key] do
        nil -> "NIL"
        result -> result
      end

    %DatabaseCommandResponse{result: :ok, message: message, database: database}
  end

  def handle_begin(%Database{transactions: transactions} = database) do
    new_level = length(transactions)
    updated_transactions = List.insert_at(transactions, -1, %Transaction{level: new_level})
    updated_database = %Database{database | transactions: updated_transactions}

    %DatabaseCommandResponse{result: :ok, message: "#{new_level}", database: updated_database}
  end

  def handle_rollback(%Database{transactions: transactions} = database) do
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
        %DatabaseCommandResponse{
          result: :ok,
          message: "#{poped_transaction.level - 1}",
          database: %Database{database | transactions: updated_transactions}
        }

      _ ->
        exit("should never get to this point")
    end
  end

  def handle_commit(%Database{transactions: transactions} = database) do
    {transaction, l} = List.pop_at(transactions, -1)
    commit_to = List.last(l, transaction)

    case {transaction, commit_to} do
      {nil, _} ->
        exit("Wtf again")

      {%Transaction{level: 0}, %Transaction{level: 0}} ->
        %DatabaseCommandResponse{result: :ok, message: "0", database: database}

      {%Transaction{log: log1}, %Transaction{level: level, log: log0}} ->
        new_commit_to_transaction_log = Map.merge(log0, log1)

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
