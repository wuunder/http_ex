defmodule HTTPEx.Telemetry do
  @moduledoc """
  Telemetry integration for event metrics, logging and error reporting.

  ## HTTP Events 

  Oban emits telemetry span events for the following Engine operations:

  * `[:http_ex, :request]`
  * `[:http_ex, :response]`
  * `[:http_ex, :error]`

  | event        | measures       | metadata                                              |
  | ------------ | -------------- | ----------------------------------------------------- |
  | `:request`   | `:system_time` | `http.method`, `http.host`, `http.path`, `http.query`, `http.url`, `http.target`, `http.scheme`, `http.request_body`, `http.request_headers` |
  | `:response`  | `:system_time` | `error`, `http.error`, `http.response_body`, `http.response_headers`, `http.status_code`, `http.retries` |
  | `:error`     | `:system_time` | `error`, `http.error`, `http.response_body`, `http.response_headers`, `http.status_code`, `http.retries` |

  ### Metadata

  #### Request

  * `http.method` — the method the HTTP request uses (e.g. `GET`)
  * `http.host` — the host of the HTTP request (e.g. `wearewuunder.com`) 
  * `http.path` - the path of the HTTP request (e.g. `/api/v1/user`)
  * `http.query` - the query of the HTTP request (e.g. `foo=bar`)
  * `http.url` - the URL of the HTTP request (e.g. `https://wearewuunder.com/api/v1/user`)
  * `http.target` - the target of the HTTP request (e.g. `/api/v1/user?foo=bar`)
  * `http.scheme` - the scheme of the HTTP request (e.g. `https`)
  * `http.request_body` - the body of the HTTP request (e.g. `'{"foo": "bar"}'`)
  * `http.request_headers` - the headers of the HTTP request (e.g. `'[{"foo": "bar"}]'`)

  #### Response and Error

  * `error` - boolean representation if there is an error or not (e.g. `false`)
  * `http.error` - error name if there is an error (e.g. `unprocessable_entity`)
  * `http.response_body` - the body of the HTTP response (e.g. `'{"bar": "foo"}'`)
  * `http.response_headers` - the headers of the HTTP response (e.g. `'[{"bar": "foo"}]`)
  * `http.status_code` - the status code of the HTTP response (e.g. `422`)
  * `http.retries` - the amount of retries that were done to get the HTTP response (e.g. `0`)
  """
  require Logger
  def default_handler_id, do: "httpex-default-logger"

  @doc """
  Attaches a default structured JSON Telemetry handler for logging.

  This function attaches a handler that outputs logs with `message` and `source` fields, along
  with some event specific fields.

   
  ## Options

  * `:level` — The log level to use for logging output, defaults to `:info`
  """

  require Logger

  @spec attach_default_logger(Logger.level()) :: :ok | {:error, :already_exists}
  def attach_default_logger(level \\ :info) when is_atom(level) do
    :telemetry.attach_many(
      default_handler_id(),
      [[:http_ex, :request], [:http_ex, :response]],
      &__MODULE__.handle_event/4,
      level: level
    )
  end

  @doc """
  Undoes `HTTPEx.Telemetry.attach_default_logger/1` by detaching the attached logger.

  ## Examples

  Detach a previously attached logger:

      :ok = HTTPEx.Telemetry.attach_default_logger()
      :ok = HTTPEx.Telemetry.detach_default_logger()

  Attempt to detach when a logger wasn't attached:

      {:error, :not_found} = HTTPEx.Telemetry.detach_default_logger()
  """
  @doc since: "2.15.0"
  @spec detach_default_logger() :: :ok | {:error, :not_found}
  def detach_default_logger do
    :telemetry.detach(default_handler_id())
  end

  @doc false
  @spec handle_event([atom()], map(), map(), Keyword.t()) :: term()
  def handle_event([:http_ex, event], _measure, meta, opts) do
    log(opts, fn -> Map.put(meta, :event, event) end)
  end

  def handle_event(_event, _measure, _meta, _opts), do: :ok

  defp log(opts, fun) do
    level = Keyword.fetch!(opts, :level)

    Logger.log(level, fn ->
      Map.put(fun.(), :source, "http_ex")
    end)
  end
end
