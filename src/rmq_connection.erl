-module(rmq_connection).
-behaviour(gen_server).

-export([
        start_link/0,
        get_connection/0,
        open_channel/0
]).

-export([
        init/1,
        handle_call/3,
        handle_cast/2,
        handle_info/2,
        terminate/2,
        code_change/3
]).


-include("logging.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


-record(state, {
            amqp_params_network,
            connection
}).



%% ===================================================================
%% APIs
%% ===================================================================
start_link() ->
   gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


get_connection() ->
   gen_server:call(?MODULE, get_connection).

open_channel() ->
    gen_server:call(?MODULE, open_channel).



%% ===================================================================
%% gen_server callbacks
%% ===================================================================
init([]) ->
    AP = get_default_amqp_params(),


    case amqp_connection:start(AP) of
        {ok, Conn} ->
            ?log_info("Connected to RabbitMQ~n", []),
            {ok, #state{amqp_params_network = AP, connection = Conn}};
        {error, _Reason} ->
            ?log_error("Can't connect to RabbitMQ~n", [])
    end.


handle_cast(Request, State) ->
    {stop, {bad_arg, Request}, State}.
  

handle_info(Info, State) ->
    {stop, {bad_arg, Info}, State}.


handle_call(get_connection, _From, State) ->
	{reply, State#state.connection, State};

handle_call(open_channel, _From, State) ->
    {ok, Channel} = amqp_connection:open_channel(State#state.connection),
    {reply, Channel, State};

handle_call(_Request, _From, State) ->
    {noreply, State}.


terminate(_Reason, State) ->
    amqp_connection:close(State#state.connection),
    ok.


code_change(_OldSvn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Internal
%% ===================================================================

get_default_amqp_params() ->
    {ok, Host} = application:get_env(rmq_tool, amqp_host),
    {ok, Port} = application:get_env(rmq_tool, amqp_port),
    {ok, Xchg} = application:get_env(rmq_tool, amqp_xchg),
    {ok, User} = application:get_env(rmq_tool, amqp_user),
    {ok, Pass} = application:get_env(rmq_tool, amqp_pass),
    
    #amqp_params_network{ 
        username = User,
        password = Pass,
        virtual_host = Xchg,
        host = Host,
        port = Port,
        heartbeat = 1
    }.