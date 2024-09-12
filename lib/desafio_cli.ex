defmodule DesafioCli do
  @moduledoc """
  Ponto de entrada para a CLI.
  """

  @doc """
  A função main recebe os argumentos passados na linha de
  comando como lista de strings e executa a CLI.
  """
  def main(_args) do
    input = IO.gets("> ")
    command = Commands.parse(input)

    case command do
      {:ok, %Command{command: "SET", key: key, value: value}} ->
        IO.puts("SET key: #{key} value: #{value}")

      {:ok, %Command{command: "GET", key: key}} ->
        IO.puts("GET key: #{key}")

      {:ok, command} ->
        IO.puts("#{command}")

      {:err, err} ->
        IO.puts(err)
    end
  end
end
