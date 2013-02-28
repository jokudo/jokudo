express    = require 'express'
everyauth  = require 'everyauth'
fs         = require 'fs'
url        = require 'url'
auth       = require './auth'
mpAPI      = require 'mixpanel'
onlineNow  = require './online-now'
redis      = require 'redis'
RedisStore = require('connect-redis')(express)

exports.boot = (app) ->

  app.mixpanel  = new mpAPI.init app.config.MIXPANEL_ACCESS_TOKEN

  auth.bootEveryauth app

  app.configure ()->
    app.set 'views', __dirname + '/../views'

    app.set 'view engine', 'ejs'

    app.use express.bodyParser()

    app.use express.methodOverride()

    app.use (req,res,next) ->
      res.header("X-powered-by", "Sharks")
      next()

    app.use require('connect-less')(
      src: __dirname + '/../public/'
      compress: true
      yuicompress: true
    )

    app.use require('./coffee-compile')(
      force: true
      src: __dirname + '/../public'
      streamOut: true
    )

    app.use express.compress()

    app.use express.static __dirname + '/../public'

    app.use express.cookieParser 'detta-är-en-hemlighet'

    redisURL     = url.parse(process.env.REDISCLOUD_URL)
    sessionStore = redis.createClient(redisURL.port, redisURL.hostname, no_ready_check: true)
    sessionStore.auth redisURL.auth?.split(":")[1]

    app.use express.session(
      secret: '43894d20b39d6jokudo14533feec50'
      cookie:
        domain: app.config.DOMAIN
      domain: app.config.DOMAIN
      httpOnly: true
      # 5 days
      maxAge: 1000*60*60*24*5
      store: new RedisStore(client: sessionStore)
    )

    app.use everyauth.middleware(app)

    onlineNow app

    # Helpers
    (require '../lib/helpers').boot app

    app.use express.favicon()
    app.use app.router


  app.set 'showStackError', false
  app.configure 'development', ()->
    app.use express.errorHandler
      dumpExceptions: true
      showStack: true


  app.configure 'staging', ()->
    app.enable 'view cache'


  app.configure 'production', ()->
    app.enable 'view cache'


  try
    gitHead = fs.readFileSync(__dirname+'/../.git/refs/remotes/origin/master', 'utf-8').trim()
    app.set 'revision', gitHead
  catch e
    app.set 'revision', 'r'+(new Date()).getTime()


