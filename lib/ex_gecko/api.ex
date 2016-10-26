defmodule ExGecko.Api do
  @moduledoc """
  API interface to communicate with geckoboard's api

  Todo: refactor code so that we can move auth part to single place
  """

  use HTTPoison.Base
  alias ExGecko.Parser
  alias __MODULE__

  @user_agent [{"User-agent", "ex_gecko"}]
  @content_type [{"Content-Type", "application/json"}]

  @doc """
  Creating URL based on url from config and resources paths
  """
  @spec process_url(String.t) :: String.t
  def process_url(path) do
    if String.starts_with?(path, "http") do
      path
    else
      "https://api.geckoboard.com/#{path}"
    end
  end

  @doc """
  Wrapper for PUT requests

  Examples
  """
  @spec update(String.t, map, boolean) :: ExGecko.response
  def update(id, put_data, data \\ false) do
    req_header = request_header_content_type
    if put_data |> is_map do
      put_data = Poison.encode!(put_data)
    end
    id
    |> build_url(data)
    |> Api.put(put_data, req_header)
    |> Parser.parse
  end

  @doc """
  Wrapper for DELETE requests

  Examples
  - ExGecko.Api.delete("mydataset")
  """
  @spec delete(String.t) :: Brighterx.response
  def delete(id) do
    req_header = request_header
    id
    |> build_url
    |> Api.delete(req_header)
    |> Parser.parse
  end

  @doc """
  Wrapper for POST requests

  Examples
  """
  @spec post_request(String.t, map, boolean) :: ExGecko.response
  def post_request(id, data, has_data \\ false) do
    req_header = request_header_content_type
    if data |> is_map do
      data = Poison.encode!(data)
    end
    id
    |> build_url(has_data)
    |> Api.post(data, req_header)
    |> Parser.parse
  end

  @doc """
  Convenience function to manage datasets.  Follows similar syntax as this
  https://developer-beta.geckoboard.com/nodejs/

  Examples
  - ExGecko.Api.find_or_create - finds or creates the dataset
  - ExGecko.Api.put - replaces all data in the dataset
  - ExGecko.Api.delete - deletes the dataset and data therein
  """
  @spec ping() :: ExGecko.response
  def ping do
    req_header = request_header
    nil
    |> build_url
    |> Api.get(req_header)
    |> Parser.parse
  end
  @spec find_or_create(String.t, map) :: ExGecko.response
  def find_or_create(id, fields), do: update(id, fields, false)
  @spec put(String.t, list) :: ExGecko.response


  # Need to handle batch job, redirect to append
  def put(id, data) when is_list(data) and length(data) > 500 do
    append(id, data)
  end

  def put(id, data) when is_list(data) do
    put(id, %{"data" => data})
  end
  def put(id, data) when is_map(data) do
    resp = update(id, data, true)
    case resp do
      {:ok, %{}} ->
        count = length(data["data"])
        {:ok, count}
      _ -> resp
    end
  end

  @doc """
  Appends data to an existing dataset. If the dataset contains a unique id field,
  then any fields with the same uniqueId will be updated.

  Example 
  """
  @spec append(String.t, map) :: ExGecko.response

  def append(id, data) when is_list(data) and length(data) > 5000 do
    IO.puts "Currently the Geckoboard datasets cannot hold more than 5000 events, reducing events sent from #{length(data)} to 5000"
    append(id, data |> limit_data)
  end

  def append(id, data) when is_list(data) and 500 < length(data) and length(data) <= 5000 do
    data
    |> Enum.chunk(500, 500, [])                   # break into the maximum request size, send individually
    |> Enum.each(fn x -> append(id, x) end)       # Enum.each function always returns :ok, could find way to check if one request fails
  end

  def append(id, data) when is_list(data) do
    append(id, %{"data" => data})
  end

  def append(id, data) when is_map(data) do
    resp = post_request(id, data, true)
    case resp do
      {:ok, %{}} ->
        count = length(data["data"])
        {:ok, count}
      _ -> resp
    end
  end

  @spec push(String.t, map) :: ExGecko.response
  @doc """
  Push API to Geckoboard, which is a POST with this data format

  {
    "api_key": "222f66ab58130a8ece8ccd7be57f12e2",
    "data": {
       "item": [
          { "text": "Visitors", "value": 4223 },
          { "text": "", "value": 238 }
        ]
    }
  }
  """
  def push(widget_key, data) do
    api_key = System.get_env("GECKO_API_KEY")
    post_data = %{"api_key" => api_key, "data" => data} |> Poison.encode!
    widget_key
    |> build_url(:push)
    |> Api.post(post_data, @content_type)
    |> Parser.parse
  end

  @doc """
  Monitor format expected from geckoboard

  {
    "status": "Up",
    "downTime": "9 days ago",
    "responseTime": "593 ms"
  }

  {
    "status": "Down",
    "downTime": "2 days ago",
    "responseTime": "593 ms"
  }
  """
  def push_monitor(widget_key, status, down_time \\ "", response_time \\ "") do
    push(widget_key, %{"status" => format_status(status), "downTime" => down_time, "responseTime" => response_time})
  end

  def format_status(:up), do: "Up"
  def format_status(:down), do: "Down"
  def format_status(status) when is_bitstring(status), do: String.capitalize(status)

  @spec create_reqs_dataset(String.t) :: ExGecko.response
  def create_reqs_dataset(id), do: create_dataset(id, "papertrail.reqs")
  @spec create_dataset(String.t, String.t) :: ExGecko.response
  def create_dataset(id, type \\ "reqs") do
    {:ok, fields} = "datasets/#{type}.json" |> File.read
    find_or_create(id, fields)
  end


  @doc """
  Builds URL based on the resource, id and parameters
  """
  @spec build_url(String.t) :: String.t
  def build_url(nil), do: "/"
  def build_url(id), do: "/datasets/#{id}"
  def build_url(id, true), do: build_url(id) <> "/data"
  def build_url(id, false), do: build_url(id)
  def build_url(id, :push), do: "https://push.geckoboard.com/v1/send/#{id}"

  @doc """
    ## Examples

      iex> Mix.Tasks.LoadData.limit_data(Enum.to_list(1..500)) === Enum.to_list(101..500)
      true
  """
  @spec limit_data(list) :: list
  def limit_data(events) do
    events
    |> Enum.reverse
    |> Enum.slice(0..4999)
    |> Enum.reverse
  end


  @doc """
  Add header with username
  and also the user agent
  """
  def auth_header do
    api_key = System.get_env("GECKO_API_KEY")
    if is_nil(api_key) do
      raise "Geckoboard API Key is missing"
    else
      api_key = api_key <> ":"
      [{"Authorization", "Basic #{Base.encode64(api_key)}"}]
    end
  end

  def request_header, do: @user_agent ++ auth_header
  def request_header_content_type, do: @content_type ++ request_header
end
