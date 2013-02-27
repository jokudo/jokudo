MandrillAPI = require('mailchimp').MandrillAPI

exports = module.exports = (app) ->

  # Config
  mandrill = new MandrillAPI app.config.MANDRILL_KEY, version : '1.0', secure: false


  # Home
  app.get '/', (req, res) ->
    res.render 'index'


  app.get '/thank-you', (req, res) ->
    res.render 'thanks'


  app.post '/signup', (req, res) ->
    email = req.body.email
    console.log 'called with', email
    if not email.match /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.edu$/i
      return res.json error:'Not a valid .edu email'

    app.models.User.findOne email: email, (err, foundUser) ->
      if foundUser
        res.json error: 'Thanks for being so eager, but we seem to already have your email address.'
      else
        user = new app.models.User email: email
        user.save (error) ->
          if error
            console.log 'retruning becsause of save error?', error
            return res.json error: error.toString()

          app.models.User.findOne email: email, (err, user) ->

            mandrill.messages_send_template {
              template_name:'signup-welcome'
            , template_content:''
            , message:
                subject: 'Welcome to jokudo'
                from_email: 'signup@jokudo.com'
                from_name: 'Jokudo Sensei'
                track_opens: true
                track_clicks: true
                auto_txt: true
                to: [
                  email: email
                ]
                template_content: []
                global_merge_vars:[
                  {name: 'CURRENT_YEAR', content: (new Date()).getFullYear()},
                  {name: 'SUBJECT', content: 'Welcome to jokudo'}
                ]
                merge_vars:[
                  rcpt: email
                  vars: [
                    name: 'REMOVE_LINK', content: 'http://'+app.config.DOMAIN+'?'+user.id
                  ]
                ]
              tags: ['signup']
            }, (err, data) ->
                if err
                  return res.json error: err
                else
                  return res.json success: true


