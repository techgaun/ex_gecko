defmodule Mix.Tasks.LoadData do
  use Mix.Task
  require Logger
  @shortdoc "Populates Geckoboard datasets"

  @moduledoc """
  This will run specific adapters to populate your geckoboard with the right dataset

  ## Examples

      export GECKO_API_KEY=<key>

      # load data from papertrail into your dataset
      mix load_data -t papertrail -d mydataset

      # setup dataset (will erease all the previous data) using the right schema
      mix load_data -d mydataset -r reqs

      # load data from papertrail (pt) into your dataset with specific arguments.  Default values for "search" and "time" will be applied
      mix load_data -t pt -d mydataset -a "time=24 hours ago,search=My Search"

  ## Command Line Options
    * `--dataset` / `-d` - the dataset you want to load
    * `--type` / `-t` - type of data you want to retrieve and load, currently only 'papertrail' is supported
    * `--reset` / `-r` - this will recreate the dataset using the specific schema
    * `--args` / `-a` - arguments to be passed to the adapter (comma-separated)
  """

  @doc false
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [dataset: :string, type: :string, reset: :string, args: :string],
      aliases: [d: :dataset, t: :type, r: :reset, a: :args]
      )
    Application.ensure_all_started(:httpoison)
    case opts[:reset] do
      nil -> _run(opts[:dataset], opts[:type], opts[:args])
      _ -> reset_dataset(opts[:reset], opts[:dataset])
    end
  end

  def log(msg), do: IO.puts msg

  def _run(dataset, _type, _args) when is_nil(dataset), do: log("No 'dataset' was provided, please use the --dataset/-d switch statement'")
  def _run(_dataset, type, _args) when is_nil(type), do: log("No 'type' was provided, please use the --type/-t switch statement'")
  def _run(dataset, "papertrail", args) do
    events = ExGecko.Adapter.Papertrail.load_events(args)
    put_data(dataset, events)
  end
  def _run(dataset, "heroku", args) do
    events = ExGecko.Adapter.Heroku.load_events(args)
    put_data(dataset, events)
  end
  def _run(dataset, "pt", args), do: _run(dataset, "papertrail", args)
  def _run(_dataset, type, _args), do: log("Do not know how to handle type '#{type}'")

  def reset_dataset(_type, dataset) when is_nil(dataset) or dataset == "", do: log("Dataset name can not be blank")
  def reset_dataset(schema, dataset) do
    log("Deleting the dataset '#{dataset}'")
    # delete will fail if it doesn't exist, but continue so we can create the new dataset
    ExGecko.Api.delete(dataset)
    log("creating dataset '#{dataset}' using schema '#{schema}'")
    {:ok, %{}} = ExGecko.Api.create_dataset(dataset, schema)
  end
  def reset_dataset(type, _dataset), do: log("Unknown dataset schema '#{type}'")

  def put_data(_dataset, events) when length(events) == 0, do: log("No events to load")
  def put_data(dataset, events) do
    log("loading #{length(events)} events to #{dataset}")
    case ExGecko.Api.put(dataset, events) do
      {:ok, count} ->
        log("successfully loaded #{count} events")
      {:error, error, code} ->
        log("HTTP Error #{code} (#{error}) loading data points")
    end
  end
end
