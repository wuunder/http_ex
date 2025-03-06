defmodule HTTPEx.Response do
  @moduledoc false
  @behaviour HTTPEx.Traceable

  alias __MODULE__
  alias HTTPEx.Shared
  alias Plug.Conn.Status

  defstruct body: nil, client: nil, retries: 0, status: nil, parsed_body: nil, headers: nil

  @type t :: %__MODULE__{
          body: nil | binary(),
          client: atom(),
          headers: nil | HTTPoison.headers(),
          parsed_body: nil | map() | list(),
          retries: non_neg_integer(),
          status: nil | integer()
        }

  @impl true
  @spec summary(Response.t()) :: String.t()
  def summary(%Response{} = response) do
    """
    #{Shared.header("HTTP response")}

    #{Shared.attr("Client")} #{Shared.value(response.client)}
    #{Shared.attr("Status")} #{Shared.value(response.status)}
    #{Shared.attr("Retries")} #{Shared.value(response.retries)}
    #{Shared.attr("Headers")}

    #{Shared.value(response.headers)}

    #{Shared.attr("Body")}

    #{Shared.value(response.body)}
    """
  end

  @doc """
  Returns the OT attributes for the HTTP response
  """
  @impl true
  @spec trace_attrs(Response.t()) :: list({String.t(), any()})
  def trace_attrs(%Response{} = response) do
    error? = response.status >= 400

    reason =
      if error?,
        do:
          response.status
          |> Status.reason_atom()
          |> Shared.inspect_value()

    Shared.trace_attrs([
      {"error", error?},
      {"http.error", reason},
      {"http.response_body", response.body},
      {"http.response_headers", response.headers},
      {"http.status_code", response.status},
      {"http.retries", response.retries}
    ])
  end

  @impl true
  @spec telemetry_event_name() :: :response
  def telemetry_event_name, do: :response
end
