exports = module.exports = (app) ->

  pageLimit = 10

  # Listing
  app.get '/jobs', (req, res) ->
    app.models.Posting.find({}).limit(pageLimit).exec (err, postings) ->
      res.render 'jobs/index', postings: postings

  app.get '/jobs/:page([0-9]+)', (req, res) ->
    skip = pageLimit * ( Math.max 0, (req.params.page-1) )
    app.models.Posting.find({}).limit(10).skip(skip).exec (err, postings) ->
      res.render 'jobs/index', postings: postings

  app.get '/jobs/:id', (req, res) ->
    app.models.Posting.findOne _id: req.params.id, (err, posting) ->
      res.render 'jobs/job', posting: posting