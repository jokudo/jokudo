fs = require 'fs'



exports = module.exports = (app) ->

  # Home
  app.get '/admin', app.gate.requireAdmin, (req, res) ->
    res.render 'admin/index';

  app.get '/admin/users', app.gate.requireAdmin, (req, res) ->
    app.models.User.find({}).sort({_id: 1}).exec (err, users) ->
      res.render 'admin/users', users: users

  app.get '/admin/users/set-school-by-email', app.gate.requireAdmin, (req, res) ->
    app.models.User.find {}, (err, users) ->
      res.send 500 if err
      res.send 404 if not users
      setSchool(user) for user in users
      res.json 'ok'

  app.get '/admin/move-resumes-to-aws', app.gate.requireAdmin, (req, res) ->
    emitter = new (require('events').EventEmitter)
    app.models.User.find {'resume.bin': {$exists: true}, 'resume.mime': {$exists: true}}, (err, users) ->
      uploadUserResume = (i) ->
          if not users[i]
            return res.send 200
          else
            user = users[i]
          if user.resume.bin.length < 1
            return uploadUserResume(i+1)
          resume =
            type: user.resume.mime
            bin: user.resume.bin
          app.saveResume user, resume, (err) ->
            if err
              console.log(err)
              return uploadUserResume(i+1)
            user.resume.bin = undefined
            user.resume.mime = undefined
            user.resume.name = undefined
            user.save () ->
              uploadUserResume(i+1)
      uploadUserResume(0)

  app.get '/admin/users/:id', app.gate.requireAdmin, (req, res) ->
    app.models.User.findById req.params.id, (err, user) ->
      return res.send(404) if not user
      thisYear = (new Date()).getFullYear()
      yearSet  = [thisYear-20..thisYear+8]
      res.render 'account/account', yearSet: yearSet, user: user

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