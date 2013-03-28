exports = module.exports = (app) ->

  # Home
  app.get '/login-to-see-that', (req, res) ->
    console.log req.session
    res.render 'account/login-to-see'