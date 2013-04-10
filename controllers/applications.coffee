exports = module.exports = (app) ->

  # Home
  app.get '/apps', app.gate.requireLoginToSee, (req, res) ->
    res.render 'applications/index'
    app.mixpanel.track 'ApplicationsView', distinct_id: req.sessionID

  app.get '/apps/:id', app.gate.requireLoginToSee, (req, res) ->
    application = ((req.user.applications || []).filter (a) ->
      return true if a.id is req.params.id)[0]
    if application isnt undefined
      res.render 'applications/index', application: application
    else
      app.send404(req, res)