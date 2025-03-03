defmodule HTTPEx.Backend.Mock.Parsing do
  defmacro __using__(_opts) do
    quote do
      # generate functions per client
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

      # fallback
      def to_client_response(client, _code, _reason),
        do:
          raise(
            ArgumentError,
            "Cannot generate mocked response. Request made for unsupported client `#{inspect(client)}`"
          )
    end
  end
end
