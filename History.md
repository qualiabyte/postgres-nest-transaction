
# History

## 0.2.0 / 2014.02.01

+ Require pg version 1.0+, 2.0+, or higher
+ Deprecate the non-pooled API
  + Deprecate `new Transaction(client)`
  + Deprecate `pg.connect(url)`
+ Add API for pooled clients
  + Provide `new Transaction(client, done)`
  + Support `pg.connect(url, callback(err, client, done))`
+ Fix compatibility with latest pg versions
  + Remove calls to `pauseDrain()`, `resumeDrain()`
  + Release pooled clients by calling pg's `done()` method

## 0.1.0 / 2013.03.08

+ Initial version
+ Publish on npm as `pg-nest`
+ For use with pg versions below 1.0
