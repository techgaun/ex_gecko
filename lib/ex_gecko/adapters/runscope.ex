defmodule ExGecko.Adapter.Runscope do
  @moduledoc """
  Interacts with runscope API.  This doesn't handle authentication described here https://www.runscope.com/docs/api/authentication.
  This will assume you have an access_token available to use.  The main thing this will do is call the tests results API to get the latest
  test results, the api is described here https://www.runscope.com/docs/api/results

  The heroku adapter accepts following arguments:

  * `test_id` : The id of the test that will be updated in the Geckoboard dataset
  * `bucket_id` : the ID of the test bucket

  Note, we need both the name and the test ID because the Runscope API does not return the name of the test in its response. Therefore we have to
  rely on the user to input the name

  """
  require HTTPoison
  alias ExGecko.Parser

  def url, do: "https://api.runscope.com"

  def load_events(opts) when is_nil(opts), do: load_events(%{})
  def load_events(opts) when is_bitstring(opts) do
    opts
    |> parse_args
    |> load_events
  end

  # Builds a single event for the given test_id, to be pushed to the geckoboard dataset
  # TO DO - support different schemas - right now, this only supports runscope.dash.json
  def load_events(%{"test_id" => test_id, "bucket_id" => _bucket_id} = opts) do
    case last_result(opts) do
      {:ok, %{"data" => last}} ->
        last_status = last["result"]
        last_test_date = get_datetime(last["finished_at"])
        success_ratio = calc_success_ratio(opts)
        avg_response_time = find_response_time(last)
        name = get_test_name(opts)
        assertion_success_ratio = last["assertions_passed"] / last["assertions_defined"]
        event = %{
                  "test_id" => test_id,
                  "name" => name,
                  "last_status" => last_status,
                  "last_test_date" => last_test_date,
                  "success_ratio" => success_ratio,
                  "avg_response_time" => avg_response_time,
                  "assertion_success_ratio" => assertion_success_ratio
                }
        {:ok, event}

      _ -> {:error, ""}
    end
  end

  # parses bitstring into a map
  def parse_args(opts) do
    opts
    |> String.split(",")
    |> Enum.map(fn(key) -> String.split(key, "=", parts: 2) |> List.to_tuple end)
    |> Map.new
  end


  def get_test_name(opts) do
    case test_detail(opts) do
      {:ok, %{"data" => detail}} -> detail["name"]
      _ -> nil
    end
  end

  #
  # Function Returns the average response time across all requests of the test
  #
  def find_response_time(test_run) do
    time = test_run
      |> Map.get("requests")
      |> Enum.filter(fn(request) -> not is_nil(request["url"]) end)     # some returned steps are not actually in the test routine and have nil urls
      |> Enum.map((fn(request) -> request["uuid"] end))
      |> avg_step_response(%{:sum => 0, :num_steps => 0}, test_run)


    if is_nil(time) do
      ""
    else
      Float.round(time, 2) # use 2 digits of precision
    end
  end

  #
  # Determines total run time of test, by recursively iterating through steps
  #
  def avg_step_response([head | tail], %{sum: sum, num_steps: num_steps} , test_run) do
    case step_response_time(head, test_run) do
      {:ok, %{:response_time => response_time}} -> avg_step_response(tail, %{:sum => (sum + response_time), :num_steps => (num_steps + 1)}, test_run)
      # If Http request to retrieve the response time fails, do not add to the average
      _ -> avg_step_response(tail, %{:sum => sum, :num_steps => num_steps}, test_run)
    end
  end

  #
  # When no more step uuids to check, average the response time
  #
  def avg_step_response([], %{sum: sum, num_steps: num_steps}, _test_run) do
    if num_steps == 0 do
      nil
    else
      (sum / num_steps) * 1000
    end
  end

  #
  # Returns the total round trip time for a particular test step
  #
  def step_response_time(uuid, %{"test_run_id" => test_run_id} = opts) do
    "/results/#{test_run_id}/steps/#{uuid}"
    |> build_url(opts)
    |> HTTPoison.get(auth_header)
    |> Parser.parse
    |> case do
        {:ok, %{"data" => step_response}} ->
          if (!is_nil(step_response["response"]["timestamp"]) && !is_nil(step_response["response"]["timestamp"])) do
            {:ok, %{ :response_time => (step_response["response"]["timestamp"] - step_response["request"]["timestamp"])} }
          else
            {:error, ""}
          end
        _ -> {:error, ""}
    end
  end

  #
  # Wrapper for converting unix time to ISO 8601 string
  #
  def get_datetime(unix_time) when is_nil(unix_time), do: ""
  def get_datetime(unix_time) do
    case unix_time_to_iso(unix_time) do
      {:ok, iso} -> iso
      _ -> ""
    end
  end

  #
  # Converts a Unix time float to an ISO 8601 string
  #
  def unix_time_to_iso(unix_time) do
    unix_time
    |> Float.floor
    |> Kernel.+(62167219200)  # convert unix time to gregorian (since year 0)
    |> Kernel.trunc
    |> :calendar.gregorian_seconds_to_datetime
    |> Timex.datetime
    |> Timex.format("{ISOz}")
  end

  #
  # Calculates the percentage of tests that have succeeded over the past 24 hours
  #
  def calc_success_ratio(opts) do
    timestamp = Timex.Convertable.to_unix(Timex.DateTime.now) - 7 * 24 * 60 * 60  # Timestamp for 24 hours ago
    new_opts = if is_nil(opts), do: %{"since" => timestamp, "count" => 50}, else: Map.merge(%{"since" => timestamp, "count" => 50}, opts)
    case test_results(new_opts) do
      {:ok, %{"data" => results}} -> Enum.reduce(results, 0, fn(result, accum) -> if result["result"] == "pass", do: accum + 1, else: accum end) / Enum.count(results)
      _ -> {:error, ""}
    end
  end


  #
  # Prepares a request matching the Geckoboard Legacy Uptime widget
  #
  def uptime(args) do
    opts = parse_args(args)
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
    ago = Float.round(:os.system_time(:seconds) - time, 2)
    cond do
       ago < 60 -> "#{Float.round(ago,2)} seconds ago"
       ago < 60*60 -> "#{Float.round(ago/60,2)} minutes ago"
       ago < 60*60*24 -> "#{Float.round(ago/3600,1)} hours ago"
       true -> "#{Float.round(ago/86400,1)} days ago"
    end
  end


  #
  # Retrieves test details such as name, version, creator, etc
  # Example URL : https://api.runscope.com/buckets/#{BUCKETID}/tests/#{TESTID}
  #
  def test_detail(opts) do
    ""
    |> build_url(opts)
    |> HTTPoison.get(auth_header)
    |> Parser.parse
  end

  #
  # Retrieves the latest result of the test, given test_id, bucket_id in opts
  #
  def last_result(opts) do
    "/results/latest"
    |> build_url(opts)
    |> HTTPoison.get(auth_header)
    |> Parser.parse
  end

  def test_results(opts) do
    "/results"
    |> build_url(opts)
    |> HTTPoison.get(auth_header)
    |> Parser.parse
  end

  def build_url(path, %{"bucket_id" => bucket_id, "test_id" => test_id} = opts) do
     params = ""
     |> add_param(opts, "count")
     |> add_param(opts, "since")

     "#{url}/buckets/#{bucket_id}/tests/#{test_id}#{path}#{params}"
  end

  def build_url(path, opts) when is_nil(opts), do: build_url(path, %{})
  def build_url(path, opts), do: build_url(path, Map.merge(opts, %{"bucket_id" => "to5q0u5gglr4", "test_id" => "d8bb2a75-828f-4f5d-92fb-d313f38f691b"}))


  #
  # If the given param is a key in the options map, appends the value to the param_string
  #
  def add_param(param_string, opts, param) do
    case opts[param] do
       nil -> param_string
       val -> if param_string == "", do: "?#{param}=#{val}", else: param_string <> "&{param}=#{val}"
    end
  end

  def auth_header do
    token = System.get_env("RUNSCOPE_TOKEN")
    if is_nil(token) do
      raise "Runscope token is missing"
    else
      [{"Authorization", "Bearer #{token}"}]
    end
  end
end
