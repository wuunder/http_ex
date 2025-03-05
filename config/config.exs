import Config

config :http_ex,
  client: :httpoison,
  open_telemetry: true

import_config "#{Mix.env()}.exs"
