defmodule Tinca do
  use Application
  use Silverb,  [
                  {"@memo_tab", :__tinca__memo__},
                  {"@trx_tab", :__tinca__trx__},
                  {"@weak_links_tab", :__tinca__weak__links__},
                  {"@awaiters", :__tinca__awaiters__}
                ]

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    true = (@weak_links_tab == :ets.new(@weak_links_tab, [:public, :named_table, :set]))
    true = (@memo_tab == :ets.new(@memo_tab, [:public, :named_table, :set]))
    true = (@trx_tab == :ets.new(@trx_tab, [:public, :named_table, :set]))
    :ok = :pg2.create(@awaiters)
    children = [
      # Define workers and child supervisors to be supervised
      # worker(Tinca.Worker, [arg1, arg2, arg3])
      worker(TincaTrxServer, []),
      worker(Tinca.GC, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tinca.Supervisor]
    Supervisor.start_link(children, opts)
  end

  #
  # public
  #

  defmodule WeakLinks do
    def make(val1, val2, ttl), do: TWeakLinks.make(val1, val2, ttl)
    def make_injection(val1, val2, ttl), do: TWeakLinks.make_injection(val1, val2, ttl)
    def get(val), do: TWeakLinks.get(val)
    def get(val, default), do: TWeakLinks.get(val, default)
  end

  def memo(func, args, ttl) when is_function(func, length(args)) and is_integer(ttl) and (ttl > 0) do
    key = %TStructs.MemoKey{func: func, args: args}
    case :ets.lookup(@memo_tab, key) do
      [{^key, %TStructs.MemoVal{data: data}}] -> data
      [] -> data = :erlang.apply(func, args)
            true = :ets.insert(@memo_tab, {key, %TStructs.MemoVal{data: data, delete_after: Exutils.makestamp + ttl}})
            data
    end
  end

	def smart_memo(func, args, pred, ttl) when is_function(func, length(args)) and is_function(pred,1) and is_integer(ttl) and (ttl > 0) do
		key = %TStructs.MemoKey{func: func, args: args}
		case :ets.lookup(@memo_tab, key) do
			[{^key, %TStructs.MemoVal{data: data}}] -> data
			[] ->
				data = :erlang.apply(func, args)
				if (pred.(data)), do: (true = :ets.insert(@memo_tab, {key, %TStructs.MemoVal{data: data, delete_after: Exutils.makestamp + ttl}}))
				data
		end
	end

  def trx(func, roll, trx_key, ttl) when is_function(func, 0) and (is_function(roll, 1) or (roll == nil)) and is_integer(ttl) and (ttl > 0) do
    case TincaTrxServer.start_trx(trx_key) do
      :ok -> TincaTrxServer.do_process(func, roll, trx_key, ttl)
      %TStructs.TrxVal{ready: true, data: data} -> data
      %TStructs.TrxVal{ready: false} -> TincaTrxServer.await(func, roll, trx_key, ttl)
    end
  end

  defmacro __using__(namespaces) when is_list(namespaces) do
    Enum.each(namespaces,
      fn(namespace) ->
        if not(is_atom(namespace)) do
          raise "Tinca : can't create table #{inspect namespace}, namespace must be atom!"
        end
      end )
    regular_put_func = quote do
                          def put(value, key, namespace) when (namespace in unquote(namespaces)) do
                              case table_exist?(namespace) do
                                true -> true = :ets.insert(namespace, {key,value})
                                        value
                                false -> raise "Tinca : table #{inspect namespace} is not exist! Was it declarated?"
                              end
                          end
                          def put(value, key, namespace) do
                            raise "Tinca : #{inspect key} is not atom, binary or number, or namespace #{inspect namespace} was not declarated for this app. Can't put value #{inspect value}."
                          end
                        end
    regular_get_func = quote do
                          def get([key], namespace), do: get(key, namespace)
                          def get([first|rest], namespace), do: get(first, namespace) |> HashUtils.get(rest)
                          def get(key, namespace) when (namespace in unquote(namespaces)) do
                              case table_exist?(namespace) do
                                true -> case :ets.lookup(namespace, key) do
                                          [{ _ , data}] -> data
                                          [] -> nil
                                        end
                                false -> raise "Tinca : table #{inspect namespace} is not exist! Was it declarated?"
                              end
                          end
                          def get(key, namespace) do
                            raise "Tinca : #{inspect key} is not atom, binary or number, or namespace #{inspect namespace} was not declarated for this app. Can't get value."
                          end
                        end

    regular_getall_func = quote do
                            def getall(namespace) do
                              case table_exist?(namespace) do
                                true -> :ets.tab2list(namespace) |> HashUtils.to_map
                                false -> raise "Tinca : table #{inspect namespace} is not exist! Was it declarated?"
                              end
                            end
                          end

    regular_keys_func =   quote do
                            def keys(namespace) do
                              case table_exist?(namespace) do
                                true -> keys_proc(namespace, :ets.first(namespace), [])
                                false -> raise "Tinca : table #{inspect namespace} is not exist! Was it declarated?"
                              end
                            end
                          end


    regular_values_func = quote do
                            def values(namespace) do
                              case table_exist?(namespace) do
                                true -> :ets.foldl(fn({_,v}, acc) -> [v|acc] end, [], namespace)
                                false -> raise "Tinca : table #{inspect namespace} is not exist! Was it declarated?"
                              end
                            end
                          end

    regular_del_func = quote do
                          def delete(key, namespace) when (namespace in unquote(namespaces)) do
                              case table_exist?(namespace) do
                                true -> true = :ets.delete(namespace, key)
                                        :ok
                                false -> raise "Tinca : table #{inspect namespace} is not exist! Was it declarated?"
                              end
                          end
                          def delete(key, namespace) do
                            raise "Tinca : #{inspect key} is not atom, binary or number, or namespace #{inspect namespace} was not declarated for this app. Can't get value."
                          end
                        end

    regular_cleanup_func = quote do
                            def cleanup(namespace) when (namespace in unquote(namespaces)) do
                                case table_exist?(namespace) do
                                  true -> true = :ets.delete_all_objects(namespace)
                                          :ok
                                  false -> raise "Tinca : table #{inspect namespace} is not exist! Was it declarated?"
                                end
                            end
                            def cleanup(namespace) do
                              raise "Tinca : namespace #{inspect namespace} was not declarated for this app. Can't do cleanup."
                            end
                          end
    regular_iterate = quote do
                        def iterate(lambda, namespace) when (is_function(lambda, 1) and (namespace in unquote(namespaces))) do
                          :ets.foldl(fn(el, _) -> lambda.(el) end , nil, namespace)
                          :ok
                        end
                        def iterate(_, namespace) do
                          raise "Tinca : namespace #{inspect namespace} was not declarated for this app or first arg is not a function."
                        end
                      end

    regular_iterate_acc = quote do
                            def iterate_acc(acc, lambda, namespace) when (is_function(lambda, 2) and (namespace in unquote(namespaces))) do
                              :ets.foldl(lambda, acc, namespace)
                            end
                            def iterate_acc(_, _, namespace) do
                              raise "Tinca : namespace #{inspect namespace} was not declarated for this app or first arg is not a function."
                            end
                          end

    funcs = case namespaces do
                  [namespace] ->  quote do
                                    def put(value, key, namespace \\ unquote(namespace) )
                                    unquote(regular_put_func)
                                    def get(key, namespace \\ unquote(namespace) )
                                    unquote(regular_get_func)
                                    def getall(namespace \\ unquote(namespace) )
                                    unquote(regular_getall_func)
                                    def delete(key, namespace \\ unquote(namespace) )
                                    unquote(regular_del_func)
                                    def cleanup(namespace \\ unquote(namespace))
                                    unquote(regular_cleanup_func)
                                    def keys(namespace \\ unquote(namespace))
                                    unquote(regular_keys_func)
                                    def values(namespace \\ unquote(namespace))
                                    unquote(regular_values_func)
                                    def iterate(lambda, namespace \\ unquote(namespace))
                                    unquote(regular_iterate)
                                    def iterate_acc(acc, lambda, namespace \\ unquote(namespace))
                                    unquote(regular_iterate_acc)
                                  end
                  ^namespaces ->  quote do
                                    unquote(regular_put_func)
                                    unquote(regular_get_func)
                                    unquote(regular_getall_func)
                                    unquote(regular_del_func)
                                    unquote(regular_cleanup_func)
                                    unquote(regular_keys_func)
                                    unquote(regular_values_func)
                                    unquote(regular_iterate)
                                    unquote(regular_iterate_acc)
                                  end
            end

    quote do
      defmodule Tinca do

        use Silverb, [{"@memo_tab", :__tinca__memo__}]

        ###############
        ### public ####
        ###############

        unquote(funcs)

        def declare_namespaces do
            Enum.each( unquote(namespaces),
                fn(table_name) ->
                  case table_exist?(table_name) do
                    false -> create_table(table_name)
                    true -> raise "Tinca : can't create table #{inspect table_name}, it is already exist! Maybe it was declarated in deps of your app?"
                  end
                end )
        end

        def memo(func, args, ttl) when is_function(func, length(args)) and is_integer(ttl) and (ttl > 0) do
          key = %TStructs.MemoKey{func: func, args: args}
          case :ets.lookup(@memo_tab, key) do
            [{^key, %TStructs.MemoVal{data: data}}] -> data
            [] -> data = :erlang.apply(func, args)
                  true = :ets.insert(@memo_tab, {key, %TStructs.MemoVal{data: data, delete_after: Exutils.makestamp + ttl}})
                  data
          end
        end

		def smart_memo(func, args, pred, ttl) when is_function(func, length(args)) and is_function(pred,1) and is_integer(ttl) and (ttl > 0) do
			key = %TStructs.MemoKey{func: func, args: args}
			case :ets.lookup(@memo_tab, key) do
				[{^key, %TStructs.MemoVal{data: data}}] -> data
				[] ->
					data = :erlang.apply(func, args)
					if (pred.(data)), do: (true = :ets.insert(@memo_tab, {key, %TStructs.MemoVal{data: data, delete_after: Exutils.makestamp + ttl}}))
					data
			end
		end

        def trx(func, roll, trx_key, ttl) when is_function(func, 0) and (is_function(roll, 1) or (roll == nil)) and is_integer(ttl) and (ttl > 0) do
          case TincaTrxServer.start_trx(trx_key) do
            :ok -> TincaTrxServer.do_process(func, roll, trx_key, ttl)
            %TStructs.TrxVal{ready: true, data: data} -> data
            %TStructs.TrxVal{ready: false} -> TincaTrxServer.await(func, roll, trx_key, ttl)
          end
        end

        defmodule WeakLinks do
          def make(val1, val2, ttl), do: TWeakLinks.make(val1, val2, ttl)
          def make_injection(val1, val2, ttl), do: TWeakLinks.make_injection(val1, val2, ttl)
          def get(val), do: TWeakLinks.get(val)
          def get(val, default), do: TWeakLinks.get(val, default)
        end

        ###############
        #### priv #####
        ###############

        defp create_table(namespace) do
          true = (namespace == :ets.new(namespace, [:public, :named_table, :set]))
        end
        defp table_exist?(namespace) do
          :ets.info(namespace) != :undefined
        end

        defp keys_proc(_, :'$end_of_table', acc), do: acc
        defp keys_proc(tab, key, acc), do: keys_proc(tab, :ets.next(tab, key), [key|acc])

      end
    end
  end

end
