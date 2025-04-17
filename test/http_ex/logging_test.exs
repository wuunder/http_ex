defmodule HTTPEx.LoggingTest do
  use ExUnit.Case

  alias HTTPExTest.MockBackend

  import ExUnit.CaptureLog
  require Logger

  describe "" do
    setup do
      log_fn = Application.get_env(:http_ex, :export_logging)

      on_exit(fn ->
        Application.put_env(:http_ex, :export_logging, log_fn)
      end)

      :ok
    end

    test "export logging when function is available" do
      Application.put_env(:http_ex, :export_logging, &Logger.info/1)

      {result, log} =
        with_log(fn ->
          HTTPEx.get("http://www.example.com", backend: MockBackend)
        end)

      assert log =~
               ~s([info] [options: [pool: HTTPEx.FinchTestPool, retry_status_codes: [500, 502, 503, 504], retry_error_codes: [:closed, :timeout], transport_max_retries: 3, transport_retry_timeout: 2000, allow_redirects: true, backend: HTTPExTest.MockBackend], __struct__: HTTPEx.Request, body: \"\", url: \"http://www.example.com\", client: :httpoison, headers: [], retries: 1, method: :get)

      assert log =~
               ~s([info] [options: [pool: HTTPEx.FinchTestPool, retry_status_codes: [500, 502, 503, 504], retry_error_codes: [:closed, :timeout], transport_max_retries: 3, transport_retry_timeout: 2000, allow_redirects: true, backend: HTTPExTest.MockBackend], __struct__: HTTPEx.Request, body: \"\", url: \"http://www.example.com\", client: :httpoison, headers: [], retries: 1, method: :get)

      assert log =~
               ~s([info] [status: 200, __struct__: HTTPEx.Response, body: \"OK!\", client: :httpoison, headers: [], parsed_body: nil, retries: 1])

      assert result ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK!",
                  client: :httpoison,
                  headers: [],
                  parsed_body: nil,
                  retries: 1,
                  status: 200
                }}
    end
  end
end
