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

  def build_args(%{"search" => search, "time" => time} = opts) do
    args = ["-j", "-S", search, "--min-time", "'#{time}'"]
    config = opts["config"]
    if config do
      IO.puts "using config file #{config}"
      args ++ ["-c", config]
    else
      args
    end
  end

  def load_events(%{"search" => search, "time" => time} = opts) do
    Application.ensure_all_started(:porcelain)
    IO.puts "Pulling papertrail logs"
    case Porcelain.exec("papertrail", build_args(opts)) do
      %{status: 0, out: output} ->
        lines = output |> String.split("\n")
        for line <- lines,
            data = decode_line(line),
            valid?(data), into: [], do: process_data(data)
      %{status: status, err: message} ->
        IO.puts "error executing command, #{status}, #{message}"
        []
    end
  end

  def load_events(opts) do
    # set default search/time values
    load_events(Map.merge(%{"time" => "72 hours ago", "search" => "API Requests"}, opts))
  end

  def decode_line(line) when is_nil(line) or line == "", do: nil
  def decode_line(line) do
    case Poison.decode(line) do
      {:ok, data} -> data
      _ -> nil
    end
  end

  def valid?(data) when is_nil(data), do: false
  def valid?(data) when not is_map(data), do: false
  def valid?(data), do: Map.has_key?(data, "message") && Map.has_key?(data, "received_at")

  @doc """
  A sample format of the json object is like this.  Note the "message" section

  %{
    "display_received_at" => "Aug 02 19:14:29", 
    "facility" => "Local3",
    "generated_at" => "2016-08-02T19:14:29Z", 
    "hostname" => "brighterlink-api",
    "id" => "697210962448814080",
    "message" => "at=info method=GET path=\"/api/companies?_=1470165266333\" host=api.brighterlink.io request_id=6c1499a0-7e13-47ce-9efb-aa0a8dc9d7ea fwd=\"199.91.127.142\" dyno=web.1 connect=0ms service=94ms status=200 bytes=3165 ",
    "program" => "heroku/router",
    "received_at" => "2016-08-02T19:14:29Z",
    "severity" => "Info",
    "source_id" => 242534344,
    "source_ip" => "54.145.114.143",
    "source_name" => "brighterlink-api"
    }

    "message" is a string broken up in this way

      at=info
      method=GET
      path=\"/api/companies?_=1470165266333\"
      host=api.brighterlink.io
      request_id=6c1499a0-7e13-47ce-9efb-aa0a8dc9d7ea
      fwd=\"199.91.127.142\"
      dyno=web.1
      connect=0ms
      service=94ms
      status=200
      bytes=3165"
  """
  def process_data(data) do
    timestamp = data["received_at"]
    message = data["message"] |> String.strip
    msg_data = message |> String.split(" ")
    path = msg_data |> Enum.at(2) |> String.split("path=") |> Enum.at(-1) |> String.replace(~S("), "") |> String.split("_=") |> Enum.at(0)
    speed = msg_data |> Enum.at(-3) |> String.split("service=") |> Enum.at(-1) |> String.replace("ms", "") |> String.to_integer
    status = msg_data |> Enum.at(-2) |> String.split("status=") |> Enum.at(-1)
    size = msg_data |> Enum.at(-1) |> String.split("bytes=") |> Enum.at(-1) |> String.to_integer
    %{"path" => path, "speed" => speed, "timestamp" => timestamp, "status" => status, "size" => size}
  end
end
