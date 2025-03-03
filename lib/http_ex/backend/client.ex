defmodule HTTPEx.Backend.Client do
  defmacro __using__(_opts) do
    quote do
      @behaviour HTTPEx.Backend.Behaviour

      # generate functions per client
      if Code.ensure_loaded?(HTTPoison) do
        @impl true
        def request(%HTTPEx.Request{client: :httpoison} = request) do
          HTTPoison.request(
            request.method,
            request.url,
            request.body,
            request.headers,
            options(request)
          )
        end
      end

      if Code.ensure_loaded?(Finch) do
        @impl true
        def request(%HTTPEx.Request{client: :finch} = request) do
          request.method
          |> Finch.build(request.url, request.headers, request.body)
          |> Finch.request(request.options[:pool], options(request))
        end
      end

      # fallback
      def request(%HTTPEx.Request{client: client}),
        do:
          raise(
            ArgumentError,
            "Cannot make HTTP call. Request made for unsupported client `#{client}`"
          )

      # generate options per known client
      if Code.ensure_loaded?(HTTPoison) do
        def options(%HTTPEx.Request{client: :httpoison} = request),
          do: [
            timeout: request.options[:timeout],
            recv_timeout: request.options[:receive_timeout]
          ]
      end

      if Code.ensure_loaded?(Finch) do
        def options(%HTTPEx.Request{client: :finch} = request),
          do:
            [
              pool_timeout: request.options[:timeout],
              receive_timeout: request.options[:receive_timeout]
            ]
            |> Enum.reject(&is_nil(elem(&1, 1)))
      end
    end
  end
end
