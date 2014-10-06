defmodule TincaTest do
  use ExUnit.Case
  use Tinca, [:namespace1]

  test "the truth" do

  	Tinca.declare_namespaces
  	"value" = Tinca.put("value", :key)
  	"value" = Tinca.get(:key)
  	:ok = Tinca.delete(:key)
    assert Tinca.get(:key) == :not_found
  end
end
