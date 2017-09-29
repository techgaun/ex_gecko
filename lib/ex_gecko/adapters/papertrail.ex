defmodule ExGecko.Adapter.Papertrail do
  @moduledoc """
  Interacts with papertrail cli to get latest logs, so that we can send to geckobard

  Papertrail adapter accepts following arguments:

  * `search` : Search terms eg. `API Requests`
  * `time` : Earliest time to search from eg. `2 hours ago`

  Under the hood, it runs papertrail command

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

  def load_events(%{"search" => _search, "time" => _time} = opts) do
    Application.ensure_all_started(:porcelain)
    IO.puts "Pulling papertrail logs"
    case Porcelain.exec("papertrail", build_args(opts)) do
      %{status: 0, out: output} ->
        lines = output |> String.split("\n")
        items =
          for line <- lines,
            data = decode_line(line),
            valid?(data), into: [], do: process_data(data)

        items
        |> Enum.reject(&(map_size(&1) < 3))
      %{status: status, err: message} ->
        IO.puts "error executing command, #{status}, #{message}"
        []
    end
  end

  def load_events(opts) do
    # set default search/time values
    load_events(Map.merge(%{"time" => "168 hours ago", "search" => "API Requests"}, opts))
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
    data["message"]
    |> String.trim
    |> String.split(" ")
    |> Enum.reduce(%{"timestamp" => timestamp}, fn x, acc ->
      Map.merge(acc, _process_metric(x))
    end)
  end

  def _process_metric("path=" <> path), do: %{"path" => (path |> String.replace(~S("), "") |> String.split("_=") |> Enum.at(0) |> String.slice(0, 99))}
  def _process_metric("status=" <> status), do: %{"status" => status}
  def _process_metric("method=" <> method), do: %{"method" => method}
  def _process_metric("bytes="), do: %{"size" => 0}
  def _process_metric("bytes=" <> size), do: %{"size" => String.to_integer(size)}
  def _process_metric("service=" <> speed), do: %{"speed" => (speed |> String.replace("ms", "") |> intval)}
  def _process_metric(~s({") <> _ = json) do
    case Poison.decode(json) do
      {:ok, json} ->
        if String.downcase(json["method"]) == "options" do
          %{}
        else
          _process_json_metric(json, %{})
        end
      _ -> %{}
    end
  end
  def _process_metric(_), do: %{}

  def _process_json_metric(%{"status" => status} = json, acc) do
    _process_json_metric(
      Map.drop(json, ~w(status)), Map.put(acc, "status", "#{status}")
    )
  end
  def _process_json_metric(%{"path" => path} = json, acc) do
    _process_json_metric(
      Map.drop(json, ~w(path)), Map.put(acc, "path", path)
    )
  end
  def _process_json_metric(%{"duration" => speed} = json, acc) do
    _process_json_metric(
      Map.drop(json, ~w(duration)), Map.put(acc, "speed", speed)
    )
  end
  def _process_json_metric(%{"user_id" => user_id} = json, acc) do
    user_id = if is_binary(user_id), do: user_id, else: "anonymous"
    _process_json_metric(
      Map.drop(json, ~w(user_id)), Map.put(acc, "user_id", user_id)
    )
  end
  def _process_json_metric(%{"method" => method} = json, acc) do
    method = String.upcase(method)
    _process_json_metric(
      Map.drop(json, ~w(method)), Map.put(acc, "method", method)
    )
  end
  def _process_json_metric(%{"date_time" => time} = json, acc) do
    _process_json_metric(
      Map.drop(json, ~w(date_time)), Map.put(acc, "timestamp", time)
    )
  end
  def _process_json_metric(_, acc), do: acc

  defp intval(""), do: 0
  defp intval(str), do: String.to_integer(str)
end
