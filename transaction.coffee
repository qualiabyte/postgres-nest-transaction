
#
# Transaction provides nested anonymous transactions for PostgreSQL.
# Designed for use with the 'pg' module on npm.
#
class Transaction

  # Debug mode.
  @DEBUG: false

  # Creates a new Transaction, using a pooled pg client.
  #
  # Example:
  #
  #     pg          = require 'pg'
  #     Transaction = require 'pg-nest'
  #     url         = "postgres://user:password@localhost:5432/db"
  #
  #     pg.connect url, (err, client, done) ->
  #       return callback err if err
  #
  #       t = new Transaction( client, done )
  #       t.start (err) ->
  #         t.query "SELECT * FROM Characters", (err, result) ->
  #           console.log result.rows
  #
  # @api public
  # @param [pg.Client] client To use for this transaction.
  # @param [Transaction] parent An optional parent (for subtransactions).
  # @param [Function] done Releases the pooled client. See `pg.connect()`
  # @return [Transaction] The new instance.
  constructor: (@client, @parent=null, @done=null) ->
    if arguments.length is 2 and typeof @parent is 'function'
      @done = arguments[1]
      @parent = null

  # Prints the given arguments when in debug mode.
  # @api private
  debug: (args...) ->
    console.log args... if Transaction.DEBUG

  # Starts the new (or nested) transaction, with an auto savepoint.
  #
  #     t = new Transaction client, done
  #     t.start (err) ->
  #       t.query "SELECT * FROM Characters", (err, result) ->
  #         console.log result.rows
  #
  # @api public
  # @param [Function] callback(err)
  start: (callback) ->
    @savepoint = @genSavepoint()
    if @parent?
    then @query "SAVEPOINT \"#{@savepoint}\";", callback
    else @query "BEGIN; SAVEPOINT \"#{@savepoint}\";", callback

  # Starts a nested subtransaction, with its own savepoint.
  # 
  # Since PostgreSQL lacks true subtransactions, this module simulates
  # them with savepoints.
  #
  # @api public
  # @param [Function] callback(err, nested)
  # @param [Transaction] nested The nested subtransaction.
  nest: (callback) ->
    nested = new Transaction @client, @
    nested.start (err) ->
      callback err, nested

  # Syntactic sugar for pg's client.query().
  #
  # The pg module's client.query() is quite versatile, supporting
  # simple or parameterized queries, and prepared statements.
  #
  #     query = "SELECT * FROM Characters"
  #     t.query query, (err, results) ->
  #       console.log results.rows
  #
  # See the [pg docs][pg-client] for details.
  #
  # @api public
  # @see pg.Client.query()
  # [pg-client]: https://github.com/brianc/node-postgres/wiki/Client
  query: (args..., callback) ->
    @debug "#{ args[0].text ? args }\n" if Transaction.DEBUG
    @client.query arguments...

  # Generates a unique savepoint name.
  #
  #     savepoint = t.genSavepoint()
  #
  # @api private
  # @return [String] A savepoint based on a timestamp and random id.
  genSavepoint: () ->
    chars = '0123456789abcdef'
    uidChars = []
    uidChars[i] = chars[Math.floor Math.random() * 16] for i in [1..32]
    uid = uidChars.join ''
    timestamp = (new Date()).toISOString()
    return timestamp + '_' + uid

  # Restarts this transaction by rolling back to its savepoint.  
  # When called on subtransactions, only the subtransaction is undone.
  #
  #     # Start transaction
  #     t.start (err) ->
  #       console.log "Started!"
  #
  #       # Run queries...
  #
  #       # Restart to rollback to savepoint
  #       t.restart (err) ->
  #         console.log "Restarted!"
  #
  # @api public
  # @param [Function] callback(err)
  restart: (callback) ->
    @rollbackToSavepoint callback

  # Rolls back to the savepoint for this transaction.
  #
  # @api private
  # @param [Function] callback(err)
  rollbackToSavepoint: (callback) ->
    @query "ROLLBACK TO SAVEPOINT \"#{@savepoint}\";", callback

  # Releases the savepoint for this transaction.
  #
  # @api private
  # @param [Function] callback(err)
  releaseSavepoint: (callback) ->
    @query "RELEASE SAVEPOINT \"#{@savepoint}\";", callback

  # Rolls back to savepoint and releases it.
  #
  # @api private
  # @param [Function] callback(err)
  rollbackToAndRelease: (callback) ->
    query = """
      ROLLBACK TO SAVEPOINT \"#{@savepoint}\";
      RELEASE SAVEPOINT \"#{@savepoint}\";
      """
    @query query, callback

  # Cancels this transaction, but allows any parents to continue.
  #
  #     t.cancel (err) ->
  #       console.log "Canceled this transaction."
  #
  # @api public
  # @param [Function] callback(err)
  cancel: (callback) ->
    if @parent?
    then @rollbackToAndRelease callback
    else @cancelAll callback

  # Cancels this transaction (and any parents) completely.
  #
  #     t.cancelAll (err) ->
  #       console.log "Canceled this and parent transactions!"
  #
  # @api public
  # @param [Function] callback(err)
  cancelAll: (callback) ->
    @query("ROLLBACK", callback); @done?()

  # Completes work on this transaction.
  #
  # This commits if called on a top-level transaction,
  # or just releases the savepoint if called on a sub-transaction.
  #
  #     t.finish (err) ->
  #       console.log "Committed the transaction" unless err
  #
  # @api public
  # @param [Function] callback(err)
  finish: (callback) ->
    if @parent?
    then @releaseSavepoint callback
    else @query("COMMIT", callback); @done?()

  # Finalizes (finish or cancel) this transaction depending on a final error.
  # 
  # Simply a convenience to replace branching calls to .cancel() or finish().  
  # Just give finalize() your last error, and it branches for you.
  #
  # It propagates any error to the callback, including lastErr.
  #
  # Instead of this:
  #
  #     t.query "INSERT INTO Foo VALUES ('bar', 'baz');", (lastErr) ->
  #       if lastErr
  #         t.cancel (err) ->
  #           console.log 'error!'
  #           doLastThing()
  #       else
  #         t.finish (err) ->
  #           console.log 'done!'
  #           doLastThing()
  #
  # You can write:
  #
  #     t.query "INSERT INTO Foo VALUES ('bar', 'baz');", (lastErr) ->
  #       t.finalize lastErr, (err) ->
  #         console.log if err then 'error!' else 'done!'
  #         doLastThing()
  #
  # @api public
  # @param [Error] lastErr If present then .cancel(), otherwise .finish().
  # @param [Function] callback(err)
  finalize: (lastErr, callback) ->
    if lastErr
    then @cancel (err) -> callback(lastErr)
    else @finish (err) -> callback(err)

module.exports = Transaction
