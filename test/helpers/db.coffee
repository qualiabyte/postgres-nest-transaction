pg          = require 'pg'
should      = require 'should'
config      = require '../../test/config'
Characters  = require '../../test/fixtures/characters'
Queries     = require '../../test/fixtures/queries'
Transaction = require '../../transaction'

pgUrl = config.postgresUrl

class DB

  # Client helper provides a pooled pg client.
  @withClient: withClient = (callback) ->
    pg.connect pgUrl, (err, client, done) ->
      should.not.exist err
      should.exist client
      should.exist done
      return callback client, done

  # Init schema helper initializes transaction test tables.
  @initSchema: initSchema = (callback) ->
    withClient (client, done) ->
      query = """
        DROP TABLE IF EXISTS Characters;
        CREATE TABLE Characters (
          id      SERIAL UNIQUE,
          name    VARCHAR(20) PRIMARY KEY,
          species VARCHAR(20) NOT NULL,
          pet     VARCHAR(20) NULL REFERENCES Characters(name) INITIALLY DEFERRED,
          crush   VARCHAR(20) NULL REFERENCES Characters(name) INITIALLY DEFERRED
        );
        """
      client.query query, (err) ->
        should.not.exist err
        done()
        return callback()

  # Clear all helper resets the transaction test table.
  @clearAll: clearAll = (callback) ->
    withClient (client, done) ->
      query = """
        TRUNCATE Characters
        RESTART IDENTITY CASCADE;
        """
      client.query query, (err) ->
        should.not.exist err
        done()
        return callback()

  # Transaction helper provides a transaction.
  @withTransaction: withTransaction = (callback) ->
    withClient (client, done) ->
      t = new Transaction client, done
      return callback t

  # StartedTransaction helper provides a started transaction.
  @withStartedTransaction: withStartedTransaction = (callback) ->
    withTransaction (t) ->
      t.start (err) ->
        should.not.exist err
        return callback t

  # NestedTransaction helper provides a transaction and nested subtransaction.
  @withNestedTransaction: withNestedTransaction = (callback) ->
    withStartedTransaction (t1) ->
      t1.nest (err, t2) ->
        should.not.exist err
        return callback t1, t2

  # Character helper inserts a character on the given transaction.
  @withCharacter: withCharacter = (name, t, callback) ->
    char = Characters[name]()
    t.query Queries.insertCharacter(char.name, char.species), (err, res) ->
      should.not.exist err
      t.query Queries.selectCharacter(char.name), (err, res) ->
        should.not.exist err
        res.rows.length.should.equal 1
        res.rows[0].should.include {name: char.name, species: char.species}
        return callback()

module.exports = DB
