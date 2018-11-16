AuthenticationManager = require ("./AuthenticationManager")
LoginRateLimiter = require("../Security/LoginRateLimiter")
UserUpdater = require "../User/UserUpdater"
Metrics = require('metrics-sharelatex')
logger = require("logger-sharelatex")
querystring = require('querystring')
Url = require("url")
Settings = require "settings-sharelatex"
basicAuth = require('basic-auth-connect')
UserHandler = require("../User/UserHandler")
UserSessionsManager = require("../User/UserSessionsManager")
Analytics = require "../Analytics/AnalyticsManager"
passport = require 'passport'
NotificationsBuilder = require("../Notifications/NotificationsBuilder")
SudoModeHandler = require '../SudoMode/SudoModeHandler'
V1Api = require "../V1/V1Api"
{User} = require "../../models/User"

module.exports = AuthenticationController =

	serializeUser: (user, callback) ->
		lightUser =
			_id: user._id
			first_name: user.first_name
			last_name: user.last_name
			isAdmin: user.isAdmin
			email: user.email
			referal_id: user.referal_id
			session_created: (new Date()).toISOString()
			ip_address: user._login_req_ip
		callback(null, lightUser)

	deserializeUser: (user, cb) ->
		cb(null, user)

	afterLoginSessionSetup: (req, user, callback=(err)->) ->
		req.login user, (err) ->
			if err?
				logger.err {user_id: user._id, err}, "error from req.login"
				return callback(err)
			# Regenerate the session to get a new sessionID (cookie value) to
			# protect against session fixation attacks
			oldSession = req.session
			req.session.destroy (err) ->
				if err?
					logger.err {user_id: user._id, err}, "error when trying to destroy old session"
					return callback(err)
				req.sessionStore.generate(req)
				for key, value of oldSession
					req.session[key] = value unless key == '__tmp'
				# copy to the old `session.user` location, for backward-comptability
				req.session.user = req.session.passport.user
				req.session.save (err) ->
					if err?
						logger.err {user_id: user._id}, "error saving regenerated session after login"
						return callback(err)
					UserSessionsManager.trackSession(user, req.sessionID, () ->)
					callback(null)

	passportLogin: (req, res, next) ->
		# This function is middleware which wraps the passport.authenticate middleware,
		# so we can send back our custom `{message: {text: "", type: ""}}` responses on failure,
		# and send a `{redir: ""}` response on success
		passport.authenticate('local', (err, user, info) ->
			if err?
				return next(err)
			if user # `user` is either a user object or false
				AuthenticationController.finishLogin(user, req, res, next)
			else
				if info.redir?
					res.json {redir: info.redir}
				else
					res.json message: info
		)(req, res, next)

	finishLogin: (user, req, res, next) ->
		redir = AuthenticationController._getRedirectFromSession(req) || "/project"
		AuthenticationController._loginAsyncHandlers(req, user)
		AuthenticationController.afterLoginSessionSetup req, user, (err) ->
			if err?
				return next(err)
			SudoModeHandler.activateSudoMode user._id, (err) ->
				if err?
					logger.err {err, user_id: user._id}, "Error activating Sudo Mode on login, continuing"
				AuthenticationController._clearRedirectFromSession(req)
				if req.headers?['accept']?.match(/^application\/json.*$/)
					res.json {redir: redir}
				else
					res.redirect(redir)

	doPassportLogin: (req, username, password, done) ->
		email = username.toLowerCase()
		Modules = require "../../infrastructure/Modules"
		Modules.hooks.fire 'preDoPassportLogin', req, email, (err, infoList) ->
			return next(err) if err?
			info = infoList.find((i) => i?)
			if info?
				return done(null, false, info)
			LoginRateLimiter.processLoginRequest email, (err, isAllowed)->
				return done(err) if err?
				if !isAllowed
					logger.log email:email, "too many login requests"
					return done(null, null, {text: req.i18n.translate("to_many_login_requests_2_mins"), type: 'error'})
				AuthenticationManager.authenticate email: email, password, (error, user) ->
					return done(error) if error?
					if user?
						# async actions
						return done(null, user)
					else
						AuthenticationController._recordFailedLogin()
						logger.log email: email, "failed log in"
						return done(
							null,
							false,
							{text: req.i18n.translate("email_or_password_wrong_try_again"), type: 'error'}
						)

	_loginAsyncHandlers: (req, user) ->
		UserHandler.setupLoginData(user, ()->)
		LoginRateLimiter.recordSuccessfulLogin(user.email)
		AuthenticationController._recordSuccessfulLogin(user._id)
		AuthenticationController.ipMatchCheck(req, user)
		Analytics.recordEvent(user._id, "user-logged-in", {ip:req.ip})
		Analytics.identifyUser(user._id, req.sessionID)
		logger.log email: user.email, user_id: user._id.toString(), "successful log in"
		req.session.justLoggedIn = true
		# capture the request ip for use when creating the session
		user._login_req_ip = req.ip

	ipMatchCheck: (req, user) ->
		if req.ip != user.lastLoginIp
			NotificationsBuilder.ipMatcherAffiliation(user._id, req.ip).create()
		UserUpdater.updateUser user._id.toString(), {
			$set: { "lastLoginIp": req.ip }
		}

	setInSessionUser: (req, props) ->
		for key, value of props
			if req?.session?.passport?.user?
				req.session.passport.user[key] = value
			if req?.session?.user?
				req.session.user[key] = value

	isUserLoggedIn: (req) ->
		user_id = AuthenticationController.getLoggedInUserId(req)
		return (user_id not in [null, undefined, false])

	# TODO: perhaps should produce an error if the current user is not present
	getLoggedInUserId: (req) ->
		user = AuthenticationController.getSessionUser(req)
		if user
			return user._id
		else
			return null

	getSessionUser: (req) ->
		if req?.session?.user?
			return req.session.user
		else if req?.session?.passport?.user
			return req.session.passport.user
		else
			return null

	requireLogin: () ->
		doRequest = (req, res, next = (error) ->) ->
			if !AuthenticationController.isUserLoggedIn(req)
				AuthenticationController._redirectToLoginOrRegisterPage(req, res)
			else
				req.user = AuthenticationController.getSessionUser(req)
				next()

		return doRequest

	requireOauth: () ->
		return (req, res, next = (error) ->) ->
			return res.status(401).send() unless req.token?
			options =
				expectedStatusCodes: [401]
				json: token: req.token
				method: "POST"
				uri: "/api/v1/sharelatex/oauth_authorize"
			V1Api.request options, (error, response, body) ->
				return next(error) if error?
				return res.status(401).json({error: "invalid_token"}) unless body?.user_profile?.id
				User.findOne { "overleaf.id": body.user_profile.id }, (error, user) ->
					return next(error) if error?
					return res.status(401).send({error: "invalid_token"}) unless user?
					req.oauth = access_token: body.access_token
					req.oauth_user = user
					next()

	_globalLoginWhitelist: []
	addEndpointToLoginWhitelist: (endpoint) ->
		AuthenticationController._globalLoginWhitelist.push endpoint

	requireGlobalLogin: (req, res, next) ->
		if req._parsedUrl.pathname in AuthenticationController._globalLoginWhitelist
			return next()

		if req.headers['authorization']?
			return AuthenticationController.httpAuth(req, res, next)
		else if AuthenticationController.isUserLoggedIn(req)
			return next()
		else
			logger.log url:req.url, "user trying to access endpoint not in global whitelist"
			AuthenticationController._setRedirectInSession(req)
			return res.redirect "/login"

	httpAuth: basicAuth (user, pass)->
		isValid = Settings.httpAuthUsers[user] == pass
		if !isValid
			logger.err user:user, pass:pass, "invalid login details"
		return isValid

	_redirectToLoginOrRegisterPage: (req, res)->
		if (req.query.zipUrl? or req.query.project_name? or req.path == '/user/subscription/new')
			return AuthenticationController._redirectToRegisterPage(req, res)
		else
			AuthenticationController._redirectToLoginPage(req, res)

	_redirectToLoginPage: (req, res) ->
		logger.log url: req.url, "user not logged in so redirecting to login page"
		AuthenticationController._setRedirectInSession(req)
		url = "/login?#{querystring.stringify(req.query)}"
		res.redirect url
		Metrics.inc "security.login-redirect"

	_redirectToRegisterPage: (req, res) ->
		logger.log url: req.url, "user not logged in so redirecting to register page"
		AuthenticationController._setRedirectInSession(req)
		url = "/register?#{querystring.stringify(req.query)}"
		res.redirect url
		Metrics.inc "security.login-redirect"

	_recordSuccessfulLogin: (user_id, callback = (error) ->) ->
		UserUpdater.updateUser user_id.toString(), {
			$set: { "lastLoggedIn": new Date() },
			$inc: { "loginCount": 1 }
		}, (error) ->
			callback(error) if error?
			Metrics.inc "user.login.success"
			callback()

	_recordFailedLogin: (callback = (error) ->) ->
		Metrics.inc "user.login.failed"
		callback()

	_setRedirectInSession: (req, value) ->
		if !value?
			value = if Object.keys(req.query).length > 0 then "#{req.path}?#{querystring.stringify(req.query)}" else "#{req.path}"
		if (
			req.session? &&
			!/^\/(socket.io|js|stylesheets|img)\/.*$/.test(value) &&
			!/^.*\.(png|jpeg|svg)$/.test(value)
		)
			req.session.postLoginRedirect = value

	_getRedirectFromSession: (req) ->
		return req?.session?.postLoginRedirect || null

	_clearRedirectFromSession: (req) ->
		if req.session?
			delete req.session.postLoginRedirect
