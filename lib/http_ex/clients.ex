defmodule HTTPEx.Clients do
  defmacro def_request do
    quote do
      unquote(HTTPEx.Clients.HTTPoison.define_request_functions())
      unquote(HTTPEx.Clients.Finch.define_request_functions())

      def request(%HTTPEx.Request{client: client}),
        do:
          raise(
            ArgumentError,
            "Cannot make HTTP call. Request made for unsupported client `#{client}`"
          )
    end
  end

  defmacro def_to_response do
    quote do
      unquote(HTTPEx.Clients.HTTPoison.define_to_response_functions())
      unquote(HTTPEx.Clients.Finch.define_to_response_functions())

      def to_response(response),
        do:
          raise(ArgumentError, "Unknown response received from http-client: #{inspect(response)}")

      defp parse_body(body) when body in ["", nil], do: nil

      defp parse_body(body) do
        case JSON.decode(body) do
          {:ok, decoded} -> decoded
          _ -> nil
        end
      end

      defp decompress_body(%{headers: headers, body: body}) do
        encodings =
          Enum.find_value(headers, [], fn {name, value} ->
            if String.downcase(name) == "content-encoding" do
              value
              |> String.downcase()
              |> String.split(",", trim: true)
              |> Enum.map(&String.trim/1)
              |> Enum.reverse()
            end
          end)

        Enum.reduce(encodings, body, &decompress_with_algorithm/2)
      end

      defp decompress_with_algorithm(gzip, data) when gzip in ["gzip", "x-gzip"],
        do: :zlib.gunzip(data)

      defp decompress_with_algorithm("deflate", data), do: :zlib.unzip(data)

      defp decompress_with_algorithm("identity", data), do: data

      defp decompress_with_algorithm(algorithm, _data),
        do: raise("unsupported decompression algorithm: #{inspect(algorithm)}")
    end
  end

  defmacro def_to_client_response do
    quote do
      unquote(HTTPEx.Clients.HTTPoison.define_to_client_response_functions())
      unquote(HTTPEx.Clients.Finch.define_to_client_response_functions())

      def to_client_response(client, _, _),
        do: raise("Unknown mocked response for http-client `#{client}`")
    end
  end
end
