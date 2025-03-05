defmodule HTTPEx.Backend.Mock.Form do
  @doc """
  Parses the given form data and removes any clutter from it, so you can
  safely compare it with another form data formatted  string.
  """
  @spec normalize(String.t()) :: %{binary() => binary()}
  def normalize(form_string) when is_binary(form_string),
    do: form_string |> String.trim() |> URI.decode_query()
end
