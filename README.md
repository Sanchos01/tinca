Tinca
=====


#
#	TODO : add "delete" function
#

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
SomeApp.Tinca.get(:not_existing_key, :namespace_1) # => :not_found

SomeApp.Tinca.get(:some_key, :not_declared_in_this_app_namespace) => exception
```
if you declared only one namespace, you can also use
```
SomeApp.Tinca.put("value", :key) # => "value"
SomeApp.Tinca.get(:key) # => "value"
SomeApp.Tinca.get(:not_existing_key) # => :not_found
```