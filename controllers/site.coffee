exports = module.exports = (app) ->

  # Home
  app.get '/', (req, res) ->
    res.render 'index'

  app.get '/now', app.gate.requireAdmin, (req, res) ->
    res.json(req.online)