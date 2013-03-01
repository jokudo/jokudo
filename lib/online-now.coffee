
exports = module.exports = (app) ->

  app.use( (req, res, next) ->
    ua = req.sessionID
    app.redisDb.zadd('online', Date.now(), ua, next)
  )

  app.use( (req, res, next) ->
    min = 60 * 1000;
    ago = Date.now() - min;
    app.redisDb.zrevrangebyscore('online', '+inf', ago, (err, users) ->
      return next(err) if err
      req.online = users.length
      next()
    )
    app.redisDb.zremrangebyscore 'online', '-inf', "(#{ago}", (err, users) -> return
  )
