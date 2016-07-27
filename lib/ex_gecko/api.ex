defmodule Brighterx.Api do
  @moduledoc """
  API interface to communicate with geckoboard's api

  Todo: refactor code so that we can move auth part to single place
  """

  use HTTPoison.Base
  alias Brighterx.Parser
  alias Brighterx.Resources.{Company, Facility, Device}
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
    module
    |> build_url(id, params)
    |> Api.get(req_header)
    |> Parser.parse(module)
  end

  @doc """
  Wrapper for POST requests

  Examples
  - Brighterx.Api.create(Brighterx.Resources.Device, %{name: "Test Thermostat", identifier: "00:01", facility_id: 1, type: "thermostat"})
  - Brighterx.Api.create(Brighterx.Resources.Company, "{\"name\": \"Samar\"}")
  """
  @spec create(any, map, list) :: Brighterx.response
  def create(module, post_data, _opts \\ []) do
    token = System.get_env("JWT")
    req_header = request_header_content_type(%{token: token})
    if post_data |> is_map do
      post_data = Poison.encode!(post_data)
    end
    module
    |> build_url(nil, %{})
    |> Api.post(post_data, req_header)
    |> Parser.parse(module)
  end

  @doc """
  Wrapper for PUT requests

  Examples
  With body as map
  - Brighterx.Api.update(Brighterx.Resources.Device, 1, %{name: "7th floor south"})

  With body as JSON string
  - Brighterx.Api.update(Brighterx.Resources.Device, 1, "{\"name\": \"7th Floor West\"}")
  """
  @spec update(any, integer, map) :: Brighterx.response
  def update(module, id, put_data) do
    token = System.get_env("JWT")
    req_header = request_header_content_type(%{token: token})
    if put_data |> is_map do
      put_data = Poison.encode!(put_data)
    end

    module
    |> build_url(id, %{})
    |> Api.put(put_data, req_header)
    |> Parser.parse(module)
  end

  @doc """
  Wrapper for DELETE requests

  Examples
  - Brighterx.Api.delete(Brighterx.Resources.Device, 1)
  """
  @spec find(any, list) :: Brighterx.response
  def remove(module, id, _opts \\ []) do
    token = System.get_env("JWT")
    req_header = request_header(%{token: token})
    module
    |> build_url(id)
    |> Api.delete(req_header)
    |> Parser.parse(module)
  end

  @doc """
  Convenience function to manage datasets.  Follows similar syntax as this
  https://developer-beta.geckoboard.com/nodejs/

  Examples
  - ExGecko.Api.find_or_create - finds or creates the dataset
  - ExGecko.Api.put - replaces all data in the dataset
  - ExGecko.Api.delete - deletes the dataset and data therein
  """
  @spec find_or_create(String.t, map) :: ExGecko.response
  def find_and_create(id, fields), do: find(Company, [id: id])
  @spec put(String.t, list) :: ExGecko.response
  def put(id, data), do: find(Company, [id: id])
  @spec delete(String.t) :: ExGecko.response
  def delete(id), do: find(Company, [id: id])

  @doc """
  Builds URL based on the resource, id and parameters
  """
  @spec build_url(any, integer, map) :: String.t
  def build_url(module, id, params \\ %{}) do
    "Elixir.Brighterx.Resources." <> module_str = module
      |> to_string
    resource_path =
      case module_str do
        "Company" ->
          "companies"
        "Facility" ->
          "facilities"
        "Device" ->
          "devices"
        _ ->
          raise ArgumentError, "Unknown resource type. Make sure you are requesting correct resource"
      end
    if id |> is_integer do
      resource_path = "#{resource_path}/#{id}"
    end
    "/datasets/#{resource_path}?#{URI.encode_query(params)}"
  end

  def url, do: "https://api.geckoboard.com/"
  
  @doc """
  Add authorization header which is basically a JWT token
  and also the user agent
  """
  def request_header(opts), do: request_header(opts, @user_agent)
  def request_header_content_type(opts), do: @content_type ++ request_header(opts)
end
