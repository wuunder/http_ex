defmodule HTTPExTest do
  @moduledoc false
  use ExUnit.Case

  alias HTTPEx.Error
  alias HTTPEx.Request
  alias HTTPEx.Response
  alias HTTPExTest.MockBackend

  import ExUnit.CaptureLog
  require Logger

  doctest HTTPEx

  describe "get/2" do
    setup do
      log_fn = Application.get_env(:http_ex, :log)

      on_exit(fn ->
        Application.put_env(:http_ex, :log, log_fn)
      end)

      :ok
    end

    test "OK" do
      assert HTTPEx.get("http://www.example.com", backend: MockBackend) ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK!",
                  client: :httpoison,
                  retries: 1,
                  status: 200,
                  parsed_body: nil,
                  headers: []
                }}
    end

    test "OK with pdf as response" do
      Application.put_env(:http_ex, :log, fn x -> Logger.bare_log(:info, x) end)

      {result, log} =
        with_log(fn ->
          HTTPEx.get("http://www.example.com/pdf.pdf", backend: MockBackend)
        end)

      assert log =~
               ~s(\e[4mHTTP response:\e[24m\n\n\e[1mClient:\e[22m \e[3m:httpoison\e[23m\n\e[1mStatus:\e[22m \e[3m200\e[23m\n\e[1mRetries:\e[22m \e[3m1\e[23m\n\e[1mHeaders:\e[22m\n\n\e[3m[]\e[23m\n\n\e[1mBody:\e[22m\n\n\e[3m%PDF-1.4\n%ÓôÌá\n1 0 obj\n<<\n/CreationDate(D:2025040\e)

      assert result ==
               {:ok,
                %HTTPEx.Response{
                  body: "%PDF-1.4\n%ÓôÌá\n1 0 obj\n<<\n/CreationDate(D:2025040",
                  client: :httpoison,
                  retries: 1,
                  status: 200,
                  parsed_body: nil,
                  headers: []
                }}
    end

    test "OK, fallback header" do
      assert HTTPEx.get("http://www.example.com", headers: nil, backend: MockBackend) ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK!",
                  client: :httpoison,
                  retries: 1,
                  status: 200,
                  parsed_body: nil,
                  headers: []
                }}

      assert HTTPEx.get("http://www.example.com", headers: [], backend: MockBackend) ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK!",
                  client: :httpoison,
                  retries: 1,
                  status: 200,
                  parsed_body: nil,
                  headers: []
                }}
    end

    test "OK, with parsed json" do
      assert HTTPEx.get("http://www.example.com/json",
               headers: [{"Content-Type", "application/json"}],
               backend: MockBackend
             ) ==
               {:ok,
                %HTTPEx.Response{
                  body: ~s({"payload":{"items":[1,2,3]}}),
                  client: :httpoison,
                  headers: [],
                  parsed_body: %{"payload" => %{"items" => [1, 2, 3]}},
                  retries: 1,
                  status: 202
                }}
    end

    test "OK for redirect" do
      assert HTTPEx.get("http://www.example.com/redirect", backend: MockBackend) ==
               {:ok,
                %HTTPEx.Response{
                  body: "You are being redirected",
                  client: :httpoison,
                  headers: [],
                  parsed_body: nil,
                  retries: 1,
                  status: 302
                }}
    end

    test "error for redirect" do
      assert HTTPEx.get("http://www.example.com/redirect",
               backend: MockBackend,
               allow_redirect: false
             ) ==
               {:error,
                %HTTPEx.Error{
                  body: "You are being redirected",
                  client: :httpoison,
                  headers: [],
                  parsed_body: nil,
                  retries: 1,
                  status: 302,
                  reason: :redirect_not_allowed
                }}
    end

    test "error, because status code dictates so" do
      assert HTTPEx.get("http://www.example.com/error", backend: MockBackend) ==
               {:error,
                %HTTPEx.Error{
                  body: ~s({"errors":[{"code":"invalid_payload"}]}),
                  client: :httpoison,
                  headers: [],
                  parsed_body: %{"errors" => [%{"code" => "invalid_payload"}]},
                  reason: :unprocessable_content,
                  retries: 1,
                  status: 422
                }}
    end

    test "error with 3 retries, because status code dictates so" do
      assert HTTPEx.get("http://www.example.com/error",
               backend: MockBackend,
               retry_status_codes: [422]
             ) ==
               {:error,
                %HTTPEx.Error{
                  body: ~s({"errors":[{"code":"invalid_payload"}]}),
                  client: :httpoison,
                  headers: [],
                  parsed_body: %{"errors" => [%{"code" => "invalid_payload"}]},
                  reason: :unprocessable_content,
                  retries: 3,
                  status: 422
                }}
    end

    test "error with 2 retries, because of timeout and overriden settings" do
      assert HTTPEx.get("http://www.example.com/timeout",
               backend: MockBackend,
               transport_max_retries: 2
             ) ==
               {:error,
                %Error{
                  body: nil,
                  client: :httpoison,
                  headers: nil,
                  parsed_body: nil,
                  reason: :timeout,
                  retries: 2,
                  status: nil
                }}
    end

    test "error with no retries, because max is set to 0" do
      assert HTTPEx.get("http://www.example.com/timeout",
               backend: MockBackend,
               transport_max_retries: 0
             ) ==
               {:error,
                %Error{
                  body: nil,
                  client: :httpoison,
                  headers: nil,
                  parsed_body: nil,
                  reason: :timeout,
                  retries: 1,
                  status: nil
                }}
    end

    test "error with no retries, because of timeout and overriden settings" do
      assert HTTPEx.get("http://www.example.com/timeout",
               backend: MockBackend,
               retry_error_codes: [:closed]
             ) ==
               {:error,
                %Error{
                  body: nil,
                  client: :httpoison,
                  headers: nil,
                  parsed_body: nil,
                  reason: :timeout,
                  retries: 1,
                  status: nil
                }}
    end
  end

  describe "post/2" do
    test "OK" do
      assert HTTPEx.post("http://www.example.com", JSON.encode!(%{data: true}),
               backend: MockBackend
             ) ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK!",
                  client: :httpoison,
                  retries: 1,
                  status: 200,
                  parsed_body: nil,
                  headers: []
                }}
    end

    test "OK, fallback header" do
      assert HTTPEx.post("http://www.example.com", JSON.encode!(%{data: true}),
               headers: nil,
               backend: MockBackend
             ) ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK!",
                  client: :httpoison,
                  retries: 1,
                  status: 200,
                  parsed_body: nil,
                  headers: []
                }}

      assert HTTPEx.post("http://www.example.com", JSON.encode!(%{data: true}),
               headers: [],
               backend: MockBackend
             ) ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK!",
                  client: :httpoison,
                  retries: 1,
                  status: 200,
                  parsed_body: nil,
                  headers: []
                }}
    end

    test "OK, with parsed json" do
      assert HTTPEx.post("http://www.example.com/json", JSON.encode!(%{data: true}),
               headers: [{"Content-Type", "application/json"}],
               backend: MockBackend
             ) ==
               {:ok,
                %HTTPEx.Response{
                  body: ~s({"payload":{"label":"ABCD"}}),
                  client: :httpoison,
                  headers: [],
                  parsed_body: %{"payload" => %{"label" => "ABCD"}},
                  retries: 1,
                  status: 200
                }}
    end

    test "error, because status code dictates so" do
      assert HTTPEx.post("http://www.example.com/error", JSON.encode!(%{data: true}),
               backend: MockBackend
             ) ==
               {:error,
                %HTTPEx.Error{
                  body: ~s({"errors":[{"code":"invalid_payload"}]}),
                  client: :httpoison,
                  headers: [],
                  parsed_body: %{"errors" => [%{"code" => "invalid_payload"}]},
                  reason: :unprocessable_content,
                  retries: 1,
                  status: 422
                }}
    end

    test "error with 3 retries, because status code dictates so" do
      assert HTTPEx.post("http://www.example.com/error", JSON.encode!(%{data: true}),
               backend: MockBackend,
               retry_status_codes: [422]
             ) ==
               {:error,
                %HTTPEx.Error{
                  body: ~s({"errors":[{"code":"invalid_payload"}]}),
                  client: :httpoison,
                  headers: [],
                  parsed_body: %{"errors" => [%{"code" => "invalid_payload"}]},
                  reason: :unprocessable_content,
                  retries: 3,
                  status: 422
                }}
    end

    test "error with 3 retries, because of timeout" do
      assert HTTPEx.post("http://www.example.com/timeout", JSON.encode!(%{data: true}),
               backend: MockBackend
             ) ==
               {:error,
                %Error{
                  body: nil,
                  client: :httpoison,
                  headers: nil,
                  parsed_body: nil,
                  reason: :timeout,
                  retries: 3,
                  status: nil
                }}
    end

    test "error with no retries, because of timeout and overriden settings" do
      assert HTTPEx.post("http://www.example.com/timeout", JSON.encode!(%{data: true}),
               backend: MockBackend,
               retry_error_codes: [:closed]
             ) ==
               {:error,
                %Error{
                  body: nil,
                  client: :httpoison,
                  headers: nil,
                  parsed_body: nil,
                  reason: :timeout,
                  retries: 1,
                  status: nil
                }}
    end
  end

  test "request/1" do
    assert HTTPEx.request(%Request{
             url: "http://www.example.com",
             body: JSON.encode!(%{data: true}),
             method: :post,
             headers: nil,
             options: [backend: MockBackend]
           }) ==
             {:ok,
              %HTTPEx.Response{
                body: "OK!",
                client: :httpoison,
                retries: 1,
                status: 200,
                parsed_body: nil,
                headers: []
              }}

    assert assert HTTPEx.request(%Request{
                    url: "http://www.example.com",
                    body: JSON.encode!(%{data: true}),
                    method: :post,
                    headers: [],
                    options: [backend: MockBackend]
                  }) ==
                    {:ok,
                     %HTTPEx.Response{
                       body: "OK!",
                       client: :httpoison,
                       retries: 1,
                       status: 200,
                       parsed_body: nil,
                       headers: []
                     }}

    {:ok, %HTTPEx.Response{body: "OK!", retries: 1, status: 200, parsed_body: nil, headers: []}}
  end

  describe "to_response #http_poison" do
    test "ok" do
      assert HTTPEx.to_response({:ok, %HTTPoison.Response{body: "OK test", status_code: 202}}, 0) ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK test",
                  client: :httpoison,
                  retries: 0,
                  status: 202,
                  parsed_body: nil,
                  headers: []
                }}
    end

    test "ok, parsed" do
      assert HTTPEx.to_response(
               {:ok,
                %HTTPoison.Response{
                  body: JSON.encode!(%{"value" => true, "other_value" => 1337}),
                  status_code: 202
                }},
               0
             ) ==
               {:ok,
                %HTTPEx.Response{
                  body: "{\"other_value\":1337,\"value\":true}",
                  client: :httpoison,
                  headers: [],
                  parsed_body: %{"other_value" => 1337, "value" => true},
                  retries: 0,
                  status: 202
                }}
    end

    test "error because of status_code" do
      assert HTTPEx.to_response(
               {:ok, %HTTPoison.Response{body: "Not found", status_code: 404}},
               0
             ) ==
               {:error,
                %HTTPEx.Error{
                  body: "Not found",
                  client: :httpoison,
                  headers: [],
                  parsed_body: nil,
                  retries: 0,
                  status: 404,
                  reason: :not_found
                }}
    end

    test "error because of generic error" do
      assert HTTPEx.to_response(
               {:error, %HTTPoison.Error{reason: :timeout}},
               0
             ) ==
               {:error,
                %HTTPEx.Error{
                  client: :httpoison,
                  reason: :timeout,
                  retries: 0
                }}
    end
  end

  describe "to_response #finch" do
    test "ok" do
      assert HTTPEx.to_response({:ok, %Finch.Response{body: "OK test", status: 202}}, 0) ==
               {:ok,
                %HTTPEx.Response{
                  body: "OK test",
                  client: :finch,
                  retries: 0,
                  status: 202,
                  parsed_body: nil,
                  headers: []
                }}
    end

    test "ok, parsed" do
      assert HTTPEx.to_response(
               {:ok,
                %Finch.Response{
                  body: JSON.encode!(%{"value" => true, "other_value" => 1337}),
                  status: 202
                }},
               0
             ) ==
               {:ok,
                %HTTPEx.Response{
                  body: "{\"other_value\":1337,\"value\":true}",
                  client: :finch,
                  headers: [],
                  parsed_body: %{"other_value" => 1337, "value" => true},
                  retries: 0,
                  status: 202
                }}
    end

    test "error because of status_code" do
      assert HTTPEx.to_response(
               {:ok, %Finch.Response{body: "Not found", status: 404}},
               0
             ) ==
               {:error,
                %HTTPEx.Error{
                  body: "Not found",
                  client: :finch,
                  headers: [],
                  parsed_body: nil,
                  retries: 0,
                  status: 404,
                  reason: :not_found
                }}
    end

    test "error because of generic error" do
      assert HTTPEx.to_response(
               {:error, %Mint.TransportError{reason: :timeout}},
               0
             ) ==
               {:error,
                %HTTPEx.Error{
                  client: :finch,
                  reason: :timeout,
                  retries: 0
                }}
    end
  end
end
