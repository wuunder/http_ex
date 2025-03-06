import Config

config :http_ex,
  client: :httpoison,
  tracing: true,
  telemetry: true

import_config "#{Mix.env()}.exs"
