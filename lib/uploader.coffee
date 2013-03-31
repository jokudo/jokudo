fs     = require 'fs'
mime   = require 'mime'
crypto = require('ezcrypto').Crypto

hashIt = (decimal, minLength=7) ->
  symbolSheet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")
  base = symbolSheet.length
  conversion = ""
  decimal = decimal % Math.pow(62,minLength)
  while (decimal >= 1)
    conversion = symbolSheet[(decimal - (base*Math.floor(decimal / base)))] + conversion;
    decimal = Math.floor(decimal / base);
  while (conversion.length < minLength)
    conversion = symbolSheet[0] + conversion
  conversion



exports.boot = (app) ->

  minLength = 7

  makeHash = (numToHash, ext, id, next) ->
    hash = hashIt numToHash, minLength
    app.models.User.findOne {'resume.s3Name': hash+'.'+ext}, (err, res) =>
      if err
        next err, null
      if res and res._id != id
        makeHash parseInt(crypto.MD5(hash).substr(0,10),16), ext, id, next
      else
        next null, hash

  app.saveResume = (user, resumeFile, next=(()->return)) ->
    bodyStream = fs.readFileSync( resumeFile.path )
    numToHash = parseInt(crypto.MD5(fs.readFileSync(resumeFile.path)),16)
    ext = mime.extension(resumeFile.type || 'binary/octet-stream') || 'pdf'
    makeHash numToHash, ext, user._id, (err, name) ->
      nameFull = name+'.'+ext
      if user.resume.s3Name isnt nameFull
        data =
          'Bucket'        : app.config.S3_BUCKET_NAME,
          'Key'           : nameFull,
          'Metadata'      : {'user': user.id},
          'ContentType'   : resumeFile.type,
          'Body'          : bodyStream
        deleteData =
          'Bucket' : app.config.S3_BUCKET_NAME,
          'Key'    : user.resume.s3Name,
        if ( user.resume.s3Name )
          ## Delete the old
          app.s3.client.deleteObject deleteData, (err, result) ->
            console.log('Error Deleting', err) if err
        # Upload the new
        app.s3.client.putObject data, (err, result) ->
          return next(err) if err
          user.resume.s3Name = nameFull
          user.save () ->
            next()
      else
        next()
