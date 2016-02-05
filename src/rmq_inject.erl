-module(rmq_inject).

-export([
    inject/2,
    inject/3,
    inject/4
]).


-include_lib("amqp_client/include/amqp_client.hrl").
-include("logging.hrl").
-include("consts.hrl").


-record(injecting_state, {
            offset,
            count,
            seconds,
            messages_count,
            max
}).


%% ===================================================================
%% APIs
%% ===================================================================


%% @doc injecting queue with all data taken from a file
-spec inject(QueueName :: binary() | [binary()], FileName :: string()) -> ok.
inject(QueueName, FileName) when is_binary(QueueName) ->
    inject([QueueName], FileName);
inject(Queues, FileName) when is_list(Queues) ->
    inject(Queues, FileName, 1).

%% @doc injecting queue with all data taken from a file. Skipping a couple of starting messages
-spec inject(Queues :: binary() | [binary()], FileName :: string(), Offset :: integer()) -> ok.
inject(Queue, FileName, Offset) when is_binary(Queue) ->
    inject([Queue], FileName, Offset);
inject(Queues, FileName, Offset) when is_list(Queues) ->
    inject(Queues, FileName, Offset, all).

%% @doc injecting queue with all data taken from a file. Skipping a couple of starting messages and limits amount
-spec inject(QueueName :: binary(), FileName :: string(), Offset :: integer(), Count :: integer()) -> ok.
inject(Queue, FileName, Offset, Count) when is_binary(Queue) ->
    inject([Queue], FileName, Offset, Count);
inject(Queues, FileName, Offset, Count)  when is_list(Queues) ->
    inject_stream(Queues,
        string:concat(?DEFAULT_DUMP_lOGS_FOLDER, FileName),
        init_injecting_state(Offset, Count)).



%% ===================================================================
%% Internals
%% ===================================================================

init_injecting_state(Offset, Count) ->
    #injecting_state{
        offset = Offset - 1,
        count = Count,
        seconds = rmq_basic_funs:get_seconds(),
        messages_count = 0,
        max = Count}.


inject_stream(Queues, FileName, State) when is_list(Queues) ->
    case file:open(FileName, [read]) of
        {ok, Fd} ->
            ?log_info("Queue `~p` will be injected with ~p messages", [Queues, State#injecting_state.count]),
            ?log_info("Options: offset=~p, amount of message=~p", [State#injecting_state.offset + 1, State#injecting_state.count]),
            Channel = rmq_connection:get_channel(),
            read_term_and_publish(Fd, 1, State,
                    fun(Term) -> [rmq_basic_funs:publish_message(Channel, Queue, Term) || Queue <- Queues] end),
            ?log_info("done", []),
            file:close(Fd);
        Error ->
            Error
    end.


publish_message(insert, State, WhatToDoFun, Term) ->
    NewState = show_progress(rmq_basic_funs:get_seconds(), State),
    WhatToDoFun(Term),
    NewState;

publish_message(_any_other_state, State, _WhatToDoFun, _Term) ->
    State.


try_to_publish(State, WhatToDoFun, Term) ->
    NewState = publish_message(get_current_state(State), State, WhatToDoFun, Term),
    get_next_state(NewState).


read_term_and_publish(_Fd, _Line, #injecting_state{offset = 0, count = 0, messages_count = Count}, _WhatToDoFun) ->
    show_summary(Count),
    ok;

read_term_and_publish(Fd, Line, State, WhatToDoFun)    ->
    case io:read(Fd, '', Line) of
        {ok, Term, EndLine } ->
            NewState = try_to_publish(State, WhatToDoFun, Term),
            read_term_and_publish(Fd, EndLine, NewState, WhatToDoFun);
        {error, Error, _Line} ->
            { error, Error};
        {eof, _Line} ->
            show_summary(State#injecting_state.messages_count),
            ok
    end.


show_summary(Count) ->
    ?log_info("Summary: ~p has been injected", [Count]).

show_progress(NowSeconds, IS = #injecting_state{ seconds = NowSeconds, messages_count = Count}) ->
    IS#injecting_state{messages_count = Count + 1};

show_progress(NowSeconds, IS = #injecting_state{max = Max, messages_count = MsgCount}) when is_atom(Max) ->
    ?log_info("Processed ~p of ~p", [MsgCount, Max]),
    IS#injecting_state{seconds = NowSeconds, messages_count = MsgCount + 1};

show_progress(NowSeconds, IS = #injecting_state{max = Max, messages_count = MsgCount}) ->
    ?log_info("Processed ~p% (~p of ~p)", [trunc(MsgCount / Max * 100), MsgCount, Max]),
    IS#injecting_state{seconds = NowSeconds, messages_count = MsgCount + 1}.


get_current_state(#injecting_state{offset = 0, count = 0}) -> done;
get_current_state(#injecting_state{offset = 0, count = _Z}) -> insert;
get_current_state(#injecting_state{offset = _Y, count = _Z}) -> continue.


get_next_state(State = #injecting_state{offset = 0, count = 0}) -> State;
get_next_state(State = #injecting_state{offset = 0, count = Value}) when is_integer(Value) ->
    State#injecting_state{count = Value - 1};
get_next_state(State = #injecting_state{offset = 0, count = Value}) when is_atom(Value) ->
    State;
get_next_state(State = #injecting_state{offset = Value, count = _Count}) -> State#injecting_state{offset = Value - 1}.
