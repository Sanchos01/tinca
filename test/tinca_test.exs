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
	Enum.each(0..10, fn(_) -> Tinca.smart_memo(&(:random.uniform(&1)), [100], &(rem(&1,2) == 0), :timer.seconds(5)) |> IO.puts end)
    assert :ok == Tinca.memo(&IO.puts/1, ["execute two times"], :timer.seconds(5))
  end

  @trx_exec :timer.seconds(15)
  defp trx_func, do: (:timer.sleep(@trx_exec); IO.puts("execute once"); 321)
  @tag timeout: 300000
  test "trx" do
    :ok = Enum.each(1..10000, fn(_) -> spawn_link(fn() -> :random.uniform(100) |> :timer.sleep; 321 = Tinca.trx(&trx_func/0, nil, 123, :timer.seconds(50)) end) end)
    :timer.sleep(@trx_exec)
    assert 1 == :ets.tab2list(:__tinca__trx__) |> length
    assert true == :ets.tab2list(:__tinca__trx__) |> List.first |> elem(1) |> Map.get(:ready)
    assert 321 == Tinca.trx(&trx_func/0, nil, 123, :timer.seconds(99999999999))
    :timer.sleep(:timer.seconds(51))
    assert [] == :ets.tab2list(:__tinca__trx__)
  end

  test "weak_links" do
    val1 = "hello, world"
    val2 = Exutils.md5_str(val1)
    assert val1 == Tinca.WeakLinks.make(val1,val2,2000)
    assert val1 == Tinca.WeakLinks.get(val2)
    assert val2 == Tinca.WeakLinks.get(val1)
    assert val1 == Tinca.WeakLinks.get(val2, val2)
    assert val1 == Tinca.WeakLinks.get(val2,"hello")
    assert val2 == Tinca.WeakLinks.get(val1, val1)
    assert val2 == Tinca.WeakLinks.get(val1,"hello")
    :timer.sleep(3000)
    assert nil == Tinca.WeakLinks.get(val2)
    assert nil == Tinca.WeakLinks.get(val1)
    assert val2 == Tinca.WeakLinks.get(val2, val2)
    assert "hello" == Tinca.WeakLinks.get(val2,"hello")
    assert val1 == Tinca.WeakLinks.get(val1, val1)
    assert "hello" == Tinca.WeakLinks.get(val1,"hello")
    assert [] == :ets.tab2list(:__tinca__weak__links__)
  end

end
