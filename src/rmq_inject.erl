-module(rmq_inject).

-export([
	inject/3,
	inject/4
]).


% -define(Q, <<"2">>).
% -define(FN, "/home/svart_ravn/work/projects/pmm/rmq_tool/src/2.qdump").

-include("logging.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


-record(state, {
			offset,
			count
}).


-define(IS_DONE, #state{offset = 0, count = 0}).


%% ===================================================================
%% APIs
%% ===================================================================

inject(QueueName, FileName, Offset) ->
	inject(QueueName, FileName, Offset, all).


inject(QueueName, FileName, Offset, Count) ->
	inject_stream(QueueName, FileName, #state{offset = Offset - 1, count = Count}).



%% ===================================================================
%% Internals
%% ===================================================================


inject_stream(QueueName, FileName, State) ->
	case file:open(FileName, [read]) of
		{ok, Fd} ->
			?log_info("Queue `~p` will be injected with ~p messages", [QueueName, State#state.count]),
			Channel = rmq_connection:get_channel(),
			read_term_and_publish(Fd, 1, State, 
					fun(Term) -> rmq_basic_funs:publish_message(Channel, QueueName, Term) end),
			?log_info("done", []),
			file:close(Fd);
		Error -> 
			Error
	end.


publish_message(insert, WhatToDoFun, Term) ->
	WhatToDoFun(Term);

publish_message(_any_other_state, _WhatToDoFun, _Term) ->
	no.


try_to_publish(State, WhatToDoFun, Term) ->
	publish_message(get_current_state(State), WhatToDoFun, Term),
	get_next_state(State).


read_term_and_publish(_Fd, _Line, ?IS_DONE, _WhatToDoFun) -> ok;

read_term_and_publish(Fd, Line, State, WhatToDoFun)	->
	case io:read(Fd, '', Line) of
		{ok, Term, EndLine } ->
			NewState = try_to_publish(State, WhatToDoFun, Term),
			read_term_and_publish(Fd, EndLine, NewState, WhatToDoFun);
		{error, Error, _Line} ->
			{ error, Error};
		{eof, _Line} ->
			ok
    end.


get_current_state(?IS_DONE) -> done;
get_current_state(#state{offset = 0, count = _Z}) -> insert;
get_current_state(#state{offset = _Y, count = _Z}) -> continue.


get_next_state(State = ?IS_DONE) -> State;
get_next_state(State = #state{offset = 0, count = Value}) when is_integer(Value) -> 
	State#state{count = Value - 1};
get_next_state(State = #state{offset = 0, count = Value}) when is_atom(Value) ->
	State;
get_next_state(State = #state{offset = Value, count = _Z}) -> State#state{offset = Value - 1}.