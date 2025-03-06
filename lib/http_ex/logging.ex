defmodule HTTPEx.Logging do
  @moduledoc """
  Handles all the HTTP logging and tracing

  TODO: abstract logging to a macro
  """

  use Tracing

  alias HTTPEx.Shared

  require Logger

  def trace(%module{} = entity) do
    trace_attrs = module.trace_attrs(entity)
    if tracing?(), do: Tracing.set_attributes(trace_attrs)

    if telemetry?(),
      do:
        :telemetry.execute(
          [:http_ex, module.telemetry_event_name()],
          %{},
          Enum.into(trace_attrs, %{})
        )

    entity
  end

  def trace({_, entity} = result) do
    trace(entity)
    result
  end

  def span(span, func) when is_function(func) and is_binary(span) do
    if tracing?() do
      Tracing.with_span span do
        func.()
      end
    else
      func.()
    end
  end

  def log(%module{} = entity) do
    if logging?() do
      log_fn().(module.summary(entity))
    end

    entity
  end

  def log({_, entity} = result) do
    log(entity)
    result
  end

  defp log_fn, do: Shared.config(:log)

  defp logging?, do: not is_nil(log_fn())

  defp tracing?, do: Shared.config(:tracing)
  defp telemetry?, do: Shared.config(:telemetry)
end
