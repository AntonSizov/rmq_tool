-module(rmq_basic_funs).

-export([
	queue_length/1,
	queue_declare/1

]).


-include_lib("amqp_client/include/amqp_client.hrl").


%% ===================================================================
%% APIs
%% ===================================================================

queue_length(QueueName) ->
	Channel = rmq_connection:open_channel(),

	{'queue.declare_ok', _, MessageCount, _} = amqp_channel:call(Channel, #'queue.declare'{queue = QueueName}),
	MessageCount.


queue_declare(QueueName) ->
	Channel = rmq_connection:open_channel(),

	Declare = #'queue.declare'{queue = QueueName},
	#'queue.declare_ok'{} = amqp_channel:call(Channel, Declare),
	amqp_channel:close(Channel).