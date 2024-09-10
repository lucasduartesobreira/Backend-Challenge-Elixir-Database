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
defmodule ParseArgs do
  @transitions %{
    0 => %{"\"" => 1, :* => 2, :number => 5},
    1 => %{:whitespace => 1, "\\" => 3, "\"" => 4, :* => 1},
    2 => %{:whitespace => 4, :* => 2, :number => 2},
    3 => %{"\"" => 1, :* => :err},
    4 => %{},
    5 => %{:* => 2, :number => 5, " " => 4}
  }

  @change_type_transitions %{
    0 => %{1 => :string, 2 => :string, 5 => :number},
    1 => %{},
    2 => %{},
    3 => %{},
    4 => %{},
    5 => %{2 => :string}
  }

  @terminal? %{
    0 => false,
    1 => false,
    2 => false,
    3 => false,
    4 => true,
    5 => false
  }

  def next_token(str, token \\ "", state \\ 0, type \\ :undefined) do
    {head, tail} = String.split_at(str, 1)
    transition_for_state = @transitions[state]
    type_transitions_for_state = @change_type_transitions[state]
    # IO.puts("head: #{head}, state: #{state}, token: #{token}, type: #{type}")

    case {@terminal?[state], String.length(head) > 0} do
      {false, true} ->
        char_type =
          cond do
            head =~ ~r/[\"\\]/ -> head
            head == " " || head == "\t" -> :whitespace
            head =~ ~r/[0-9]/ -> :number
            true -> :*
          end

        case transition_for_state[char_type] do
          nil ->
            {:err, "unable to parse token"}

          result_state ->
            new_type =
              case type_transitions_for_state[result_state] do
                nil -> type
                result -> result
              end

            next_token(tail, token <> head, result_state, new_type)
        end

      {true, true} ->
        {:ok, String.trim(token), String.trim(str),
         if is_boolean_type(token) do
           :boolean
         else
           type
         end}

      {_, false} ->
        {:ok, String.trim(token), "",
         if is_boolean_type(token) do
           :boolean
         else
           type
         end}
    end
  end

  def is_boolean_type(token) do
    token == "TRUE" || token == "FALSE"
  end
end
