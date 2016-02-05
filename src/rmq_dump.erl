-module(rmq_dump).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logging.hrl").
-include("consts.hrl").

-export([
    dump/3,
    dump/2,
    dump/1
]).

-record(dump_progress_state, {
    seconds,
    left,
    count,
    messages_count
}).

-define(QUEUE_IS_EMPTY_MSG, "Queue is empty. Skip").

%% ===================================================================
%% APIs
%% ===================================================================

%% @doc dump queue
-spec dump(QueueName :: binary()) -> ok.
dump(QueueName) ->
    dump(QueueName, _MaxMsgs = 0, _NoAck = true).


%% @doc dump queue, limiting amount of dumped messages
-spec dump(QueueName :: binary(), MaxMessages :: integer()) -> ok.
dump(QueueName, MaxMessages) ->
    dump(QueueName, MaxMessages, _NoAck = true).


%% @doc dump queue, limiting amount of dumped messages
-spec dump(QueueName :: binary(), MaxMessages :: integer(), NoAck :: atom()) -> ok.
dump(QueueName, MaxMessages, NoAck) ->
    dump(QueueName, MaxMessages, NoAck, rmq_basic_funs:queue_is_exists(QueueName)).

%% ===================================================================
%% Internals
%% ===================================================================

dump(QueueName, _MaxMessages, _NoAck, _IsExist = false) ->
    ?log_info("Queue `~s` doesn't exist", [QueueName]);

dump(QueueName, MaxMessages, NoAck, _IsExist = true) ->
    Channel = rmq_connection:get_channel(),
    ?log_debug("Got channel: ~p", [Channel]),
    MessagesCount = get_max_items(QueueName, MaxMessages),
    ?log_debug("Dump msgs count: ~p", [MessagesCount]),
    DumpProgress = #dump_progress_state{
        seconds = rmq_basic_funs:get_seconds(),
        left = MessagesCount,
        count = MessagesCount,
        messages_count = 0
    },
    FileName = compose_log_file_name(QueueName),
    ?log_info("Dumping queue to ~s", [FileName]),
    dump_queue_contents(QueueName, Channel, NoAck, DumpProgress, FileName).


get_max_items(QueueName, 0) ->
    rmq_basic_funs:queue_length(QueueName);
get_max_items(QueueName, Max) ->
    AvailableMsgsNumber = rmq_basic_funs:queue_length(QueueName),
    min(AvailableMsgsNumber, Max).


dump_queue_contents(_, _, _, #dump_progress_state{count = 0, messages_count = 0}, _LogFileName) ->
    ?log_info(?QUEUE_IS_EMPTY_MSG, []);

dump_queue_contents(_, _, _, #dump_progress_state{left = 0, messages_count = Cnt}, _LogFileName) ->
    ?log_info("Summary: ~p messages have been dumped (max msg count reached)", [Cnt]);

dump_queue_contents(QueueName, Channel, NoAck, State, LogFileName) ->
    NewState = show_progress(rmq_basic_funs:get_seconds(), State),

    BasicGet = #'basic.get'{queue = QueueName, no_ack = NoAck},

    case amqp_channel:call(Channel, BasicGet) of
        {#'basic.get_ok'{}, Content} ->
            push_to_dump(LogFileName, Content),
            dump_queue_contents(QueueName, Channel, NoAck, NewState, LogFileName);
        #'basic.get_empty'{} ->
            ?log_info("Summary: ~p messages have been dumped (basic.get_empty)",
                [State#dump_progress_state.messages_count])
    end.


push_to_dump(LogFileName, Content) ->
    file:write_file(LogFileName, io_lib:format("~p.~n", [Content]), [append]).


show_progress(NowSeconds, DumpProgressState = #dump_progress_state{seconds = NowSeconds}) ->
    #dump_progress_state{
        left = Left,
        messages_count = DumpedCnt
    } = DumpProgressState,
    DumpProgressState#dump_progress_state{
        left = Left - 1,
        messages_count = DumpedCnt + 1
    };

show_progress(NowSeconds, DumpProgressState = #dump_progress_state{}) ->
    #dump_progress_state{
        left = Left,
        count = Count,
        messages_count = DumpedCnt
    } = DumpProgressState,
    PercentDone = 100 - trunc(Left / Count * 100),
    ?log_info("Processed ~p% (~p of ~p)", [PercentDone, Count - Left, Count]),
    DumpProgressState#dump_progress_state{
        seconds = NowSeconds,
        left = Left - 1,
        count = Count,
        messages_count = DumpedCnt + 1
    }.


concat_anything(List) ->
    L = concat_anything(List, []),
    lists:flatten(L).

concat_anything([], Acc) ->
    Acc;

concat_anything([H|T], Acc) when is_integer(H) ->
    concat_anything(T, Acc ++ integer_to_list(H));

concat_anything([H|T], Acc) when is_bitstring(H) ->
    concat_anything(T, Acc ++ binary_to_list(H));

concat_anything([H|T], Acc) when is_list(H) ->
    concat_anything(T, Acc ++ H).


compose_log_file_name(QueueName) ->
    { {Year, Month, Day}, {Hour, Minutes, Seconds}} = erlang:localtime(),
    concat_anything([
        ?DEFAULT_DUMP_lOGS_FOLDER,
        QueueName, "_", Year, Month, Day, "_", Hour, Minutes, Seconds, ".qdump"
    ]).
