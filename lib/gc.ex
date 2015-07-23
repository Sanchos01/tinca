defmodule Tinca.GC do
	use Silverb, [{"@ttl",100},{"@memo_tab", :__tinca__memo__},{"@trx_tab", :__tinca__trx__},{"@awaiters", :__tinca__awaiters__}]
	use Tinca, [:__tinca__memo__, :__tinca__trx__]
	use ExActor.GenServer, export: __MODULE__
	definit do
		{:ok, nil, @ttl}
	end
	definfo :timeout do
		now = Exutils.makestamp
		Tinca.iterate(fn({k = %TStructs.MemoKey{}, %TStructs.MemoVal{delete_after: delete_after}}) -> if (now > delete_after), do: true = :ets.delete(@memo_tab, k) end, @memo_tab)
		Tinca.iterate(fn
			{%TStructs.TrxKey{}, %TStructs.TrxVal{status: :processing}} -> :ok
			{k = %TStructs.TrxKey{}, %TStructs.TrxVal{status: :ready, delete_after: delete_after}} -> if (now > delete_after), do: true = :ets.delete(@trx_tab, k)
		end, @trx_tab)
		{:noreply, nil, @ttl}
	end
end