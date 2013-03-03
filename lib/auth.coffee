everyauth = require 'everyauth'


exports.requireLogin = (req, res, next) ->
  if not req.loggedIn
    rw = req.headers['x-requested-with']
    req.session.redirectTo = req.headers.referer or '/';
    return res.send(401) if rw is "XMLHttpRequest"
    return res.redirect '/login'
  next()

exports.requireAdmin = (req, res, next) ->
  rw = req.headers['x-requested-with']

  if not req.loggedIn
    req.session.redirectTo = req.headers.referer or '/';
    return res.send(401) if rw is "XMLHttpRequest"
    return res.redirect '/login'
  if not req.user.admin
    req.session.redirectTo = req.headers.referer or '/';
    return res.send(401) if rw is "XMLHttpRequest"
    return res.redirect '/'
  next()


exports.bootApp = (app) ->
  exports.bootEveryauth app
  app.gate =
    requireLogin: exports.requireLogin
    requireAdmin: exports.requireAdmin

exports.bootEveryauth = (app) =>
  everyauth.everymodule
    .handleLogout( (req, res) ->
      mpId = req.sessionID
      app.mixpanel.track 'Logout', distinct_id: mpId
      req.logout()
      @.redirect res, this.logoutRedirectPath()
    )
    .findUserById( (userId, callback) ->
      app.models.User.findById userId, callback
    )
    .performRedirect( (res, location) ->
      res.redirect(location, 303)
    )

  everyauth.password
    # Login
    .getLoginPath("/login")
    .postLoginPath("/login")
    .loginView("account/login")
    .loginLocals( (req, res) ->
      locals = res.locals
      for prop, val of app.locals
        locals[prop] = val
      locals
    )
    .loginWith("email")
    .authenticate((email, password) ->
      promise = @.Promise()
      return ["Please enter your .edu email"] if not email
      return ["Please enter your password"] if not password

      hashedPass = app.models.User.encryptPassword password
      app.models.User.findOne  email: email, hashPassword:  hashedPass, (err, user) ->
        return promise.fulfill([err]) if err
        return promise.fulfill(['Incorrect username or password.']) if user is null
        user.lastLogin = new Date()
        user.loginCount++
        user.save()
        promise.fulfill user
      promise
    )
    .respondToLoginSucceed( (res, user, data) ->
      if user
        # Log login session
        mpId = data.req.sessionID
        app.mixpanel.track 'Logged In', distinct_id: mpId
        data.req.session.mixpanelInjection = "
          mixpanel.name_tag('#{user.email}');
          mixpanel.identify('#{user.email}');
          mixpanel.people.set({'$email':'#{user.email}','$first_name':'#{user.firstName}','$last_name':'#{user.lastName}','$last_login':#{Date.now()}});
          mixpanel.people.increment({'login_count':1});
        ";
        # Redirect to home or wherever redirectTo is set to
      redirectTo = data?.session?.redirectTo or '/account'
      data.session.redirectTo = undefined
      @.redirect(res, redirectTo)
    )


    # Registration
    .getRegisterPath("/register")
    .postRegisterPath("/register")
    .registerView("account/register")
    .registerLocals( (req, res) ->
      locals = res.locals
      for prop, val of app.locals
        locals[prop] = val
      locals
    )
    .extractExtraRegistrationParams((req) ->
      email: req.body.email
      name:
        first: req.body.first_name
        last: req.body.last_name
      resume: req.files?.resume
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

      app.models.User.count $or: [ {email: newUserAttributes.email}, {_email: newUserAttributes.email}], (err, count) ->
        if count
          return promise.fulfill(["It appears that email has already been used. Did you forget your password?"])
        else
          user = new app.models.User
            firstName: newUserAttributes.name.first
            lastName: newUserAttributes.name.last
          user.setPassword newUserAttributes.password
          user.changeEmail newUserAttributes.email
          user.save (err) ->
            if err
              return promise.fulfill([err])
            promise.fulfill user
      promise
    )
    .respondToRegistrationSucceed( (res, user, data) ->

      # Log the registration
      mpId = data.req.sessionID
      app.mixpanel.track 'Registered', distinct_id: mpId
      data.req.session.mixpanelInjection = "
        mixpanel.name_tag('#{user.email}');
        mixpanel.identify('#{user.email}');
        mixpanel.people.set({'$email':'#{user.email}','$first_name':'#{user.firstName}','$last_name':'#{user.lastName}',$created: '#{new Date()}','$last_login':#{Date.now()}, login_count: 0});
        mixpanel.people.increment({'login_count':1});
      ";
      # Redirect
      redirectTo = data?.session?.redirectTo or '/account'
      data.session.redirectTo = undefined
      @.redirect(res, redirectTo)
    )





