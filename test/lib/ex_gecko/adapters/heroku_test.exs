defmodule ExGecko.Adapter.HerokuTest do
  use ExUnit.Case
  import Mock
  alias ExGecko.Adapter.Heroku
  doctest ExGecko.Adapter.Heroku

  @heroku_log File.read!("test/support/heroku.log")

  test "load_events/1 loads CPU load event data correctly" do
    with_mock Porcelain, exec: fn _, _ -> %{status: 0, out: @heroku_log} end do
      [evt] = Heroku.load_events(nil)
      assert evt["load_1m"] === 0.00
      assert evt["load_5m"] === 0.08
      assert evt["timestamp"] === "2016-08-02T22:23:31Z"
    end
  end

  test "load_events/1 loads memory event data correctly" do
    with_mock Porcelain, exec: fn _, _ -> %{status: 0, out: @heroku_log} end do
      [evt] = Heroku.load_events(%{"type" => "memory"})
      assert evt["memory_cache"] === 5.38
      assert evt["memory_total"] === 125.00
      assert evt["timestamp"] === "2016-08-02T22:23:31Z"
    end
  end

  test "load_events/1 loads postgres event data correctly" do
    with_mock Porcelain, exec: fn _, _ -> %{status: 0, out: @heroku_log} end do
      [evt] = Heroku.load_events(%{"type" => "db"})
      assert evt["db_size"] === 1_279_201_044.0 / (1024 * 1024)
      assert evt["tables_count"] === 10
      assert evt["timestamp"] === "2016-08-02T22:22:52Z"
      [evt] = Heroku.load_events(%{"type" => "db-server"})
      assert evt["timestamp"] === "2016-08-02T22:22:52Z"
      assert evt["load_1m"] === 0.025
    end
  end
end
