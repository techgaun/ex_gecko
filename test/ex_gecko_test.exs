defmodule ExGeckoTest do
  use ExUnit.Case
  doctest ExGecko

  require IEx

  @fields  %{"fields" => %{"amount" => %{"type" => "number", "name" => "Amount",  "optional" => false}, "timestamp" => %{"type" => "datetime", "name" => "Date",  "optional" => false}}}
  @req_fields %{"path" => %{"name" => "Request Path", "type" => "string", "optional" => false},
     "speed" => %{"name" => "Request Speed", "type" => "number",  "optional" => false},
     "timestamp" => %{"name" => "Date", "type" => "datetime",  "optional" => false},
     "status" => %{"name" => "Status Code", "type" => "string",  "optional" => false},
     "size" => %{"name" => "Request Size", "type" => "number",  "optional" => false}
   }
   @data %{"path" => "/api/testpath",
          "speed" => 491,
          "timestamp" => "2016-07-20T10:11:01Z",
          "status" => "200",
          "size" => 15010
         }

  @batch_fields %{"fields" => %{"globalid" => %{"type" => "string", "name"=>"Global Id"}, "testfield" => %{ "type" => "number", "name" => "Test Field"}}}
  @batch_path "test/support/batch_request.json"

  setup do
    name = "testset_" <> (:os.timestamp |> elem(2) |> Integer.to_string)
    on_exit fn ->
      ExGecko.Api.delete(name)
    end
    {:ok, dataset: name}
  end

  test "should ping" do
    resp = ExGecko.Api.ping
    assert {:ok, %{}} = resp
  end

  test "should find or create dataset properly", %{dataset: name} do
    {:ok, resp} = ExGecko.Api.find_or_create(name, @fields)
    assert resp["fields"] == @fields["fields"]
    # ensure the created_at is recent
    {:ok, resp2} = ExGecko.Api.find_or_create(name, @fields)
    assert resp["created_at"] == resp2["created_at"]
  end

  test "should delete dataset properly", %{dataset: name} do
    {:ok, _resp} = ExGecko.Api.find_or_create(name, @fields)
    {:ok, %{}} = ExGecko.Api.delete(name)
  end

  test "should create reqs dataset properly", %{dataset: name} do
    {:ok, resp} = ExGecko.Api.create_reqs_dataset(name)
    assert resp["fields"] == @req_fields
  end

  test "should put reqs data properly", %{dataset: name} do
    {:ok, _resp} = ExGecko.Api.create_reqs_dataset(name)
    {:ok, 1} = ExGecko.Api.put(name, [@data])
  end

  test "should batch job of 2000 items", %{dataset: name} do
    batch_data =  get_batch_data(@batch_path)
    {:ok, _resp} = ExGecko.Api.find_or_create(name, @batch_fields)
    {:ok, 2000}= ExGecko.Api.append(name, batch_data["data"])
  end

  def get_batch_data(path) do
    path
    |> File.read!
    |> Poison.Parser.parse!
  end


end
