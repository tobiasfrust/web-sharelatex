AuthorizationManager = require("./AuthorizationManager")
async = require "async"
logger = require "logger-sharelatex"
ObjectId = require("mongojs").ObjectId
Errors = require "../Errors/Errors"
AuthenticationController = require "../Authentication/AuthenticationController"
TokenAccessHandler = require '../TokenAccess/TokenAccessHandler'

module.exports = AuthorizationMiddlewear =
	ensureUserCanReadMultipleProjects: (req, res, next) ->
		project_ids = (req.query.project_ids or "").split(",")
		AuthorizationMiddlewear._getUserId req, (error, user_id) ->
			return next(error) if error?
			# Remove the projects we have access to. Note rejectSeries doesn't use
			# errors in callbacks
			async.rejectSeries project_ids, (project_id, cb) ->
				token = TokenAccessHandler.getRequestToken(req, project_id)
				AuthorizationManager.canUserReadProject user_id, project_id, token, (error, canRead) ->
					return next(error) if error?
					cb(canRead)
			, (unauthorized_project_ids) ->
				if unauthorized_project_ids.length > 0
					AuthorizationMiddlewear.redirectToRestricted req, res, next
				else
					next()

	ensureUserCanReadProject: (req, res, next) ->
		AuthorizationMiddlewear._getUserAndProjectId req, (error, user_id, project_id) ->
			return next(error) if error?
			token = TokenAccessHandler.getRequestToken(req, project_id)
			AuthorizationManager.canUserReadProject user_id, project_id, token, (error, canRead) ->
				return next(error) if error?
				if canRead
					logger.log {user_id, project_id}, "allowing user read access to project"
					next()
				else
					logger.log {user_id, project_id}, "denying user read access to project"
					if req.headers?['accept']?.match(/^application\/json.*$/)
						res.sendStatus(403)
					else
						AuthorizationMiddlewear.redirectToRestricted req, res, next

	ensureUserCanWriteProjectSettings: (req, res, next) ->
		AuthorizationMiddlewear._getUserAndProjectId req, (error, user_id, project_id) ->
			return next(error) if error?
			token = TokenAccessHandler.getRequestToken(req, project_id)
			AuthorizationManager.canUserWriteProjectSettings user_id, project_id, token, (error, canWrite) ->
				return next(error) if error?
				if canWrite
					logger.log {user_id, project_id}, "allowing user write access to project settings"
					next()
				else
					logger.log {user_id, project_id}, "denying user write access to project settings"
					AuthorizationMiddlewear.redirectToRestricted req, res, next

	ensureUserCanWriteProjectContent: (req, res, next) ->
		AuthorizationMiddlewear._getUserAndProjectId req, (error, user_id, project_id) ->
			return next(error) if error?
			token = TokenAccessHandler.getRequestToken(req, project_id)
			AuthorizationManager.canUserWriteProjectContent user_id, project_id, token, (error, canWrite) ->
				return next(error) if error?
				if canWrite
					logger.log {user_id, project_id}, "allowing user write access to project content"
					next()
				else
					logger.log {user_id, project_id}, "denying user write access to project settings"
					AuthorizationMiddlewear.redirectToRestricted req, res, next

	ensureUserCanAdminProject: (req, res, next) ->
		AuthorizationMiddlewear._getUserAndProjectId req, (error, user_id, project_id) ->
			return next(error) if error?
			token = TokenAccessHandler.getRequestToken(req, project_id)
			AuthorizationManager.canUserAdminProject user_id, project_id, token, (error, canAdmin) ->
				return next(error) if error?
				if canAdmin
					logger.log {user_id, project_id}, "allowing user admin access to project"
					next()
				else
					logger.log {user_id, project_id}, "denying user admin access to project"
					AuthorizationMiddlewear.redirectToRestricted req, res, next

	ensureUserIsSiteAdmin: (req, res, next) ->
		AuthorizationMiddlewear._getUserId req, (error, user_id) ->
			return next(error) if error?
			AuthorizationManager.isUserSiteAdmin user_id, (error, isAdmin) ->
				return next(error) if error?
				if isAdmin
					logger.log {user_id}, "allowing user admin access to site"
					next()
				else
					logger.log {user_id}, "denying user admin access to site"
					AuthorizationMiddlewear.redirectToRestricted req, res, next

	_getUserAndProjectId: (req, callback = (error, user_id, project_id) ->) ->
		project_id = req.params?.project_id or req.params?.Project_id
		if !project_id?
			return callback(new Error("Expected project_id in request parameters"))
		if !ObjectId.isValid(project_id)
			return callback(new Errors.NotFoundError("invalid project_id: #{project_id}"))
		AuthorizationMiddlewear._getUserId req, (error, user_id) ->
			return callback(error) if error?
			callback(null, user_id, project_id)

	_getUserId: (req, callback = (error, user_id) ->) ->
		user_id = AuthenticationController.getLoggedInUserId(req) || req?.oauth_user?._id || null
		return callback(null, user_id)

	redirectToRestricted: (req, res, next) ->
		res.redirect "/restricted?from=#{encodeURIComponent(req.url)}"

	restricted : (req, res, next)->
		if AuthenticationController.isUserLoggedIn(req)
			res.render 'user/restricted',
				title:'restricted'
		else
			from = req.query.from
			logger.log {from: from}, "redirecting to login"
			redirect_to = "/login"
			if from?
				AuthenticationController.setRedirectInSession(req, from)
			res.redirect redirect_to
