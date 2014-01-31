should        = require 'should'
Transaction   = require '../transaction'
DB            = require '../test/helpers/db'
Characters    = require '../test/fixtures/characters'
Queries       = require '../test/fixtures/queries'

describe 'Transaction', ->

  { initSchema, clearAll, withCharacter, withClient,
    withTransaction, withStartedTransaction, withNestedTransaction } = DB

  before (done) ->
    initSchema done

  beforeEach (done) ->
    clearAll done

  describe 'new Transaction( client )', ->
    it 'should create a new transaction', (done) ->
      withClient (client, done2) ->
        t = new Transaction client, done2
        t.should.be.an.instanceof Transaction
        t.client.should.equal client
        should.not.exist t.parent
        done()

  describe 'new Transaction( client, parent )', ->
    it 'should create a new nested transaction', (done) ->
      withClient (client, done2) ->
        t1 = new Transaction client, done2
        t2 = new Transaction client, t1, done2
        t2.parent.should.equal t1
        t2.client.should.equal t1.client
        done()

  describe 'transaction.start()', ->
    it 'should start a new transaction', (done) ->
      withClient (client, done2) ->
        t = new Transaction client, done2
        t.start (err) ->
          should.not.exist err
          done()

    it 'should start a new nested transaction', (done) ->
      withStartedTransaction (t1) ->
        t2 = new Transaction t1.client, t1, t1.done
        t2.start (err) ->
          should.not.exist err
          done()

  describe 'transaction.nest( callback(err, nested) )', ->
    it 'should start a nested subtransaction', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.finish (err) ->
            should.not.exist err
            done()

    it 'should complete a nested subtransaction', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.nest (er1, t2) ->
            withCharacter 'Jake', t2, ->
              t2.cancel (er2) ->
                t.query "SELECT * FROM Characters", (er3, result) ->
                  [er1, er2, er3].should.eql [1..3].map -> null
                  result.rows.length.should.equal 1
                  result.rows[0].name.should.equal 'Finn'
                  t.finish (err) ->
                    should.not.exist err
                    done()

  describe 'transaction.query( query, callback )', ->
    it 'should delegate to client.query()', (done) ->
      withStartedTransaction (t) ->
        t.query Queries.insertCharacter('Finn', 'human'), (err, res) ->
          should.not.exist err
          t.query Queries.selectCharacter('Finn'), (err, res) ->
            should.not.exist err
            res.rows.length.should.equal 1
            row = res.rows[0]
            row.should.include name: 'Finn', species: 'human'
            t.finish (err) ->
              should.not.exist err
              done()

    it 'should also delegate to client.query() when nested', (done) ->
      withNestedTransaction (t1, t2) ->
        t2.query Queries.insertCharacter('Finn', 'human'), (err, res) ->
          should.not.exist err
          t2.query Queries.selectCharacter('Finn'), (err, res) ->
            should.not.exist err
            res.rows.length.should.equal 1
            row = res.rows[0]
            row.should.include name: 'Finn', species: 'human'
            t2.cancel (err) ->
              t1.cancel (err) ->
                done()

  describe 'transaction.cancel()', ->
    it 'should cancel the current transaction', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.cancel (er1) ->
            t.query Queries.selectCharacter('Finn'), (er2, res) ->
              should.not.exist e for e in [er1, er2]
              res.rows.length.should.equal 0, "Insertion should be canceled."
              done()

    it 'should not cancel the parent when nested', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.nest (er1, t2) ->
            withCharacter 'Jake', t2, ->
              t2.cancel (er2) ->
                t.query "SELECT * FROM Characters", (err, res) ->
                  res.rows.length.should.equal 1
                  res.rows[0].name.should.equal 'Finn'
                  t.finish (err) ->
                    should.not.exist err
                    done()

  describe 'transaction.restart()', ->
    it 'should restart by rolling back to savepoint', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.restart (er1) ->
            t.query Queries.selectCharacter('Finn'), (er2, res) ->
              should.not.exist e for e in [er1, er2]
              res.rows.length.should.equal 0, "Character should be rolled back."
              t.finish (err) ->
                done()

    it 'should callback with error if transaction already finished', (done) ->
      withStartedTransaction (t) ->
        t.finish (er1) ->
          should.not.exist er1, "Transaction should finish without error."
          t.restart (er2) ->
            should.exist er2, "Restarting a finished transaction should error."
            done()

    it 'should restart only the subtransaction when nested', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.nest (err, t2) ->
            withCharacter 'Jake', t2, ->
              t2.restart (err) ->
                should.not.exist err
                withCharacter 'Rainicorn', t2, ->
                  t2.finish (err) ->
                    should.not.exist err
                    t.query "SELECT * From Characters ORDER BY name", (err, result) ->
                      should.not.exist err
                      result.rows.length.should.equal 2
                      result.rows[0].name.should.equal 'Finn'
                      result.rows[1].name.should.equal 'Rainicorn'
                      t.finish (err) ->
                        should.not.exist err
                        done()

  describe 'transaction.finish()', ->
    it 'should commit an unnested transaction', (done) ->
      withStartedTransaction (t) ->
        t.query Queries.insertCharacter('Finn', 'human'), (er1, res) ->
          t.query Queries.selectCharacter('Finn'), (er2, res) ->
            res.rows[0].should.include name: 'Finn', species: 'human'
            t.finish (er3) ->
              t.restart (er4) ->
                should.exist er4, "Restarting a finished transaction should error."
                t.query Queries.selectCharacter('Finn'), (er5, res) ->
                  should.not.exist e for e in [er1, er2, er3, er5]
                  res.rows[0].should.include name: 'Finn', species: 'human'
                  done()

    it 'does callback without error if transaction already canceled', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.cancel (err) ->
            should.not.exist err
            t.finish (err) ->
              should.throws -> should.exist err
              done()

  describe 'transaction.finalize( lastErr, callback(err) )', ->
    it 'should commit if lastErr is null', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.finalize null, (err) ->
            should.not.exist err
            withClient (client, done2) ->
              client.query "SELECT * FROM Characters", (err, result) ->
                should.not.exist err
                result.rows.length.should.equal 1
                result.rows[0].name.should.equal 'Finn'
                done2()
                done()

    it 'should rollback and propagate lastErr if not null', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          lastErr = new Error("Dummy error.")
          t.finalize lastErr, (err) ->
            should.exist err
            withClient (client, done2) ->
              client.query "SELECT * FROM Characters", (err, result) ->
                should.not.exist err
                result.rows.length.should.equal 0
                done2()
                done()

    it 'does callback without error if commit already cancelled', (done) ->
      withStartedTransaction (t) ->
        withCharacter 'Finn', t, ->
          t.cancel (err) ->
            should.not.exist err
            lastErr = null
            t.finalize lastErr, (err) ->
              should.throws -> should.exist err
              withClient (client, done2) ->
                client.query "SELECT * FROM Characters", (err, result) ->
                  should.not.exist err
                  result.rows.length.should.equal 0
                  done2()
                  done()
