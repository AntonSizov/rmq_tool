-module(rmq_basic_funs).

-export([
	queue_length/1,
	queue_declare/1,
	queue_is_exists/1,
	publish_message/3
]).

-include("logging.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


%% ===================================================================
%% APIs
%% ===================================================================

queue_length(QueueName) ->
	Channel = rmq_connection:get_channel(),

	try
		#'queue.declare_ok'{message_count = MessageCount} = amqp_channel:call(Channel, #'queue.declare'{queue = QueueName, passive = true}),
		MessageCount
	catch
		_Ex:Reason -> ?log_error("Error: ~p.", [Reason]),
		0
	end.


queue_is_exists(QueueName) ->
	Channel = rmq_connection:get_channel(),
	try
		#'queue.declare_ok'{} = amqp_channel:call(Channel, #'queue.declare'{queue = QueueName, passive = true}),
		true
	catch
		_Ex:Reason -> ?log_error("Error: ~p.", [Reason]),
		false
	end.


queue_declare(QueueName) ->
	Channel = rmq_connection:get_channel(),

	Declare = #'queue.declare'{queue = QueueName},
	#'queue.declare_ok'{} = amqp_channel:call(Channel, Declare).


publish_message(Channel, QueueName, Mesage) -> 
	Publish = #'basic.publish'{ routing_key = QueueName },
	amqp_channel:call(Channel, Publish, Mesage).	