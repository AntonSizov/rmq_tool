-ifndef(logging_hrl).
-define(logging_hrl, included).

-define( log_common(Lvl, Fmt, Args),
		io:format("["++Lvl++"] "++Fmt++" [~s:~p]~n", Args ++ [?FILE, ?LINE] )
	).

-define( log_info(Fmt, Args), ?log_common("INFO", Fmt, Args) ).
-define( log_debug(Fmt, Args), ?log_common("DEBUG", Fmt, Args) ).
-define( log_warn(Fmt, Args), ?log_common("WARN", Fmt, Args) ).
-define( log_error(Fmt, Args), ?log_common("ERR", Fmt, Args) ).

-endif. % logging_hrl
