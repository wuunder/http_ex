defmodule HTTPExTest.MockBackend do
  @moduledoc false
  use ExUnit.Case
  @behaviour HTTPEx.Backend.Behaviour

  alias HTTPEx.Request

  @impl true
  def request(%Request{method: :get, url: "http://www.example.com"} = request) do
    assert request.headers == []
    {:ok, %HTTPoison.Response{status_code: 200, body: "OK!"}}
  end

  def request(%Request{method: :get, url: "http://www.example.com/pdf.pdf"} = request) do
    assert request.headers == []

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: "%PDF-1.4\n%ÓôÌá\n1 0 obj\n<<\n/CreationDate(D:2025040"
     }}
  end

  def request(%Request{method: :get, url: "http://www.example.com/redirect"} = request) do
    assert request.headers == []
    {:ok, %HTTPoison.Response{status_code: 302, body: "You are being redirected"}}
  end

  def request(%Request{method: :get, url: "http://www.example.com/json"} = request) do
    assert request.headers == [{"Content-Type", "application/json"}]

    {:ok,
     %HTTPoison.Response{
       status_code: 202,
       body: JSON.encode!(%{"payload" => %{items: [1, 2, 3]}})
     }}
  end

  def request(%Request{method: :get, url: "http://www.example.com/error"}) do
    {:ok,
     %HTTPoison.Response{
       status_code: 422,
       body: JSON.encode!(%{"errors" => [%{"code" => "invalid_payload"}]})
     }}
  end

  def request(%Request{method: :get, url: "http://www.example.com/timeout"}) do
    {:error, %HTTPoison.Error{reason: :timeout}}
  end

  def request(
        %Request{method: :post, body: "{\"data\":true}", url: "http://www.example.com"} =
          request
      ) do
    assert request.headers == []
    {:ok, %HTTPoison.Response{status_code: 200, body: "OK!"}}
  end

  def request(
        %Request{method: :post, body: "{\"data\":true}", url: "http://www.example.com/json"} =
          request
      ) do
    assert request.headers == [{"Content-Type", "application/json"}]

    {:ok,
     %HTTPoison.Response{
       status_code: 200,
       body: JSON.encode!(%{"payload" => %{"label" => "ABCD"}})
     }}
  end

  def request(%Request{
        method: :post,
        body: "{\"data\":true}",
        url: "http://www.example.com/error"
      }) do
    {:ok,
     %HTTPoison.Response{
       status_code: 422,
       body: JSON.encode!(%{"errors" => [%{"code" => "invalid_payload"}]})
     }}
  end

  def request(%Request{
        method: :post,
        body: "{\"data\":true}",
        url: "http://www.example.com/timeout"
      }) do
    {:error, %HTTPoison.Error{reason: :timeout}}
  end
end
