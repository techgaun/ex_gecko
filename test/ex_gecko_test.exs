defmodule ExGeckoTest do
  use ExUnit.Case
  doctest ExGecko

  @fields  %{"fields" => %{"amount" => %{"type" => "number", "name" => "Amount"}, "timestamp" => %{"type" => "datetime", "name" => "Date"}}}
  @req_fields %{"path" => %{"name" => "Request Path", "type" => "string"},
     "speed" => %{"name" => "Request Speed", "type" => "number"},
     "timestamp" => %{"name" => "Date", "type" => "datetime"},
     "status" => %{"name" => "Status Code", "type" => "string"},
     "size" => %{"name" => "Request Size", "type" => "number"}
   }

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
    created_at = resp["created_at"]
    {:ok, resp2} = ExGecko.Api.find_or_create(name, @fields)
    assert resp["created_at"] == resp2["created_at"]
  end

  test "should delete dataset properly", %{dataset: name} do
    {:ok, resp} = ExGecko.Api.find_or_create(name, @fields)
    {:ok, %{}} = ExGecko.Api.delete(name)    
  end

  test "should create reqs dataset properly", %{dataset: name} do
    {:ok, resp} = ExGecko.Api.create_reqs_dataset(name)
    assert resp["fields"] == @req_fields
  end
end
