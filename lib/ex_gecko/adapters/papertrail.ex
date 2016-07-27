defmodule ExGecko.Adapter.Papertrail do

@moduledoc """
Interacts with papertrail cli to get latest logs, so that we can send to geckobard
papertrail -S "API Requests" --min-time '120 minutes ago'
"""

  def load_events(opts \\ %{"time" => "8 hours ago", "search" => "API Requests"}) do
    Application.ensure_all_started(:porcelain)
    case Porcelain.exec("papertrail", ["-S", opts["search"], "--min-time", "'#{opts["time"]}'"]) do
      %{status: 0, out: output} ->
        output
        |> String.split("\n")
        |> Enum.map(fn(line) ->
           data = String.split(line, " ")
           if length(data) > 5 do
             timestamp = "2016-#{convert_month(Enum.at(data, 0))}-#{Enum.at(data, 1)}T#{Enum.at(data, 2)}Z"
             path = data |> Enum.at(7) |> String.split("path=") |> Enum.at(-1) |> String.replace("\"", "") |> String.split("_=") |> Enum.at(0)
             speed = data |> Enum.at(-4) |> String.split("service=") |> Enum.at(-1) |> String.replace("ms", "") |> String.to_integer
             data = %{"path" => path, "speed" => speed, "timestamp" => timestamp, "count" => 1}
             data
           else
            %{}
           end
        end)
      %{status: status, err: message} ->
        IO.puts "error executing command, #{status}, #{message}"
        []
      end
  end

  def convert_month(month) do
    case month do
      "Jul" -> "07"
    end
  end
end