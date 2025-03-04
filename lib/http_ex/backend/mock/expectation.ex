defmodule HTTPEx.Backend.Mock.Expectation do
  @moduledoc """
  Defines a HTTP mock expectation.
  Consists of a matching part and an expectation part.
  """
  @behaviour HTTPEx.Traceable

  import HTTPEx.Clients, only: [def_to_client_response: 0]

  alias HTTPEx.Backend.Mock.XML
  alias __MODULE__
  alias HTTPEx.Request
  alias HTTPEx.Shared

  defstruct calls: 0,
            description: nil,
            expects: %{
              body: :any,
              headers: :any,
              path: :any,
              query: :any
            },
            global: false,
            index: 0,
            matchers: %{
              body: :any,
              headers: :any,
              host: :any,
              method: :any,
              path: :any,
              port: :any,
              query: :any
            },
            max_calls: 1,
            min_calls: 1,
            priority: 0,
            response: %{status: 200, body: "OK"},
            type: :assertion

  @type string_formats() :: :json | :xml

  @type func_matcher() :: (Request.t() -> boolean()) | (Request.t() -> {boolean(), map()})
  @type string_matcher() :: String.t()
  @type string_with_format_matcher() :: {String.t(), string_formats()}
  @type regex_matcher() :: Regex.t()
  @type wildcard_matcher() :: :any
  @type keyword_list_matcher() :: list({String.t(), String.t() | Regex.t()})
  @type map_matcher() :: map()
  @type enum_matcher() :: atom()
  @type int_matcher() :: integer()

  @type matcher() ::
          func_matcher()
          | string_matcher()
          | string_with_format_matcher()
          | regex_matcher()
          | wildcard_matcher()
          | keyword_list_matcher()
          | map_matcher()
          | enum_matcher()
          | int_matcher()

  @type matcher_field_type() ::
          :func
          | :string
          | :string_with_format
          | :regex
          | :wildcard
          | :keyword_list
          | :map
          | :enum
          | :int

  @type match_result() :: {boolean(), list(atom()), list(atom()), map()}
  @type expects_result() :: {boolean(), list(atom()), list(atom())}

  @type response_map() :: %{
          :status => Plug.Conn.status(),
          :body => String.t(),
          optional(:headers) => list(),
          optional(:replace_body_vars) => boolean()
        }

  @type response_error() :: {:error, atom()}

  @type response_func() :: (Request.t() -> response_map() | response_error())

  @type http_response() :: {:ok, struct()} | {:error, struct()}

  @type t() :: %__MODULE__{
          calls: non_neg_integer(),
          description: String.t() | nil,
          expects: %{
            body:
              func_matcher()
              | string_matcher()
              | string_with_format_matcher()
              | regex_matcher()
              | wildcard_matcher(),
            headers: keyword_list_matcher() | wildcard_matcher(),
            path: string_matcher() | regex_matcher() | wildcard_matcher(),
            query: map_matcher() | wildcard_matcher()
          },
          global: boolean(),
          index: non_neg_integer(),
          matchers: %{
            body:
              func_matcher()
              | string_matcher()
              | string_with_format_matcher()
              | regex_matcher()
              | wildcard_matcher(),
            headers: func_matcher() | keyword_list_matcher() | wildcard_matcher(),
            host: func_matcher() | string_matcher() | regex_matcher() | wildcard_matcher(),
            method: enum_matcher() | wildcard_matcher(),
            path: func_matcher() | string_matcher() | regex_matcher() | wildcard_matcher(),
            port: int_matcher() | wildcard_matcher(),
            query: func_matcher() | map_matcher() | wildcard_matcher()
          },
          max_calls: non_neg_integer() | :infinity,
          min_calls: non_neg_integer(),
          priority: non_neg_integer(),
          response: response_func() | response_map() | response_error(),
          type: :assertion | :stub
        }

  @matcher_fields %{
    body: [:func, :string, :string_with_format, :regex, :wildcard],
    headers: [:func, :keyword_list, :wildcard],
    host: [:func, :string, :regex, :wildcard],
    method: [{:enum, [:post, :get]}, :wildcard],
    path: [:func, :string, :regex, :wildcard],
    port: [:int, :wildcard],
    query: [:func, :map, :wildcard]
  }

  @expects_fields %{
    body: [:func, :string, :string_with_format, :regex, :wildcard],
    headers: [:func, :keyword_list, :wildcard],
    path: [:func, :string, :regex, :wildcard],
    query: [:func, :map, :wildcard]
  }

  @doc """
  Builds an Expectation struct from the given Keyword list

  ## Options

  - description
  - method
  - endpoint
  - body
  - headers
  - host
  - path
  - port
  - query
  - expect_body
  - expect_headers
  - expect_path
  - expect_query
  - calls

  ## Examples

      iex> Expectation.new!(method: :get, endpoint: "http://www.example.com", response: %{status: 200, body: "OK"}, type: :assert)
      %Expectation{matchers: %{host: "www.example.com", method: :get, path: "/", port: 80, body: :any, headers: :any, query: :any}, type: :assertion}

  """
  @spec new!(Keyword.t()) :: Expectation.t()
  def new!(opts) when is_list(opts) do
    type = Keyword.fetch!(opts, :type)

    {min_calls, max_calls} =
      case type do
        :stub -> {0, :infinity}
        :reject -> {0, 0}
        :assert -> {1, Keyword.get(opts, :calls, 1)}
      end

    expectation_type =
      if type == :stub do
        :stub
      else
        :assertion
      end

    global = Keyword.get(opts, :global, false)

    match_method = Keyword.get(opts, :method, :any)

    match_uri =
      if is_binary(Keyword.get(opts, :endpoint)) do
        opts
        |> Keyword.get(:endpoint)
        |> URI.parse()
      else
        %URI{}
      end

    match_body = Keyword.get(opts, :body, :any)
    match_headers = Keyword.get(opts, :headers, :any)
    match_host = Keyword.get(opts, :host, match_uri.host)
    match_path = Keyword.get(opts, :path, match_uri.path || "/")
    match_port = Keyword.get(opts, :port, match_uri.port || :any)
    match_query = Keyword.get(opts, :query, URI.decode_query(match_uri.query || ""))

    match_query =
      if match_query == %{} do
        :any
      else
        match_query
      end

    expect_body = Keyword.get(opts, :expect_body, :any)
    expect_headers = Keyword.get(opts, :expect_headers, :any)
    expect_path = Keyword.get(opts, :expect_path, :any)
    expect_query = Keyword.get(opts, :expect_query, :any)

    if (type == :assert || type == :reject) &&
         (match_host == :any || match_port == :any || match_path == :any) do
      raise ArgumentError, "Assertions requires at least a matcher on hostname, port and path"
    end

    if type == :assert && max_calls < 1 do
      raise ArgumentError, "Assertions are required to be called at least one time"
    end

    if type == :reject &&
         (expect_body != :any || expect_headers != :any || expect_path != :any ||
            expect_query != :any) do
      raise ArgumentError, "Rejected calls cannot have any expections configured"
    end

    response = Keyword.get(opts, :response)

    if type == :reject && response,
      do: raise(ArgumentError, "Rejected calls cannot have a response")

    if type != :reject && !response,
      do: raise(ArgumentError, "A response is required for a stub or assertion")

    if type != :reject, do: validate_response_option!(response)

    %Expectation{
      description: opts[:description],
      global: global,
      min_calls: min_calls,
      max_calls: max_calls,
      response: response,
      type: expectation_type
    }
    |> set_expect!(:body, expect_body)
    |> set_expect!(:headers, expect_headers)
    |> set_expect!(:path, expect_path)
    |> set_expect!(:query, expect_query)
    |> set_match!(:body, match_body)
    |> set_match!(:headers, match_headers)
    |> set_match!(:host, match_host)
    |> set_match!(:method, match_method)
    |> set_match!(:path, match_path)
    |> set_match!(:port, match_port)
    |> set_match!(:query, match_query)
  end

  @impl true
  @spec summary(Expectation.t()) :: String.t()
  def summary(%Expectation{} = expectation) do
    """
      #{Shared.header("HTTP expectation ##{expectation.index}")}

      #{Shared.attr("Description")} #{Shared.value(expectation.description)}

      #{Shared.attr("Calls")} ##{expectation.calls}
      #{Shared.attr("Min calls")} #{Shared.value(expectation.min_calls)}
      #{Shared.attr("Max calls")} #{Shared.value(expectation.max_calls)}

      #{Shared.attr("Matchers")}

      #{Shared.attr("Host")} #{Shared.value(expectation.matchers.host)}
      #{Shared.attr("Port")} #{Shared.value(expectation.matchers.port)}
      #{Shared.attr("Method")} #{Shared.value(expectation.matchers.method)}
      #{Shared.attr("Path")} #{Shared.value(expectation.matchers.path)}
      #{Shared.attr("Query")} #{Shared.value(expectation.matchers.query)}
      #{Shared.attr("Headers")} #{Shared.value(expectation.matchers.headers)}
      #{Shared.attr("Body")}

      #{Shared.value(expectation.matchers.body)}

      #{Shared.attr("Expectations")}

      #{Shared.attr("Path")} #{Shared.value(expectation.expects.path)}
      #{Shared.attr("Query")} #{Shared.value(expectation.expects.query)}
      #{Shared.attr("Headers")} #{Shared.value(expectation.expects.headers)}
      #{Shared.attr("Body")}

      #{Shared.value(expectation.expects.body)}

      #{Shared.attr("Response")}

      #{Shared.value(expectation.response)}
    """
  end

  @doc """
  Sets matcher field for given Expectation

  ## Examples

      iex> Expectation.set_match!(%Expectation{}, :host, "localhost")
      %Expectation{matchers: %{body: :any, headers: :any, host: "localhost", method: :any, path: :any, port: :any, query: :any}}

      iex> Expectation.set_match!(%Expectation{}, :body, "OK!")
      %Expectation{matchers: %{body: "OK!", headers: :any, host: :any, method: :any, path: :any, port: :any, query: :any}}

      iex> Expectation.set_match!(%Expectation{}, :body, {"{}", :json})
      %Expectation{matchers: %{body: {"{}", :json}, headers: :any, host: :any, method: :any, path: :any, port: :any, query: :any}}

      iex> Expectation.set_match!(%Expectation{}, :body, {"<test>a</test>", :xml})
      %Expectation{matchers: %{body: {"<test>a</test>", :xml}, headers: :any, host: :any, method: :any, path: :any, port: :any, query: :any}}

      iex> Expectation.set_match!(%Expectation{}, :host, nil)
      ** (ArgumentError) Invalid type used for matcher field `host`

      iex> Expectation.set_match!(%Expectation{}, :unknown, :any)
      ** (ArgumentError) Unknown matcher field `unknown`

  """
  @spec set_match!(Expectation.t(), atom(), matcher()) :: Expectation.t()
  def set_match!(%Expectation{} = expectation, field, value) when is_atom(field) do
    case validate_matcher_value(field, value) do
      :ok ->
        %{expectation | matchers: Map.put(expectation.matchers, field, value)}

      {:error, :unknown_field} ->
        raise ArgumentError, "Unknown matcher field `#{field}`"

      {:error, :invalid_field_type} ->
        raise ArgumentError, "Invalid type used for matcher field `#{field}`"
    end
  end

  @doc """
  Sets expects field for given Expectation

  ## Examples

      iex> Expectation.set_expect!(%Expectation{}, :body, "ok!")
      %Expectation{expects: %{body: "ok!", headers: :any, path: :any, query: :any}}

      iex> Expectation.set_expect!(%Expectation{}, :body, nil)
      ** (ArgumentError) Invalid type used for expects field `body`

      iex> Expectation.set_expect!(%Expectation{}, :unknown, nil)
      ** (ArgumentError) Unknown expects field `unknown`

  """
  @spec set_expect!(Expectation.t(), atom(), matcher()) :: Expectation.t()
  def set_expect!(%Expectation{} = expectation, field, value) when is_atom(field) do
    case validate_expects_value(field, value) do
      :ok ->
        %{expectation | expects: Map.put(expectation.expects, field, value)}

      {:error, :unknown_field} ->
        raise ArgumentError, "Unknown expects field `#{field}`"

      {:error, :invalid_field_type} ->
        raise ArgumentError, "Invalid type used for expects field `#{field}`"
    end
  end

  @doc """
  Increases the calls counter in Expectation

  ## Example

      iex> expectation = %Expectation{}
      ...> expectation.calls
      0
      iex> expectation = Expectation.increase_call(expectation)
      ...> expectation.calls
      1

  """
  @spec increase_call(Expectation.t()) :: Expectation.t()
  def increase_call(%Expectation{} = expectation),
    do: %{expectation | calls: expectation.calls + 1}

  @doc """
  Gets matcher field from given Expectation

  ## Examples

      iex> expectation = Expectation.set_match!(%Expectation{}, :host, "localhost")
      iex> Expectation.get_match(expectation, :host)
      "localhost"
      iex> Expectation.get_match(expectation, :headers)
      :any

      iex> expectation = Expectation.set_match!(%Expectation{}, :path, fn _request -> true end)
      iex> is_function(Expectation.get_match(expectation, :path))
      true

  """
  @spec get_match(Expectation.t(), atom()) :: matcher()
  def get_match(%Expectation{matchers: matchers}, key)
      when is_atom(key) and is_map_key(matchers, key),
      do: Map.get(matchers, key)

  @doc """
  Gets expects field from given Expectation

  ## Examples

      iex> expectation = Expectation.set_expect!(%Expectation{}, :body, "OK!")
      iex> Expectation.get_expect(expectation, :body)
      "OK!"
      iex> Expectation.get_expect(expectation, :path)
      :any

  """
  @spec get_expect(Expectation.t(), atom()) :: matcher()
  def get_expect(%Expectation{expects: expects}, key)
      when is_atom(key) and is_map_key(expects, key),
      do: Map.get(expects, key)

  @doc """
  Validates if the field with the given value is allowed as a matcher

  ## Examples

  A string matcher:

      iex> Expectation.validate_matcher_value(:host, "localhost")
      :ok

  You can also use a function and either return a true/false:

      iex> Expectation.validate_matcher_value(:host, fn _request -> true end)
      :ok

  Note, that the function has to have an arity of one.
  Other function arity's will return an error:

      iex> Expectation.validate_matcher_value(:host, fn -> true end)
      {:error, :invalid_field_type}

  You can also supply regexes:

      iex> Expectation.validate_matcher_value(:path, Regex.compile!("http://localhost:5000/*"))
      :ok

  A wildcard:

      iex> Expectation.validate_matcher_value(:path, :any)
      :ok

  Match keyword lists with String.t() values on both sides:

      iex> Expectation.validate_matcher_value(:headers, [{"Content-Type", "application/json"}])
      :ok

  Or with a Regex.t():

      iex> Expectation.validate_matcher_value(:headers, [{"Content-Type", ~r/application/}])
      :ok

  Invalid lists, tuples. types are not valid:

      iex> Expectation.validate_matcher_value(:headers, [{"Content-Type", :value}])
      {:error, :invalid_field_type}

      iex> Expectation.validate_matcher_value(:headers, [])
      {:error, :invalid_field_type}

      iex> Expectation.validate_matcher_value(:headers, [{"Content-Type", "Value", "Other-Value"}])
      {:error, :invalid_field_type}

      iex> Expectation.validate_matcher_value(:headers, "Content-Type: application/json")
      {:error, :invalid_field_type}

  Some fields require an enum, like `method`:

      iex> Expectation.validate_matcher_value(:method, :post)
      :ok

      iex> Expectation.validate_matcher_value(:method, :get)
      :ok

      iex> Expectation.validate_matcher_value(:method, "get")
      {:error, :invalid_field_type}

  You can also match a map. This is useful if you want to match query params:

      iex> Expectation.validate_matcher_value(:query, %{"user_id" => "1234"})
      :ok

      iex> Expectation.validate_matcher_value(:query, %{user_id: "1234"})
      {:error, :invalid_field_type}

      iex> Expectation.validate_matcher_value(:query, %{})
      {:error, :invalid_field_type}

  """
  @spec validate_matcher_value(atom(), matcher()) :: :ok | {:error, atom()}
  def validate_matcher_value(field, value) when is_atom(field) do
    with :ok <- validate_field(@matcher_fields, field) do
      validate_field_value_type(@matcher_fields, field, value)
    end
  end

  @doc """
  Validates if the field with the given value is allowed as an expects
  """
  @spec validate_expects_value(atom(), matcher()) :: :ok | {:error, atom()}
  def validate_expects_value(field, value) when is_atom(field) do
    with :ok <- validate_field(@expects_fields, field) do
      validate_field_value_type(@expects_fields, field, value)
    end
  end

  @doc """
  Looks up which type the given matcher field is

  ## Examples

      iex> Expectation.get_matcher_type(:host, "localhost")
      :string

      iex> Expectation.get_matcher_type(:body, {"{}", :json})
      :string_with_format

      iex> Expectation.get_matcher_type(:body, {"<a>b</a>", :xml})
      :string_with_format

      iex> Expectation.get_matcher_type(:host, fn _request -> true end)
      :func

      iex> Expectation.get_matcher_type(:query, %{"user_id" => "1234"})
      :map

      iex> Expectation.get_matcher_type(:headers, [{"Content-Type", "application/json"}])
      :keyword_list

      iex> Expectation.get_matcher_type(:path, :any)
      :wildcard

      iex> Expectation.get_matcher_type(:port, 1337)
      :int

      iex> Expectation.get_matcher_type(:path, ~r/api/)
      :regex

      iex> Expectation.get_matcher_type(:method, :post)
      :enum

      iex> Expectation.get_matcher_type(:method, :get)
      :enum

  """
  @spec get_matcher_type(atom(), matcher()) :: matcher_field_type()
  def get_matcher_type(field, value) when is_atom(field) and not is_nil(value) do
    possible_types = Map.get(@matcher_fields, field)

    type =
      Enum.find(possible_types, fn type ->
        valid_value_of_type?(value, type)
      end)

    case type do
      {type, _opts} -> type
      type -> type
    end
  end

  @doc """
  Tests if the request matches all fields.

  The `match_request` function will always return a tuple with a boolean,
  the fields that matched, and a map with collected variables
  from regexes or :func matchers that were executed.

  These vars can be used in responses to replace placeholders in responses.

  ## Examples

  A complex example, mixing different matchers:

      iex> expectation =
      ...>   %Expectation{}
      ...>   |> Expectation.set_match!(:host, "www.example.com")
      ...>   |> Expectation.set_match!(:port, 80)
      ...>   |> Expectation.set_match!(:body, fn %Request{} = request -> {String.contains?(request.body, "OK"), %{"var" => 1}} end)
      ...>   |> Expectation.set_match!(:headers, [{"secret", "123"}])
      ...>   |> Expectation.set_match!(:path, Regex.compile!("api/(?<api_version>[^/]+)/path"))
      ...>   |> Expectation.set_match!(:query, %{"user_id" => "1337"})
      ...>   |> Expectation.set_match!(:method, :post)
      iex> Expectation.match_request(
      ...>   %Request{
      ...>     url: "http://www.example.com/api/v1/path/test?token=XYZ&user_id=1337",
      ...>     body: "Payload OK!",
      ...>     headers: [{"app", "test"}, {"secret", "123"}],
      ...>     method: :post
      ...>   },
      ...>   expectation
      ...> )
      {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{"api_version" => "v1", "var" => 1}}
      iex> Expectation.match_request(
      ...>   %Request{
      ...>     url: "http://www.example.co/api/v2/path/test?token=XYZ",
      ...>     body: "Payload OK!",
      ...>     headers: [{"app", "test"}, {"secret", "123"}],
      ...>     method: :post
      ...>   },
      ...>   expectation
      ...> )
      {false, [:method, :headers, :body, :path, :port], [:host, :query], %{"api_version" => "v2", "var" => 1}}

  A couple of examples using the body formatters.

  JSON:

      iex> payload = JSON.encode!(%{username: "test"})
      ...> formatted_payload = JSON.encode!(%{username: "test"})
      iex> expectation =
      ...>   %Expectation{}
      ...>   |> Expectation.set_match!(:host, "www.example.com")
      ...>   |> Expectation.set_match!(:port, 80)
      ...>   |> Expectation.set_match!(:body, {formatted_payload, :json})
      ...>   |> Expectation.set_match!(:method, :post)
      iex> Expectation.match_request(
      ...>   %Request{
      ...>     url: "http://www.example.com/api/v1/path/test?token=XYZ&user_id=1337",
      ...>     body: payload,
      ...>     method: :post
      ...>   },
      ...>   expectation
      ...> )
      {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}

    XML:

        iex> payload = "<test>data</test>"
        ...> formatted_payload = "<test>\\n  data\\n</test>"
        iex> expectation =
        ...>   %Expectation{}
        ...>   |> Expectation.set_match!(:host, "www.example.com")
        ...>   |> Expectation.set_match!(:port, 80)
        ...>   |> Expectation.set_match!(:body, {formatted_payload, :xml})
        ...>   |> Expectation.set_match!(:method, :post)
        iex> Expectation.match_request(
        ...>   %Request{
        ...>     url: "http://www.example.com/api/v1/path/test?token=XYZ&user_id=1337",
        ...>     body: payload,
        ...>     method: :post
        ...>   },
        ...>   expectation
        ...> )
        {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
  """
  @spec match_request(Request.t(), Expectation.t()) :: match_result()
  def match_request(%Request{} = request, %Expectation{} = expectation) do
    fields = Map.keys(@matcher_fields)

    {matching_fields, vars} =
      Enum.reduce(fields, {[], %{}}, fn field, {all_fields, all_vars} ->
        match_value = get_match(expectation, field)
        type = get_matcher_type(field, match_value)
        request_value = get_request_value(request, field, type)

        case match_value(type, match_value, request_value) do
          {true, vars} -> {[field | all_fields], Map.merge(all_vars, vars)}
          true -> {[field | all_fields], all_vars}
          false -> {all_fields, all_vars}
        end
      end)

    {length(fields) == length(matching_fields), matching_fields, fields -- matching_fields, vars}
  end

  @doc """
  Finds the expectation that matches the given Request.t()

  ## Example

      iex> expectation_1 =
      ...>   %Expectation{index: 0}
      ...>   |> Expectation.set_match!(:host, "www.example.com")
      ...>   |> Expectation.set_match!(:port, 80)
      ...>
      ...> expectation_2 =
      ...>   %Expectation{index: 1}
      ...>   |> Expectation.set_match!(:host, "www.example.com")
      ...>   |> Expectation.set_match!(:path, Regex.compile!("api/(?<api_version>[^/]+)/path/*"))
      ...>   |> Expectation.set_match!(:port, 80)
      ...>
      ...> expectations = [expectation_1, expectation_2]
      ...>
      ...> {:ok, match, vars} =
      ...>   Expectation.find_matching_expectation(
      ...>     expectations,
      ...>     %Request{
      ...>       url: "http://www.example.com/api/v1/path/test?token=XYZ&user_id=1337",
      ...>       body: "Payload OK!",
      ...>       headers: [{"app", "test"}, {"secret", "123"}],
      ...>       method: :post
      ...>     }
      ...>   )
      ...>
      ...> match == expectation_2
      true
      iex> vars
      %{"api_version" => "v1"}
      iex> {:ok, match, vars} =
      ...>   Expectation.find_matching_expectation(
      ...>     expectations,
      ...>     %Request{
      ...>       url: "http://www.example.com/another-path",
      ...>       body: "Payload OK!",
      ...>       headers: [{"app", "test"}, {"secret", "123"}],
      ...>       method: :post
      ...>     }
      ...>   )
      ...>
      ...> match == expectation_1
      true
      iex> vars
      %{}

  """
  @spec find_matching_expectation(list(Expectation.t()), Request.t()) ::
          {:ok, Expectation.t(), map()} | {:error, atom()} | {:error, atom(), Expectation.t()}
  def find_matching_expectation(expectations, %Request{} = request)
      when is_list(expectations) do
    matching_expectations =
      expectations
      |> Enum.map(fn expectation -> {expectation, match_request(request, expectation)} end)
      |> Enum.filter(fn {_expectation, match_result} ->
        case match_result do
          {true, _matches, _misses, _vars} -> true
          _ -> false
        end
      end)

    sorted_expectations =
      Enum.sort_by(
        matching_expectations,
        fn {expectation, match_result} ->
          {true, fields, _misses, _vars} = match_result

          {length(fields), expectation.priority, expectation.index}
        end,
        :desc
      )

    matching_expectation =
      sorted_expectations
      |> Enum.filter(fn {expectation, _match_result} ->
        expectation.max_calls == :infinity || expectation.calls < expectation.max_calls
      end)
      |> List.first()

    cond do
      Enum.empty?(matching_expectations) ->
        {:error, :no_matches}

      is_nil(matching_expectation) ->
        {expectation, _} = List.first(sorted_expectations)
        {:error, :max_calls_reached, expectation}

      true ->
        {expectation, {true, _matches, _misses, vars}} = matching_expectation
        {:ok, expectation, vars}
    end
  end

  @spec validate_expectations(Request.t(), Expectation.t()) ::
          :ok | {:error, atom(), list(atom())}
  def validate_expectations(%Request{} = request, %Expectation{} = expectation) do
    case match_expects(request, expectation) do
      {true, _, _} -> :ok
      {false, _, missed} -> {:error, :expectations_not_met, missed}
    end
  end

  @doc """
  Tests if the request mets all defined expectations.

  The `match_expects` function will always return a tuple with a boolean
  and a list of fields that did not match.

  ## Examples

  A complex example, mixing different matchers:

      iex> expectation =
      ...>   %Expectation{}
      ...>   |> Expectation.set_expect!(:body, fn %Request{} = request -> {String.contains?(request.body, "OK"), %{"var" => 1}} end)
      ...>   |> Expectation.set_expect!(:headers, [{"secret", "123"}])
      ...>   |> Expectation.set_expect!(:path, Regex.compile!("api/(?<api_version>[^/]+)/path"))
      ...>   |> Expectation.set_expect!(:query, %{"user_id" => "1337"})
      iex> Expectation.match_expects(
      ...>   %Request{
      ...>     url: "http://www.example.com/api/v1/path/test?token=XYZ&user_id=1337",
      ...>     body: "Payload OK!",
      ...>     headers: [{"app", "test"}, {"secret", "123"}],
      ...>     method: :post
      ...>   },
      ...>   expectation
      ...> )
      {true, [:path, :body, :query, :headers], []}
      iex> Expectation.match_expects(
      ...>   %Request{
      ...>     url: "http://www.example.com/api/v1/path/test?token=XYZ&user_id=1339",
      ...>     body: "Some error",
      ...>     headers: [{"app", "test"}, {"geheim", "123"}],
      ...>     method: :post
      ...>   },
      ...>   expectation
      ...> )
      {false, [:path], [:body, :query, :headers]}

  """
  @spec match_expects(Request.t(), Expectation.t()) :: expects_result()
  def match_expects(%Request{} = request, %Expectation{} = expectation) do
    fields = Map.keys(@expects_fields)

    matching_fields =
      Enum.filter(fields, fn field ->
        expect_value = get_expect(expectation, field)
        type = get_matcher_type(field, expect_value)
        request_value = get_request_value(request, field, type)

        case match_value(type, expect_value, request_value) do
          {true, _vars} -> true
          true -> true
          false -> false
        end
      end)

    {length(fields) == length(matching_fields), matching_fields, fields -- matching_fields}
  end

  @doc """
  Generates a fake response from a map, an error tuple or a http driver struct.
  Replaces any vars if a response map has the option `replace_body_vars` set to `true`.

  The response can also be a function. This function receives a Request.t() and must return
  a valid response().
  """
  def to_response(%Request{} = request, %Expectation{response: fun}, %{} = vars)
      when is_function(fun, 1) do
    request
    |> fun.()
    |> parse_response(vars, request.client)
  end

  def to_response(%Request{} = request, %Expectation{response: fun}, %{} = vars)
      when is_function(fun, 2) do
    request
    |> fun.(vars)
    |> parse_response(vars, request.client)
  end

  def to_response(%Request{} = request, %Expectation{response: response}, %{} = vars),
    do: parse_response(response, vars, request.client)

  def_to_client_response()

  defp parse_response(%{status: status, body: body} = response, %{} = vars, client)
       when is_integer(status) and is_binary(body) do
    body =
      if response[:replace_body_vars] do
        Enum.reduce(vars, body, fn {key, value}, body ->
          String.replace(body, "{{#{key}}}", value)
        end)
      else
        body
      end

    to_client_response(client, :ok, %{
      status_code: status,
      body: body,
      headers: response[:headers] || []
    })
  end

  defp parse_response({:error, reason}, %{}, client),
    do: to_client_response(client, :error, reason)

  defp get_request_value(%Request{} = request, _field, :func), do: request

  defp get_request_value(%Request{} = request, field, _type),
    do: Request.get_field(request, field)

  defp match_value(:func, func, %Request{} = request) when is_function(func) do
    case func.(request) do
      true -> true
      {true, %{} = vars} -> {true, vars}
      _ -> false
    end
  end

  defp match_value(:wildcard, _matcher, _value_to_match), do: true

  defp match_value(:regex, %Regex{} = regex, value_to_match) do
    if Regex.match?(regex, "#{value_to_match}") do
      {true, Regex.named_captures(regex, "#{value_to_match}")}
    else
      false
    end
  end

  defp match_value(:string, matcher, value_to_match)
       when is_binary(matcher) and is_binary(value_to_match),
       do:
         String.downcase(String.trim(matcher)) ==
           String.downcase(String.trim("#{value_to_match}"))

  defp match_value(:string_with_format, {matcher, :json}, value_to_match)
       when is_binary(matcher) and is_binary(value_to_match),
       do: JSON.decode!(matcher) == JSON.decode!(value_to_match)

  defp match_value(:string_with_format, {matcher, :xml}, value_to_match)
       when is_binary(matcher) and is_binary(value_to_match),
       do: XML.normalize(matcher) == XML.normalize(value_to_match)

  defp match_value(:int, matcher, value_to_match)
       when is_integer(matcher) and is_integer(value_to_match),
       do: matcher === value_to_match

  defp match_value(:map, %{} = matcher, %{} = value_to_match) do
    Enum.all?(matcher, fn {key, value} ->
      Map.has_key?(value_to_match, key) && Map.get(value_to_match, key) == value
    end)
  end

  defp match_value(:keyword_list, matcher, value_to_match)
       when is_list(matcher) and is_list(value_to_match) do
    Enum.all?(matcher, fn {key, value} ->
      case List.keyfind(value_to_match, key, 0) do
        {_key, actual_value} ->
          (match?(%Regex{}, value) && Regex.match?(value, actual_value)) || actual_value == value

        _ ->
          false
      end
    end)
  end

  defp match_value(:enum, matcher, value_to_match)
       when not is_nil(matcher) and not is_nil(value_to_match),
       do: matcher === value_to_match

  defp match_value(_type, _matcher, _value_to_match), do: false

  defp validate_field(definition, field) do
    if Map.has_key?(definition, field) do
      :ok
    else
      {:error, :unknown_field}
    end
  end

  defp validate_field_value_type(%{} = definition, field, value) do
    if Enum.any?(definition[field], &valid_value_of_type?(value, &1)) do
      :ok
    else
      {:error, :invalid_field_type}
    end
  end

  defp valid_value_of_type?(value, :wildcard), do: value == :any
  defp valid_value_of_type?(value, :func), do: is_function(value, 1)
  defp valid_value_of_type?(value, :string), do: is_binary(value)

  defp valid_value_of_type?({value, :json}, :string_with_format) when is_binary(value), do: true

  defp valid_value_of_type?({value, :xml}, :string_with_format) when is_binary(value), do: true

  defp valid_value_of_type?({value, :form}, :string_with_format) when is_map(value), do: true
  defp valid_value_of_type?(_value, :string_with_format), do: false

  defp valid_value_of_type?(value, {:enum, allowed}) when is_list(allowed),
    do: Enum.member?(allowed, value)

  defp valid_value_of_type?(value, :int), do: is_integer(value)

  defp valid_value_of_type?(value, :map),
    do: is_map(value) && Enum.any?(value) && not Shared.only_atom_keys?(value)

  defp valid_value_of_type?(value, :regex) do
    case value do
      %Regex{} -> true
      _ -> false
    end
  end

  defp valid_value_of_type?([_head | _tail] = value, :keyword_list) when is_list(value) do
    Enum.all?(value, fn item ->
      case item do
        {key, value} when is_binary(key) and (is_binary(value) or is_struct(value, Regex)) -> true
        _ -> false
      end
    end)
  end

  defp valid_value_of_type?(_value, :keyword_list), do: false

  defp validate_response_option!(%{} = response) do
    if not Map.has_key?(response, :body), do: raise(ArgumentError, "Response requires a body")

    if not Map.has_key?(response, :status),
      do: raise(ArgumentError, "Response requires a status code")

    if not is_binary(response[:body]),
      do: raise(ArgumentError, "Response body should contain a binary")

    if not is_binary(response[:body]),
      do: raise(ArgumentError, "Response body should contain a binary")

    if not is_integer(response[:status]),
      do: raise(ArgumentError, "Response status should be an integer")

    if Map.has_key?(response, :headers) and not is_list(response[:headers]),
      do: raise(ArgumentError, "Response headers should be a list with tuples")

    :ok
  end

  defp validate_response_option!(%{status: _, body: _}), do: :ok
  defp validate_response_option!(response) when is_function(response, 1), do: :ok

  defp validate_response_option!({:error, reason}) when is_atom(reason) and not is_nil(reason),
    do: :ok

  defp validate_response_option!(_),
    do: raise(ArgumentError, "Invalid response given to expectation")
end
