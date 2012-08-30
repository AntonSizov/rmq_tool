-module(rmq_inject).

-export([
	inject_series/2,

	read_and_inject/3,
	read_and_inject_stream/5,

	read_and_inject_old/4,
	read_and_inject_simple/4,
	read_and_inject_proper/4
]).

-include("logging.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").





inject_into_queue_single(QName, Chan, Msg) ->
	Publish = #'basic.publish'{ routing_key = QName },
	%Msg = #amqp_msg{props = Props, payload = Payload},
	amqp_channel:call(Chan, Publish, Msg).

inject_series_one_by_one(_, _, []) ->
	ok;
inject_series_one_by_one(QName, Chan, [Item | SoFar]) ->
	inject_into_queue_single(QName, Chan, Item),
	inject_series_one_by_one(QName, Chan, SoFar).
	


inject_series(QName, Series) ->
	Chan = rmq_connection:open_channel(),

	?log_info("Injecting ~p items into ~p~n", [length(Series), QName]),
	inject_series_one_by_one(QName, Chan, Series),
	amqp_channel:close(Chan).


read_and_inject_stream(QName, FileName, Limit, Offset, TellFun) ->
	case file:open(FileName, [read]) of
		{ok, Fd} ->
			Chan = rmq_connection:open_channel(),
			read_terms_and_execute(Fd, 1, Limit, Offset, fun(T) ->
				Msg = TellFun(T),
				inject_into_queue_single(QName, Chan, Msg)
			end),
			amqp_channel:close(Chan),
			file:close(Fd);
		Error ->
			Error
	end.

use_term(_Term, 0, 0, _F) ->
	{ 0, 0 };
use_term(Term, Limit, 0, F) ->
	F( Term ),
	{ Limit - 1, 0 };
use_term(_Term, Limit, Offset, _F) when Offset > 0 ->
	{ Limit, Offset - 1 }.
	

read_terms_and_execute(Fd, Line, Limit, Offset, F) ->
	case io:read(Fd, '', Line) of
		{ ok, Term, EndLine } ->
			case use_term(Term, Limit, Offset, F) of
				{ 0, 0 } ->
					ok;
				{ NewLimit, NewOffset } ->
	    			read_terms_and_execute(Fd, EndLine, NewLimit, NewOffset, F)
	    	end;
		{ error, Error, _Line } ->
			{ error, Error };
		{ eof, _Line } ->
			ok
    end.

read_and_inject(QName, Fun, FileName) ->
	{ok, Tuples} = file:consult(FileName),
	Msgs = lists:map(Fun, Tuples),
	inject_series(QName, Msgs).

read_and_inject_old(QName, FileName, Limit, Offset) ->
	Props = #'P_basic'{delivery_mode = 2}, % persistent message
	read_and_inject_stream(QName, 
					FileName, Limit, Offset,
					fun(Payload) -> 
						#amqp_msg{props = Props, payload = Payload}
					end).

read_and_inject_simple(QName, FileName, Limit, Offset) ->
	Props = #'P_basic'{delivery_mode = 2}, % persistent message
	read_and_inject_stream(QName, 
					FileName, Limit, Offset,
					fun({Payload, _}) -> 
						#amqp_msg{props = Props, payload = Payload}
					end).

read_and_inject_proper(QName, FileName, Limit, Offset) ->
	read_and_inject_stream(QName, 
					FileName, Limit, Offset,
					fun({_, Msg}) -> Msg end).

