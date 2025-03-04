defmodule HTTPEx do
  @moduledoc """
  HTTPEx provides common functionality to do HTTP calls like GET and POST via a HTTP client (like HTTPoison, Finch etc.).

  It adds a couple of additional features on top of a HTTP library:
  - Adds OT tracing
  - Adds a standarized Request, Response and Error struct
  - Switch between different HTTP clients (like HTTPoison, Finch etc.)
  - Adds a standarized response
  - Adds retry mechanism when timeout of connection closed is encountered
  - Adds a stub HTTP client that is able to mock requests for all possibile implementations that use this module

  See HTTPEx.TestBackend to see how stubbing out requests and responses work.
  """

  alias HTTPEx.Error
  alias HTTPEx.Logging
  alias HTTPEx.Request
  alias HTTPEx.Response
  alias HTTPEx.Shared

  import HTTPEx.Clients, only: [def_to_response: 0]

  @backend Application.compile_env(:http_ex, :backend, HTTPEx.Backend.Default)
  @retry_wait 100

  @doc """
  Executes GET request

  ## Examples

      iex> HTTPEx.get("http://www.example.com", backend: MockBackend)
      {:ok, %HTTPEx.Response{body: "OK!", client: :httpoison, retries: 1, status: 200, parsed_body: nil, headers: []}}

      iex> HTTPEx.get("http://www.example.com", backend: MockBackend, client: :finch)
      {:ok, %HTTPEx.Response{body: "OK!", client: :httpoison, retries: 1, status: 200, parsed_body: nil, headers: []}}

      iex> HTTPEx.get("http://www.example.com/json", headers: [{"Content-Type", "application/json"}], backend: MockBackend)
      {
        :ok,
        %HTTPEx.Response{
          body: "{\\"payload\\":{\\"items\\":[1,2,3]}}",
          client: :httpoison,
          headers: [],
          parsed_body: %{"payload" => %{"items" => [1, 2, 3]}},
          retries: 1,
          status: 202
        }
      }

      iex> HTTPEx.get("http://www.example.com/error", backend: MockBackend)
      {
        :error,
        %HTTPEx.Error{
          body: "{\\"errors\\":[{\\"code\\":\\"invalid_payload\\"}]}",
          client: :httpoison,
          headers: [],
          parsed_body: %{"errors" => [%{"code" => "invalid_payload"}]},
          retries: 1,
          status: 422,
          reason: :unprocessable_entity
        }
      }

  """
  @spec get(String.t(), Keyword.t()) :: {:ok, Response.t()} | {:error, Error.t()}
  def get(url, options \\ []) when is_binary(url) and is_list(options),
    do:
      request(%Request{
        client: Keyword.get(options, :client),
        headers: Keyword.get(options, :headers, []),
        method: :get,
        url: url,
        options: options |> Keyword.delete(:headers) |> Keyword.delete(:client)
      })

  @doc """
  Executes POST request

  ## Examples

      iex> HTTPEx.post("http://www.example.com", JSON.encode!(%{"data" => true}), backend: MockBackend)
      {:ok, %HTTPEx.Response{body: "OK!", client: :httpoison, retries: 1, status: 200, parsed_body: nil, headers: []}}

  """
  @spec post(String.t(), String.t(), Keyword.t()) :: {:ok, Response.t()} | {:error, Error.t()}
  def post(url, body, options \\ []) when is_binary(url) and is_binary(body) and is_list(options),
    do:
      request(%Request{
        client: Keyword.get(options, :client),
        body: body,
        headers: Keyword.get(options, :headers, []),
        method: :post,
        url: url,
        options: options |> Keyword.delete(:headers) |> Keyword.delete(:client)
      })

  @doc """
  Executes a Request

  ## Examples

      iex> request = %HTTPEx.Request{
      ...>   method: :get,
      ...>   client: :finch,
      ...>   url: "http://www.example.com",
      ...>   options: [backend: MockBackend],
      ...> }
      ...> HTTPEx.request(request)
      {:ok, %HTTPEx.Response{body: "OK!", client: :httpoison, retries: 1, status: 200, parsed_body: nil, headers: []}}

      iex> request = %HTTPEx.Request{
      ...>   method: :post,
      ...>   body: JSON.encode!(%{"data" => true}),
      ...>   url: "http://www.example.com/json",
      ...>   headers:  [{"Content-Type", "application/json"}],
      ...>   options: [backend: MockBackend],
      ...> }
      ...> HTTPEx.request(request)
      {
        :ok,
        %HTTPEx.Response{
          body: "{\\"payload\\":{\\"label\\":\\"ABCD\\"}}",
          client: :httpoison,
          headers: [],
          parsed_body: %{"payload" => %{"label" => "ABCD"}},
          retries: 1,
          status: 200
        }
      }

  """
  @spec request(Request.t()) :: {:ok, Response.t()} | {:error, Error.t()}
  def request(%Request{} = request) do
    # Wraps the entire HTTP call into one single `HTTP` span
    # Each retry will spawn with a `[method]` underneath it.
    Logging.span("HTTP", fn ->
      request
      |> Request.init()
      |> Logging.trace()
      |> request_with_retries()
      |> Logging.trace()
    end)
  end

  def_to_response()

  defp retry?(_request, {:ok, %Response{}}), do: false

  defp retry?(request, {:error, %Error{} = error}) do
    retry_timeout = Keyword.get(request.options, :transport_retry_timeout)

    max_retries = Keyword.get(request.options, :transport_max_retries)

    reached_retries? = request.retries >= max_retries
    time_diff = :erlang.monotonic_time(:millisecond) - request.start_time

    reached_timeout? = time_diff >= retry_timeout

    retry_enabled?() and can_be_retried?(request, error) and
      not reached_retries? and not reached_timeout?
  end

  defp can_be_retried?(%Request{} = request, %Error{status: status}) when is_number(status),
    do: status in Keyword.get(request.options, :retry_status_codes, [])

  defp can_be_retried?(%Request{} = request, %Error{reason: reason}) when is_atom(reason),
    do: reason in Keyword.get(request.options, :retry_error_codes)

  defp can_be_retried?(_request, _error), do: false

  defp request_with_retries(%Request{} = request) do
    # Wrap the actual call in a span underneath the HTTP span with the name of the method
    # This results in the following trace:
    #
    # - HTTP
    #   - POST
    #   - retry_sleep
    #   - POST
    if request.retries >= 2 do
      Logging.span("retry_sleep", fn ->
        Process.sleep(@retry_wait * request.retries)
      end)
    end

    backend = request.options[:backend] || @backend

    response =
      Logging.span(Request.trace_method(request.method), fn ->
        request
        |> Logging.trace()
        |> Logging.log()
        |> backend.request()
        |> to_response(request.retries)
        |> Logging.trace()
        |> Logging.log()
      end)

    if retry?(request, response) do
      request
      |> Request.increase_retries()
      |> request_with_retries()
    else
      response
    end
  end

  defp retry_enabled?, do: Shared.config(:retry, true) == true
end
