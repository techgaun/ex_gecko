defmodule ExGecko.Adapter.Runscope do
  @moduledoc """
  Interacts with runscope API.  This doesn't handle authentication described here https://www.runscope.com/docs/api/authentication.
  This will assume you have an access_token available to use.  The main thing this will do is call the tests results API to get the latest
  test results, the api is described here https://www.runscope.com/docs/api/results
  """
  require HTTPoison
  require IEx
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

  def build_url(path, %{"bucket_key" => bucket_key, "test_id" => test_id} = opts) do
     params = case opts["count"] do
       nil -> ""
       count -> "?count=#{count}"
     end
     "#{url}/buckets/#{bucket_key}/tests/#{test_id}/results#{path}#{params}"
  end

  def build_url(path, opts) when is_nil(opts), do: build_url(path, %{})
  def build_url(path, opts), do: build_url(path, Map.merge(opts, %{"bucket_key" => "to5q0u5gglr4", "test_id" => "d8bb2a75-828f-4f5d-92fb-d313f38f691b"}))

  def auth_header do
    token = System.get_env("RUNSCOPE_TOKEN")
    if is_nil(token) do
      raise "Runscope token is missing"
    else
      [{"Authorization", "Bearer #{token}"}]
    end
  end


  # Function Returns the average response time across all requests of the test

  def find_response_time(test_run) do
    test_run
      |> Map.get("requests")
      |> Enum.filter(fn(request) -> not is_nil(request["url"]) end)     # some returned steps are not actually in the test routine and have nil urls
      |> Enum.map((fn(request) -> request["uuid"] end))
      |> avg_step_response(%{:sum => 0, :num_steps => 0}, test_run)
  end

  def avg_step_response([head | tail], %{:sum => sum, :num_steps => num_steps} , test_run) do
    case step_response_time(head, test_run) do
      {:ok, %{:response_time => response_time}} -> avg_step_response(tail, %{:sum => (sum + response_time), :num_steps => (num_steps + 1)}, test_run)
      # If Http request to retrieve the response time fails, do not add to the average
      _ -> avg_step_response(tail, %{:sum => sum, :num_steps => num_steps}, test_run)
    end
  end

  # When no more step uuids to check, average the response time
  def avg_step_response([], %{:sum => sum, :num_steps => num_steps}, test_run) do
    (sum / num_steps) * 1000
  end

  # Returns the total round trip time for a particular test step
  def step_response_time(uuid, %{"test_run_id" => test_run_id} = opts) do
    "/#{test_run_id}/steps/#{uuid}"
    |> build_url(opts)
    |> HTTPoison.get(auth_header)
    |> Parser.parse
    |> case do
        {:ok, %{"data" => step_response}} ->
          {:ok, %{ :response_time => (step_response["response"]["timestamp"] - step_response["request"]["timestamp"])} }
        _ -> {:error, ""}
    end
  end
end
