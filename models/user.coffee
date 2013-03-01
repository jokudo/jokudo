crypto = require('ezcrypto').Crypto
mongoose = require('mongoose')
Schema = mongoose.Schema

# Schema Setup
UserSchema = new Schema(
  email:
    type: String
    index:
      unique: true
  hashPassword:
    type: String
    index: true
  firstName: String
  lastName: String
  friends: [
    type: Schema.ObjectId
    ref: 'User'
  ]
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


UserSchema.method 'sendConfirmationEmail', (mandrill) ->
  hash = crypto.SHA256(@.email or '').substring(3,30)
  url = "http://#{process.env.DOMAIN}/account/confirm_email/#{@.id}/#{hash}"
  mandrill.messages_send_template {
      template_name: 'email-confirmation'
    , template_content: ''
    , message:
        subject: "Confirm your jokudo account, #{@.firstName}"
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
          {name: 'SUBJECT', content: "Confirm your jokudo account, #{@.firstName}"}
        ]
        merge_vars:[
          rcpt: @.email
          vars: [
            {name: 'CONFIRM_LINK', content: url}
            {name: 'FNAME', content: @.firstName}
          ]
        ]
    , tags: ['confirmation']
    }, (err, data) ->
        if err
          console.log 'error-', err


UserSchema.pre 'save', (next) ->
  @.modified = Date.now()
  next()






# Exports
exports.UserSchema = module.exports.UserSchema = UserSchema
exports.boot = module.exports.boot = (app) ->
  mongoose.model 'User', UserSchema
  app.models.User = mongoose.model 'User'
  app.models.User.encryptPassword = ->
    u = new app.models.User()
    u.encryptPassword.apply @, arguments


