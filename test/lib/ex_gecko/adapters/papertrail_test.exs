defmodule ExGecko.Adapter.PapertrailTest do
  use ExUnit.Case
  import Mock
  alias ExGecko.Adapter.Papertrail
  doctest ExGecko.Adapter.Papertrail

  @pt_req_log File.read!("test/support/papertrail.log")

  test "load_events/1 loads request event data correctly" do
    with_mock Porcelain, [exec: fn (_, _) -> %{status: 0, out: @pt_req_log} end] do
      [evt] = Papertrail.load_events(%{})
      assert evt["path"] === "/ws/websocket?token=tk&vsn=1.0.0"
      assert evt["status"] === "403"
      assert evt["timestamp"] === "2016-08-04T17:39:34Z"
    end
  end
end
