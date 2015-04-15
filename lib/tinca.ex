defmodule Tinca do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Tinca.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tinca.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defmacro __using__(namespaces) when is_list(namespaces) do
    Enum.each(namespaces, 
      fn(namespace) ->
        if not(is_atom(namespace)) do
          raise "Tinca : can't create table #{inspect namespace}, namespace must be atom!"
        end
      end )
    regular_put_func = quote do
                          def put(value, key, namespace) when ( ( is_atom(key) or is_binary(key) or is_number(key) ) and (namespace in unquote(namespaces))) do
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
                          def get(key, namespace) when ( ( is_atom(key) or is_binary(key) or is_number(key) ) and (namespace in unquote(namespaces))) do
                              case table_exist?(namespace) do
                                true -> case :ets.lookup(namespace, key) do
                                          [{ _ , data}] -> data
                                          _ -> nil
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
                          def delete(key, namespace) when ( ( is_atom(key) or is_binary(key) or is_number(key) ) and (namespace in unquote(namespaces))) do
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

        ###############
        #### priv #####
        ###############

        defp create_table(namespace) do
          true = (namespace == :ets.new(namespace, [:public, :named_table, :ordered_set, {:write_concurrency, true}, {:read_concurrency, true}, :protected]))
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
