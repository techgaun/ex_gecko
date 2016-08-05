defmodule ExGecko.Adapter.Runscope do
  @moduledoc """
  Interacts with runscope API.  This doesn't handle authentication described here https://www.runscope.com/docs/api/authentication.
  This will assume you have an access_token available to use.  The main thing this will do is call the tests results API to get the latest
  test results, the api is described here https://www.runscope.com/docs/api/results
  """
  require HTTPoison
  alias ExGecko.Parser

  def url, do: "https://api.runscope.com"

  def uptime(opts) do
    case last_result(opts) do
      {:ok, %{"data" => last}} ->
        status = if last["result"] == "pass", do: :up, else: :down
        {:ok, {status, find_last_down(last, opts), find_response_time(last)}}
      _ -> {:error, ""}
    end
  end

  def find_response_time(result) do
      # this is very specific to our test case, have to refactor for more general use
      response_time = Enum.at(Enum.at(result["requests"], 1)["assertions"], 1)["actual_value"]
      if is_nil(response_time) do
        response_time = Float.round((result["finished_at"] - result["started_at"]) * 1000, 2)
      end
      response_time
  end

  def find_last_down(last, opts) do
    result = if last["result"] != "pass" do
      # use the finished_at time for the last time it was down
      last
    else
      new_opts = if is_nil(opts), do: %{"count" => 50}, else: Map.merge(%{"count" => 50}, opts)
      {:ok, %{"data" => results}} = test_results(new_opts)
      Enum.find(results, fn(result) -> result["result"] != "pass" end)
    end
    convert_to_ago(result)
  end

  def convert_to_ago(result) when is_nil(result), do: ""
  def convert_to_ago(result) do
    time = result["finished_at"]
    ago = Float.round((:os.system_time(:milli_seconds) / 1000) - time, 2)
    "#{ago} secs ago"
  end

  def last_result(opts) do
    "/latest"
    |> build_url(opts)
    |> HTTPoison.get(auth_header)
    |> Parser.parse
  end

  def test_results(opts) do
    ""
    |> build_url(opts)
    |> HTTPoison.get(auth_header)
    |> Parser.parse
  end

  def build_url(path, %{"bucket" => bucket, "test" => test} = opts) do
     params = case opts["count"] do
       nil -> ""
       count -> "?count=#{count}"
     end
     "#{url}/buckets/#{bucket}/tests/#{test}/results#{path}#{params}"
  end

  def build_url(path, opts) when is_nil(opts), do: build_url(path, %{})
  def build_url(path, opts), do: build_url(path, Map.merge(opts, %{"bucket" => "to5q0u5gglr4", "test" => "d8bb2a75-828f-4f5d-92fb-d313f38f691b"}))

  def auth_header do
    token = System.get_env("RUNSCOPE_TOKEN")
    if is_nil(token) do
      raise "Runscope token is missing"
    else
      [{"Authorization", "Bearer #{token}"}]
    end
  end
end
