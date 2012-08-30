-module(rmq_tool).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logging.hrl").


-export([
	purge_queue/1,
	dump_queue/3,
	dump_queue/2,
	dump_queue/1	
]).


%% ===================================================================
%% APIs
%% ===================================================================

%% purge queue
purge_queue(QueueName) ->
	Channel = rmq_connection:open_channel(),
	?log_info("Purging the queue ~p.~n", [QueueName]),

	try
		Purge = #'queue.purge'{queue = QueueName},
		amqp_channel:call(Channel, Purge)
	catch
		_Ex:Reason -> ?log_error("Purging error: ~p.~n", [Reason])
	end,

 	amqp_channel:close(Channel),
 	ok.
 	

%% dump queue
dump_queue(QueueName) ->
	dump_queue(QueueName, rmq_basic_funs:queue_length(QueueName), true).


dump_queue(QueueName, Max) ->
	dump_queue(QueueName, Max, true).


dump_queue(QueueName, Max, NoAck) ->
	Channel = rmq_connection:open_channel(),
	?log_debug("Dumping the queue ~p.~n", [QueueName]),
	
	ok = dump_queue_contents(QueueName, Channel, Max, Max - (Max rem 10), NoAck),
	amqp_channel:close(Channel). 	


%% ===================================================================
%% Internals
%% ===================================================================


dump_queue_contents(_, _, 0, _, _) -> 
	show_progress(100, 0),
	?log_debug("Reached the limit.~n", []),
	ok;

dump_queue_contents(QueueName, Channel, Left, Max, NoAck) ->
	show_progress(100 - trunc(Left / Max * 100), trunc(Left / Max * 100) rem 10),
	BasicGet = #'basic.get'{queue = QueueName, no_ack = NoAck},

	case amqp_channel:call(Channel, BasicGet) of
		{#'basic.get_ok'{ }, Content} ->
			#amqp_msg{payload = _Payload} = Content,
			file:write_file(
				lists:flatten(io_lib:format("log/~s.qdump", [QueueName])),
				io_lib:format("{~p} .~n", [Content]),
				[append] 
			),
			dump_queue_contents(QueueName, Channel, Left - 1, Max, NoAck);
		#'basic.get_empty'{} ->
			?log_debug("Queue is empty.~n", [])
	end.


show_progress(0, 0) -> 	ok;

show_progress(Progress, 0) ->
	?log_info("... ~p% done~n", [Progress]);

show_progress(_Progress, _OtherValue) -> ok.