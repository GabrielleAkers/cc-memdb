# cc-memdb

remote key/value caching for computercraft

inspired by [memcached](https://memcached.org/)

uses ecnet2 for secure client/server communication

run the server first to get the server address then create a file in the client directory called `.memdb.client.config` like this
```
{
  server = "theaddressstring",
  client_id = "mysupersecretclientid"
}
```
clients that share a `client_id` will be able to share state

example usage:
with the server running start the client and use it like this to `set/get` data:
```
memdb> client
memdb connection established
set name 'Gabby'
get name
VALUE "Gabby"
del name
get name
ERROR path does not exist
```

you can also `set` an expiration time on the data like this
```
set temp_val {a=1} 10
get temp_val
VALUE {
  a = 1,
}
```
the number after the key and value is the lifetime, in this case 10 seconds. so 10 seconds later you might try
```
get temp_val
ERROR path does not exist
```
the value has been forgotten. if you dont pass a lifetime or set it to 0 then it will be infinite. if the lifetime exceeds 30 days then it's treated as the number of seconds since the epoch so you can set an exact expiration date and time for long lived values.

you can also do things like `append/prepend` to lists:
```
set mylist {1}
get mylist
VALUE {
  1,
}
append mylist 2
get mylist
VALUE {
  1,
  2
}
prepend mylist 'this one has spaces'
get mylist
VALUE {
  "this one has spaces",
  1,
  2
}
```

or `incr/decr` numbers:
```
set mynumber 6
get mynumber
VALUE 6
incr mynumber 2.2
get mynumber
VALUE 8.2
decr mynumber 1.5
get mynumber
VALUE 6.7
```

to view a list of all available commands use `list_cmd` and you can get help with a command using `help <command>`
