defmodule HTTPEx.Shared do
  @moduledoc false

  @spec header(String.t()) :: String.t()
  def header(header), do: "#{IO.ANSI.underline()}#{header}:#{IO.ANSI.no_underline()}"

  @spec attr(any()) :: String.t()
  def attr(attr), do: "#{IO.ANSI.bright()}#{attr}:#{IO.ANSI.normal()}"

  @spec value(any()) :: String.t()
  def value(data), do: "#{IO.ANSI.italic()}#{inspect_value(data)}#{IO.ANSI.not_italic()}"

  @spec trace_attrs(list({String.t(), any()})) :: list({String.t(), any()})
  def trace_attrs(attrs), do: Enum.reject(attrs, fn {_key, value} -> is_nil(value) end)

  @spec config(atom(), any()) :: any()
  def config(key, default \\ nil), do: Application.get_env(:http_ex, key, default)

  @spec inspect_value(any()) :: String.t()
  def inspect_value(value) when is_binary(value), do: value
  def inspect_value(value), do: inspect(value)

  @spec only_atom_keys?(map() | struct()) :: boolean()
  def only_atom_keys?(struct) when is_struct(struct), do: true

  def only_atom_keys?(map) when is_map(map) do
    map
    |> Map.keys()
    |> Enum.all?(&is_atom/1)
  end
end
