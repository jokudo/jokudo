exports = module.exports = (app) ->

  # Home
  app.get '/login-to-see-that', (req, res) ->
    res.render 'account/login-to-see'