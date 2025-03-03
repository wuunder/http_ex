# HttpEx

HttpEx is an Elixir HTTP abstraction library to easily log, trace and mock your HTTP calls.

Note: work in progress. Things to come:

* Add support for different HTTP clients
* Add support for different tracing backends (currently only supports OpenTelemetry)
* Add support for different logger backends

![Build status](https://github.com/wuunder/http_ex/actions/workflows/ci.yml/badge.svg)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `http_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:http_ex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/http_ex>.

## Mocks

TODO
