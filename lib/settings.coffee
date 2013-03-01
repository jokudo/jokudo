express     = require 'express'
everyauth   = require 'everyauth'
fs          = require 'fs'
url         = require 'url'
auth        = require './auth'
mpAPI       = require 'mixpanel'
onlineNow   = require './online-now'
redis       = require 'redis'
RedisStore  = require('connect-redis')(express)
helpers     = require './helpers'
MandrillAPI = require('mailchimp').MandrillAPI



exports.boot = (app) ->

  # Add the Mixpanel
  app.mixpanel  = new mpAPI.init app.config.MIXPANEL_ACCESS_TOKEN

  # Add mandrill
  app.mandrill = new MandrillAPI app.config.MANDRILL_KEY, version : '1.0', secure: false

  # Bootup authorization ( everyauth + our middleware )
  auth.bootApp app

  # Configuration method
  app.configure ()->
    app.set 'views', __dirname + '/../views'

    app.set 'view engine', 'ejs'

    app.use (req,res,next) ->
      res.header("X-powered-by", "Sharks")
      next()

    app.use express.bodyParser()

    app.use express.methodOverride()

    # Send down css in place of less
    app.use require('connect-less')(
      src: __dirname + '/../public/'
      compress: true
      yuicompress: true
    )

    # Compile our coffeescripts on the fly
    app.use require('./coffee-compile')(
      force: true
      src: __dirname + '/../public'
      streamOut: true
    )

    # Compress all transactions
    app.use express.compress()

    # Server static files
    app.use express.static __dirname + '/../public'

    # Set our cookie secret
    app.use express.cookieParser 'detta-är-en-hemlighet'

    # Create a redis connection based on our env settings
    redisURL     = url.parse(app.config.REDISCLOUD_URL)
    sessionStore = redis.createClient(redisURL.port, redisURL.hostname, no_ready_check: true)
    sessionStore.auth redisURL.auth?.split(":")[1]

    # Setup sessions using the Redis connection store
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

    # Helpers
    helpers.boot app

    # Bind in the everyauth middleware
    app.use everyauth.middleware(app)

    # Bind in our onlineNow user count middleware
    onlineNow app

    # Everyone loves favicons!
    app.use express.favicon()

    # And last but not least the routers
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


