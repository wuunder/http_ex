ExUnit.start()

Finch.start_link(name: HTTPEx.FinchTestPool)

HTTPEx.Backend.Mock.start()
