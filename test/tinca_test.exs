defmodule TincaTest do
  use ExUnit.Case
  use Tinca, [:namespace1]

  test "the truth" do

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
    assert [:k1, "k2"] == Tinca.keys
    assert ["value", "value2"] == Tinca.values
    Tinca.cleanup(:namespace1)
    assert %{} == Tinca.getall
    Tinca.put("value", :k1)
    Tinca.cleanup
    assert %{} == Tinca.getall
    assert [] == Tinca.keys
    assert [] == Tinca.values
  end
end
