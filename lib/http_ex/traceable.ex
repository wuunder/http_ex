defmodule HTTPEx.Traceable do
  @moduledoc false
  @callback trace_attrs(struct()) :: list({String.t(), any()})
  @callback summary(struct()) :: String.t()

  @optional_callbacks trace_attrs: 1
end
