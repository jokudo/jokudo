exports = module.exports = (app) ->

  # Home
  app.get '/', (req, res) ->
    res.render 'index'
    app.mixpanel.track 'HomeView', distinct_id: req.sessionID

  # About
  app.get '/about', (req, res) ->
    res.render 'about'
    app.mixpanel.track 'AboutView', distinct_id: req.sessionID

  app.get '/now', app.gate.requireAdmin, (req, res) ->
    res.json(req.online)