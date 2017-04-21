defmodule TWeakLinks do
	use Silverb
	use Tinca, [:__tinca__weak__links__]

	def make(val1, val2, ttl) do
		delete_after = Exutils.makestamp + ttl
		Tinca.put(%TStructs.MemoVal{data: val1, delete_after: delete_after}, val2)
		Tinca.put(%TStructs.MemoVal{data: val2, delete_after: delete_after}, val1)
		val1
	end

	def make_injection(val1, val2, ttl) do
		delete_after = Exutils.makestamp + ttl
		Tinca.put(%TStructs.MemoVal{data: val1, delete_after: delete_after}, val2)
		val1
	end

	def get(val, default \\ nil) do
		case Tinca.get(val) do
			%TStructs.MemoVal{data: data} -> data
			nil -> default
		end
	end

end
