user = process.env.PG_USER or 'transaction_test'
pass = process.env.PG_PASS or ''
host = process.env.PG_HOST or 'localhost'
port = process.env.PG_PORT or '5432'
db   = process.env.PG_DB   or 'transaction_test'

Config =

  # Postgres Url
  postgresUrl:  "postgres://#{user}:#{pass}@#{host}:#{port}/#{db}"

module.exports = Config
