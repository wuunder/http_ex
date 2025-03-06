defmodule HTTPEx.Traceable do
  @moduledoc false
  @callback summary(struct()) :: String.t()
  @callback telemetry_event_name() :: atom()
  @callback trace_attrs(struct()) :: list({String.t(), any()})

  @optional_callbacks trace_attrs: 1, telemetry_event_name: 0
end
