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

  ## Command Line Options
    * `--dataset` / `-d` - the dataset you want to load
    * `--type` / `-t` - type of data you want to retrieve and load, currently only 'papertrail' is supported
  """

  @doc false
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [dataset: :string, type: :string],
      aliases: [d: :dataset, t: :type]
      )
    _run(opts[:dataset], opts[:type])
  end

  def log(msg), do: IO.puts msg

  def _run(dataset, _type) when is_nil(dataset), do: log("No 'dataset' was provided, please use the --dataset/-d switch statement'")
  def _run(_dataset, type) when is_nil(type), do: log("No 'type' was provided, please use the --type/-t switch statement'")
  def _run(dataset, "papertrail") do
    events = ExGecko.Adapter.Papertrail.load_events()
    put_data(dataset, events)
  end
  def _run(dataset, "pt"), do: _run(dataset, "papertrail")
  def _run(_dataset, type), do: log("Do not know how to handle type '#{type}'")

  def put_data(_dataset, events) when length(events) == 0, do: log("No events to load")
  def put_data(dataset, events) do
    Application.ensure_all_started(:httpoison)
    case ExGecko.Api.put(dataset, events) do
      {:ok, %{}} ->
        log("Papertrail data loaded (#{length(events)} events)")
      {:error, error, code} ->
        log("HTTP Error #{code} (#{error}) loading papertrail data points")
    end
  end

end
