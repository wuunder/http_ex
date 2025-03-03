defmodule HTTPEx.Parsing do
  defmacro __using__(_opts) do
    quote do
      if Code.ensure_loaded?(HTTPoison) do
        # httpoison < 400
        def to_response(
              {:ok, %HTTPoison.Response{status_code: status, body: body, headers: headers}},
              retries
            )
            when status < 400,
            do:
              {:ok,
               %HTTPEx.Response{
                 status: status,
                 body: body,
                 parsed_body: parse_body(body),
                 headers: headers,
                 retries: retries
               }}

        # httpoison > 400
        def to_response(
              {:ok, %HTTPoison.Response{status_code: status, body: body, headers: headers}},
              retries
            )
            when status >= 400,
            do:
              {:error,
               %HTTPEx.Error{
                 reason: Plug.Conn.Status.reason_atom(status),
                 status: status,
                 body: body,
                 parsed_body: parse_body(body),
                 headers: headers,
                 retries: retries
               }}

        # httpoison error
        def to_response({:error, %HTTPoison.Error{} = error}, retries),
          do: {:error, %HTTPEx.Error{reason: error.reason, retries: retries}}
      end

      if Code.ensure_loaded?(Finch) do
        # finch > 400
        def to_response(
              {:ok, %Finch.Response{status: status, body: body, headers: headers} = response},
              retries
            )
            when status < 400 do
          body = decompress_body(response)

          {:ok,
           %HTTPEx.Response{
             status: status,
             body: body,
             parsed_body: parse_body(body),
             headers: headers,
             retries: retries
           }}
        end

        # finch > 400
        def to_response(
              {:ok, %Finch.Response{status: status, body: body, headers: headers} = response},
              retries
            )
            when status >= 400 do
          body = decompress_body(response)

          {:error,
           %HTTPEx.Error{
             reason: Plug.Conn.Status.reason_atom(status),
             status: status,
             body: body,
             parsed_body: parse_body(body),
             headers: headers,
             retries: retries
           }}
        end

        # finch errors
        def to_response({:error, %Finch.Error{} = error}, retries),
          do: {:error, %HTTPEx.Error{reason: error.reason, retries: retries}}

        def to_response({:error, %Mint.TransportError{} = error}, retries),
          do: {:error, %HTTPEx.Error{reason: error.reason, retries: retries}}

        def to_response({:error, %Mint.HTTPError{} = error}, retries),
          do: {:error, %HTTPEx.Error{reason: error.reason, retries: retries}}
      end

      def to_response(_response),
        do: raise(ArgumentError, "Unknown response received from http-client")

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
end
