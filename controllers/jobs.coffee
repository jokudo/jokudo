exports = module.exports = (app) ->

  # Articles per page
  pageLimit = 9

  # pagination middleware function sets some
  # local view variables that any view can use
  pagination = (req, res, next) ->
    page = parseInt(req.params.page) || 1
    num = page * pageLimit;
    app.models.Posting.count (err, total) ->
      res.locals.total = total
      res.locals.pages = Math.ceil(total / pageLimit)
      res.locals.page = page
      res.locals.prevPage = true if (page > 1)
      res.locals.nextPage = true if (page < res.locals.pages)
      next()

  app.get '/jobs/:page([0-9]+)?', app.gate.requireLoginToSee, pagination, (req, res) ->
    skip = pageLimit * ( Math.max 0, (req.params.page-1) )
    app.models.Posting.find({}).sort({company: 1, title:1, modified: 1}).limit(pageLimit).skip(skip).exec (err, postings) ->
      res.render 'jobs/index', postings: postings
    app.mixpanel.track 'JobListings', distinct_id: req.sessionID

  app.get '/jobs/:id', app.gate.requireLoginToSee, (req, res) ->
    app.models.Posting.findOne _id: req.params.id, (err, posting) ->
      return app.send404(req, res) if not posting or err
      res.render 'jobs/job', posting: posting