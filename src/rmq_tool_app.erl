-module(rmq_tool_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).


-include("consts.hrl").

%% ===================================================================
%% Application callbacks
%% ===================================================================


start(_StartType, _StartArgs) ->
    filelib:ensure_dir(?DEFAULT_DUMP_lOGS_FOLDER),
    rmq_tool_sup:start_link().


stop(_State) ->
    ok.
