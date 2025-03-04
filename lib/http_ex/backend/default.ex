defmodule HTTPEx.Backend.Default do
  @moduledoc """
  The default backend for HTTP calls.
  Uses actual the actual http implementation.
  """
  import HTTPEx.Clients, only: [def_request: 0]

  def_request()
end
