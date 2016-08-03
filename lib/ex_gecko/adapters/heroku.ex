defmodule ExGecko.Adapter.Heroku do
  @moduledoc """
  Interacts with heroku cli to get latest logs, so that we can send to geckobard
  heroku log --app <app_name>
  """

  def load_events(opts) when is_nil(opts), do: load_events(%{})
  def load_events(opts) when is_bitstring(opts) do
    new_opts = opts
    |> String.split(",")
    |> Enum.map(fn(key) -> String.split(key, "=", parts: 2) |> List.to_tuple end)
    |> Map.new
    load_events(new_opts)
  end

  def load_events(%{"app" => app, "lines" => lines, "type" => type} = opts) do
    Application.ensure_all_started(:porcelain)
    case Porcelain.exec("heroku", ["logs", "--app", app, "--num", "#{lines}"]) do
      %{status: 0, out: output} ->
        lines = output |> String.split("\n")
        for line <- lines, valid?(line, type), into: [], do: parse_line(line)
      %{status: status, err: message} ->
        IO.puts "error executing command, #{status}, #{message}"
        []
      end
  end

  def load_events(opts) do
    # set default search/time values
    load_events(Map.merge(%{"app" => "brighterlink-api", "lines" => 100, "type" => "load"}, opts))
  end

  def valid?(line, _) when is_nil(line) or line === "", do: false
  def valid?(line, "load"), do: line =~ "sample#load_avg"
  def valid?(line, "memory"), do: line =~ "sample#memory_total"
  def valid?(line, "db"), do: line =~ "sample#current_transaction"

  @doc """
  Few sample lines:

  "2016-08-02T22:23:31.718210+00:00 heroku[web.1]: source=web.1 dyno=heroku.49170529.b313ea93-6d23-470c-af62-2e7bf7acd76d sample#load_avg_1m=0.00 sample#load_avg_5m=0.08 sample#load_avg_15m=0.20"
  "2016-08-02T22:23:31.718381+00:00 heroku[web.1]: source=web.1 dyno=heroku.49170529.b313ea93-6d23-470c-af62-2e7bf7acd76d sample#memory_total=125.00MB sample#memory_rss=119.61MB sample#memory_cache=5.38MB sample#memory_swap=0.00MB sample#memory_pgpgin=415421pages sample#memory_pgpgout=386999pages sample#memory_quota=512.00MB"
  "2016-08-02T22:22:52+00:00 app[heroku-postgres]: source=HEROKU_POSTGRESQL_PINK sample#current_transaction=4171563.0 sample#db_size=1279201044.0bytes sample#tables=10 sample#active-connections=2 sample#waiting-connections=0 sample#index-cache-hit-rate=0.42019 sample#table-cache-hit-rate=0.78018 sample#load-avg-1m=0.025 sample#load-avg-5m=0.015 sample#load-avg-15m=0.025 sample#read-iops=0 sample#write-iops=0 sample#memory-total=3786332.0kB sample#memory-free=151956kB sample#memory-cached=3286396.0kB sample#memory-postgres=14840kB"
  """
  def parse_line(line) do
    data = line
      |> String.split(" ")
    data_map = data
      |> Enum.reduce(%{}, fn (x, acc) ->
        metric = _process_metric(x)
        case metric do
          %{} ->
            Map.merge(acc, metric)

          _ ->
            acc
        end
      end)
      |> _timestamp(line)
  end

  def _process_metric("dyno=heroku." <> dyno), do: %{"dyno" => dyno}
  def _process_metric("sample#load_avg_1m=" <> load_1m), do: %{"1m" => String.to_float(load_1m)}
  def _process_metric("sample#load_avg_5m=" <> load_5m), do: %{"5m" => String.to_float(load_5m)}
  def _process_metric("sample#load_avg_15m=" <> load_15m), do: %{"15m" => String.to_float(load_15m)}
  def _process_metric(_), do: nil

  def _timestamp(data, line) do
    ts = line |> String.slice(0, 19)
    Map.put(data, "timestamp", ts)
  end
end
