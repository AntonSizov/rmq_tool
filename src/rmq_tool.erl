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
	inject/4,

	help/0
]).



%% ===================================================================
%% APIs
%% ===================================================================

%% @doc Purges queue
-spec purge(QueueName :: binary()) -> ok.
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


%% @doc dump queue
-spec dump(QueueName :: binary()) -> ok.
dump(QueueName) ->
	rmq_dump:dump(QueueName).


%% @doc dump queue, limiting amount of dumped messages
-spec dump(QueueName :: binary(), MaxMessages :: integer()) -> ok.
dump(QueueName, Max) ->
	rmq_dump:dump(QueueName, Max).


%% @doc dump queue, limiting amount of dumped messages
-spec dump(QueueName :: binary(), MaxMessages :: integer(), NoAck :: atom()) -> ok.
dump(QueueName, Max, NoAck) ->
	rmq_dump:dump(QueueName, Max, NoAck).


%% @doc injecting queue with all data taken from a file
-spec inject(QueueName :: binary(), FileName :: string()) -> ok.
inject(QueueName, FileName) ->
	rmq_inject:inject(QueueName, FileName).


%% @doc injecting queue with all data taken from a file. Skipping a couple of starting messages
-spec inject(QueueName :: binary(), FileName :: string(), Offset :: integer()) -> ok.
inject(QueueName, FileName, Offset) ->
	rmq_inject:inject(QueueName, FileName, Offset).


%% @doc injecting queue with all data taken from a file. Skipping a couple of starting messages and limits amount
-spec inject(QueueName :: binary(), FileName :: string(), Offset :: integer(), Count :: integer()) -> ok.
inject(QueueName, FileName, Offset, Count) ->
	rmq_inject:inject(QueueName, FileName, Offset, Count).

%% @doc Print help info
help() ->
	Messages = [
	"Purge queue: ~n"
	"rmq_tool:purge(<<\"pmm.mmwl.response.sms\">>).~n",
	"Dupm all messages in queue: ~n"
	"rmq_tool:dump(<<\"pmm.mmwl.response.sms\">>).~n",
	"Dump 1000 messages in queue: ~n"
	"rmq_tool:dump(<<\"pmm.mmwl.response.sms\">>, 1000).~n",
	"Inject all messages into queue: ~n"
	"rmq_tool:inject(<<\"pmm.mmwl.response.sms\">>, \"pmm.mmwl.response.sms_20121022_17184.qdump\")~n",
	"Advanced inject messages into queue: ~n"
	"rmq_tool:inject(QueueName, FileName, Offset, Count)~n"
	],
	lists:foreach(fun(S) ->
		io:format(S ++ "~n", [])
	end, Messages),
	ok.
