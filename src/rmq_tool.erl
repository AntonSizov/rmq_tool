-module(rmq_tool).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logging.hrl").


-export([
	purge/1,
	% aliases from dump
	dump/3,
	dump/2,
	dump/1,

	% aliases from inject
	inject/2,
	inject/3,
	inject/4
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
		?log_info("~p message(s) purged", [Count])
	catch
		_Ex:Reason -> ?log_error("Purging error: ~p.", [Reason])
	end,

 	ok.
 	

%% dump queue
dump(QueueName) ->
	rmq_dump:dump(QueueName).


dump(QueueName, Max) ->
	rmq_dump:dump(QueueName, Max).


dump(QueueName, Max, NoAck) ->
	rmq_dump:dump(QueueName, Max, NoAck).


%% inject queue
inject(QueueName, FileName, Offset) ->
	rmq_inject:inject(QueueName, FileName, Offset).


inject(QueueName, FileName, Offset, Count) ->
	rmq_inject:inject(QueueName, FileName, Offset, Count).

inject(QueueName, FileName) ->
	rmq_inject:inject(QueueName, FileName).	