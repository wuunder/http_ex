defmodule HTTPEx.Backend.Mock.ExpectationTest do
  use ExUnit.Case

  alias HTTPEx.Backend.Mock.Expectation
  alias HTTPEx.Request

  doctest Expectation

  describe "match_request/2" do
    test "func match" do
      expectation =
        get_with_match(:body, fn request ->
          request.body == "A match"
        end)

      request = get_request(:body, "A match")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "func no match" do
      expectation =
        get_with_match(:body, fn request ->
          request.body == "A match"
        end)

      request = get_request(:body, "Not a match")

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :query, :host, :path, :port], [:body], %{}}
    end

    test "string match" do
      expectation = get_with_match(:body, "A match")

      request = get_request(:body, "A match")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}

      expectation = get_with_match(:body, "A MaTcH")

      request = get_request(:body, "A match")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}

      expectation = get_with_match(:body, "A match")

      request = get_request(:body, "a MaTch")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "string no match" do
      expectation = get_with_match(:body, "A match")

      request = get_request(:body, "Not a match")

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :query, :host, :path, :port], [:body], %{}}
    end

    test "string_with_format :json match" do
      formatted_json = """
      {
        "person": {
          "name": "match"
        }
      }
      """

      unformatted_json = """
      {"person": {"name":"match"}}
      """

      expectation = get_with_match(:body, {formatted_json, :json})
      request = get_request(:body, unformatted_json)

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "string_with_format :json no match" do
      formatted_json = """
      {
        "person": {
          "name": "no match"
        }
      }
      """

      unformatted_json = """
      {"person": {"name":"match"}}
      """

      expectation = get_with_match(:body, {formatted_json, :json})
      request = get_request(:body, unformatted_json)

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :query, :host, :path, :port], [:body], %{}}

      expectation = get_with_match(:body, {unformatted_json, :json})
      request = get_request(:body, formatted_json)

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :query, :host, :path, :port], [:body], %{}}
    end

    test "string_with_format :xml match" do
      formatted_xml = """
      <foo>
        <text>
          bar
        </text>
        <items>
          <item>1</item>
          <item>2</item>
        </items>
      </foo>
      """

      unformatted_xml = """
      <foo><text>bar</text><items><item>1</item><item>2</item></items></foo>
      """

      expectation = get_with_match(:body, {formatted_xml, :xml})
      request = get_request(:body, unformatted_xml)

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "string_with_format :xml no match" do
      formatted_xml = """
      <foo>
        <text>
          baz
        </text>
        <items>
          <item>2</item>
        </items>
      </foo>
      """

      unformatted_xml = """
      <foo><text>bar</text><items><item>1</item><item>2</item></items></foo>
      """

      expectation = get_with_match(:body, {formatted_xml, :xml})
      request = get_request(:body, unformatted_xml)

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :query, :host, :path, :port], [:body], %{}}
    end

    test "string_with_format :form match" do
      form_1 = """
      foo=bar&name=Piet
      """

      form_2 = """
      name=Piet&foo=bar
      """

      expectation = get_with_match(:body, {form_1, :form})
      request = get_request(:body, form_2)

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "string_with_format :form no match" do
      form_1 = """
      foo=baz&name=Jan
      """

      form_2 = """
      name=Piet&foo=bar
      """

      expectation = get_with_match(:body, {form_1, :form})
      request = get_request(:body, form_2)

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :query, :host, :path, :port], [:body], %{}}
    end

    test "regex match" do
      expectation = get_with_match(:body, ~r/a match/i)

      request = get_request(:body, "could be a match")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "regex no match" do
      expectation = get_with_match(:body, ~r/a match/i)

      request = get_request(:body, "not what we expected")

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :query, :host, :path, :port], [:body], %{}}
    end

    test "wildcard" do
      expectation = get_with_match(:body, :any)

      request = get_request(:body, "could be anything")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "keyword_list match string" do
      expectation = get_with_match(:headers, [{"content-type", "application/json"}])

      request = get_request(:headers, [{"content-type", "application/json"}])

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}

      expectation = get_with_match(:headers, [{"content-type", "application/json"}])

      request =
        get_request(:headers, [{"content-type", "application/json"}, {"more-headers", "ok"}])

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "keyword_list no match string" do
      expectation = get_with_match(:headers, [{"content-type", "application/json"}])

      request = get_request(:headers, [{"content-type", "application/xml"}])

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :query, :body, :host, :path, :port], [:headers], %{}}
    end

    test "keyword_list match regex" do
      expectation = get_with_match(:headers, [{"content-type", ~r/application/}])

      request = get_request(:headers, [{"content-type", "application/json"}])

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "keyword_list no match regex" do
      expectation = get_with_match(:headers, [{"content-type", ~r/application/}])

      request = get_request(:headers, [{"content-type", "unknown"}])

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :query, :body, :host, :path, :port], [:headers], %{}}
    end

    test "map match" do
      expectation = get_with_match(:query, %{"id" => "123", "user_id" => "456"})
      request = get_request(:url, "http://www.example.com/get-order?user_id=456&id=123")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}

      expectation = get_with_match(:query, %{"user_id" => "456"})
      request = get_request(:url, "http://www.example.com/get-order?user_id=456&id=123")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "map no match" do
      expectation = get_with_match(:query, %{"id" => "123", "user_id" => "456"})
      request = get_request(:url, "http://www.example.com/get-order?user_id=1337&id=456")

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :body, :host, :path, :port], [:query], %{}}
    end

    test "enum match" do
      expectation = get_with_match(:method, :post)
      request = get_request(:method, :post)

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "enum no match" do
      expectation = get_with_match(:method, :get)
      request = get_request(:method, :post)

      assert Expectation.match_request(request, expectation) ==
               {false, [:headers, :query, :body, :host, :path, :port], [:method], %{}}

      expectation = get_with_match(:method, :post)
      request = get_request(:method, :get)

      assert Expectation.match_request(request, expectation) ==
               {false, [:headers, :query, :body, :host, :path, :port], [:method], %{}}
    end

    test "int match" do
      expectation = get_with_match(:port, 443)
      request = get_request(:url, "https://www.example.com")

      assert Expectation.match_request(request, expectation) ==
               {true, [:method, :headers, :query, :body, :host, :path, :port], [], %{}}
    end

    test "int no match" do
      expectation = get_with_match(:port, 80)
      request = get_request(:url, "https://www.example.com")

      assert Expectation.match_request(request, expectation) ==
               {false, [:method, :headers, :query, :body, :host, :path], [:port], %{}}
    end
  end

  describe "to_response #httpoison" do
    test "map" do
      request = %Request{client: :httpoison, method: :get, url: "http://www.example.com"}

      expectation = %Expectation{
        response: %{status: 202, body: "OK {{var}}", replace_body_vars: true}
      }

      assert Expectation.to_response(request, expectation, %{"var" => "test"}) ==
               {:ok, %HTTPoison.Response{body: "OK test", status_code: 202}}
    end

    test "func map" do
      request = %Request{client: :httpoison, method: :get, url: "http://www.example.com"}

      expectation = %Expectation{
        response: fn _ -> %{status: 202, body: "OK {{var}}", replace_body_vars: true} end
      }

      assert Expectation.to_response(request, expectation, %{"var" => "test"}) ==
               {:ok, %HTTPoison.Response{body: "OK test", status_code: 202}}
    end

    test "econnrefused" do
      request = %Request{client: :httpoison, method: :get, url: "http://www.example.com"}
      expectation = %Expectation{response: {:error, :econnrefused}}

      assert Expectation.to_response(request, expectation, %{}) ==
               {:error, %HTTPoison.Error{reason: :econnrefused}}
    end

    test "func error" do
      request = %Request{client: :httpoison, method: :get, url: "http://www.example.com"}
      expectation = %Expectation{response: fn _ -> {:error, :econnrefused} end}

      assert Expectation.to_response(request, expectation, %{}) ==
               {:error, %HTTPoison.Error{reason: :econnrefused}}
    end

    test "timeout" do
      request = %Request{client: :httpoison, method: :get, url: "http://www.example.com"}
      expectation = %Expectation{response: {:error, :timeout}}

      assert Expectation.to_response(request, expectation, %{}) ==
               {:error, %HTTPoison.Error{reason: :timeout}}
    end
  end

  describe "to_response #finch" do
    test "map" do
      request = %Request{client: :finch, method: :get, url: "http://www.example.com"}

      expectation = %Expectation{
        response: %{status: 202, body: "OK {{var}}", replace_body_vars: true}
      }

      assert Expectation.to_response(request, expectation, %{"var" => "test"}) ==
               {:ok, %Finch.Response{body: "OK test", status: 202}}
    end

    test "func map" do
      request = %Request{client: :finch, method: :get, url: "http://www.example.com"}

      expectation = %Expectation{
        response: fn _ -> %{status: 202, body: "OK {{var}}", replace_body_vars: true} end
      }

      assert Expectation.to_response(request, expectation, %{"var" => "test"}) ==
               {:ok, %Finch.Response{body: "OK test", status: 202}}
    end

    test "econnrefused" do
      request = %Request{client: :finch, method: :get, url: "http://www.example.com"}
      expectation = %Expectation{response: {:error, :econnrefused}}

      assert Expectation.to_response(request, expectation, %{}) ==
               {:error, %Mint.TransportError{reason: :econnrefused}}
    end

    test "func error" do
      request = %Request{client: :finch, method: :get, url: "http://www.example.com"}
      expectation = %Expectation{response: fn _ -> {:error, :econnrefused} end}

      assert Expectation.to_response(request, expectation, %{}) ==
               {:error, %Mint.TransportError{reason: :econnrefused}}
    end

    test "timeout" do
      request = %Request{client: :finch, method: :get, url: "http://www.example.com"}
      expectation = %Expectation{response: {:error, :timeout}}

      assert Expectation.to_response(request, expectation, %{}) ==
               {:error, %Mint.TransportError{reason: :timeout}}
    end
  end

  defp get_with_match(field, match) do
    expectation = %Expectation{}

    %{expectation | matchers: Map.put(expectation.matchers, field, match)}
  end

  defp get_request(field, value),
    do:
      %Request{
        method: :get,
        url: "http://www.example.com"
      }
      |> Map.put(field, value)
end
