defmodule HTTPEx.Clients.HTTPoison do
  @moduledoc """
  HTTPoison driver
  """

  @doc """
  Function to generate request functions to execute actual HTTPoison requests
  """
  def define_request_functions do
    quote do
      if Code.ensure_loaded?(HTTPoison) do
        def request(%HTTPEx.Request{client: :httpoison} = request) do
          opts =
            [
              timeout: request.options[:timeout],
              recv_timeout: request.options[:receive_timeout],
              ssl: request.options[:ssl],
              follow_redirect: request.options[:follow_redirect]
            ]
            |> Enum.reject(&is_nil(elem(&1, 1)))

          HTTPoison.request(
            request.method,
            request.url,
            request.body,
            request.headers,
            opts
          )
        end
      end
    end
  end

  @doc """
  Function to generate request_options functions for HTTPoison requests
  """
  def define_request_options_functions do
    quote do
      if Code.ensure_loaded?(HTTPoison) do
        def request_options(%HTTPEx.Request{client: :httpoison} = request) do
          [
            timeout: request.options[:timeout],
            recv_timeout: request.options[:receive_timeout],
            ssl: request.options[:ssl]
          ]
          |> Enum.reject(&is_nil(elem(&1, 1)))
        end
      end
    end
  end

  @doc """
  Function to generate to_response functions for HTTPoison requests
  """
  def define_to_response_functions do
    quote do
      if Code.ensure_loaded?(HTTPoison) do
        def to_response(
              {:ok,
               %HTTPoison.Response{status_code: status, body: body, headers: headers} = response},
              retries
            )
            when status < 400 do
          body = decompress_body(response)

          {:ok,
           %HTTPEx.Response{
             client: :httpoison,
             status: status,
             body: body,
             parsed_body: parse_body(body),
             headers: headers,
             retries: retries
           }}
        end

        def to_response(
              {:ok,
               %HTTPoison.Response{status_code: status, body: body, headers: headers} = response},
              retries
            )
            when status >= 400 do
          body = decompress_body(response)

          {:error,
           %HTTPEx.Error{
             client: :httpoison,
             reason: Plug.Conn.Status.reason_atom(status),
             status: status,
             body: body,
             parsed_body: parse_body(body),
             headers: headers,
             retries: retries
           }}
        end

        # httpoison error
        def to_response({:error, %HTTPoison.Error{} = error}, retries),
          do: {:error, %HTTPEx.Error{client: :httpoison, reason: error.reason, retries: retries}}
      end
    end
  end

  @doc """
  Function to generate mock responses
  """
  def define_to_client_response_functions do
    quote do
      if Code.ensure_loaded?(HTTPoison) do
        def to_client_response(:httpoison, :ok, %{} = response),
          do:
            {:ok,
             %HTTPoison.Response{
               status_code: response.status_code,
               body: response.body,
               headers: response.headers
             }}

        def to_client_response(:httpoison, :error, reason),
          do: {:error, %HTTPoison.Error{reason: reason}}
      end
    end
  end
end
