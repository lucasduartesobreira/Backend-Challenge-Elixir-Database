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
        "ROLLBACK"

      %Command{command: "COMMIT", key: nil, value: nil} ->
        "COMMIT"

      _ ->
        {:err, database}
    end
  end

  def handle_set(key, value, %Database{transactions: transactions} = database) do
    {%Transaction{log: log}, remaining_transactions} =
      List.pop_at(transactions, -1, %Transaction{})

    message = if(Map.has_key?(log, key), do: "TRUE", else: "FALSE") <> " #{value}"

    updated_transaction = %Transaction{log: Map.put(log, key, value)}

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

  def new() do
    %Database{}
  end
end
