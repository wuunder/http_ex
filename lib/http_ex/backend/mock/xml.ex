defmodule HTTPEx.Backend.Mock.XML do
  @doc """
  Parses the given XML and removes any clutter from it, so you can
  safely compare it with another XML string.
  """
  @spec normalize(String.t()) :: String.t() | nil
  def normalize(xml_string) when is_binary(xml_string) do
    case parse(xml_string) do
      {:ok, parsed} ->
        :xmerl.export([parsed], __MODULE__)

      :error ->
        nil
    end
  end

  def unquote(:"#xml-inheritance#")() do
    []
  end

  def unquote(:"#text#")(text) do
    :xmerl_lib.export_text(text)
  end

  def unquote(:"#root#")(data, [%{name: _, value: v}], [], _e) do
    [v, data]
  end

  def unquote(:"#root#")(data, _attrs, [], _e) do
    ["<?xml version=\"1.0\"?>", data]
  end

  def unquote(:"#element#")(tag, [], attrs, _parents, _e) do
    :xmerl_lib.empty_tag(tag, attrs)
  end

  def unquote(:"#element#")(tag, data, attrs, _parents, _e) do
    data =
      if is_a_tag?(data) do
        clean_up_tag(data)
      else
        data
        |> to_string()
        |> String.trim()
      end

    :xmerl_lib.markup(tag, attrs, data)
  end

  # This function distinguishes an XML tag from an XML value.

  # Let's say there's an XML string `<Outer><Inner>Value</Inner></Outer>`,
  # there will be two calls to this function:
  # 1. The first call has `data` parameter `['Value']`
  # 2. The second call has `data` parameter
  #    `[[['<', 'Inner', '>'], ['Value'], ['</', 'Inner', '>']]]`

  # The first one is an XML value, not an XML tag.
  # The second one is an XML tag.

  defp is_a_tag?(data) do
    is_all_chars =
      Enum.reduce(
        data,
        true,
        fn d, acc ->
          is_char = is_integer(Enum.at(d, 0))
          acc && is_char
        end
      )

    !is_all_chars
  end

  # This function cleans up a tag data contaminated by characters outside the tag.

  # If the tag data is indented, this function removes the new lines
  # ```
  # [
  #   '\\n        ',
  #   [['<', 'Tag', '>'], ['Value'], ['</', 'Tag', '>']],
  #   '\\n      '
  # ]
  # ```

  # After the cleanup, the tag data looks like this:
  # ```
  # [[['<', 'Tag', '>'], ['Value'], ['</', 'Tag', '>']]]
  # ```
  defp clean_up_tag(data) do
    Enum.filter(
      data,
      fn d -> !is_integer(Enum.at(d, 0)) end
    )
  end

  defp parse(xml_string) do
    try do
      {:ok, SweetXml.parse(xml_string, space: :normalize)}
    catch
      :exit, _ -> :error
    end
  end
end
