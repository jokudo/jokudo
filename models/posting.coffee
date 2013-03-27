mongoose    = require 'mongoose'

Schema = mongoose.Schema

# Schema Setup
PostingSchema = new Schema(
  company: String
  title: String
  description: String
  location: String
  schedule: String

  modified:
    type: Date
    default: Date.now
)


PostingSchema.set 'toJSON', virtuals: true
PostingSchema.set 'toObject', virtuals: true

PostingSchema.virtual('id')
  .get( () -> this._id.toHexString() )

PostingSchema.pre 'save', (next) ->
  if @.modifiedPaths().length > 0 or @.isNew
    @.modified = Date.now()
  next()



# Exports
exports.PostingSchema = module.exports.PostingSchema = PostingSchema
exports.boot = module.exports.boot = (app) ->
  mandrill = app.mandrill or mandrill
  redisDb  = app.redisDb
  mongoose.model 'Posting', PostingSchema
  app.models.Posting = mongoose.model 'Posting'



