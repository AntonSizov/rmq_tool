This app is a simple tool that able to manage RabbitMQ when [rabbitmq-management plugin] is not available.

[rabbitmq-management plugin]: http://www.rabbitmq.com/management.html

### Features
- purge queue
- delete queue
- dump queue
- restore queue dump

### Installation and launching

``` shell
git clone https://github.com/AntonSizov/rmq_tool.git
cd ./rmq_tool
make && make console
```

To veiw help, type in Erlang shell:

``` erlang
(rmq_tool@127.0.0.1)1> rmq_tool:help().
Purge queue:
rmq_tool:purge(<<"pmm.mmwl.response.sms">>).

Dupm all messages in queue:
rmq_tool:dump(<<"pmm.mmwl.response.sms">>).

Dump 1000 messages in queue:
rmq_tool:dump(<<"pmm.mmwl.response.sms">>, 1000).

List available dumps:
rmq_tool:list_dumps().

Inject all messages into queue:
rmq_tool:inject(<<"pmm.mmwl.response.sms">>, 1) %% 1 is the number of the dump from list_dump listing
rmq_tool:inject(<<"pmm.mmwl.response.sms">>, "pmm.mmwl.response.sms_20121022_17184.qdump")

Advanced inject messages into queue:
rmq_tool:inject(QueueName, FileName, Offset)
rmq_tool:inject(QueueName, FileName, Offset, Count)

Delete queue:
rmq_tool:delete_queue(<<"queue_name">>).
ok
(rmq_tool@127.0.0.1)2>
```