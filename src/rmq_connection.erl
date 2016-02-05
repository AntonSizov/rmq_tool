-module(rmq_connection).
-behaviour(gen_server).

-export([
        start_link/0,
        get_channel/0
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
            connection,
            channel
}).



%% ===================================================================
%% APIs
%% ===================================================================

%% @doc starting module
-spec start_link() -> {ok, pid()}.
start_link() ->
   gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


%% @doc get current channel
-spec get_channel() -> pid().
get_channel() ->
    gen_server:call(?MODULE, get_channel).

%% ===================================================================
%% gen_server callbacks
%% ===================================================================

init([]) ->
    AmqpParams = get_default_amqp_params(),
    case amqp_connection:start(AmqpParams) of
        {ok, Connection} ->
            link(Connection),
            ?log_info("Connected to RabbitMQ", []),
            {ok, Channel} = amqp_connection:open_channel(Connection),
            link(Channel),
            {ok, #state{connection = Connection, channel = Channel}};
        {error, Reason} ->
            ?log_error("Can't connect to RabbitMQ: ~p", [Reason]),
            {stop, {cant_connect_rabbitmq, Reason}}
    end.


handle_cast(Request, State) ->
    {stop, {bad_arg, Request}, State}.

handle_info(Info, State) ->
    {stop, {bad_arg, Info}, State}.


handle_call(get_channel, _From, State) ->
    {reply, State#state.channel, State};

handle_call(_Request, _From, State) ->
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.


code_change(_OldSvn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Internal
%% ===================================================================

get_default_amqp_params() ->
    {ok, Host} = application:get_env(rmq_tool, host),
    {ok, VHost} = application:get_env(rmq_tool, virtual_host),
    {ok, Port} = application:get_env(rmq_tool, port),
    {ok, User} = application:get_env(rmq_tool, username),
    {ok, Pass} = application:get_env(rmq_tool, password),
    {ok, HeartBeat0} = application:get_env(rmq_tool, heartbeat),
    HeartBeat =
    case HeartBeat0 of
        true -> 1;
        false -> 0
    end,
    {ok, ConnTimeout} = application:get_env(rmq_tool, connection_timeout),

    ConnectArgs = [
        {host, Host},
        {virtual_host, VHost},
        {port, Port},
        {username, User},
        {password, Pass},
        {heartbeat, HeartBeat},
        {connection_timeout, ConnTimeout}
    ],
    ?log_info("Try to connect: ~p~n", [ConnectArgs]),

    #amqp_params_network{
        username = list_to_binary(User),
        password = list_to_binary(Pass),
        host = Host,
        virtual_host = VHost,
        port = Port,
        heartbeat = HeartBeat,
        connection_timeout = ConnTimeout
    }.
