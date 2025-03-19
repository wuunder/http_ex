defmodule HTTPEx.Backend.Mock.TestHelpers do
  @moduledoc """
  This can be used in your test suite for convenience.
  These macros add tracing to your expectations making them easier to spot if you
  miss expected calls.
  """
  defmacro expect_request!(opts) do
    %{module: mod, file: file, line: line} = __CALLER__

    quote do
      HTTPEx.Backend.Mock.expect_request!(
        Keyword.put(unquote(opts), :stacktrace, {unquote(file), unquote(line), unquote(mod)})
      )
    end
  end

  defmacro assert_no_request!(opts) do
    %{module: mod, file: file, line: line} = __CALLER__

    quote do
      HTTPEx.Backend.Mock.assert_no_request!(
        Keyword.put(unquote(opts), :stacktrace, {unquote(file), unquote(line), unquote(mod)})
      )
    end
  end

  defmacro stub_request!(opts) do
    %{module: mod, file: file, line: line} = __CALLER__

    quote do
      HTTPEx.Backend.Mock.stub_request!(
        Keyword.put(unquote(opts), :stacktrace, {unquote(file), unquote(line), unquote(mod)})
      )
    end
  end
end
