crypto = require('ezcrypto').Crypto


exports = module.exports = (app) ->


  app.get '/account', app.gate.requireLogin, (req, res) ->
    res.json req.user



  ##
  #
  # Email account confirmation
  #
  ##

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



  ##
  #
  # Forgot Password flow
  #
  ##


  # Forgot password form
  app.get '/account/forgot_password', (req, res) ->
    if req.loggedIn
      return res.redirect '/account'
    res.render 'account/forgot'

  # Forgot password submit
  app.post '/account/forgot_password', (req, res) ->
    if req.loggedIn
      return res.redirect '/account'
    app.models.User.findOne email: req.body.email, (err, user) ->
      if err or not user
        res.render 'account/forgot', {errors: ['That seems to be an unknown email, maybe you don\'t have an account']}
      else
        user.sendForgotPasswordEmail app.mandrill, app.redisDb
        res.redirect '/account/forgot_sent'

  # Forgot password submit
  app.get '/account/forgot_sent', (req, res) ->
    res.render 'account/forgot-sent'

  # Reset link from email
  app.get '/account/reset_password/:hash', (req, res) ->
    app.redisDb.get req.params.hash, (err, userId) ->
      if err or not userId
        return res.render 'errors/reset_wrong'
      app.models.User.findOne _id: userId, (err, user) ->
        if err or not user
          return res.render 'errors/reset_wrong'
        req.session.resetPasswordHash = req.params.hash
        res.render 'account/reset-password'

  # Reset form submit
  app.post '/account/reset_password', (req, res) ->
    hash = req.session.resetPasswordHash
    app.redisDb.get hash, (err, userId) ->
      if err or not userId
        return res.render 'errors/reset_wrong'
      if not req.body.password
        return res.render 'account/reset-password', errors: ['Invalid new password']
      if req.body.password isnt req.body.confirm_password
        return res.render 'account/reset-password', errors: ['Your new passwords do not match']
      if req.body.password.length < 6
        return res.render 'account/reset-password', errors: ['Your password must be at least 6 characters']
      app.models.User.findOne _id: userId, (err, user) ->
        if err or not user
          return res.render 'errors/reset_wrong'
        user.setPassword req.body.password
        req.session.resetPasswordHash = null
        app.redisDb.del hash
        user.save (err) ->
          # Login the user before redirecting
          user.lastLogin = new Date()
          user.loginCount++
          user.save()
          req.session.auth = userId: user.id, loggedIn: true;
          req.user = user;
          delete req.session.redirectTo;
          req.session.save();
          res.redirect '/account'
