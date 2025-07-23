defmodule HTTPEx.Backend.MockTest do
  use ExUnit.Case

  alias ExUnit.AssertionError
  alias HTTPEx.Backend.Mock
  alias HTTPEx.Request

  describe "request/1" do
    test "ok" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        response: %{status: 200, body: "OK"}
      )

      assert Mock.request(%Request{
               client: :httpoison,
               url: "http://www.example.com",
               method: :get,
               body: "GET"
             }) ==
               {:ok, %HTTPoison.Response{status_code: 200, body: "OK", headers: []}}
    end

    test "ok, with finch" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        response: %{status: 200, body: "OK"}
      )

      assert Mock.request(%Request{
               client: :finch,
               url: "http://www.example.com",
               method: :get,
               body: "GET"
             }) ==
               {:ok, %Finch.Response{body: "OK", headers: [], status: 200, trailers: []}}
    end

    test "ok, with finch and stream" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        response: %{status: 200, body: "OK"}
      )

      assert Mock.request(%Request{
               client: :finch,
               url: "http://www.example.com",
               method: :get,
               body: {:stream, ["GET"]}
             }) ==
               {:ok, %Finch.Response{body: "OK", headers: [], status: 200, trailers: []}}
    end

    test "ok with bitstring" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        method: :post,
        expect_body: {JSON.encode!(%{"data" => true}), :json},
        response: %{status: 200, body: "OK"}
      )

      assert Mock.request(%Request{
               client: :httpoison,
               url: "http://www.example.com",
               method: :post,
               body: JSON.encode_to_iodata!(%{"data" => true})
             }) ==
               {:ok,
                %HTTPoison.Response{
                  body: "OK",
                  headers: [],
                  status_code: 200
                }}
    end

    test "no matches" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        response: %{status: 200, body: "OK"}
      )

      assert_raise AssertionError, ~r/No HTTP request found/, fn ->
        Mock.request(%Request{url: "https://www.example.com", method: :get, body: "GET"})
      end
    end

    test "max calls reached" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        max_calls: 2,
        response: %{status: 200, body: "OK"}
      )

      assert_raise AssertionError,
                   ~r/Maximum number of HTTP calls already made for request/,
                   fn ->
                     Mock.request(%Request{
                       client: :httpoison,
                       url: "http://www.example.com",
                       method: :get,
                       body: "GET"
                     })

                     Mock.request(%Request{
                       client: :httpoison,
                       url: "http://www.example.com",
                       method: :get,
                       body: "GET"
                     })

                     Mock.request(%Request{
                       client: :httpoison,
                       url: "http://www.example.com",
                       method: :get,
                       body: "GET"
                     })
                   end
    end

    test "a rejected call should not be made" do
      Mock.assert_no_request!(endpoint: "http://www.example.com")

      assert_raise AssertionError, ~r/An unexpected HTTP request was made/, fn ->
        Mock.request(%Request{url: "http://www.example.com", method: :get, body: "GET"}) ==
          {:ok, %HTTPoison.Response{status_code: 200, body: "OK", headers: []}}
      end
    end

    test "expectations not met" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        max_calls: 2,
        response: %{status: 200, body: "OK"}
      )

      assert_raise AssertionError,
                   ~r/The HTTP request that was made, didn't match an expectation/,
                   fn ->
                     Mock.request(%Request{
                       url: "http://www.example.com",
                       method: :get,
                       body: "something else!"
                     })
                   end
    end
  end

  describe "verify!/1" do
    test "ok" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        response: %{status: 200, body: "OK"}
      )

      assert Mock.request(%Request{
               client: :httpoison,
               url: "http://www.example.com",
               method: :get,
               body: "GET"
             }) ==
               {:ok, %HTTPoison.Response{status_code: 200, body: "OK", headers: []}}

      Mock.verify!(self())
    end

    test "expected call wasn't made" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        response: %{status: 200, body: "OK"}
      )

      assert_raise AssertionError,
                   ~r/An expected HTTP call was called 0 but was expected to be called 1 times/,
                   fn ->
                     Mock.verify!(self())
                   end
    end

    test "min_calls not met" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        min_calls: 3,
        response: %{status: 200, body: "OK"}
      )

      Mock.request(%Request{
        client: :httpoison,
        url: "http://www.example.com",
        method: :get,
        body: "GET"
      })

      Mock.request(%Request{
        client: :httpoison,
        url: "http://www.example.com",
        method: :get,
        body: "GET"
      })

      assert_raise AssertionError,
                   ~r/An expected HTTP call was called 2 but was expected to be called 3 times/,
                   fn ->
                     Mock.verify!(self())
                   end
    end

    test "min_calls met" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        min_calls: 2,
        response: %{status: 200, body: "OK"}
      )

      Mock.request(%Request{
        client: :httpoison,
        url: "http://www.example.com",
        method: :get,
        body: "GET"
      })

      Mock.request(%Request{
        client: :httpoison,
        url: "http://www.example.com",
        method: :get,
        body: "GET"
      })

      Mock.verify!(self())
    end

    test "min_calls with max_calls met" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        min_calls: 1,
        max_calls: 5,
        response: %{status: 200, body: "OK"}
      )

      Enum.each(1..3, fn _ ->
        Mock.request(%Request{
          client: :httpoison,
          url: "http://www.example.com",
          method: :get,
          body: "GET"
        })
      end)

      Mock.verify!(self())
    end

    test "both min_calls met, max_calls met and then exceeded" do
      Mock.expect_request!(
        endpoint: "http://www.example.com",
        expect_body: "GET",
        min_calls: 2,
        max_calls: 3,
        response: %{status: 200, body: "OK"}
      )

      Mock.request(%Request{
        client: :httpoison,
        url: "http://www.example.com",
        method: :get,
        body: "GET"
      })

      Mock.request(%Request{
        client: :httpoison,
        url: "http://www.example.com",
        method: :get,
        body: "GET"
      })

      Mock.verify!(self())

      Mock.request(%Request{
        client: :httpoison,
        url: "http://www.example.com",
        method: :get,
        body: "GET"
      })

      assert_raise AssertionError,
                   ~r/Maximum number of HTTP calls already made for request/,
                   fn ->
                     Mock.request(%Request{
                       client: :httpoison,
                       url: "http://www.example.com",
                       method: :get,
                       body: "GET"
                     })
                   end
    end
  end
end
