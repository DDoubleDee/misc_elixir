defmodule EasyETS do
  @moduledoc """
  This module shortens the code required to work with ETS and adds a few extra features to help with table organization.
  """
  def debug_struct() do
    %{first: 1, second: ["This", "is a", "list"], third: %{first: 1, second: {"This", "is a", "tuple"}}}
  end
  @doc """
  Creates a connector with and ETS with the given `name`, `structure` and ETS options `opts`.

  Returns `{:success, "ETS created"}`.

  `structure` is a map with keys and default values for said keys.

  ## Example

    iex> EasyETS.create(:my_ets, %{name: "John", surname: "Drake"})
    {:success, "ETS created"}

  """
  def create(name, structure \\ %{}, opts \\ [:named_table, :set, :public]) do
    pid = spawn(EasyETS, :connector, [name, structure, 0])
    try do
      Process.register(pid, name)
      send(name, {:create, self(), opts})
      receive do
        answer ->
          answer
      end
    rescue
      _ ->
        Process.exit(pid, :kill)
        {:fail, "Name is already taken"}
    end
  end
  @doc """
  Writes given map `values` into ETS with the given `name`.

  Returns `{:success, id}` where `id` is the identification number given to the map inserted into ETS.

  The map `values` is checked for keys that match the ones given in the structure, and they are inserted into the map if they match the constraints given to those keys.

  If some keys are missing, defaults from the structure are put in their place.

  ## Example

    iex> EasyETS.write(:my_ets, %{name: "Alex"})
    {:success, 0}

  """
  def write(name, values) do
    send(name, {:write, self(), values})
    receive do
      answer ->
        answer
    end
  end
  @doc """
  Finds the map under the given `id` in the ETS with the given `name`.

  Returns `{:success, values}` on successful find.

  Returns `{:fail, "Does not exist"}` if `id` does not exist.

  Uses simple :ets.lookup with the given `id`.

  ## Example

    iex> EasyETS.read(:my_ets, 0)
    {:success, %{name: "Alex", surname: "Drake"}}

    iex> EasyETS.read(:my_ets, 1)
    {:fail, "Does not exist"}

  """
  def read(name, id) do
    send(name, {:read, self(), id})
    receive do
      answer ->
        answer
    end
  end
  @doc """
  Matches any keys present in `values` with those written in the structure and uses :ets.match_object() to find entries that match.
  
  This function can also be used to output all entries in the :ets if you pass an empty map in it.

  Returns `{:success, [{entry_id, entry}]}` on successful find, with the list being sorted by id lowest to highest.

  Returns `{:fail, match_map, "Does not exist"}` if :ets.match_object(match_map) returns empty list.

  ## Example

    iex> EasyETS.match(:my_ets, %{name: "Alex"})
    {:success, [{0, %{name: "Alex", surname: "Drake"}}]}
    
    iex> EasyETS.match(:my_ets, %{})
    {:success, [
      {0, %{name: "Alex", surname: "Drake"}},
      {1, %{name: "Sara", surname: "Drake"}}
      ]}

    iex> EasyETS.match(:my_ets, %{name: "John"})
    {:fail, {:_, %{name: "John", surname: :_}}, "Does not exist"}

  """
  def match(name, values) do
    send(name, {:match, self(), values})
    receive do
      answer ->
        answer
    end
  end
  @doc """
  Replaces values under `id` with `values` if it exists, otherwise returns error.

  Returns `{:success, id}` if successful.

  Returns `{:fail, "ID doesn't exist"}` if `id` does not exist.

  ## Examples

    iex> EasyETS.update(:my_ets, 0, %{name: "Josh"})
    {:success, 0}

    iex> EasyETS.update(:my_ets, 1, %{name: "Josh"})
    {:fail, "ID doesn't exist"}

  """
  def update(name, id, values) do
    send(name, {:update, self(), id, values})
    receive do
      answer ->
        answer
    end
  end
  @doc """
  Deletes values under `id` if it exists.

  Returns `{:success, id}` whether or not id exists.

  ## Examples

    iex> EasyETS.delete(:my_ets, 0)
    {:success, 0}
  """
  def delete(name, id) do
    send(name, {:delete, self(), id})
    receive do
      answer ->
        answer
    end
  end
  @doc """
  Adds a constraint `func` under a given `key`.

  Returns `{:success, {key: func}}`.

  In the future, if the value under `key`, passed through `func`, returns boolean `false`, it is overwritten by the default value in structure.

  Be careful! If the function returns a non boolean value, it will be treated as value to be inserted under key.

  ## Examples

    iex> EasyETS.add_constraint(:my_ets, :name, fn name -> is_bitstring(name) end)
    {:success, %{name: #Function<44.65746770/1 in :erl_eval.expr/5>}}

  """
  def add_constraint(name, key, func) when is_function(func) do
    send(name, {:add_cnstr, self(), key, func})
    receive do
      answer ->
        answer
    end
  end
  def add_constraint(_name, _key, _func) do
    {:fail, "3rd value passed is not function"}
  end
  @doc """
  Returns structure and constraints of the connector under `name`.

  Returns `{:success, structure, constraints}`.

  ## Examples

    iex> EasyETS.get_info(:my_ets)
    {:success, %{name: "John", surname: "Drake"}, %{name: #Function<44.65746770/1 in :erl_eval.expr/5>}}

  """
  def get_info(name) do
    send(name, {:get_strct, self()})
    receive do
      answer ->
        answer
    end
  end



  @doc """
  This is not supposed to be used externally, but privating this would have broken the module.
  """
  def connector(name, structure, next_id, constraints \\ %{}) do
    receive do
      {:create, from, opts} ->
        try do
          :ets.new(name, opts)
          send(from, {:success, "ETS created"})
          connector(name, structure, next_id, constraints)
        rescue
          _ ->
            send(from, {:error, "Connector error"})
            connector(name, structure, next_id, constraints)
        end
      {:write, from, values} ->
        try do
          put_into_struct(structure, values, constraints)
          |>  (&:ets.insert(name, {next_id, &1})).()
          send(from, {:success, next_id})
          connector(name, structure, next_id + 1, constraints)
        rescue
          _ ->
            send(from, {:error, "Connector error"})
            connector(name, structure, next_id, constraints)
        catch
          {:fail, values} ->
            send(from, {:fail, {values, "Variable constraint returned false"}})
            connector(name, structure, next_id, constraints)
        end
      {:read, from, id} ->
        try do
          answer = :ets.lookup(name, id)
          if answer == [] do
            send(from, {:fail, "Does not exist"})
          else
            {_id, answer} = List.first(answer)
            send(from, {:success, answer})
          end
          connector(name, structure, next_id, constraints)
        rescue
          _ ->
            send(from, {:error, "Connector error"})
            connector(name, structure, next_id, constraints)
        end
      {:match, from, values} ->
        try do
          map = match_structure(structure, values)
          answer = :ets.match_object(name, map)
          if answer == [] do
            send(from, {:fail, map, "Does not exist"})
          else
            answer = Enum.reverse(answer)
            send(from, {:success, answer})
          end
          connector(name, structure, next_id, constraints)
        rescue
          _ ->
            send(from, {:error, "Connector error"})
            connector(name, structure, next_id, constraints)
        end
      {:update, from, id, values} ->
        try do
          check = :ets.lookup(name, id)
          |> Enum.empty?
          if check do
            send(from, {:fail, "ID doesn't exist"})
            connector(name, structure, next_id, constraints)
          else
            put_into_struct(structure, values, constraints)
            |>  (&:ets.insert(name, {id, &1})).()
            send(from, {:success, id})
            connector(name, structure, next_id, constraints)
          end
        rescue
          _ ->
            send(from, {:error, "Connector error"})
            connector(name, structure, next_id, constraints)
        catch
          {:fail, values} ->
            send(from, {:fail, {values, "Variable constraint returned false"}})
            connector(name, structure, next_id, constraints)
        end
      {:delete, from, id} ->
        try do
          :ets.delete(name, id)
          send(from, {:success, id})
          connector(name, structure, next_id, constraints)
        rescue
          _ ->
            send(from, {:error, "Connector error"})
            connector(name, structure, next_id, constraints)
        end
      {:add_cnstr, from, key, constraint} ->
        try do
          constraints = add_constr(structure, constraints, {key, constraint})
          send(from, {:success, constraints})
          connector(name, structure, next_id, constraints)
        rescue
          _ ->
            send(from, {:error, "Connector error"})
            connector(name, structure, next_id, constraints)
        catch
          {:fail, error} ->
            send(from, {:fail, error})
            connector(name, structure, next_id, constraints)
        end
      {:get_strct, from} ->
        send(from, {:success, structure, constraints})
        connector(name, structure, next_id, constraints)
    end
  end


  ################################################################# Helper fns
  defp match_structure(structure, values) do
    {:_, Enum.map(structure, fn {key, _default} ->
      {key, Map.get(values, key, :_)}
    end)
    |> Map.new()}
  end
  defp add_constr(structure, constraints, {key, constraint}) when is_map_key(structure, key) do
    Map.put(constraints, key, constraint)
  end
  defp add_constr(_structure, _constraints, {key, _constraint}) do
    throw {:fail, "#{key} not present in structure"}
  end
  defp put_into_struct(structure, values, _) when structure == %{} and is_map(values) do
    values
  end
  defp put_into_struct(structure, values, constraints) when is_map(structure) and structure != %{} and is_map(values) and not is_function(constraints) do
    Enum.map(structure, fn {key, default} ->
      {key, Map.get(values, key, default)
      |> (&put_into_struct(default, &1, Map.get(constraints, key, fn _a -> true end))).()}
    end)
    |> Map.new()
  end
  defp put_into_struct(_default, values, constraint) when is_function(constraint) do
    check = constraint.(values)
    if not is_boolean(check) do
      check
    else
      if check do
      values
      else
      throw {:fail, values}
      end
    end
  end
  defp put_into_struct(_default, values, _constraints) do
    values
  end
  ################################################################################
end
