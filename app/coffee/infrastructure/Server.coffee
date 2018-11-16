Path = require "path"
express = require('express')
Settings = require('settings-sharelatex')
logger = require 'logger-sharelatex'
metrics = require('metrics-sharelatex')
crawlerLogger = require('./CrawlerLogger')
expressLocals = require('./ExpressLocals')
Router = require('../router')
helmet = require "helmet"
metrics.inc("startup")
UserSessionsRedis = require('../Features/User/UserSessionsRedis')
Csrf = require('./Csrf')

sessionsRedisClient = UserSessionsRedis.client()

session = require("express-session")
RedisStore = require('connect-redis')(session)
bodyParser = require('body-parser')
multer  = require('multer')
methodOverride = require('method-override')
cookieParser = require('cookie-parser')
bearerToken = require('express-bearer-token')

# Init the session store
sessionStore = new RedisStore(client:sessionsRedisClient)

passport = require('passport')
LocalStrategy = require('passport-local').Strategy

Mongoose = require("./Mongoose")

oneDayInMilliseconds = 86400000
ReferalConnect = require('../Features/Referal/ReferalConnect')
RedirectManager = require("./RedirectManager")
ProxyManager = require("./ProxyManager")
translations = require("translations-sharelatex").setup(Settings.i18n)
Modules = require "./Modules"

ErrorController = require "../Features/Errors/ErrorController"
UserSessionsManager = require "../Features/User/UserSessionsManager"
AuthenticationController = require "../Features/Authentication/AuthenticationController"


metrics.event_loop?.monitor(logger)

Settings.editorIsOpen ||= true

if Settings.cacheStaticAssets
	staticCacheAge = (oneDayInMilliseconds * 365)
else
	staticCacheAge = 0

app = express()

webRouter = express.Router()
privateApiRouter = express.Router()
publicApiRouter = express.Router()

if Settings.behindProxy
	app.enable('trust proxy')

webRouter.use express.static(__dirname + '/../../../public', {maxAge: staticCacheAge })
app.set 'views', __dirname + '/../../views'
app.set 'view engine', 'pug'
Modules.loadViewIncludes app



app.use bodyParser.urlencoded({ extended: true, limit: "2mb"})
# Make sure we can process the max doc length plus some overhead for JSON encoding
app.use bodyParser.json({limit: Settings.max_doc_length + 64 * 1024}) # 64kb overhead
app.use multer(dest: Settings.path.uploadFolder)
app.use methodOverride()
app.use bearerToken()

app.use metrics.http.monitor(logger)
RedirectManager.apply(webRouter)
ProxyManager.apply(publicApiRouter)


webRouter.use cookieParser(Settings.security.sessionSecret)
webRouter.use session
	resave: false
	saveUninitialized:false
	secret:Settings.security.sessionSecret
	proxy: Settings.behindProxy
	cookie:
		domain: Settings.cookieDomain
		maxAge: Settings.cookieSessionLength
		secure: Settings.secureCookie
	store: sessionStore
	key: Settings.cookieName
	rolling: true

# passport
webRouter.use passport.initialize()
webRouter.use passport.session()

passport.use(new LocalStrategy(
	{
		passReqToCallback: true,
		usernameField: 'email',
		passwordField: 'password'
	},
	AuthenticationController.doPassportLogin
))
passport.serializeUser(AuthenticationController.serializeUser)
passport.deserializeUser(AuthenticationController.deserializeUser)

Modules.hooks.fire 'passportSetup', passport, (err) ->
	if err?
		logger.err {err}, "error setting up passport in modules"

Modules.applyNonCsrfRouter(webRouter, privateApiRouter, publicApiRouter)

webRouter.csrf = new Csrf()
webRouter.use webRouter.csrf.middleware
webRouter.use translations.expressMiddlewear
webRouter.use translations.setLangBasedOnDomainMiddlewear

# Measure expiry from last request, not last login
webRouter.use (req, res, next) ->
	req.session.touch()
	if AuthenticationController.isUserLoggedIn(req)
		UserSessionsManager.touch(AuthenticationController.getSessionUser(req), (err)->)
	next()

webRouter.use ReferalConnect.use
expressLocals(app, webRouter, privateApiRouter, publicApiRouter)

if app.get('env') == 'production'
	logger.info "Production Enviroment"
	app.enable('view cache')

app.use (req, res, next)->
	metrics.inc "http-request"
	crawlerLogger.log(req)
	next()

webRouter.use (req, res, next) ->
	if Settings.editorIsOpen
		next()
	else if req.url.indexOf("/admin") == 0
		next()
	else
		res.status(503)
		res.render("general/closed", {title:"maintenance"})

# add security headers using Helmet
webRouter.use (req, res, next) ->
	isLoggedIn = AuthenticationController.isUserLoggedIn(req)
	isProjectPage = !!req.path.match('^/project/[a-f0-9]{24}$')

	helmet({ # note that more headers are added by default
		dnsPrefetchControl: false
		referrerPolicy: { policy: 'origin-when-cross-origin' }
		noCache: isLoggedIn || isProjectPage
		noSniff: false
		hsts: false
		frameguard: false
	})(req, res, next)

profiler = require "v8-profiler"
privateApiRouter.get "/profile", (req, res) ->
	time = parseInt(req.query.time || "1000")
	profiler.startProfiling("test")
	setTimeout () ->
		profile = profiler.stopProfiling("test")
		res.json(profile)
	, time

app.get "/heapdump", (req, res)->
	require('heapdump').writeSnapshot '/tmp/' + Date.now() + '.web.heapsnapshot', (err, filename)->
		res.send filename

logger.info ("creating HTTP server").yellow
server = require('http').createServer(app)

# provide settings for separate web and api processes
# if enableApiRouter and enableWebRouter are not defined they default
# to true.
notDefined = (x) -> !x?
enableApiRouter = Settings.web?.enableApiRouter
if enableApiRouter or notDefined(enableApiRouter)
	logger.info("providing api router");
	app.use(privateApiRouter)
	app.use(ErrorController.handleApiError)

enableWebRouter = Settings.web?.enableWebRouter
if enableWebRouter or notDefined(enableWebRouter)
	logger.info("providing web router");
	app.use(publicApiRouter) # public API goes with web router for public access
	app.use(ErrorController.handleApiError)
	app.use(webRouter)
	app.use(ErrorController.handleError)

router = new Router(webRouter, privateApiRouter, publicApiRouter)

module.exports =
	app: app
	server: server
