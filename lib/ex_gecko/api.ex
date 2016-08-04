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
    "#{url}#{path}"
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
  def put(id, data) when is_list(data) and length(data) > 400 do
    IO.puts "Currently the Geckoboard API can not support more than 400 events, reducing events sent from #{length(data)} to 400"
    put(id, data |> limit_data)
  end

  def put(id, data) when is_list(data), do: put(id, %{"data" => data})
  def put(id, data) when is_map(data) do
    resp = update(id, data, true)
    case resp do
      {:ok, %{}} ->
        count = length(data["data"])
        {:ok, count}
      _ -> resp
    end
  end
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


  def url, do: "https://api.geckoboard.com/"

  @doc """
    ## Examples

      iex> Mix.Tasks.LoadData.limit_data(Enum.to_list(1..500)) === Enum.to_list(101..500)
      true
  """
  @spec limit_data(list) :: list
  def limit_data(events) do
    events
    |> Enum.reverse
    |> Enum.slice(0..399)
    |> Enum.reverse
  end

  @doc """
  Add header with username
  and also the user agent
  """
  def request_header(headers) do
    api_key = System.get_env("GECKO_API_KEY")
    if is_nil(api_key) do
      raise "Geckoboard API Key is missing"
    else
      api_key = api_key <> ":"
      headers ++ [{"Authorization", "Basic #{Base.encode64(api_key)}"}]
    end
  end

  def request_header, do: request_header(@user_agent)
  def request_header_content_type, do: @content_type ++ request_header
end
