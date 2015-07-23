defmodule TStructs do
	use Silverb
	defmodule MemoKey do
		defstruct 	func: nil,
					args: nil
	end
	defmodule MemoVal do
		defstruct	data: nil,
					delete_after: nil
	end

	defmodule TrxKey do
		defstruct 	func: nil,
					roll: nil,
					args: nil,
					trx: nil
	end
	defmodule TrxVal do
		defstruct 	data: nil,
					status: nil,
					delete_after: nil
	end
	defmodule TrxProto do
		defstruct 	subject: nil,
					content: nil
	end
end