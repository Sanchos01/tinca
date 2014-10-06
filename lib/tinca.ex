defmodule Tinca do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    create_table(:global_tinca_namespace)
    create_declared_tables

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Tinca.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tinca.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  ##############
  ### public ###
  ##############

  def put(value, key, namspace \\ :global_tinca_namespace)
  def put(value, key, namspace) when (is_atom(namspace) and is_atom(key)) do
    case table_exist?(namspace) do
      true ->
        true = :ets.insert(namspace, {key,value})
        value
      false ->
        raise "Tinca : table #{inspect namspace} is not exist! Was it declarated in config.exs?"
    end
  end
  
  def get(key, namspace \\ :global_tinca_namespace)
  def get(key, namspace) do
    case table_exist?(namspace) do
      true ->
        case :ets.lookup(namspace, key) do
          [{ _ , data}] -> data
          _ -> :not_found
        end
      false -> 
        raise "Tinca : table #{inspect namspace} is not exist! Was it declarated in config.exs?"
    end
  end
  

  ###############
  #### priv #####
  ###############

  defp create_declared_tables do
    declared_tables = :application.get_all_env(:tinca)[:namespaces] |> IO.inspect
  end

  defp create_table(namspace) do
    :ets.new(namspace, [:public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}, :protected])
  end
  defp table_exist?(namspace) do
    :ets.info(namspace) != :undefined
  end

end
