defmodule HTTPEx.Backend.Default do
  @moduledoc """
  The default backend for HTTP calls.
  Uses actual the actual HTTPoison implementation.

  The idea is that multiple HTTP clients can be defined here if we feel like it.
  Like Finch. At the moment of writing, only HTTPoison is supported.
  """
  @behaviour HTTPEx.Backend.Behaviour

  alias HTTPEx.Request

  @impl true
  def request(%Request{} = request),
    do:
      HTTPoison.request(
        request.method,
        request.url,
        request.body,
        request.headers,
        options(request)
      )

  defp options(request),
    do: [timeout: request.options[:timeout], recv_timeout: request.options[:receive_timeout]]
end
