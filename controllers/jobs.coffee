exports = module.exports = (app) ->

  pageLimit = Infinity

  # Listing
  app.get '/jobs', app.gate.requireLogin,  (req, res) ->
    app.models.Posting.find({}).sort({company: 1, title:1, modified: 1}).limit(pageLimit).exec (err, postings) ->
      res.render 'jobs/index', postings: postings

  app.get '/jobs/:page([0-9]+)', app.gate.requireLogin, (req, res) ->
    skip = pageLimit * ( Math.max 0, (req.params.page-1) )
    app.models.Posting.find({}).sort({company: 1, title:1, modified: 1}).limit(10).skip(skip).exec (err, postings) ->
      res.render 'jobs/index', postings: postings

  app.get '/jobs/:id', app.gate.requireLogin, (req, res) ->
    app.models.Posting.findOne _id: req.params.id, (err, posting) ->
      res.render 'jobs/job', posting: posting