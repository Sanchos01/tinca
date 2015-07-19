defmodule Tinca.GC do
	use Silverb, [{"@ttl",100}]
	use Tinca, [:__tinca__memo__]
	use ExActor.GenServer, export: __MODULE__
	definit do
		{:ok, nil, @ttl}
	end
	definfo :timeout do
		now = Exutils.makestamp
		Tinca.iterate(fn({k, {_, delete_after}}) -> if (now > delete_after), do: true = :ets.delete(:__tinca__memo__, k) end)
		{:noreply, nil, @ttl}
	end
end