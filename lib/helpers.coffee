exports.wrapper = (req) ->
  result = {}

  result.request = req

  result.loggedIn = !!(req.session?.auth?.loggedIn)

  result.messages = (require 'express-messages-bootstrap')(req);

  result.domain = process.env.DOMAIN;

  result.path = (req.url.split('/')||['',''])[1..];

  result.distinctId = req.sessionID

  result.user = req.user or req.session.user

  result.mixpanel = () ->
    [result, req.session.mixpanelInjection] = [req.session.mixpanelInjection, '']
    result

  result


exports.boot = module.exports.boot = (app) ->
  app.use (req, res, next) ->
    locals = exports.wrapper(req)
    for prop, val of locals
      res.locals[prop] = val
    next()

  app.locals.mp = app.mixpanel

  app.locals.app = app

  app.locals.numberize = (number) ->
    r = number[-1..0]
    if r is '1' then 'st' else if r is '2' then 'nd' else if r is '3' then 'rd' else 'th'