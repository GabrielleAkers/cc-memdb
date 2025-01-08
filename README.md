# cc-memdb

remote memory caching for computercraft

inspired by memcached

uses ecnet2 for secure client/server communication

run the server first to get the server address then create a file in the client directory called `.memdb.client.config` like this
```
{
  server = "theaddressstring",
  client_id = "mysupersecretclientid"
}
```
clients that share a `client_id` will be able to share state
