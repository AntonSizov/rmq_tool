-module(rmq_tool).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("logging.hrl").

-export([
    main/1
]).

-export([
	% aliases from dump
	dump/3,
	dump/2,
	dump/1,

	% aliases from inject
	inject/2,
	inject/3,
	inject/4,

	purge/1,
	delete_queue/1,
	list_dumps/0,
	help/0
]).


-define(OptSpecList, [
        {host,               $h, "host",            {string, "localhost"}, ""},
        {port,               $p, "port",            {integer, 5672},       ""},
        {virtual_host,       $H, "virtual_host",    {string, "/"},         ""},
        {username,           $u, "username",        {string, "guest"},     ""},
        {password,           $p, "password",        {string, "guest"},     ""},
        {heartbeat,          $b, "heartbeat",       {boolean, false},      ""},
        {connection_timeout, $t, "connect_timeout", {integer, 5000},       ""}
    ]).

%% ===================================================================
%% APIs
%% ===================================================================

-spec main([list()]) -> ignore.
main(Args) ->
    {ok, {Props, CmdAndArgs}} = getopt:parse(?OptSpecList, Args),
    main(Props, CmdAndArgs).

main(Props, ["purge", QueueName]) ->
    start_all(Props),
	purge(list_to_binary(QueueName)),
    halt(0);
main(Props, ["dump", QueueName]) ->
    start_all(Props),
	dump(list_to_binary(QueueName)),
    halt(0);
main(Props, ["dump", QueueName, N]) ->
    start_all(Props),
    dump(list_to_binary(QueueName), list_to_integer(N)),
    halt(0);
main(_Props, ["list_dumps"]) ->
    list_dumps(),
    halt(0);
main(Props, ["restore", QueueName0, DumpIdOrFileName]) ->
    start_all(Props),
    QueueName = list_to_binary(QueueName0),
    try list_to_integer(DumpIdOrFileName) of
        DumpId ->
	        inject(QueueName, DumpId)
    catch _:_ ->
	    inject(QueueName, list_to_binary(DumpIdOrFileName))
    end,
    halt(0);
main(Props, ["restore", QueueName, DumpFileName, Offset]) ->
    start_all(Props),
	inject(list_to_binary(QueueName), list_to_binary(DumpFileName), list_to_integer(Offset)),
    halt(0);
main(Props, ["restore", QueueName, DumpFileName, Offset, Count]) ->
    start_all(Props),
	inject(list_to_binary(QueueName), list_to_binary(DumpFileName), list_to_integer(Offset), list_to_integer(Count)),
    halt(0);
main(Props, ["delete_queue", QueueName]) ->
    start_all(Props),
	delete_queue(list_to_binary(QueueName)),
    halt(0);
main(_Props, _) ->
    MainOptionsDescr = [
        {"command", "purge, dump, list_dumps, restore, delete_queue"},
        {"command_args", ""}
    ],
    getopt:usage(?OptSpecList, "rmq_tool", "<command> [<command_args>]", MainOptionsDescr),

    AvailableCmdsHelpMsg =
    "~n"
    "\tAvailable commands and its args description:~n~n"

    "\tPurge queue:~n"
    "\trmq_tool purge <queue_name>~n~n"

    "\tDupm all messages in queue: ~n"
    "\trmq_tool dump <queue_name>~n~n"

    "\tDump N messages in queue: ~n"
    "\trmq_tool dump <queue_name> <N>~n~n"

    "\tList available dumps: ~n"
    "\trmq_tool list_dumps~n~n"

    "\tRestore messages from queue dump by dump id: ~n"
    "\trmq_tool restore <queue_name> <dump_id>~n~n"

    "\tRestore messages from queue dump by dump file name: ~n"
    "\trmq_tool restore <queue_name> <dump_file_name>~n~n"

    "\tAdvanced messages restore: ~n"
    "\trmq_tool restore <queue_name> <dump_file_name> <offset>~n"
    "\trmq_tool restore <queue_name> <dump_file_name> <offset> <count>~n~n"

    "\tDelete queue: ~n"
    "\trmq_tool delete_queue <queue_name>~n",

    io:format(standard_error, AvailableCmdsHelpMsg, []).


