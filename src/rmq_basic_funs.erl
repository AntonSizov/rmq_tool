-module(rmq_basic_funs).

-export([
	queue_length/1,
	queue_declare/1,
	queue_is_exists/1,
	publish_message/3
]).


-export([
	get_seconds/0
]).

-include("logging.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


%% ===================================================================
%% APIs
%% ===================================================================


%% @doc Returns queue length
-spec queue_length(QueueName :: binary()) -> integer().
queue_length(QueueName) ->
	Channel = rmq_connection:get_channel(),

	try
		#'queue.declare_ok'{message_count = MessageCount} = amqp_channel:call(Channel, #'queue.declare'{queue = QueueName, passive = true}),
		MessageCount
	catch
		_Ex:Reason -> ?log_error("Error: ~p.", [Reason]),
		0
	end.


%% @doc Checking if query exists
- spec queue_is_exists(QueueName :: binary()) -> boolean().
queue_is_exists(QueueName) ->
	Channel = rmq_connection:get_channel(),
	try
		#'queue.declare_ok'{} = amqp_channel:call(Channel, #'queue.declare'{queue = QueueName, passive = true}),
		true
	catch
		_Ex:Reason -> ?log_error("Error: ~p.", [Reason]),
		false
	end.


%% @doc Creates queue
- spec queue_declare(QueueName :: binary()) -> #'queue.declare_ok'{}.
queue_declare(QueueName) ->
	Channel = rmq_connection:get_channel(),

	Declare = #'queue.declare'{queue = QueueName},
	#'queue.declare_ok'{} = amqp_channel:call(Channel, Declare).


%% @doc Publish message to the give queue
- spec publish_message(Channel :: pid(), QueueName :: binary(), Message :: #amqp_msg{}) -> ok.
publish_message(Channel, QueueName, Message) -> 
	Publish = #'basic.publish'{ routing_key = QueueName },
	amqp_channel:call(Channel, Publish, Message).	

%% @doc Returns current seconds
-spec get_seconds() -> integer().
get_seconds() ->
	{_Megaseconds, Seconds, _Microseconds} = erlang:now(),
	Seconds.
