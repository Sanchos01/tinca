defmodule TincaTrxServer do
	use Silverb, [{"@trx_tab", :__tinca__trx__},{"@awaiters", :__tinca__awaiters__}]
	use Tinca, [:__tinca__trx__]
	use ExActor.GenServer, export: :_tinca_trx_server_
	definit do
		{:ok, nil}
	end
	defcall start_trx(trx_key) do
		case Tinca.get(trx_key) do
			nil -> 	%TStructs.TrxVal{ready: false} |> Tinca.put(trx_key)
					{:reply, :ok, nil}
			val = %TStructs.TrxVal{} -> {:reply, val, nil}
		end
	end



	def do_process(func, roll, trx_key, ttl) do
		try do
			data = func.()
			%TStructs.TrxVal{ready: true, delete_after: Exutils.makestamp + ttl, data: data} |> Tinca.put(trx_key)
			:pg2.get_members(@awaiters) |> Stream.uniq |> Enum.each(&( send(&1, %TStructs.TrxProto{subject: :data_is_ready, content: {trx_key, data}}) ))
			data
		catch
			error -> rollback_proc(roll, error, trx_key)
		rescue
			error -> rollback_proc(roll, error, trx_key)
		end
	end
	defp rollback_proc(roll, error, trx_key) do
		try do
			case roll do
				nil -> :ok
				_ when is_function(roll,1) -> roll.(error)
			end
		catch
			_ -> :ok
		rescue
			_ -> :ok
		end
		:ok = Tinca.delete(trx_key)
		:pg2.get_members(@awaiters) |> Stream.uniq |> Enum.each(&( send(&1, %TStructs.TrxProto{subject: :data_exception, content: trx_key}) ))
		raise("#{__MODULE__} : exception transaction, rollback was executed. Error #{inspect error}")
	end



	def await(func, roll, trx_key, ttl) do
		:ok = :pg2.join(@awaiters, self)
		case Tinca.get(trx_key) do
			nil ->
				:ok = purge_messages
				Tinca.trx(func, roll, trx_key, ttl)
			%TStructs.TrxVal{ready: true, data: data} ->
				:ok = purge_messages
				data
			%TStructs.TrxVal{ready: false} ->
				receive do
					%TStructs.TrxProto{subject: :data_is_ready, content: {^trx_key, data}} ->
						:ok = purge_messages
						data
					%TStructs.TrxProto{subject: :data_exception, content: ^trx_key} ->
						:ok = purge_messages
						Tinca.trx(func, roll, trx_key, ttl)
				after
					ttl ->
						:ok = purge_messages
						Tinca.trx(func, roll, trx_key, ttl)
				end
		end
	end
	defp purge_messages do
		:ok = :pg2.leave(@awaiters, self)
		purge_messages_proc
	end
	defp purge_messages_proc do
		receive do
			%TStructs.TrxProto{} -> purge_messages_proc
		after
			10 -> :ok
		end
	end



end
