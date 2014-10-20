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
                          def get(key, namespace) when ( ( is_atom(key) or is_binary(key) or is_number(key) ) and (namespace in unquote(namespaces))) do
                              case table_exist?(namespace) do
                                true -> case :ets.lookup(namespace, key) do
                                          [{ _ , data}] -> data
                                          _ -> :not_found
                                        end
                                false -> raise "Tinca : table #{inspect namespace} is not exist! Was it declarated?"
                              end
                          end
                          def get(key, namespace) do
                            raise "Tinca : #{inspect key} is not atom, binary or number, or namespace #{inspect namespace} was not declarated for this app. Can't get value."
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

    put_funcs = case namespaces do
                  [namespace] ->  quote do
                                    def put(value, key, namespace \\ unquote(namespace) )
                                    unquote(regular_put_func)
                                  end
                  ^namespaces ->  regular_put_func
                end
    get_funcs = case namespaces do
                  [namespace] ->  quote do
                                    def get(key, namespace \\ unquote(namespace) )
                                    unquote(regular_get_func)
                                  end
                  ^namespaces ->  regular_get_func
                end
    del_funcs = case namespaces do
                  [namespace] ->  quote do
                                    def delete(key, namespace \\ unquote(namespace) )
                                    unquote(regular_del_func)
                                  end
                  ^namespaces ->  regular_del_func
                end

    quote do
      defmodule Tinca do

        ###############
        ### public ####
        ###############

        unquote(put_funcs)
        unquote(get_funcs)
        unquote(del_funcs)

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
          namespace = :ets.new(namespace, [:public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}, :protected])
        end
        defp table_exist?(namespace) do
          :ets.info(namespace) != :undefined
        end

      end
    end
  end

end
