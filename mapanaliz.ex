defmodule Mapanaliz do

  @doc """
  Returns a map which contains the count of all types that are inside the input map.
  """
  def get_in(map, key_list \\ nil)
  def get_in(map, key_list) when is_nil(key_list) do
    key_list = all_path_list(map)
    Enum.reduce(key_list, %{}, fn keys, output ->
      process(map, keys, output)
    end)
  end
  def get_in(map, key_list) do
    Enum.reduce(key_list, %{}, fn keys, output ->
      process(map, keys, output)
    end)
  end
  defp process(map, keys, output) do
    value = Enum.reduce(keys, map, fn key, out ->
      Map.get(out, key)
    end)
    cond do
      is_map(value) -> Map.put(output, :map_count, 1 + Map.get(output, :map_count, 0))
      is_integer(value) -> Map.put(output, :integer_count, 1 + Map.get(output, :integer_count, 0))
      is_bitstring(value) -> Map.put(output, :bitstring_count, 1 + Map.get(output, :bitstring_count, 0))
      is_list(value) -> Map.put(output, :list_count, 1 + Map.get(output, :list_count, 0))
      is_float(value) -> Map.put(output, :float_count, 1 + Map.get(output, :float_count, 0))
      is_tuple(value) -> Map.put(output, :tuple_count, 1 + Map.get(output, :tuple_count, 0))
      is_boolean(value) -> Map.put(output, :boolean_count, 1 + Map.get(output, :boolean_count, 0))
      is_atom(value) -> Map.put(output, :atom_count, 1 + Map.get(output, :atom_count, 0))
      is_nil(value) -> Map.put(output, :nil_count, 1 + Map.get(output, :nil_count, 0))
      is_struct(value) -> Map.put(output, :struct_count, 1 + Map.get(output, :struct_count, 0))
      is_function(value) -> Map.put(output, :function_count, 1 + Map.get(output, :function_count, 0))
      is_binary(value) -> Map.put(output, :binary_count, 1 + Map.get(output, :binary_count, 0))
      true -> output
    end
  end

  @doc """
  Returns a list of lists which store the key path to every value in map.
  """

  def all_path_list(map) do
    iterate(Map.to_list(map), [], [])
  end
  defp iterate([], _iteration, output) do
    output
  end
  defp iterate([{key, map} | tail], iteration, output) when is_map(map) do
    output = output ++ [iteration ++ [key]]
    output = iterate(Map.to_list(map), iteration ++ [key], output)
    iterate(tail, iteration, output)
  end
  defp iterate([{key, _} | tail], iteration, output) do
    output = output ++ [iteration ++ [key]]
    iterate(tail, iteration, output)
  end
end
