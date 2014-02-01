
# postgres-nest-transaction

Nest transactions easily with PostgreSQL & Node.js. Designed for use with [pg][pg] on npm.
[pg]: https://github.com/brianc/node-postgres

## Install

```shell
$ npm install pg-nest
```

## Example

```coffee
pg          = require 'pg'
Transaction = require 'pg-nest'
url         = "postgres://user:password@localhost:5432/db"

# Retrieve a pooled client connection.
pg.connect url, (err, client, done) ->

  # Create a new transaction with the pooled pg client.
  t = new Transaction( client, done )

  # Start a new transaction with auto savepoint, and insert our hero!
  t.start (err) ->
    t.query "INSERT INTO Characters VALUES ('Finn', 'human')", (err) ->

      # Create a nested subtransaction with savepoint, and continue...
      t.nest (err, t2) ->
        t2.query "INSERT INTO Characters VALUES ('Ice King', 'wizard')", (err) ->

          # Wrong character! ~_~ Cancel the subtransaction to rollback.
          t2.cancel (err) ->

            # Commit our work on the parent transaction.
            t.finish (err) ->
              console.log 'Saved Finn!' unless err
```

## API Overview

<table>
<tr>
  <th colspan=2>Class: Transaction</th>
</tr>
<tr>
  <th colspan=2 align=left><a href="#constructor">Constructor</a></th>
</tr>
<tr>
  <td><code>new Transaction( client, done )</code></td>
  <td><i>Creates a new transaction, using a pooled pg client.</i></td>
</tr>
<tr>
  <th colspan=2 align=left><a href="#start">Start / Nest</a></th>
</tr>
<tr>
  <td><code>transaction.start(cb(err))</code></td>
  <td><i>Starts a new transaction, with auto savepoint</i></td>
</tr>
<tr>
  <td><code>transaction.nest(cb(err, nested))</code></td>
  <td><i>Starts a nested subtransaction, with auto savepoint.</i></td>
</tr>
<tr>
  <th colspan=2 align=left><a href="#query">Query</a></th>
</tr>
<tr>
  <td><code>transaction.query(args..., cb(err, result))</code></td>
  <td><i>Syntactic sugar for client.query().</i></td>
</tr>
<tr>
  <th colspan=2 align=left><a href="#restart">Restart / Cancel</a></th>
</tr>
<tr>
  <td><code>transaction.restart(cb(err))</code></td>
  <td><i>Restarts this transaction by rolling back to its savepoint.</i></td>
</tr>
<tr>
  <td><code>transaction.cancel(cb(err))</code></td>
  <td><i>Cancels this transaction, but allows any parents to continue.</i></td>
</tr>
<tr>
  <td><code>transaction.cancelAll(cb(err))</code></td>
  <td><i>Cancels both this transaction and all parents.</i></td>
</tr>
<tr>
  <th colspan=2 align=left><a href="#finish">Finish / Finalize</a></th>
</tr>
<tr>
  <td><code>transaction.finish(cb(err))</code></td>
  <td><i>Completes work on this transaction.</i></td>
</tr>
<tr>
  <td><code>transaction.finalize(lastErr, cb(err))</code></td>
  <td><i>Completes or cancels, depending on an error status.</i></td>
</tr>
</table>

## API

<a name="constructor"></a>

### new Transaction(client, done)

Creates a new transaction, using a pooled pg client.

```coffee
pg          = require 'pg'
Transaction = require 'pg-nest'

pg.connect url, (err, client, done) ->
  t = new Transaction( client, done )
```

Just pass the client instance and done() function
provided by pg.connect().  
When the transaction completes, it will automatically release the
client by calling done().  
See the [pg docs](https://github.com/brianc/node-postgres/wiki/pg) on
`pg.connect()` for details.

<a name="start"></a>

### start(callback(err))

Starts the new (or nested) transaction, with an auto savepoint.

```coffee
t = new Transaction client, done
t.start (err) ->
  t.query "SELECT * FROM Characters", (err, result) ->
    console.log result.rows
```

### nest(callback(err, nested))

Starts a nested subtransaction, with its own savepoint.

Since PostgreSQL lacks true subtransactions, this module simulates them with savepoints.

```coffee
t = new Transaction client, done
t.start (err) ->
  t.nest (err, t2) ->
    t2.query "SELECT * FROM Characters", (err, result) ->
      console.log result.rows
```

<a name="query"></a>

### query(text, callback(err, result))
### query(text, values, callback(err, result))
### query(config, callback(err, result))

Syntactic sugar for pg's client.query().

The pg module's client.query() is quite versatile, supporting
simple or parameterized queries, and prepared statements.

```coffee
query = "SELECT * FROM Characters"
t.query query, (err, result) ->
  console.log result.rows
```

See the [pg docs][pg-client] on `Client.query()` for details.
[pg-client]: https://github.com/brianc/node-postgres/wiki/Client

**Params**

+ `text` *String* The query text (for simple queries).
+ `values` *Array* An array of values (for parameterized queries).
+ `config` *Object* A configuration object (for parameterized queries or prepared statements).
+ `callback(err, result)` *Function* Called with the query result or error.

<a name="restart"></a>

### restart(callback(err))

Restarts this transaction by rolling back to its savepoint.  
When called on subtransactions, only the subtransaction is undone.

```coffee
# Start transaction
t.start (err) ->
  console.log "Started!"

  # Run queries...

  # Restart to rollback to savepoint
  t.restart (err) ->
    console.log "Restarted!"
```

### cancel(callback(err))

Cancels this transaction, but allows any parents to continue.

```coffee
t.cancel (err) ->
  console.log "Canceled this transaction."
```

### cancelAll(callback(err))

Cancels this transaction (and any parents) completely.

```coffee
t.cancelAll (err) ->
  console.log "Canceled this and parent transactions!"
```

<a name="finish"></a>

### finish(callback(err))

Completes work on this transaction.

This commits if called on a top-level transaction,
or just releases the savepoint if called on a subtransaction.

```coffee
t.finish (err) ->
  console.log "Committed the transaction" unless err
```

<a name="finalize"></a>

### finalize(lastErr, callback(err))

Finalizes (finish or cancel) this transaction depending on a final error.

Simply a convenience to replace branching calls to .cancel() or finish().  
Just give finalize() your last error, and it branches for you.

It propagates any error to the callback, including lastErr.

Instead of this:

```coffee
t.query "INSERT INTO Foo VALUES ('bar', 'baz');", (lastErr) ->
  if lastErr
    t.cancel (err) ->
      console.log 'error!'
      doLastThing()
  else
    t.finish (err) ->
      console.log 'done!'
      doLastThing()
```

You can write:

```coffee
t.query "INSERT INTO Foo VALUES ('bar', 'baz');", (lastErr) ->
  t.finalize lastErr, (err) ->
    console.log if err then 'error!' else 'done!'
    doLastThing()
```

**Params**

+ `lastErr` *Error* If present then .cancel(), otherwise .finish().
+ `callback(err)` *Function* Called on completion or error.


## License
MIT
