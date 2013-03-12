exports = module.exports = (app) ->

  # Home
  app.get '/jobs', (req, res) ->
    res.render 'jobs/index'