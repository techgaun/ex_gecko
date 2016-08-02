defmodule ExGecko.Adapter.Papertrail do
  @moduledoc """
  Interacts with papertrail cli to get latest logs, so that we can send to geckobard
  papertrail -S "API Requests" --min-time '120 minutes ago'
  """

  def load_events(opts) when is_nil(opts), do: load_events(%{})
  def load_events(opts) when is_bitstring(opts) do
    new_opts = opts
    |> String.split(",")
    |> Enum.map(fn(key) -> String.split(key, "=", parts: 2) |> List.to_tuple end)
    |> Map.new
    load_events(new_opts)
  end

  def load_events(%{"search" => search, "time" => time} = opts) do
    Application.ensure_all_started(:porcelain)
    case Porcelain.exec("papertrail", ["-S", search, "--min-time", "'#{time}'"]) do
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
    load_events(Map.merge(%{"time" => "72 hours ago", "search" => "API Requests"}, opts))
  end

  def valid?(line) when is_nil(line) or line == "", do: false
  def valid?(line), do: length(String.split(line, " ")) > 10

  @doc """
  A sample format line is this

  Jul 28 13:45:47 brighterlink-api heroku/router: at=info method=GET path="/api/companies?id=1&_=1469713536888" host=api.brighterlink.io request_id=64e85251-bfe0-4f86-9e27-e3ae60fce74a fwd="199.91.127.142" dyno=web.1 connect=0ms service=41ms status=200 bytes=969

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
    data = line
      |> String.replace("  ", " ")
      |> String.split(" ")
    {year, _, _} = :erlang.date
    timestamp = "#{year}-#{convert_month(Enum.at(data, 0))}-#{format_day(Enum.at(data, 1))}T#{Enum.at(data, 2)}Z"
    path = data |> Enum.at(7) |> String.split("path=") |> Enum.at(-1) |> String.replace(~S("), "") |> String.split("_=") |> Enum.at(0)
    speed = data |> Enum.at(-4) |> String.split("service=") |> Enum.at(-1) |> String.replace("ms", "") |> String.to_integer
    status = data |> Enum.at(-3) |> String.split("status=") |> Enum.at(-1)
    size = data |> Enum.at(-2) |> String.split("bytes=") |> Enum.at(-1) |> String.to_integer
    %{"path" => path, "speed" => speed, "timestamp" => timestamp, "status" => status, "size" => size}
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
