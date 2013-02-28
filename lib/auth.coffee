everyauth = require 'everyauth'


exports.bootEveryauth = (app) =>
  everyauth.everymodule.handleLogout (req, res) ->
    req.logout()
    @.redirect res, this.logoutRedirectPath()

  everyauth.everymodule.findUserById (userId, callback) ->
    app.models.User.findById userId, callback


  everyauth.password
    # Login
    .getLoginPath("/login")
    .postLoginPath("/login")
    .loginView("login")
    .loginWith("email")
    .authenticate((email, password) ->
      promise = @.Promise()
      return ["Please enter your .edu email"] if not email
      return ["Please enter your password"] if not password

      hashedPass = app.models.User.encryptPassword password
      app.models.User.findOne  email: email, hashPassword:  hashedPass, (err, user) ->
        return promise.fulfill([err]) if err
        return promise.fulfill(['Incorrect username or password.']) if user is null
        app.mixpanel.track 'Logged In', distinct_id: session.distinctId
        promise.fulfill user
      promise
    )
    .respondToLoginSucceed( (res, user, data) ->
      # Log new user creation
      if user then @.redirect(res, data.session.redirectTo)
    )


    # Registration
    .getRegisterPath("/register")
    .postRegisterPath("/register")
    .registerView("register")
    .extractExtraRegistrationParams((req) ->
      email: req.body.email
      name:
        first: req.body.first_name
        last: req.body.last_name
    )
    .validateRegistration((newUserAttributes) ->
      if not newUserAttributes.email or not newUserAttributes.email.match /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.edu$/i
        return ["You must use a valid .edu email"]
      if not newUserAttributes.name.first or not newUserAttributes.name.last
        return ["Please enter your first and last name"]
      if not newUserAttributes.password
        return ["You must enter a password"]
      if newUserAttributes.password.length < 6
        return ["Your password must be at least 6 characters"]
      null
    )
    .registerUser( (newUserAttributes) ->
      promise = @.Promise()
      user = new app.models.User email: newUserAttributes.email
      user.setPassword newUserAttributes.password
      user.save (err) ->
        if err
          if err.code is 11000 and err.err.match /email/
            return promise.fulfill(["It appears that email has already been used. Did you forget your password?"])
          return promise.fulfill([err])
        promise.fulfill user
      promise
    )
    .respondToRegistrationSucceed( (res, user, data) ->
      @.redirect(res, data.session.redirectTo)
    )
