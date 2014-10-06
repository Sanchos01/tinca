defmodule TincaTest do
  use ExUnit.Case
  use Tinca, [:namespace1]

  test "the truth" do

  	Tinca.declare_namespaces
  	Tinca.put("value", :key)
    assert Tinca.get(:key) == "value"
  end
end
