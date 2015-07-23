defmodule TincaTest do
  use ExUnit.Case
  use Tinca, [:namespace1]

  test "test storage" do
  	Tinca.declare_namespaces
  	assert "value" == Tinca.put("value", :key)
  	assert "value" == Tinca.get(:key)
  	assert :ok == Tinca.delete(:key)
    assert Tinca.get(:key) == nil
    assert %{k1: %{k2: 123}} == Tinca.put(%{k1: %{k2: 123}}, :key)
    assert 123 == Tinca.get([:key, :k1, :k2])
    assert %{k2: 123} == Tinca.get([:key, :k1])
    assert nil == Tinca.get(:not_exist)
    assert nil == Tinca.get([:key, :k3])
    assert :ok == Tinca.delete(:key)
    assert nil == Tinca.get([:key, :k1])
    assert "value" == Tinca.put("value", :k1)
    assert "value2" == Tinca.put("value2", "k2")
    assert %{"k2" => "value2", :k1 => "value"} == Tinca.getall
    assert ["k2", :k1] == Tinca.keys
    assert ["value2", "value"] == Tinca.values
    Tinca.cleanup(:namespace1)
    assert %{} == Tinca.getall
    Tinca.put("value", :k1)
    Tinca.cleanup
    assert %{} == Tinca.getall
    assert [] == Tinca.keys
    assert [] == Tinca.values
    assert [1,2,3] == [1,2,3] |> Enum.map(&(Tinca.put(&1,&1)))
    assert :ok == Tinca.iterate(fn({k,v}) -> Tinca.put(v*2, k) end)
    assert [6,4,2] == Tinca.values
    assert %{1 => 2, 2 => 4, 3 => 6} == Tinca.iterate_acc(%{}, fn({k,v}, acc) -> Map.put(acc, k, v) end)
  end

  test "memo" do
    :ok = Tinca.memo(&IO.puts/1, ["execute two times"], :timer.seconds(5))
    Enum.each(0..100, fn(_) -> :ok = Tinca.memo(&IO.puts/1, ["execute two times"], :timer.seconds(5)) end)
    :timer.sleep(:timer.seconds(6))
    assert :ok == Tinca.memo(&IO.puts/1, ["execute two times"], :timer.seconds(5))
  end

  defp trx_func(t) do 
    IO.inspect(Exutils.make_verbose_datetime)
    :timer.sleep(t)
    IO.inspect(Exutils.make_verbose_datetime)
    IO.puts("execute once")
  end
  test "trx" do
    :ok = Enum.each(1..100000, fn(_) -> spawn_link(fn() -> :timer.sleep(:random.uniform(100)); Tinca.trx(&trx_func/1, nil, [:timer.seconds(15)], 123, :timer.seconds(50)) end) end)
    :timer.sleep(:timer.seconds(15))
    assert 1 == :ets.tab2list(:__tinca__trx__) |> length
    assert :ready == :ets.tab2list(:__tinca__trx__) |> List.first |> elem(1) |> Map.get(:status)
  end

end
