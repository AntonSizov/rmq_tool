-ifndef(logging_hrl).
-define(logging_hrl, included).

-define(log_common(Lvl, Fmt, Args),
    ((fun(__Lvl, __Fmt, __Args) ->
        {ok, Verbose} = application:get_env(rmq_tool, verbose),

        {FileLineFmt, FileLineArgs} =
        if
            Verbose ->
                {" [~s:~p]", [?FILE, ?LINE]};
            true ->
                {"", []}
        end,

        LvlFmt = "["++__Lvl++"] ",

        if
            __Lvl == "DEBUG" andalso not Verbose ->
                ok;
            true ->
                io:format(LvlFmt++__Fmt++FileLineFmt++"~n", __Args++FileLineArgs)
        end

    end)(Lvl, Fmt, Args))
).

-define(log_info(Fmt, Args), ?log_common("INFO", Fmt, Args)).
-define(log_debug(Fmt, Args), ?log_common("DEBUG", Fmt, Args)).
-define(log_warn(Fmt, Args), ?log_common("WARN", Fmt, Args)).
-define(log_error(Fmt, Args), ?log_common("ERROR", Fmt, Args)).

-endif. % logging_hrl
