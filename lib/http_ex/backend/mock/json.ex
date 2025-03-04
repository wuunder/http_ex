defmodule HTTPEx.Backend.Mock.JSON do
  @doc """
  Parses the given JSON and removes any clutter from it, so you can
  safely compare it with another JSON string.
  """
  @spec normalize(String.t()) :: any()
  def normalize(json_string) when is_binary(json_string) do
    case JSON.decode(json_string) do
      {:ok, parsed} ->
        parsed

      _ ->
        nil
    end
  end
end
