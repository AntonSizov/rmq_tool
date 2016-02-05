A command line tool that able to purge, delete, dump and restore RabbitMQ queues
using AMQP protocol.

### How to?

1. Download rmq_tool escript from releases page or build your own
2. Execute `./rmq_tool` to see help message like listed below

### Help output

```shell
Usage: rmq_tool [-h [<host>]] [-p [<port>]] [-H [<virtual_host>]]
                [-u [<username>]] [-p [<password>]] [-b [<heartbeat>]]
                [-t [<connection_timeout>]] [-v [<verbose>]] <command>
                [<command_args>]

  -h, --host
  -p, --port
  -H, --virtual_host
  -u, --username
  -p, --password
  -b, --heartbeat
  -t, --connect_timeout
  -v, --verbose
  command                purge, dump, restore, delete_queue
  command_args


	Available commands and its args description:

	Purge queue:
	rmq_tool purge <queue_name>

	Dupm all messages in queue:
	rmq_tool dump <queue_name>

	Dump N messages in queue:
	rmq_tool dump <queue_name> <N>

	Restore messages from queue dump by dump file name:
	rmq_tool restore <queue_name> <dump_file_name>

	Advanced messages restore:
	rmq_tool restore <queue_name> <dump_file_name> <offset>
	rmq_tool restore <queue_name> <dump_file_name> <offset> <count>

	Delete queue:
	rmq_tool delete_queue <queue_name>
```

### Build

Run `make` and you will get rmq_tool escript in project dirictory
There is an *Erlang* should be provided in PATH

```shell
git clone https://github.com/AntonSizov/rmq_tool.git && cd rmq_tool && make
```