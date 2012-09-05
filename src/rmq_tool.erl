-module(rmq_tool).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logging.hrl").


-export([
	purge/1,
	dump/3,
	dump/2,
	dump/1,

	% aliases from inject
	inject_series/2,

	read_and_inject/3,
	read_and_inject_stream/5,

	read_and_inject_old/4,
	read_and_inject_simple/4,
	read_and_inject_proper/4	
]).


%% ===================================================================
%% APIs
%% ===================================================================

%% purge queue
purge(QueueName) ->
	Channel = rmq_connection:get_channel(),
	?log_info("Purging the queue ~p...  ", [QueueName]),

	try
		Purge = #'queue.purge'{queue = QueueName},
		{'queue.purge_ok', Count} = amqp_channel:call(Channel, Purge),
		?log_info("~p items purged", [Count])
	catch
		_Ex:Reason -> ?log_error("Purging error: ~p.", [Reason])
	end,

 	ok.
 	

%% dump queue
dump(QueueName) ->
	dump(QueueName, rmq_basic_funs:queue_length(QueueName), true).


dump(QueueName, Max) ->
	dump(QueueName, Max, true).


dump(QueueName, Max, NoAck) ->
	Channel = rmq_connection:get_channel(),
	?log_info("Dumping the queue ~p.", [QueueName]),
	
	ok = dump_queue_contents(QueueName, Channel, Max, Max - (Max rem 10), NoAck).



inject_series(QName, Series) ->
	rmq_inject:inject_series(QName, Series).


read_and_inject_stream(QName, FileName, Limit, Offset, TellFun) ->
	rmq_inject:read_and_inject_stream(QName, FileName, Limit, Offset, TellFun).


read_and_inject(QName, Fun, FileName) ->
	rmq_inject:read_and_inject(QName, Fun, FileName).


read_and_inject_proper(QName, FileName, Limit, Offset) ->
	rmq_inject:read_and_inject_proper(QName, FileName, Limit, Offset).


read_and_inject_old(QName, FileName, Limit, Offset) ->
	rmq_inject:read_and_inject_old(QName, FileName, Limit, Offset).


read_and_inject_simple(QName, FileName, Limit, Offset) ->
	rmq_inject:read_and_inject_simple(QName, FileName, Limit, Offset).


%% ===================================================================
%% Internals
%% ===================================================================


dump_queue_contents(_, _, 0, _, _) -> 
	show_progress(100, 0),
	?log_info("Reached the limit.", []),
	ok;

dump_queue_contents(QueueName, Channel, Left, Max, NoAck) ->
	show_progress(100 - trunc(Left / Max * 100), trunc(Left / Max * 100) rem 10),
	BasicGet = #'basic.get'{queue = QueueName, no_ack = NoAck},

	case amqp_channel:call(Channel, BasicGet) of
		{#'basic.get_ok'{ }, Content} ->
			file:write_file(
				lists:flatten(io_lib:format("log/~s.qdump", [QueueName])),
				io_lib:format("{~p} .", [Content]),
				[append] 
			),
			dump_queue_contents(QueueName, Channel, Left - 1, Max, NoAck);
		#'basic.get_empty'{} ->
			?log_info("Queue is empty.", [])
	end.


show_progress(0, 0) -> 	ok;

show_progress(Progress, 0) ->
	?log_info("... ~p% done", [Progress]);

show_progress(_Progress, _OtherValue) -> ok.