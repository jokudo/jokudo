redis   = require 'redis'
url     = require 'url'
exports = module.exports = (app) ->

  redisURL  = url.parse(process.env.REDISCLOUD_URL)
  db        = redis.createClient(redisURL.port, redisURL.hostname, no_ready_check: true)
  db.auth redisURL.auth?.split(":")[1]

  app.use( (req, res, next) ->
    ua = req.sessionID
    db.zadd('online', Date.now(), ua, next)
  )

  app.use( (req, res, next) ->
    min = 60 * 1000;
    ago = Date.now() - min;
    db.zrevrangebyscore('online', '+inf', ago, (err, users) ->
      return next(err) if err
      req.online = users.length
      next()
    )
    db.zremrangebyscore 'online', '-inf', "(#{ago}", (err, users) -> return
  )
