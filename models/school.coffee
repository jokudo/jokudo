fs          = require 'fs'
crypto      = require('ezcrypto').Crypto
mongoose    = require 'mongoose'
MandrillAPI = require('mailchimp').MandrillAPI

Schema = mongoose.Schema

# Schema Setup
SchoolSchema = new Schema(
  name:
    type: String
    index:
      unique: true
  email: String
  majors: [String]
  modified:
    type: Date
    default: Date.now
)


SchoolSchema.set 'toJSON', virtuals: true
SchoolSchema.set 'toObject', virtuals: true

SchoolSchema.virtual('id')
  .get( () -> this._id.toHexString() )




SchoolSchema.pre 'save', (next) ->
  if @.modifiedPaths().length > 0 or @.isNew
    @.modified = Date.now()
  next()



# Exports
exports.SchoolSchema = module.exports.SchoolSchema = SchoolSchema
exports.boot = module.exports.boot = (app) ->
  mandrill = app.mandrill or mandrill
  redisDb  = app.redisDb
  mongoose.model 'School', SchoolSchema
  app.models.School = mongoose.model 'School'



