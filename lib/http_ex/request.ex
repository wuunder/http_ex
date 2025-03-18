defmodule HTTPEx.Request do
  @moduledoc false
  @behaviour HTTPEx.Traceable

  alias __MODULE__
  alias HTTPEx.Shared

  @default_allow_redirect true
  @default_retry_error_codes [:closed, :timeout]
  @default_retry_status_codes [500, 502, 503, 504]
  @default_max_retries 3
  @default_retry_timeout 2000

  @enforce_keys [:method, :url]
  defstruct body: "",
            client: nil,
            headers: [],
            method: nil,
            options: [],
            retries: 0,
            start_time: 0,
            url: nil

  @type method() :: :get | :post | :head | :patch | :delete | :options | :put
  @type url() :: String.t() | URI.t()
  @type headers() :: list(tuple())
  @type options() :: Keyword.t()

  @type t() :: %__MODULE__{
          body:
            binary()
            | iodata()
            | {:stream, Enumerable.t()}
            | {:multipart, Enumerable.t()}
            | {:form, Enumerable.t()}
            | nil,
          client: atom(),
          headers: headers(),
          method: method(),
          options: options(),
          retries: non_neg_integer(),
          start_time: number(),
          url: url()
        }

  @doc """
  Initializes the request. Creates a request struct and sets the defaults.

  ## Example

    iex> request = Request.init(%Request{url: "http://www.example.com", method: :get})
    ...> request.options
    [pool: HTTPEx.FinchTestPool, retry_status_codes: [500, 502, 503, 504], retry_error_codes: [:closed, :timeout], transport_max_retries: 3, transport_retry_timeout: 2000, allow_redirects: true]

  """
  @spec init(Request.t()) :: Request.t()
  def init(%Request{} = request) do
    merged_options =
      request.options
      |> Keyword.put_new(
        :allow_redirects,
        Shared.config(:allow_redirect, @default_allow_redirect)
      )
      |> Keyword.put_new(
        :transport_retry_timeout,
        Shared.config(:retry_timeout, @default_retry_timeout)
      )
      |> Keyword.put_new(
        :transport_max_retries,
        Shared.config(:max_retries, @default_max_retries)
      )
      |> Keyword.put_new(
        :retry_error_codes,
        Shared.config(:retry_error_codes, @default_retry_error_codes)
      )
      |> Keyword.put_new(
        :retry_status_codes,
        Shared.config(:retry_status_codes, @default_retry_status_codes)
      )
      |> Keyword.put_new(:pool, Shared.config(:pool))

    %{
      request
      | client: request.client || Shared.config(:client),
        headers: request.headers || [],
        options: merged_options,
        start_time: :erlang.monotonic_time(:millisecond),
        retries: 1
    }
  end

  @doc """
  Increases the number of retries of the request
  """
  @spec increase_retries(Request.t()) :: Request.t()
  def increase_retries(%Request{} = request), do: %{request | retries: request.retries + 1}

  @doc """
  Gets a field from the request

  ## Examples

      iex> request = %Request{url: "http://localhost:5000/test?user_id=1337", method: :post, body: "Response", headers: [{"Content-Type", "application/json"}]}
      iex> Request.get_field(request, :url)
      "http://localhost:5000/test?user_id=1337"
      iex> Request.get_field(request, :method)
      :post
      iex> Request.get_field(request, :host)
      "localhost"
      iex> Request.get_field(request, :headers)
      [{"Content-Type", "application/json"}]
      iex> Request.get_field(request, :port)
      5000
      iex> Request.get_field(request, :path)
      "/test"
      iex> request = %Request{url: "http://localhost:5000?user_id=1337", method: :post, body: "Response", headers: [{"Content-Type", "application/json"}]}
      iex> Request.get_field(request, :path)
      "/"
      iex> Request.get_field(request, :query)
      %{"user_id" => "1337"}
  """
  @spec get_field(Request.t(), atom()) :: any()
  def get_field(%Request{} = request, field) when field in [:query, :host, :port, :path] do
    value =
      request.url
      |> URI.parse()
      |> Map.get(field)

    case field do
      :query ->
        value
        |> to_string()
        |> URI.decode_query()

      :path ->
        value || "/"

      _ ->
        value
    end
  end

  def get_field(%Request{} = request, field) when is_atom(field) and is_map_key(request, field),
    do: Map.get(request, field)

  @impl true
  @spec summary(Request.t()) :: String.t()
  def summary(%Request{} = request) do
    """
    #{Shared.header("HTTP request")}

    #{Shared.attr("Client")} #{Shared.value(request.client)}
    #{Shared.attr("Retry")} ##{Shared.value(request.retries)}
    #{Shared.attr("URL")} #{Shared.value(request.url)}
    #{Shared.attr("Method")} #{Shared.value(request.method)}
    #{Shared.attr("Headers")}

    #{Shared.value(request.headers)}

    #{Shared.attr("Body")}

    #{Shared.value(request.body)}
    """
  end

  @doc """
  Returns the OT attributes for the HTTP request
  """
  @impl true
  @spec trace_attrs(Request.t()) :: list({String.t(), any()})
  def trace_attrs(%Request{} = request) do
    uri = URI.parse(request.url)

    Shared.trace_attrs([
      {"http.method", trace_method(request.method)},
      {"http.host", uri.host},
      {"http.path", uri.path},
      {"http.query", uri.query},
      {"http.url", request.url},
      {"http.target", "#{uri.path}?#{uri.query}"},
      {"http.scheme", to_string(uri.scheme)},
      {"http.request_body", request.body},
      {"http.request_headers", inspect(request.headers)}
    ])
  end

  @spec trace_method(atom() | String.t()) :: String.t()
  def trace_method(method) when is_atom(method) or is_binary(method),
    do: String.upcase("#{method}")
end
