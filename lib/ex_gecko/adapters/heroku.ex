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

  def load_events(%{"app" => app, "lines" => lines} = opts) do
    Application.ensure_all_started(:porcelain)
    case Porcelain.exec("heroku", ["logs", "--app", app, "--num", "#{lines}"]) do
      %{status: 0, out: output} ->
        lines = output |> String.split("\n")
        for line <- lines, valid?(line), into: [], do: parse_line(line)
      %{status: status, err: message} ->
        IO.puts "error executing command, #{status}, #{message}"
        []
      end
  end

  def load_events(opts) do
    # set default search/time values
    load_events(Map.merge(%{"app" => "brighterlink-api", "lines" => 100}, opts))
  end

  def valid?(line) when is_nil(line) or line == "", do: false
  def valid?(line) do
    line =~ "sample#load_avg" || line =~ "sample#memory_total" || line =~ "sample#current_transaction"
  end

  @doc """
  Few sample lines:

  "2016-08-02T22:23:31.718210+00:00 heroku[web.1]: source=web.1 dyno=heroku.49170529.b313ea93-6d23-470c-af62-2e7bf7acd76d sample#load_avg_1m=0.00 sample#load_avg_5m=0.08 sample#load_avg_15m=0.20"
  "2016-08-02T22:23:31.718381+00:00 heroku[web.1]: source=web.1 dyno=heroku.49170529.b313ea93-6d23-470c-af62-2e7bf7acd76d sample#memory_total=125.00MB sample#memory_rss=119.61MB sample#memory_cache=5.38MB sample#memory_swap=0.00MB sample#memory_pgpgin=415421pages sample#memory_pgpgout=386999pages sample#memory_quota=512.00MB"
  "2016-08-02T22:22:52+00:00 app[heroku-postgres]: source=HEROKU_POSTGRESQL_PINK sample#current_transaction=4171563.0 sample#db_size=1279201044.0bytes sample#tables=10 sample#active-connections=2 sample#waiting-connections=0 sample#index-cache-hit-rate=0.42019 sample#table-cache-hit-rate=0.78018 sample#load-avg-1m=0.025 sample#load-avg-5m=0.015 sample#load-avg-15m=0.025 sample#read-iops=0 sample#write-iops=0 sample#memory-total=3786332.0kB sample#memory-free=151956kB sample#memory-cached=3286396.0kB sample#memory-postgres=14840kB"

  0 -> Jul
  1 -> 28
  2 -> 13:45:47
  3 -> brighterlink-api
  4 -> heroku/router:
  5 -> at=info
  6 -> method=GET
  7 -> path="/api/companies?id=1&_=1469713536888"
  8 -> host=api.brighterlink.io
  9 -> request_id=64e85251-bfe0-4f86-9e27-e3ae60fce74a
  10 -> fwd="199.91.127.142"
  11 -> dyno=web.1
  12 -> connect=0ms
  13 -> service=41ms
  14 -> status=200
  15 -> bytes=969
  16 ->
  """
  def parse_line(line) do
    line
    # data = line
    #   |> String.replace("  ", " ")
    #   |> String.split(" ")
    # {year, _, _} = :erlang.date
    # timestamp = "#{year}-#{convert_month(Enum.at(data, 0))}-#{format_day(Enum.at(data, 1))}T#{Enum.at(data, 2)}Z"
    # path = data |> Enum.at(7) |> String.split("path=") |> Enum.at(-1) |> String.replace(~S("), "") |> String.split("_=") |> Enum.at(0)
    # speed = data |> Enum.at(-4) |> String.split("service=") |> Enum.at(-1) |> String.replace("ms", "") |> String.to_integer
    # status = data |> Enum.at(-3) |> String.split("status=") |> Enum.at(-1)
    # size = data |> Enum.at(-2) |> String.split("bytes=") |> Enum.at(-1) |> String.to_integer
    # %{"path" => path, "speed" => speed, "timestamp" => timestamp, "status" => status, "size" => size}
  end

  def convert_month(month) do
    case month do
      "Jan" -> "01"
      "Feb" -> "02"
      "Mar" -> "03"
      "Apr" -> "04"
      "May" -> "05"
      "Jun" -> "06"
      "Jul" -> "07"
      "Aug" -> "08"
      "Sep" -> "09"
      "Oct" -> "10"
      "Nov" -> "11"
      "Dec" -> "12"
      _ -> ":error"
    end
  end

  @doc """
  ## Examples

      iex> ExGecko.Adapter.Papertrail.format_day("1")
      "01"

      iex> ExGecko.Adapter.Papertrail.format_day("11")
      "11"
  """
  @spec format_day(String.t) :: String.t
  def format_day(day) when is_bitstring(day) do
    case String.length(day) do
      1 ->
        "0#{day}"

      _ ->
        day
    end
  end
  def format_day(day), do: day
end