-spec delete_queue(binary()) -> ok.
delete_queue(QueueName) when is_binary(QueueName) ->
	Channel = rmq_connection:get_channel(),
	try
		Delete = #'queue.delete'{queue = QueueName},
		#'queue.delete_ok'{} = amqp_channel:call(Channel, Delete),
		?log_info("Successfully deleted", [])
	catch
		Class:Error -> ?log_error("Delete error ~p:~p", [Class,Error])
	end.


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
inject(QueueName, DumpNumber) when is_integer(DumpNumber) ->
	{ok, Dumps} = get_dump_list(),
	FileName = lists:nth(DumpNumber, Dumps),
	inject(QueueName, FileName);
inject(QueueName, FileName) ->
	rmq_inject:inject(QueueName, FileName).


%% @doc injecting queue with all data taken from a file. Skipping a couple of starting messages
-spec inject(QueueName :: binary(), FileName :: string(), Offset :: integer()) -> ok.
inject(QueueName, DumpNumber, Offset) when is_integer(DumpNumber) ->
	{ok, Dumps} = get_dump_list(),
	FileName = lists:nth(DumpNumber, Dumps),
	inject(QueueName, FileName, Offset);
inject(QueueName, FileName, Offset) ->
	rmq_inject:inject(QueueName, FileName, Offset).


%% @doc injecting queue with all data taken from a file. Skipping a couple of starting messages and limits amount
-spec inject(QueueName :: binary(), FileName :: string(), Offset :: integer(), Count :: integer()) -> ok.
inject(QueueName, FileName, Offset, Count) ->
	rmq_inject:inject(QueueName, FileName, Offset, Count).

%% @doc List all available dump files
-spec list_dumps() -> ok.
list_dumps() ->
	{ok, Dumps} = get_dump_list(),
	Print = fun(N) ->
		Name = lists:nth(N, Dumps),
		io:format("~p: ~p~n", [N, Name])
	end,
	lists:foreach(Print, lists:seq(1, length(Dumps))).

get_dump_list() ->
	RawList = os:cmd("ls ./dumps"),
	ListOfDumps = string:tokens(RawList, "\n"),
	{ok, ListOfDumps}.

%% @doc Print help info
-spec help() -> ok.
help() ->
	io:format(
	"Purge queue: ~n"
	"rmq_tool:purge(<<\"pmm.mmwl.response.sms\">>).~n~n"

	"Dupm all messages in queue: ~n"
	"rmq_tool:dump(<<\"pmm.mmwl.response.sms\">>).~n~n"

	"Dump 1000 messages in queue: ~n"
	"rmq_tool:dump(<<\"pmm.mmwl.response.sms\">>, 1000).~n~n"

	"List available dumps: ~n"
	"rmq_tool:list_dumps().~n~n"

	"Inject all messages into queue: ~n"
	"rmq_tool:inject(<<\"pmm.mmwl.response.sms\">>, 1) %% 1 is the number of the dump from list_dump listing~n"
	"rmq_tool:inject(<<\"pmm.mmwl.response.sms\">>, \"pmm.mmwl.response.sms_20121022_17184.qdump\")~n~n"

	"Advanced inject messages into queue: ~n"
	"rmq_tool:inject(QueueName, FileName, Offset)~n"
	"rmq_tool:inject(QueueName, FileName, Offset, Count)~n~n"

	"Delete queue: ~n"
	"rmq_tool:delete_queue(<<\"queue_name\">>).~n"
	).


start_all(Props) ->
    PropNameList = [
        host,
        port,
        virtual_host,
        username,
        password,
        heartbeat,
        connection_timeout
    ],

    [ok = application:set_env(?MODULE, K, proplists:get_value(K, Props)) ||
        K <- PropNameList],
    ok = application:start(amqp_client),
    ok = application:start(?MODULE).
