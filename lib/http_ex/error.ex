defmodule HTTPEx.Error do
  @moduledoc false
  @behaviour HTTPEx.Traceable

  alias __MODULE__
  alias HTTPEx.Shared

  defstruct body: nil,
            headers: nil,
            parsed_body: nil,
            reason: nil,
            retries: 0,
            status: nil

  @type t :: %__MODULE__{
          body: nil | String.t(),
          headers: nil | HTTPoison.headers(),
          parsed_body: nil | map() | list(),
          reason: atom(),
          retries: non_neg_integer(),
          status: nil | integer()
        }

  @impl true
  @spec summary(Error.t()) :: String.t()
  def summary(%Error{} = error) do
    """
    #{Shared.header("HTTP error")}

    #{Shared.attr("Reason")} #{Shared.value(error.reason)}
    #{Shared.attr("Status")} #{Shared.value(error.status)}
    #{Shared.attr("Retries")} #{Shared.value(error.retries)}
    #{Shared.attr("Headers")} #{Shared.value(error.headers)}

    #{Shared.attr("Body")}

    #{Shared.value(error.body)}
    """
  end

  @impl true
  @spec trace_attrs(Error.t()) :: list()
  def trace_attrs(%Error{} = error) do
    Shared.trace_attrs([
      {"error", true},
      {"http.error", Shared.inspect_value(error.reason)},
      {"http.response_body", error.body},
      {"http.response_headers", error.headers},
      {"http.status_code", error.status || 0},
      {"http.retries", error.retries}
    ])
  end
end
