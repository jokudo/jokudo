exports = module.exports = (app) ->

  # Home
  app.get '/', (req, res) ->
    res.render 'index'

  # About
  app.get '/about', (req, res) ->
    res.render 'about'

  app.get '/now', app.gate.requireAdmin, (req, res) ->
    res.json(req.online)