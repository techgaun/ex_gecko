defmodule ExGecko.Adapter.Heroku do
  @moduledoc """
  Interacts with heroku cli to get latest logs, so that we can send the data to geckobard.

  The heroku adapter accepts following arguments:

  * `type` : One of `db`, `db-server`, `pg-backup`, `memory` and `load`
  * `app` : The heroku app you are wishing to pump logs from
  * `lines` : Number of lines to pull from logs (not applicable for `pg-backup`)

  Under the hood, it runs heroku command:

      heroku log --app <app_name> --num 1000
      heroku pg:backups --app <app_name>
  """

  def load_events(opts) when is_nil(opts), do: load_events(%{})
  def load_events(opts) when is_bitstring(opts) do
    opts
    |> String.split(",")
    |> Enum.map(fn(key) -> String.split(key, "=", parts: 2) |> List.to_tuple end)
    |> Map.new
    |> load_events
  end

  def load_events(%{"app" => app, "lines" => lines, "type" => type} = _opts) do
    Application.ensure_all_started(:porcelain)
    case Porcelain.exec("heroku", porcelain_args(type, app, lines)) do
      %{status: 0, out: output} ->
        lines = output
          |> strip_output(type)
          |> String.split("\n")
        for line <- lines, valid?(line, type), into: [], do: line |> parse_line(type) |> drop_keys(type)
      %{status: status, err: message} ->
        IO.puts "error executing command, #{status}, #{message}"
        []
      end
  end

  def load_events(opts) do
    # set default search/time values
    load_events(Map.merge(%{"app" => "brighterlink-api", "lines" => "100", "type" => "load"}, opts))
  end

  @doc """
  ## Examples

      iex> ExGecko.Adapter.Heroku.porcelain_args("pg-backup", "brighterlink", "1000")
      ["pg:backups", "--app", "brighterlink"]

      iex> ExGecko.Adapter.Heroku.porcelain_args("load", "brighterlink", "1000")
      ["logs", "--app", "brighterlink", "--num", "1000"]
  """
  @spec porcelain_args(String.t, String.t, String.t) :: List.t
  def porcelain_args("pg-backup", app, _), do: ["pg:backups", "--app", app]
  def porcelain_args(_, app, lines), do: ["logs", "--app", app, "--num", lines]

  @doc """
  ## Examples

      iex> ExGecko.Adapter.Heroku.strip_output("test=== Restores out", "pg-backup")
      "test"

      iex> ExGecko.Adapter.Heroku.strip_output("test===", "load")
      "test==="
  """
  @spec strip_output(String.t, String.t) :: String.t
  def strip_output(output, "pg-backup") do
    [backup | _] = output
      |> String.split("=== Restores")
    backup
  end
  def strip_output(output, _), do: output

  def valid?(line, _) when is_nil(line) or line === "", do: false
  def valid?(line, "load"), do: line =~ "sample#load_avg"
  def valid?(line, "memory"), do: line =~ "sample#memory_total"
  def valid?(line, type) when type in ["db", "db-server"], do: line =~ "sample#current_transaction"
  def valid?(line, "pg-backup"), do: line =~ "Completed"

  @doc """
  Few sample lines:

  "2016-08-02T22:23:31.718210+00:00 heroku[web.1]: source=web.1 dyno=heroku.49170529.b313ea93-6d23-470c-af62-2e7bf7acd76d sample#load_avg_1m=0.00 sample#load_avg_5m=0.08 sample#load_avg_15m=0.20"
  "2016-08-02T22:23:31.718381+00:00 heroku[web.1]: source=web.1 dyno=heroku.49170529.b313ea93-6d23-470c-af62-2e7bf7acd76d sample#memory_total=125.00MB sample#memory_rss=119.61MB sample#memory_cache=5.38MB sample#memory_swap=0.00MB sample#memory_pgpgin=415421pages sample#memory_pgpgout=386999pages sample#memory_quota=512.00MB"
  "2016-08-02T22:22:52+00:00 app[heroku-postgres]: source=HEROKU_POSTGRESQL_PINK sample#current_transaction=4171563.0 sample#db_size=1279201044.0bytes sample#tables=10 sample#active-connections=2 sample#waiting-connections=0 sample#index-cache-hit-rate=0.42019 sample#table-cache-hit-rate=0.78018 sample#load-avg-1m=0.025 sample#load-avg-5m=0.015 sample#load-avg-15m=0.025 sample#read-iops=0 sample#write-iops=0 sample#memory-total=3786332.0kB sample#memory-free=151956kB sample#memory-cached=3286396.0kB sample#memory-postgres=14840kB"
  """
  def parse_line(line, "pg-backup") do
    [backup_id, backup_start_time, backup_end_time, backup_size, backup_db] = line
      |> String.split(["  ", "Completed "])
      |> Enum.filter(&(String.length(&1) > 0))
    %{
      "backup_id" => backup_id,
      "backup_start_time" => pgbackup_timestamp(backup_start_time),
      "backup_end_time" => pgbackup_timestamp(backup_end_time),
      "backup_size" => float_value(backup_size),
      "backup_db" => String.trim(backup_db)
    }
  end
  def parse_line(line, _) do
    line
    |> String.split(" ")
    |> Enum.reduce(%{}, fn (x, acc) ->
      Map.merge(acc, _process_metric(x))
    end)
    |> _timestamp(line)
  end

  def _process_metric("dyno=heroku." <> dyno), do: %{"dyno" => dyno}
  def _process_metric("sample#load_avg_1m=" <> load_1m), do: %{"load_1m" => float_value(load_1m)}
  def _process_metric("sample#load_avg_5m=" <> load_5m), do: %{"load_5m" => float_value(load_5m)}
  def _process_metric("sample#load_avg_15m=" <> load_15m), do: %{"load_15m" => float_value(load_15m)}
  def _process_metric("sample#memory_total=" <> memory_total), do: %{"memory_total" => float_value(memory_total)}
  def _process_metric("sample#memory_rss=" <> memory_rss), do: %{"memory_rss" => float_value(memory_rss)}
  def _process_metric("sample#memory_cache=" <> memory_cache), do: %{"memory_cache" => float_value(memory_cache)}
  def _process_metric("sample#memory_swap=" <> memory_swap), do: %{"memory_swap" => float_value(memory_swap)}
  def _process_metric("sample#memory_pgpgin=" <> memory_pgpgin), do: %{"memory_pgpgin" => int_value(memory_pgpgin)}
  def _process_metric("sample#memory_pgpgout=" <> memory_pgpgout), do: %{"memory_pgpgout" => int_value(memory_pgpgout)}
  def _process_metric("sample#memory_quota=" <> memory_quota), do: %{"memory_quota" => float_value(memory_quota)}
  def _process_metric("source=" <> source), do: %{"source" => source}
  def _process_metric("sample#current_transaction=" <> current_transaction), do: %{"current_transaction" => current_transaction}
  def _process_metric("sample#db_size=" <> db_size), do: %{"db_size" => bytes_to_mb(db_size)}
  def _process_metric("sample#tables=" <> tables_count), do: %{"tables_count" => int_value(tables_count)}
  def _process_metric("sample#active-connections=" <> active_connections), do: %{"active_connections" => int_value(active_connections)}
  def _process_metric("sample#waiting-connections=" <> waiting_connections), do: %{"waiting_connections" => int_value(waiting_connections)}
  def _process_metric("sample#index-cache-hit-rate=" <> index_cache_hit_rate), do: %{"index_cache_hit_rate" => float_value(index_cache_hit_rate)}
  def _process_metric("sample#table-cache-hit-rate=" <> table_cache_hit_rate), do: %{"table_cache_hit_rate" => float_value(table_cache_hit_rate)}
  def _process_metric("sample#load-avg-1m=" <> load_1m), do: %{"load_1m" => float_value(load_1m)}
  def _process_metric("sample#load-avg-5m=" <> load_5m), do: %{"load_5m" => float_value(load_5m)}
  def _process_metric("sample#load-avg-15m=" <> load_15m), do: %{"load_15m" => float_value(load_15m)}
  def _process_metric("sample#read-iops=" <> read_iops), do: %{"read_iops" => int_value(read_iops)}
  def _process_metric("sample#write-iops=" <> write_iops), do: %{"write_iops" => int_value(write_iops)}
  def _process_metric("sample#memory-total=" <> memory_total), do: %{"memory_total" => kb_to_mb(memory_total)}
  def _process_metric("sample#memory-free=" <> memory_free), do: %{"memory_free" => kb_to_mb(memory_free)}
  def _process_metric("sample#memory-cached=" <> memory_cache), do: %{"memory_cache" => kb_to_mb(memory_cache)}
  def _process_metric("sample#memory-postgres=" <> memory_postgres), do: %{"memory_postgres" => kb_to_mb(memory_postgres)}
  def _process_metric(_), do: %{}

  def _timestamp(data, line) do
    ts = line |> String.slice(0, 19)
    Map.put(data, "timestamp", "#{ts}Z")
  end

  def pgbackup_timestamp(str) do
    ts = str
      |> String.slice(0, 19)
      |> String.replace(" ", "T")
    "#{ts}Z"
  end

  def drop_keys(data, "db") do
    invalid_keys = ["load_1m", "load_5m", "load_15m", "read_iops",
        "write_iops", "memory_total", "memory_cache", "memory_free"
      ]
    data
    |> Map.drop(invalid_keys)
  end
  def drop_keys(data, "db-server") do
    invalid_keys = ["current_transaction", "db_size", "tables_count", "active_connections",
        "waiting_connections", "index_cache_hit_rate", "table_cache_hit_rate", "memory_postgres"
      ]
    data
    |> Map.drop(invalid_keys)
  end
  def drop_keys(data, _), do: data

  defp bytes_to_mb(str) do
    str
    |> float_value
    |> Kernel./(1_048_576)
  end
  defp kb_to_mb(str) do
    str
    |> float_value
    |> Kernel./(1024)
  end
  defp float_value(str) do
    {val, _} = Float.parse(str)
    val
  end
  defp int_value(str) do
    {val, _} = Integer.parse(str)
    val
  end
end
