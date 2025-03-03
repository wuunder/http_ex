import Config

config :http_ex,
  default_client: :httpoison,
  open_telemetry: true

import_config "#{Mix.env()}.exs"
