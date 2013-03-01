crypto = require('ezcrypto').Crypto


exports = module.exports = (app) ->

  # Confirm Email
  app.get '/account/confirm_email/:userId/:hash', (req, res) ->
    app.models.User.findOne _id: req.params.userId, (err, user) ->
      if not user or err
        return res.render 'errors/confirm_wrong'
      if req.params.hash is crypto.SHA256(user.email).substring(3,30)
        user.confirmed = true
        user.save (err) ->
          res.redirect '/'
      else
        return res.render 'errors/confirm_wrong'

  app.get '/now', (req, res) ->
    res.json(req.online)

  app.get '/users-only', app.gate.requireLogin, (req, res) ->
    res.json("Welcome to the jungle")


