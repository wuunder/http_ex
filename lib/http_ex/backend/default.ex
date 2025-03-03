defmodule HTTPEx.Backend.Default do
  @moduledoc """
  The default backend for HTTP calls.
  Uses actual the actual http implementation.
  """

  use HTTPEx.Backend.Client
end
