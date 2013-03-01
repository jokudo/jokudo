exports = module.exports = (app) ->

  # Home
  app.get '/', (req, res) ->
    res.render 'index'

  app.get '/now', (req, res) ->
    res.json(req.online)

  app.get '/users-only', app.gate.requireLogin, (req, res) ->
    res.json("Welcome to the jungle")


