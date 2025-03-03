import Config

config :opentelemetry,
  traces_exporter: :none

config :opentelemetry, :processors, [
  {:otel_simple_processor, %{}}
]

config :http_ex, backend: HTTPEx.Backend.Mock
