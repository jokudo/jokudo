exports = module.exports = (app) ->

  # Home
  app.get '/admin/postings', app.gate.requireAdmin, (req, res) ->
    app.models.Posting.find {}, (err, postings) ->
      res.render 'admin/postings', postings: postings

  app.post '/admin/postings', app.gate.requireAdmin, (req, res) ->
    posting = new app.models.Posting req.body
    upsertData = posting.toObject()
    delete upsertData._id
    app.models.Posting.update _id: posting.id, upsertData, upsert: true, (err) ->
      res.redirect '/admin/postings'

  app.get '/admin/postings/new', app.gate.requireAdmin, (req, res) ->
    res.render 'admin/postings-form', posting: new app.models.Posting

  app.get '/admin/postings/:id', app.gate.requireAdmin, (req, res) ->
    app.models.Posting.findOne _id: req.params.id, (err, posting) ->
      if posting
        res.render 'admin/postings-form', posting: posting
      else
        res.send 500 if err
        res.send 404 if not posting