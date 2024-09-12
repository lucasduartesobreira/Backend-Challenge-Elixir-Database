defmodule DesafioCli do
  @moduledoc """
  Ponto de entrada para a CLI.
  """
  alias Database.DatabaseCommandResponse

  @doc """
  A função main recebe os argumentos passados na linha de
  comando como lista de strings e executa a CLI.
  """
  def main(_args) do
    database = Database.new()
    main_loop(database)
  end

  def main_loop(%Database{} = database) do
    input = IO.gets("> ")

    %DatabaseCommandResponse{database: database, message: message, result: result} =
      Database.handle_command(input, database)

    IO.puts(
      case result do
        :ok -> message
        :err -> "Error: " <> message
      end
    )

    main_loop(database)
  end
end
