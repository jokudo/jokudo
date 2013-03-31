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
  middleName: String
  lastName: String

  school:
    type: Schema.ObjectId
    ref: 'School'
  _school: String
  major: [String]
  minor: [String]
  graduation: Date

  urls:
    github:   String
    twitter:  String
    facebook: String
    linkedin: String
    personal: String

  resume:
    mime: String
    name: String
    bin: Buffer
    s3Name: String

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
  .get( () -> "#{@.firstName || ''} #{@.lastName || ''}".trim() )
  .set( (fullName) ->
    p = fullName.split ' '
    @.firstName = p[0]
    @.lastName = p[1]
  )

UserSchema.virtual('avatar')
  .get( () -> "https://secure.gravatar.com/avatar/#{crypto.MD5(@.email)}?s=75&d=identicon" )

UserSchema.virtual('avatar_large')
  .get( () -> "https://secure.gravatar.com/avatar/#{crypto.MD5(@.email)}?s=250&d=identicon" )


UserSchema.virtual('avatar_large')
  .get( () -> "https://secure.gravatar.com/avatar/#{crypto.MD5(@.email)}?s=250&d=identicon" )


UserSchema.virtual('school_name')
  .get( () ->
    @._school or 'Pending Email Confirmation'
  )

UserSchema.virtual('graduation_date')
  .get( () ->
    months = [
      "January"
      "February"
      "March"
      "April"
      "May"
      "June"
      "July"
      "August"
      "September"
      "October"
      "November"
      "December"
    ]
    if not @.graduation
      return "Not specified"
    else
      return "#{months[@.graduation_month-1]} #{@.graduation_year}"
  )
  .set( (date) -> @.graduation = date )

UserSchema.virtual('graduation_month')
  .get( () ->
    if not @.graduation
      return (new Date()).getMonth() + 1
    else
      return @.graduation.getMonth() + 1
  )
  .set( (month) ->
    @.graduation = new Date() if not @.graduation
    @.graduation.setMonth(month)
  )

UserSchema.virtual('graduation_year')
  .get( () ->
    if not @.graduation
      return (new Date()).getFullYear()
    else
      return @.graduation.getFullYear()
  )
  .set( (year) ->
    @.graduation = new Date() if not @.graduation
    @.graduation.setYear(year)
  )

UserSchema.virtual('graduated')
  .get( () ->
    return @.graduation < new Date()
  )


UserSchema.virtual('major_string')
  .get( () ->
    return @.major.join(' and ') or 'Undeclaired'
  )


UserSchema.virtual('hasResume')
  .get( () ->
    return !!(@.resume.s3Name)
  )

UserSchema.virtual('resume_name')
  .get( () ->
    if @.hasResume
      return @.resume.s3Name or @.resume.name or 'resume'
    else
      return 'none'
 )

UserSchema.virtual('resume_url')
  .get( () ->
    if @.hasResume
      return 'http://r.jokudo.com/'+@.resume.s3Name
    else
      return '/account/resume'
 )

UserSchema.virtual('github_url')
  .get( () ->
    if @.urls.github
      return 'http://github.com/'+@.urls.github
 )
UserSchema.virtual('twitter_url')
  .get( () ->
    if @.urls.twitter
      return 'http://twitter.com/'+@.urls.twitter
 )
UserSchema.virtual('facebook_url')
  .get( () ->
    if @.urls.facebook
      return 'http://facebook.com/'+@.urls.facebook
 )
UserSchema.virtual('linkedin_url')
  .get( () ->
    if @.urls.linkedin
      return 'http://linkedin.com/in/'+@.urls.linkedin
 )
UserSchema.virtual('personal_url')
  .get( () ->
    if @.urls.personal
      return 'http://'+@.urls.personal
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
  throw new Error 'Method No longer supported'

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


