exports = module.exports = (app) ->

  # Home
  app.get '/admin', app.gate.requireAdmin, (req, res) ->
    res.render 'admin/index';

  app.get '/admin/users', app.gate.requireAdmin, (req, res) ->
    app.models.User.find({}).sort({created: -1}).exec (err, users) ->
      res.render 'admin/users', users: users


  app.get '/admin/users/:id', app.gate.requireAdmin, (req, res) ->
    app.models.User.findById req.params.id, (err, user) ->
      return res.send(404) if not user?.resume?.bin
      thisYear = (new Date()).getFullYear()
      yearSet  = [thisYear-20..thisYear+8]
      app.models.School.find {}, (err, schools) ->
        res.render 'account/account', schools: schools, yearSet: yearSet, user: user

  app.get '/admin/users/:id/resume/:name.:format?', app.gate.requireAdmin, (req, res) ->
    app.models.User.findById req.params.id, (err, user) ->
      return res.send(404) if not user?.resume?.bin
      res.setHeader('Content-Length', user.resume.bin.length);
      res.setHeader('Content-type', user.resume.mime);
      res.write(user.resume.bin, 'binary');
      res.end()


  app.get '/admin/users/set-school-by-email', app.gate.requireAdmin, (req, res) ->
    app.models.User.find {}, (err, users) ->
      res.send 500 if err
      res.send 404 if not users
      setSchool(user) for user in users
      res.json 'ok'


  setSchool = (user) ->
    schoolEmailUrl = user.email.match /@(:?[a-zA-Z0-9-]+\.)?([a-zA-Z0-9-]+\.edu)/
    app.models.School.findOne email: schoolEmailUrl[2], (err, school) ->
      if school
        user.school = school
        user._school = school.name
        user.save()