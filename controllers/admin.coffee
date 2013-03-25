exports = module.exports = (app) ->

  # Home
  app.get '/admin', app.gate.requireAdmin, (req, res) ->
    res.render 'admin/index';

  app.get '/admin/users', app.gate.requireAdmin, (req, res) ->
    app.models.User.find({}).sort({created: -1}).exec (err, users) ->
      res.render 'admin/users', users: users


  app.get '/admin/users/:id/resume/:name.:format?', app.gate.requireAdmin, (req, res) ->
    app.models.User.findById req.params.id, (err, user) ->
      return res.send(404) if not user?.resume?.bin
      res.setHeader('Content-Length', user.resume.bin.length);
      res.setHeader('Content-type', user.resume.mime);
      res.write(user.resume.bin, 'binary');
      res.end()


  setSchool = (user) ->
    schoolEmailUrl = user.email.match /@(:?[a-zA-Z0-9-]+\.)?([a-zA-Z0-9-]+\.edu)/
    app.models.School.findOne email: schoolEmailUrl[2], (err, school) ->
      if school
        user.school = school
        user._school = school.name
        user.save()