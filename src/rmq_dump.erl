-module(rmq_dump).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logging.hrl").


-export([
	dump/3,
	dump/2,
	dump/1
]).


-record(dump_progress_state, {
            seconds,
            left,
            count
}).


-define(QUEUE_IS_EMPTY_MSG, "Queue is empty.").

%% ===================================================================
%% APIs
%% ===================================================================


%% dump queue
dump(QueueName) ->
	dump(QueueName, 0, true).


dump(QueueName, MaxMessages) ->
	dump(QueueName, MaxMessages, true).


dump(QueueName, MaxMessages, NoAck) ->
	dump(QueueName, MaxMessages, NoAck, rmq_basic_funs:queue_is_exists(QueueName)).


dump(QueueName, _MaxMessages, _NoAck, false) ->
	?log_info("Queue `~p` doesn't exists", [QueueName]),
	ok;


%% ===================================================================
%% Internals
%% ===================================================================


dump(QueueName, MaxMessages, NoAck, true) ->
	?log_info("Dumping the queue ~p.", [QueueName]),

	Channel = rmq_connection:get_channel(),
	MessagesCount = get_max_items(QueueName, MaxMessages),
	DumpProgress = #dump_progress_state{seconds = get_seconds(), left = MessagesCount, count = MessagesCount},
	FileName = compose_log_file_name(QueueName),

 	dump_queue_contents(QueueName, Channel, NoAck, DumpProgress, FileName).


get_max_items(QueueName, 0) ->
	rmq_basic_funs:queue_length(QueueName);
get_max_items(_QueueName, Max) ->
	Max.


get_seconds() ->
	{_Megaseconds, Seconds, _Microseconds} = erlang:now(),
	Seconds.


dump_queue_contents(_, _, _, #dump_progress_state{count = 0}, LogFileName) -> 
	push_to_dump_empty_queue(LogFileName),
	?log_info(?QUEUE_IS_EMPTY_MSG, []),
	ok;


dump_queue_contents(_, _, _, #dump_progress_state{left = 0}, _) -> 
	?log_info("Done...", []),
	ok;

dump_queue_contents(QueueName, Channel, NoAck, State, LogFileName) ->
	NewState = show_progress(get_seconds(), State),

	BasicGet = #'basic.get'{queue = QueueName, no_ack = NoAck},

	case amqp_channel:call(Channel, BasicGet) of
		{#'basic.get_ok'{}, Content} ->
			push_to_dump(LogFileName, Content),
			dump_queue_contents(QueueName, Channel, NoAck, NewState, LogFileName);
		#'basic.get_empty'{} ->
			push_to_dump_empty_queue(LogFileName),
			?log_info(?QUEUE_IS_EMPTY_MSG, [])
	end.


push_to_dump_empty_queue(LogFileName) ->
	file:write_file(LogFileName, ?QUEUE_IS_EMPTY_MSG).


push_to_dump(LogFileName, Content) ->
	file:write_file(LogFileName, io_lib:format("~p.~n", [Content]), [append]).



show_progress(NowSeconds, DPS = #dump_progress_state{ seconds = NowSeconds, left = Left}) ->
	DPS#dump_progress_state{left = Left - 1};

show_progress(NowSeconds, DPS = #dump_progress_state{left = Left, count = Count}) ->
	?log_info("Processed ~p% (~p of ~p)", [100 - trunc(Left / Count * 100), Count - Left, Count]),
	DPS#dump_progress_state{seconds = NowSeconds, left = Left - 1, count = Count}.




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
	concat_anything(["log/", QueueName, "_", Year, Month, Day, "_", Hour, Minutes, Seconds, ".qdump"]).
