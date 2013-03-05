fs          = require 'fs'
crypto      = require('ezcrypto').Crypto
mongoose    = require 'mongoose'
MandrillAPI = require('mailchimp').MandrillAPI

redisDb = {}

if process.env.MANDRILL_KEY
  mandrill  = new MandrillAPI process.env.MANDRILL_KEY, version : '1.0', secure: false


Schema = mongoose.Schema

# Schema Setup
UserSchema = new Schema(
  email:
    type: String
    index:
      unique: true
  _email: # Used for pending email changes
    type: String
  hashPassword:
    type: String
    index: true
  firstName: String
  lastName: String
  resume:
    mime: String
    bin: Buffer
  confirmed:
    type: Boolean
    default: false
  loginCount:
    type: Number
    default: 1
  lastLogin:
    type: Date
    default: Date.now
  modified:
    type: Date
    default: Date.now
  admin:
    type: Boolean
    default: false
)


UserSchema.set 'toJSON', virtuals: true
UserSchema.set 'toObject', virtuals: true


UserSchema.virtual('password')
  .get( () -> this._password )
  .set( (pass) ->
    @.setPassword(pass)
    @._password = pass
  )

UserSchema.virtual('id')
  .get( () -> this._id.toHexString() )

UserSchema.virtual('name')
  .get( () -> "#{@.firstName} #{@.lastName}".trim() )
  .set( (fullName) ->
    p = fullName.split ' '
    @.firstName = p[0]
    @.lastName = p[1]
  )

UserSchema.method 'changeEmail', (newEmail) ->
  # Put the new email into the _email property
  return if newEmail is @.email
  @._email = newEmail
  @.confirmed = false

UserSchema.method 'confirmEmail', (email) ->
  @.email = @._email or @.email
  @._email = undefined
  @.confirmed = true

UserSchema.method 'saveResume', (resumeFile) ->
  @.resume.mime = resumeFile.mime
  @.resume.bin = fs.readFileSync resumeFile.path

UserSchema.method 'encryptPassword', (plainText) ->
  plainText = plainText + '_9dD83n'
  crypto.MD5(plainText)

UserSchema.method 'setPassword', (plainText) ->
  @.hashPassword = @.encryptPassword plainText
  @

UserSchema.method 'authenticate', (plainText) ->
  @.hashPassword is @.encryptPassword plainText

UserSchema.method 'isPasswordless', () ->
  !(@.hashPassword?.length)


UserSchema.method 'sendConfirmationEmail', (config={}) ->

  # Confirmation hash
  email = @._email or @.email
  hash = crypto.SHA256(email or '').substring(3,30)

  hash =  (Math.random()*10000).toString(16).split('').reverse().join('').substring(0,5) +
    '-' + crypto.SHA256(@._email or '').substring(20,25) +
    '-' + (Math.random()*10000).toString(16).split('').reverse().join('').substring(0,5) +
    '-' + Date.now().toString().split('').reverse().join('').substring(0,5)
  hash = hash.toUpperCase()
  redisDb.set hash, @.id

  url = "http://#{process.env.DOMAIN}/account/confirm_email/#{hash}"

  if @.firstName
    name = " , #{@.firstName}"
  else
    name = ""

  # Which template
  if config.update is true
    template = 'email-change-confirmation'
    subject = "Confirm your change of email#{name}"
  else
    template = 'email-confirmation'
    subject = "Confirm your jokudo account#{name}"

  # Send Template
  mandrill.messages_send_template {
      template_name: template
    , template_content: ''
    , message:
        subject: subject
        from_email: 'signup@jokudo.com'
        from_name: 'Jokudo'
        track_opens: true
        track_clicks: true
        auto_txt: true
        to: [
          email: email
        ]
        template_content: []
        global_merge_vars:[
          {name: 'CURRENT_YEAR', content: (new Date()).getFullYear()},
          {name: 'SUBJECT', content: subject}
        ]
        merge_vars:[
          rcpt: email
          vars: [
            {name: 'CONFIRM_LINK', content: url}
            {name: 'FNAME', content: @.firstName or "Hey there!"}
          ]
        ]
    , tags: ['confirmation']
    }, (err, data) ->
        if err
          console.log 'error-', err





UserSchema.method 'sendForgotPasswordEmail', (mandrill, redisDb) ->
  hash =  (Math.random()*10000).toString(16).split('').reverse().join('').substring(0,5) +
    '-' + crypto.SHA256(@.email or '').substring(20,25) +
    '-' + crypto.MD5(@.hashPassword or '').substring(15,20) +
    '-' + Date.now().toString().split('').reverse().join('').substring(0,5)
  hash = hash.toUpperCase()
  redisDb.set hash, @.id
  redisDb.expire hash, 24 * 60 * 60 * 1000

  url = "http://#{process.env.DOMAIN}/account/reset_password/#{hash}"
  mandrill.messages_send_template {
      template_name: 'forgot-password'
    , template_content: ''
    , message:
        subject: "Recover your your jokudo password"
        from_email: 'signup@jokudo.com'
        from_name: 'Jokudo'
        track_opens: true
        track_clicks: true
        auto_txt: true
        to: [
          email: @.email
        ]
        template_content: []
        global_merge_vars:[
          {name: 'CURRENT_YEAR', content: (new Date()).getFullYear()},
          {name: 'SUBJECT', content: "Recover your your jokudo password"}
        ]
        merge_vars:[
          rcpt: @.email
          vars: [
            {name: 'RESET_LINK', content: url}
            {name: 'FNAME', content: @.firstName or "Hey there!"}
          ]
        ]
    , tags: ['password-reset']
    }, (err, data) ->
        if err
          console.log 'error-', err







UserSchema.pre 'save', (next) ->
  if @.modifiedPaths().length > 0 or @.isNew
    @.modified = Date.now()
  if @.isNew
    @.email = @._email
    @._email = undefined
    @.sendConfirmationEmail update: false
  else if @.isModified '_email'
    if @._email isnt @.email and @._email
      @.confirmed = false
      @.sendConfirmationEmail update: true
  next()






# Exports
exports.UserSchema = module.exports.UserSchema = UserSchema
exports.boot = module.exports.boot = (app) ->
  mandrill = app.mandrill or mandrill
  redisDb  = app.redisDb
  mongoose.model 'User', UserSchema
  app.models.User = mongoose.model 'User'
  app.models.User.encryptPassword = ->
    u = new app.models.User()
    u.encryptPassword.apply @, arguments


