defmodule ExGecko.PushTest do
  use ExUnit.Case
  doctest ExGecko
  @monitor_key "129376-2cea8100-7834-0134-2c47-22000bdb45ae"

  test "should push up monitor up properly" do
    resp = ExGecko.Api.push_monitor(@monitor_key, :up)
    assert {:ok, %{}} = resp
  end

  test "should push up monitor with optional data properly" do
    resp = ExGecko.Api.push_monitor(@monitor_key, :up, "2 days ago", "500ms")
    assert {:ok, %{}} = resp
  end

  test "should push down monitor up properly" do
    resp = ExGecko.Api.push_monitor(@monitor_key, :down)
    assert {:ok, %{}} = resp
  end

  test "should push down monitor with optional data properly" do
    resp = ExGecko.Api.push_monitor(@monitor_key, :down, "2 days ago", "500ms")
    assert {:ok, %{}} = resp
  end

end

