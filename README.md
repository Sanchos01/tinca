Tinca
=====

usage:

1) in start/2 function of your app declare namespaces
```
defmodule SomeApp do

  use Application
  use Tinca, [:namespace_1, :namespace_2]

  def start(_type, _args) do
	  ...

	  Tinca.declare_namespaces
	  ...
  end
```
2) somewhere in your application :
```
SomeApp.Tinca.put("value", :key, :namespace_1) # => "value"
SomeApp.Tinca.get(:key, :namespace_1) # => "value"
SomeApp.Tinca.get(:not_existing_key, :namespace_1) # => nil
SomeApp.Tinca.delete(:key, :namespace_1) # => :ok
SomeApp.Tinca.get(:key, :namespace_1) # => nil
SomeApp.Tinca.get(:some_key, :not_declared_in_this_app_namespace) => exception
```
if you declared only one namespace, you can also use
```
SomeApp.Tinca.put("value", :key) # => "value"
SomeApp.Tinca.get(:key) # => "value"
SomeApp.Tinca.get(:not_existing_key) # => nil
```
3) You also can use iterate funcs like

```
Tinca.iterate(lambda, namespace)
Tinca.iterate_acc(acc, lambda, namespace)
```

4) For dynamic cache and transactions use

```
Tinca.memo(func, args, ttl)
Tinca.trx(func, roll, trx_key, ttl)
```