defmodule HTTPEx.LoggingTest do
  use ExUnit.Case

  alias HTTPExTest.MockBackend

  describe "export_logging" do
    setup do
      log_fn = Application.get_env(:http_ex, :export_logging)

      on_exit(fn ->
        Application.put_env(:http_ex, :export_logging, log_fn)
      end)

      :ok
    end

    test "export logging when function is available" do
      {:ok, pid} = Agent.start_link(fn -> [] end)

      Application.put_env(:http_ex, :export_logging, fn x -> Agent.update(pid, &[x | &1]) end)

      HTTPEx.get("http://www.example.com", backend: MockBackend)

      assert [
               %HTTPEx.Response{
                 status: 200,
                 body: "OK!",
                 client: :httpoison,
                 headers: [],
                 retries: 1,
                 parsed_body: nil
               },
               %HTTPEx.Response{
                 status: 200,
                 body: "OK!",
                 client: :httpoison,
                 headers: [],
                 retries: 1,
                 parsed_body: nil
               },
               %HTTPEx.Request{
                 options: [
                   pool: HTTPEx.FinchTestPool,
                   retry_status_codes: [500, 502, 503, 504],
                   retry_error_codes: [:closed, :timeout],
                   transport_max_retries: 3,
                   transport_retry_timeout: 2000,
                   allow_redirects: true,
                   backend: HTTPExTest.MockBackend
                 ],
                 body: "",
                 url: "http://www.example.com",
                 client: :httpoison,
                 headers: [],
                 method: :get,
                 retries: 1
               },
               %HTTPEx.Request{
                 options: [
                   pool: HTTPEx.FinchTestPool,
                   retry_status_codes: [500, 502, 503, 504],
                   retry_error_codes: [:closed, :timeout],
                   transport_max_retries: 3,
                   transport_retry_timeout: 2000,
                   allow_redirects: true,
                   backend: HTTPExTest.MockBackend
                 ],
                 body: "",
                 url: "http://www.example.com",
                 client: :httpoison,
                 headers: [],
                 method: :get,
                 retries: 1
               }
             ] = Agent.get(pid, & &1)
    end
  end
end
