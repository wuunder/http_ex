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

      assert Mock.request(%Request{url: "http://www.example.com", method: :get, body: "GET"}) ==
               {:ok, %HTTPoison.Response{status_code: 200, body: "OK", headers: []}}
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
                       url: "http://www.example.com",
                       method: :get,
                       body: "GET"
                     })

                     Mock.request(%Request{
                       url: "http://www.example.com",
                       method: :get,
                       body: "GET"
                     })

                     Mock.request(%Request{
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
                   ~r/The HTTP request that was made, didn't match one or more expectations/,
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

      assert Mock.request(%Request{url: "http://www.example.com", method: :get, body: "GET"}) ==
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
  end
end
