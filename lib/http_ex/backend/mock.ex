defmodule HTTPEx.Backend.Mock do
  @moduledoc """
  Backend for mocked HTTP requests

  ## Stubbing requests

  To add a stubbed request mock, use `stub_request!/1`.
  This means that the request _may_ be made but is not asserted.

  This is usually done in the beginning of your test suite.
  These stubs are global and are not isolated. Every test, process etc. will be able to access these.

  ## Asserted requests

  To add an assertion, use `expect_request!/1`.
  This means that the test will fail, if the HTTP request is not made.
  This is usally done on a case per case basis in your tests.

  These assertions are isolated and are only accessible for the test you are currently running.
  Processes that were spawned while the test are running, will also be able to access those defined assertions.

  ## Matching and expectations inside defined stubs or assertions

  There is a difference between a _match_ and an _expectation_ within a configured mock or expectation.
  Given the following example:

  ```elixir
  expect_request!(
    host: "localhost",
    port: 3000,
    response: %{
      status: 200,
      body: "OK"
    }
  )
  ```

  This adds a match on `host` and `port`. So every request made to `localhost:3000`.

  When a HTTP call is made, the Mock library will try to look through the registered stubs and asserts
  and will try find a request that matches the value provided in `host`.

  However, there is also the possibility to assert the actually made request.
  This is handy when you want to explicitly verify that the request you are making, is using the right
  payload, headers etc.

  ```elixir
  expect_request!(
    endpoint: "http://localhost:3000/api/rates",
    expect_body: JSON.encode!(%{"user_id" => "1337"}),
    expect_body_format: :json
  )
  ```

  In this case, the Mock library will match all requests made to port 3000, host localhost,
  path `api/rates`. When that request is made, it will verify that the used `body` matches the one
  in `expect_body`. When that is not the case, the test will raise an `AssertionError`.
  """
  @behaviour HTTPEx.Backend.Behaviour

  alias ExUnit.AssertionError
  alias HTTPEx.Backend.Mock
  alias HTTPEx.Backend.Mock.Expectation
  alias HTTPEx.Request
  alias HTTPEx.Shared

  @global_server {:global, Mock.Stubs}
  @local_server {:global, Mock.Assertions}
  @timeout 30_000

  @doc """
  Starts the mock registries in a supervisor.
  We have a server running for the global mocks and local mocks.
  """
  def start do
    children = [
      %{id: Mock.Stubs, type: :worker, start: {Mock, :start_stubs, []}},
      %{id: Mock.Assertions, type: :worker, start: {Mock, :start_assertions, []}}
    ]

    Supervisor.start_link(children, name: Mock.Supervisor, strategy: :one_for_one)

    NimbleOwnership.set_mode_to_shared(@global_server, self())
  end

  @doc """
  Start the HTTPEx Mock server for global expectations.
  """
  def start_stubs do
    case NimbleOwnership.start_link(name: @global_server) do
      {:error, {:already_started, _}} ->
        :ignore

      other ->
        other
    end
  end

  @doc """
  Start the HTTPEx Mock server for local expectations.
  """
  def start_assertions do
    case NimbleOwnership.start_link(name: @local_server) do
      {:error, {:already_started, _}} ->
        :ignore

      other ->
        other
    end
  end

  @doc """
  Adds an asserted request. It will require a match always on `endpoint`, `method` and (optional) `caller`.
  If you try to add an expected request that already exists, this function will throw an exception.

  If you want to explicitly override the request, you must set the `allow_override` option.

  ## Options

  * `body` -
    The request body that is to be matched when an HTTP call is made.

  * `body_format` -
    Sets the matching body format. By using this, the matcher can
    do a safe comparison. This is handy if your fixtures are formatted
    but your requests are not.

    Can be one of:
    - `json`
    - `xml`
    - `form`

  * `description` -
    Described the expectation.

  * `expect_body` -
    The request body that is expected to be used.

  * `expect_body_format` -
    Sets the expected body format. By using this, the matcher can
    do a safe comparison. This is handy if your fixtures are formatted
    but your requests are not.

    Can be one of:
    - `json`
    - `xml`
    - `form`

  * `expect_headers` -
    The request headers that are expected to be used.

  * `expect_path` -
    The request path that is to be expected to be used.

  * `expect_query` -
    The request url query that is to be expected to be used.

  * `headers` -
    The request headers that are to be matched when an HTTP call is made.

  * `host` -
    The request host that is to be matched when an HTTP call is made.
    You can also use `endpoint` instead of this option.

  * `endpoint` -
    The request URL that is to be matched when an HTTP call is made.

  * `min_calls` number() | nil (default 1) -
    Sets the minimum number of calls that are allowed.
    If you set this to `nil`, the request is not mandatory.

  * `max_calls` number() | nil (default nil) -
    Sets the maximum number of the times the request can be made.

  * `method` atom() -
    The method that is to be matched when an HTTP call is made.

  * `path` String.t() | function() -
    The request path that is to be matched when an HTTP call is made.
    You can also use `path` instead of this option.

  * `port` number() -
    The request port that is to be matched when an HTTP call is made.
    You can also use `endpoint` instead of this option.

  * `query` map() | function() -
    The url query that is to be matched when an HTTP call is made.
    You can also pass this down to `endpoint` or in combination with `endpoint`.

  * `response` {:ok, map() | HTTPoison.Response.t()} | {:error, atom() | HTTPoison.Error.t()} -
    Sets the fake response. Can be one of:
    * {:ok, %{status: _status_code, body: _body, headers: _headers}}
    * {:ok, %HTTPoison.Response{}}
    * {:error, :timeout}
    * {:error, %HTTPoison.Error{}}

  ## Examples

      iex> HTTPEx.Mock.expect_request!(
      ...>   method: :get,
      ...>   max_calls: 2,
      ...>   endpoint: "http://www.example.com",
      ...>   response: %{status: 200, body: "OK!", headers: [{"Content-Type", "application/json"}]},
      ...> )

  """
  @spec expect_request!(Keyword.t()) :: :ok | {:error, atom()}
  def expect_request!(opts) when is_list(opts) do
    expectation = Expectation.new!(Keyword.put(opts, :type, :assert))
    add!(@local_server, expectation)
  end

  @doc """
  The inverse of an expected call. Checks that the call (using the matchers) wasn't made.

  ## Examples

      iex> HTTPEx.Mock.assert_no_request!(
      ...>   method: :get,
      ...>   endpoint: "http://www.example.com"
      ...> )
  """
  @spec assert_no_request!(Keyword.t()) :: :ok | {:error, atom()}
  def assert_no_request!(opts) when is_list(opts) do
    expectation =
      opts
      |> Keyword.put(:type, :reject)
      |> Expectation.new!()

    add!(@local_server, expectation)
  end

  @doc """
  Adds a stubbed HTTP request. Does not check if the request is actually made.
  This is used to setup basic HTTP requests all your tests can use.

  ## Examples

      iex> HTTPEx.Mock.stub_request!(
      ...>   method: :get,
      ...>   endpoint: "http://www.example.com",
      ...>   response: %{status: 200, body: "OK"}
      ...> )

  ## Options

  See `expect_request!/1`
  """
  def stub_request!(opts) when is_list(opts) do
    expectation = Expectation.new!(Keyword.put(opts, :type, :stub))
    server = if Keyword.get(opts, :global), do: @global_server, else: @local_server
    add!(server, expectation)
  end

  @doc """
  Returns a response from one of the expectations
  """
  @impl HTTPEx.Backend.Behaviour
  def request(%Request{} = request) do
    request = parse_body(request)

    caller_pids = [self() | caller_pids()]

    local_owner_pid = fetch_owner_from_callers(@local_server, caller_pids)
    global_owner_pid = fetch_owner_from_callers(@global_server, caller_pids)

    case match_expectation(request, local_owner_pid, global_owner_pid) do
      {:ok, expectation, vars} ->
        Expectation.to_response(request, expectation, vars)

      {:error, :no_matches} ->
        raise AssertionError,
          message: """
          No HTTP request found that are registered with `expect_request`

          #{Request.summary(request)}
          """

      {:error, :max_calls_reached, %{max_calls: 0} = expectation} ->
        raise AssertionError,
          message: """
          An unexpected HTTP request was made

          #{Expectation.summary(expectation)}

          #{Request.summary(request)}
          """

      {:error, :max_calls_reached, expectation} ->
        raise AssertionError,
          message: """
          Maximum number of HTTP calls already made for request

          #{Expectation.summary(expectation)}

          #{Request.summary(request)}
          """

      {:error, :expectations_not_met, missed, expectation} ->
        raise AssertionError,
          message: """
          The HTTP request that was made, didn't match one or more expectations.

          #{Shared.attr("Fields mismatched")} #{Shared.value(missed)}

          #{Expectation.summary(expectation)}

          #{Request.summary(request)}
          """

      {:error, error} ->
        raise AssertionError, message: error
    end
  end

  @doc """
  Verifies made HTTP calls.
  Adds a ExUnit hook and checks if all HTTP calls were actually made.
  """
  def verify_on_exit! do
    owner_pid = self()
    NimbleOwnership.set_owner_to_manual_cleanup(@local_server, owner_pid)

    ExUnit.Callbacks.on_exit(HTTPEx.Mock, fn ->
      verify!(owner_pid)
      NimbleOwnership.cleanup_owner(@local_server, owner_pid)
    end)
  end

  @doc """
  Manually verify made calls
  """
  def verify!(owner_pid \\ self()) do
    @local_server
    |> list(owner_pid)
    |> Enum.each(fn %Expectation{} = expectation ->
      if expectation.min_calls > 0 && expectation.calls < expectation.min_calls do
        raise AssertionError,
          message: """
          An expected HTTP call was called #{expectation.calls} but was expected to be called #{expectation.min_calls} times.

          #{Expectation.summary(expectation)}
          """
      end
    end)
  end

  defp add!(server, expectation) do
    case NimbleOwnership.get_and_update(
           server,
           self(),
           :expectations,
           fn from ->
             index = length(from || [])
             to = from || []
             {from, to ++ [%{expectation | index: index}]}
           end,
           @timeout
         ) do
      {:ok, return} ->
        return

      {:error, %NimbleOwnership.Error{} = error} ->
        raise error
    end
  end

  # Find the pid of the actual caller
  defp caller_pids do
    case Process.get(:"$callers") do
      nil -> []
      pids when is_list(pids) -> pids
    end
  end

  defp fetch_owner_from_callers(server, caller_pids) do
    case NimbleOwnership.fetch_owner(server, caller_pids, :expectations, @timeout) do
      {tag, owner_pid} when tag in [:shared_owner, :ok] -> owner_pid
      :error -> nil
    end
  end

  defp list(_server, nil), do: []

  defp list(server, owner_pid) do
    case NimbleOwnership.get_owned(server, owner_pid, :expectations, @timeout) do
      %{expectations: expectations} -> expectations
      _ -> []
    end
  end

  defp match_expectation(request, local_owner_pid, global_owner_pid) do
    case match_local(request, local_owner_pid) do
      {:error, :no_matches} -> match_global(request, global_owner_pid)
      other -> other
    end
  end

  defp match_local(request, owner_pid) do
    expectations = list(@local_server, owner_pid)

    with {:ok, expectation, vars} <-
           Expectation.find_matching_expectation(expectations, request),
         :ok <- validate_expectations(request, expectation),
         {:ok, _} <- update_expectation_calls(expectation, owner_pid) do
      {:ok, expectation, vars}
    end
  end

  defp match_global(request, owner_pid) do
    expectations = list(@global_server, owner_pid)
    Expectation.find_matching_expectation(expectations, request)
  end

  defp update_expectation_calls(%{type: :stub}, _owner_pid), do: {:ok, nil}

  defp update_expectation_calls(%{type: :assertion} = expectation, owner_pid) do
    NimbleOwnership.get_and_update(@local_server, owner_pid, :expectations, fn expectations ->
      updated_expectation = Expectation.increase_call(expectation)

      updated_expectations =
        List.replace_at(expectations || [], updated_expectation.index, updated_expectation)

      {expectations, updated_expectations}
    end)
  end

  defp validate_expectations(_request, %{type: :stub}), do: :ok

  defp validate_expectations(request, %{type: :assertion} = expectation) do
    case Expectation.validate_expectations(request, expectation) do
      :ok -> :ok
      {:error, error, missed} -> {:error, error, missed, expectation}
    end
  end

  defp parse_body(%Request{body: {:stream, enum}} = request),
    do: %{request | body: enum |> Enum.to_list() |> Enum.join()}

  defp parse_body(%Request{body: body} = request) when is_bitstring(body),
    do: %{request | body: to_string(body)}

  defp parse_body(%Request{} = request), do: request
end
