# cc-memdb

A distributed key/value caching system for computercraft inspired by [memcached](https://memcached.org/) that uses [ecnet2](https://github.com/migeyel/ecnet) for secure client/server communication

There is a terminal client `client.lua` and a programmatic client `api_client.lua`

To get started using it run the installer with

    wget run https://raw.githubusercontent.com/GabrielleAkers/cc-memdb/refs/heads/main/install.lua
    cd memdb

then run `server.lua` and take note of the address that prints in the terminal. dont forget to set the server chunk to forceload

to setup clients do the same steps as above and also create a file in the `memdb` directory called `.memdb.client.config` like this


    {
      server = "theaddressstring",
      client_id = "mysupersecretclientid"
    }

fill in the server address you noted down and come up with a client id. clients that share a client id will be able to share state.

when setting up the computers that will run both the server and client make sure to attach the modem to the top -- although this could be changed in the `client.lua` and `server.lua` files respectively.

example terminal client usage:

with the server running start the client and use it like this to `set/get` data:


    memdb> client
    memdb connection established
    set name 'Gabby'
    get name
    VALUE "Gabby"
    del name
    get name
    ERROR path does not exist

both `set` and `get` also support paths instead of plain keys


    set c {d=1}
    get c
    VALUE {
      d = 1,
    }
    set c.d 2
    get c.d
    VALUE 2

you can also `set` an expiration time on the data like this


    set temp_val {a=1} 10
    get temp_val
    VALUE {
      a = 1,
    }


the number after the key and value is the lifetime, in this case 10 seconds. so 10 seconds later you might try

    get temp_val
    ERROR path does not exist

the value has been forgotten. if you dont pass a lifetime or set it to 0 then it will be infinite. if the lifetime exceeds 30 days then it's treated as the number of seconds since the epoch so you can set an exact expiration date and time for long lived values.

using `get_id` you can get a unique identifier for the path you give it

    set a 'someval'
    get_id a
    VALUE "954352a765d1012e6f52a7413dad44caaaaa18ff3e9074c50118638937a1bf90"

you can use this id with the `safe_set` command to only set the new value if the id wasnt changed -- like by another client messing with the data at the same path in between you setting it the first time and now

    set a 'some other val'
    get a
    VALUE "some other val"
    safe_set a 7 954352a765d1012e6f52a7413dad44caaaaa18ff3e9074c50118638937a1bf90
    get a
    VALUE "some other val"

you can also do things like `append/prepend` to lists:


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


or `incr/decr` numbers:


    set mynumber 6
    get mynumber
    VALUE 6
    incr mynumber 2.2
    get mynumber
    VALUE 8.2
    decr mynumber 1.5
    get mynumber
    VALUE 6.7


to view a list of all available commands use `list_cmd` and you can get help with a command using `help <command>`
