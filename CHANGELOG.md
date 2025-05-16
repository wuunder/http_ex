# Changelog

## v0.2.2 (2025-04-30)

### Bug Fixes

- When testing with an `expect_request!`, `expect_body: {json_as_string, :json}` now returns the diff as 
  Map in the assertion. Which makes differences easier to spot.

## v0.2.1 (2025-04-30)

### Bug Fixes

- Unzip the body when the content-encoding states is gzipped for the client httpoison

## v0.2 (2025-04-23)

### Bug Fixes

- Fixed a bug where the export logging would sometimes trigger twice 
  instead of once.

## v0.1 (2025-03-03)

First release
