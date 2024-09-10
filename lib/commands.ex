defmodule Commands do
  def parse("") do
    nil
  end

  def parse(line) do
    line = String.trim(line)
    [command | args] = String.split(line, " ", parts: 2)
    uppercase_command = String.upcase(command)

    case uppercase_command do
      "SET" ->
        parsed = parse_set_key(args)

        case parsed do
          {:ok, key, value} -> {:ok, "SET", key, value}
          {:err, err} -> {:err, err}
        end

      "GET" ->
        {:ok, "GET"}

      "BEGIN" ->
        {:ok, "BEGIN"}

      "ROLLBACK" ->
        {:ok, "ROLLBACK"}

      "COMMIT" ->
        {:ok, "COMMIT"}

      command ->
        {:err, "No command #{command}"}
    end
  end

  def parse_set_key([args]) do
    args = String.trim(args)

    case args do
      "\"" <> rest ->
        [first, rest] = String.split(rest, "\"", parts: 2)
        parse_set_key([first <> rest])

      _ ->
        splited = String.split(args, " ", parts: 2)

        case splited do
          [key, value] -> {:ok, key, value}
          _ -> {:err, "Error parsing SET args"}
        end
    end
  end
end
