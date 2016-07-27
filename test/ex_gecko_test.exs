defmodule ExGeckoTest do
  use ExUnit.Case
  doctest ExGecko

  setup do
    name = "testset_" <> (:os.timestamp |> Tuple.to_list |> Enum.join(""))
    on_exit fn ->
      IO.inspect System.cmd("#{File.cwd!}/test/cleanup.sh", [name])
    end
    {:ok, dataset: name}
  end

  test "should create reqs dataset properly", %{dataset: name} do
    IO.puts name
    resp = ExGecko.Api.create_reqs_dataset(name)
    IO.inspect resp
  end
end
