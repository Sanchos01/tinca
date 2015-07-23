defmodule TincaTrxServer do
	use Silverb, [{"@trx_tab", :__tinca__trx__},{"@awaiters", :__tinca__awaiters__}]
	use Tinca, [:__tinca__trx__]
	use ExActor.GenServer, export: :_tinca_trx_server_
	definit do
		{:ok, nil}
	end
	defcall start_trx(k = %TStructs.TrxKey{}) do
		case Tinca.get(k) do
			nil -> 	%TStructs.TrxVal{status: :processing} |> Tinca.put(k)
					{:reply, :ok, nil}
			val = %TStructs.TrxVal{} -> {:reply, val, nil}
		end
	end

	def do_process(k = %TStructs.TrxKey{func: func, args: args}, ttl) do
		try do
			data = :erlang.apply(func, args)
			%TStructs.TrxVal{status: :ready, delete_after: Exutils.makestamp + ttl, data: data} |> Tinca.put(k)
			:pg2.get_members(@awaiters) |> Stream.uniq |> Enum.each(&( send(&1, %TStructs.TrxProto{subject: :data_is_ready, content: {k, data}}) ))
			data
		catch
			error -> rollback_proc(k, error)
		rescue
			error -> rollback_proc(k, error)
		end
	end

	def await(k = %TStructs.TrxKey{func: func, roll: roll, args: args, trx: trx}, ttl) do
		:ok = :pg2.join(@awaiters, self)
		case Tinca.get(k) do
			nil -> 	
				purge_messages 
				Tinca.trx(func, roll, args, trx, ttl)
			%TStructs.TrxVal{status: :ready, data: data} -> 
				purge_messages
				data
			%TStructs.TrxVal{status: :processing} -> 
				receive do
					%TStructs.TrxProto{subject: :data_is_ready, content: {^k, data}} -> 
						purge_messages
						data
					%TStructs.TrxProto{subject: :data_exception, content: ^k} -> 
						purge_messages
						Tinca.trx(func, roll, args, trx, ttl)
				end
		end
	end

	#
	#	priv
	#

	defp rollback_proc(k = %TStructs.TrxKey{roll: roll, args: args}, error) do
		try do
			case roll do
				nil -> :ok
				_ when is_function(roll) -> :erlang.apply(roll, [error|args])
			end
		catch
			_ -> :ok
		rescue
			_ -> :ok
		end
		:ok = Tinca.delete(k)
		:pg2.get_members(@awaiters) |> Stream.uniq |> Enum.each(&( send(&1, %TStructs.TrxProto{subject: :data_exception, content: k}) ))
		raise("#{__MODULE__} : exception transaction, rollback was executed. Error #{inspect error}")
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