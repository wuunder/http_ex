defmodule HTTPEx.Clients.Finch do
  @moduledoc """
  Finch driver
  """

  @doc """
  Function to generate request functions to execute actual Finch requests
  """
  def define_request_functions do
    quote do
      if Code.ensure_loaded?(Finch) do
        def request(%HTTPEx.Request{client: :finch} = request) do
          opts =
            [
              pool_timeout: request.options[:timeout],
              receive_timeout: request.options[:receive_timeout]
            ]
            |> Enum.reject(&is_nil(elem(&1, 1)))

          request.method
          |> Finch.build(request.url, request.headers, request.body)
          |> Finch.request(request.options[:pool], opts)
        end
      end
    end
  end

  @doc """
  Function to generate to_response functions for Finch requests
  """
  def define_to_response_functions do
    quote do
      if Code.ensure_loaded?(Finch) do
        def to_response(
              {:ok, %Finch.Response{status: status, body: body, headers: headers} = response},
              retries
            )
            when status < 400 do
          body = decompress_body(response)

          {:ok,
           %HTTPEx.Response{
             client: :finch,
             status: status,
             body: body,
             parsed_body: parse_body(body),
             headers: headers,
             retries: retries
           }}
        end

        def to_response(
              {:ok, %Finch.Response{status: status, body: body, headers: headers} = response},
              retries
            )
            when status >= 400 do
          body = decompress_body(response)

          {:error,
           %HTTPEx.Error{
             client: :finch,
             reason: Plug.Conn.Status.reason_atom(status),
             status: status,
             body: body,
             parsed_body: parse_body(body),
             headers: headers,
             retries: retries
           }}
        end

        def to_response({:error, %Finch.Error{} = error}, retries),
          do: {:error, %HTTPEx.Error{client: :finch, reason: error.reason, retries: retries}}

        def to_response({:error, %Mint.TransportError{} = error}, retries),
          do: {:error, %HTTPEx.Error{client: :finch, reason: error.reason, retries: retries}}

        def to_response({:error, %Mint.HTTPError{} = error}, retries),
          do: {:error, %HTTPEx.Error{client: :finch, reason: error.reason, retries: retries}}
      end
    end
  end

  @doc """
  Function to generate mock responses
  """
  def define_to_client_response_functions do
    quote do
      if Code.ensure_loaded?(Finch) do
        def to_client_response(:finch, :ok, %{} = response),
          do:
            {:ok,
             %Finch.Response{
               status: response.status_code,
               body: response.body,
               headers: response.headers
             }}

        def to_client_response(:finch, :error, :timeout),
          do: {:error, %Mint.TransportError{reason: :timeout}}

        def to_client_response(:finch, :error, :econnrefused),
          do: {:error, %Mint.TransportError{reason: :econnrefused}}

        def to_client_response(:finch, :error, :closed),
          do: {:error, %Mint.TransportError{reason: :closed}}

        def to_client_response(:finch, :error, reason), do: {:error, %Finch.Error{reason: reason}}
      end
    end
  end
end
