defmodule Command do
  @enforce_keys [:command]
  defstruct [:command, :key, :value]
end

defmodule Commands do
  def parse("") do
    nil
  end

  def parse(line) do
    line = String.trim(line)
    [command | args] = String.split(line, " ", parts: 2)
    uppercase_command = String.upcase(command)

    case {uppercase_command, args} do
      {"SET", _} ->
        parsed = parse_set_args(args)

        case parsed do
          {:ok, key, value} -> {:ok, %Command{command: "SET", key: key, value: value}}
          {:err, err} -> {:err, err}
        end

      {"GET", [args]} ->
        parsed = parse_key(args)

        case parsed do
          {:ok, key, _} -> {:ok, %Command{command: "GET", key: key}}
          err -> err
        end

      {"BEGIN", _} ->
        {:ok, %Command{command: "BEGIN"}}

      {"ROLLBACK", _} ->
        {:ok, %Command{command: "ROLLBACK"}}

      {"COMMIT", _} ->
        {:ok, %Command{command: "COMMIT"}}

      {command, _} ->
        {:err, "No command #{command}"}
    end
  end

  @invalid_set_syntax "invalid syntax, should use SET <key> <value>"

  defp parse_set_args([]) do
    {:err, @invalid_set_syntax}
  end

  defp parse_set_args([args]) do
    args = String.trim_leading(args)
    key = parse_key(args)

    case key do
      {:ok, key_token, tail} when tail != "" and tail != nil ->
        value = parse_value(tail)

        case value do
          {:ok, value_token} -> {:ok, key_token, value_token}
          err -> err
        end

      {:ok, _, _} ->
        {:err, @invalid_set_syntax}

      err ->
        err
    end
  end

  def parse_key(args) do
    key = ParseArgs.next_token(args)

    case key do
      {:ok, key_token, tail, :string} ->
        {:ok, key_token, tail}

      {:ok, token, _, type} ->
        {:err,
         "only strings are accepted as key, found a key of type #{type}, you could try \"#{token}\""}

      _ ->
        {:err, @invalid_set_syntax}
    end
  end

  @using_nil_as_value ~s/NIL is not accepted as value for the SET command, you could try "NIL"/
  def parse_value(args) do
    value = ParseArgs.next_token(args)

    case value do
      {:ok, value_token, "", :string} ->
        {:ok, value_token}

      {:ok, value_token, "", :boolean} ->
        {:ok, value_token == "TRUE"}

      {:ok, _, "", "NIL"} ->
        {:err, @using_nil_as_value}

      _ ->
        {:err, @invalid_set_syntax}
    end
  end
end

defmodule ParseArgs do
  @transitions %{
    0 => %{"\"" => 1, :* => 2, :number => 5},
    1 => %{:whitespace => 1, "\\" => 3, "\"" => :end, :* => 1, :number => 1},
    2 => %{:whitespace => :end, :* => 2, :number => 2},
    3 => %{"\"" => 1, :* => :err},
    :end => %{},
    5 => %{:* => 2, :number => 5, :whitespace => :end}
  }

  @change_type_transitions %{
    0 => %{1 => :string, 2 => :string, 5 => :number},
    1 => %{},
    2 => %{},
    3 => %{},
    :end => %{},
    5 => %{2 => :string}
  }

  def next_token(str, token \\ "", state \\ 0, type \\ :undefined) do
    {head, tail} = String.split_at(str, 1)
    transition_for_state = @transitions[state]
    type_transitions_for_state = @change_type_transitions[state]

    case {state == :end, String.length(head) > 0} do
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

      {_, _} ->
        cond do
          is_boolean_type(token) ->
            {:ok, String.trim(token), String.trim(str), :boolean}

          is_nil_type(token) ->
            {:ok, String.trim(token), String.trim(str), "NIL"}

          true ->
            {:ok, String.trim(token), String.trim(str), type}
        end
    end
  end

  def is_boolean_type(token) do
    token = String.trim(token)
    token == "TRUE" || token == "FALSE"
  end

  def is_nil_type(token) do
    token = String.trim(token)
    token == "NIL"
  end
end
