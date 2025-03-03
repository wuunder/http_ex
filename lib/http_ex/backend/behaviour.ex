defmodule HTTPEx.Backend.Behaviour do
  @moduledoc false
  alias HTTPEx.Request

  @callback request(Request.t()) :: {:ok, struct()} | {:error, struct()}
end
