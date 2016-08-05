defmodule ExGecko do
  @moduledoc """
  ex_gecko is an Elixir SDK to push data to Geckoboard.

  ex_gecko provides a simple wrapper around [Geckoboard Datasets API](https://developer-beta.geckoboard.com/).
  It also implements an adapter based modular design to load data from various sources into the datasets.
  Currently, we provide heroku and papertrail adapters.

  If you're looking to use Gecko API, you should check out `ExGecko.Api` module.
  Our adapters for heroku and papertrail can be used via `Mix.Tasks.Gecko.Load`.

  You need to set GECKO_API_KEY in your environment variable to start using ex_gecko.
  """
end
