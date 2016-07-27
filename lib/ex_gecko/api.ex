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
  Wrapper for GET requests

  Example
  - Brighterx.Api.find(Brighterx.Resources.Company, [params: %{name: "Brightergy"}])

  - A tuple of {:ok, [%Brighterx.Resource.<ResourceType>{}]} is returned for successful requests
  - For http status code 204, a :ok atom is returned indicating the request was fulfilled successfully
    but no response body i.e. message-body
  - For all other errors, a tuple of {:ok, <error_detail_map>, status_code} is returned
  """
  @spec find(any, list) :: Brighterx.response
  def find(module, opts \\ []) do
    id = opts[:id] || nil
    params = opts[:params] || %{}
    token = System.get_env("JWT")
    req_header = request_header(%{token: token})
    build_url(id, params)
    |> Api.get(req_header)
    |> Parser.parse
  end

  @doc """
  Wrapper for POST requests

  Examples
  - Brighterx.Api.create(Brighterx.Resources.Device, %{name: "Test Thermostat", identifier: "00:01", facility_id: 1, type: "thermostat"})
  - Brighterx.Api.create(Brighterx.Resources.Company, "{\"name\": \"Samar\"}")
  """
  @spec create(map, list) :: Brighterx.response
  def create(post_data, _opts \\ []) do
    token = System.get_env("GECKO_API_KEY")
    req_header = request_header_content_type(%{token: token})
    if post_data |> is_map do
      post_data = Poison.encode!(post_data)
    end
    build_url(nil, %{})
    |> Api.post(post_data, req_header)
    |> Parser.parse
  end

  @doc """
  Wrapper for PUT requests

  Examples
  With body as map
  - Brighterx.Api.update(Brighterx.Resources.Device, 1, %{name: "7th floor south"})

  With body as JSON string
  - Brighterx.Api.update(Brighterx.Resources.Device, 1, "{\"name\": \"7th Floor West\"}")
  """
  @spec update(String.t, map) :: Brighterx.response
  def update(id, put_data) do
    token = System.get_env("GECKO_API_KEY")
    req_header = request_header_content_type(%{token: token})
    if put_data |> is_map do
      put_data = Poison.encode!(put_data)
    end
    build_url(id, %{})
    |> Api.put(put_data, req_header)
    |> Parser.parse
  end

  @doc """
  Wrapper for DELETE requests

  Examples
  - Brighterx.Api.delete(Brighterx.Resources.Device, 1)
  """
  @spec remove(String.t, list) :: Brighterx.response
  def remove(id, _opts \\ []) do
    token = System.get_env("GECKO_API_KEY")
    req_header = request_header(%{token: token})
    build_url(id)
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
  def ping, do: find(%{})
  @spec find_or_create(String.t, map) :: ExGecko.response
  def find_or_create(id, fields), do: find(id, fields)
  @spec put(String.t, list) :: ExGecko.response
  def put(id, data), do: find(id, data)
  @spec delete(String.t) :: ExGecko.response
  def delete(id), do: remove(id)

  @doc """
  Builds URL based on the resource, id and parameters
  """
  @spec build_url(String.t, map) :: String.t
  def build_url(id, params \\ %{}) do
    "/datasets/#{id}?#{URI.encode_query(params)}"
  end

  def url, do: "https://api.geckoboard.com/"
  
  @doc """
  Add header with username
  and also the user agent
  """
  def request_header(%{api_key: api_key}, headers), do: headers ++ [{"Authorization", "Basic #{Base.encode64(api_key)}"}]
  def request_header(opts), do: request_header(opts, @user_agent)
  def request_header_content_type(opts), do: @content_type ++ request_header(opts)
end
