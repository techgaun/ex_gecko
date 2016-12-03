defmodule ExGecko.Adapter.RunscopeTest do
  use ExUnit.Case
  alias ExGecko.Adapter.Runscope
  doctest ExGecko.Adapter.Runscope

  @unix 1478133443.0

  test "should convert unix time to ISO 8601 string" do
  	resp = Runscope.get_datetime(@unix)
  	assert "2016-11-03T00:37:23Z" == resp
  end
end
