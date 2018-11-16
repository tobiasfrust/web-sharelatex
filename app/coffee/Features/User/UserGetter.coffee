mongojs = require("../../infrastructure/mongojs")
metrics = require('metrics-sharelatex')
logger = require('logger-sharelatex')
db = mongojs.db
ObjectId = mongojs.ObjectId
{ getUserAffiliations } = require("../Institutions/InstitutionsAPI")
Errors = require("../Errors/Errors")

module.exports = UserGetter =
	getUser: (query, projection, callback = (error, user) ->) ->
		return callback(new Error("no query provided")) unless query?
		if query?.email?
			return callback(new Error("Don't use getUser to find user by email"), null)
		if arguments.length == 2
			callback = projection
			projection = {}
		if typeof query == "string"
			try
				query = _id: ObjectId(query)
			catch e
				return callback(null, null)
		else if query instanceof ObjectId
			query = _id: query

		db.users.findOne query, projection, callback

	getUserEmail: (userId, callback = (error, email) ->) ->
		@getUser userId, { email: 1 }, (error, user) ->
			callback(error, user?.email)

	getUserFullEmails: (userId, callback = (error, emails) ->) ->
		@getUser userId, { email: 1, emails: 1 }, (error, user) ->
			return callback error if error?
			return callback new Error('User not Found') unless user

			getUserAffiliations userId, (error, affiliationsData) ->
				return callback error if error?
				callback null, decorateFullEmails(user.email, user.emails or [], affiliationsData)

	getUserByMainEmail: (email, projection, callback = (error, user) ->) ->
		email = email.trim()
		if arguments.length == 2
			callback = projection
			projection = {}
		db.users.findOne email: email, projection, callback

	getUserByAnyEmail: (email, projection, callback = (error, user) ->) ->
		email = email.trim()
		if arguments.length == 2
			callback = projection
			projection = {}
		# $exists: true MUST be set to use the partial index
		query = emails: { $exists: true }, 'emails.email': email
		db.users.findOne query, projection, (error, user) =>
			return callback(error, user) if error? or user?

			# While multiple emails are being rolled out, check for the main email as
			# well
			@getUserByMainEmail email, projection, callback

	getUsersByHostname: (hostname, projection, callback = (error, users) ->) ->
		reversedHostname = hostname.trim().split('').reverse().join('')
		query = emails: { $exists: true }, 'emails.reversedHostname': reversedHostname
		db.users.find query, projection, callback

	getUsers: (user_ids, projection, callback = (error, users) ->) ->
		try
			user_ids = user_ids.map (u) -> ObjectId(u.toString())
		catch error
			return callback error
		
		db.users.find { _id: { $in: user_ids} }, projection, callback

	getUserOrUserStubById: (user_id, projection, callback = (error, user, isStub) ->) ->
		try
			query = _id: ObjectId(user_id.toString())
		catch e
			return callback(new Error(e))
		db.users.findOne query, projection, (error, user) ->
			return callback(error) if error?
			return callback(null, user, false) if user?
			db.userstubs.findOne query, projection, (error, user) ->
				return callback(error) if error
				return callback() if !user?
				callback(null, user, true)

	# check for duplicate email address. This is also enforced at the DB level
	ensureUniqueEmailAddress: (newEmail, callback) ->
		@getUserByAnyEmail newEmail, (error, user) ->
			return callback(new Errors.EmailExistsError('alread_exists')) if user?
			callback(error)

decorateFullEmails = (defaultEmail, emailsData, affiliationsData) ->
	emailsData.map (emailData) ->
		emailData.default = emailData.email == defaultEmail

		affiliation = affiliationsData.find (aff) -> aff.email == emailData.email
		if affiliation?
			{ institution, inferred, role, department } = affiliation
			emailData.affiliation = { institution, inferred, role, department }
		else
			emailsData.affiliation = null

		emailData

[
	'getUser',
	'getUserEmail',
	'getUserByMainEmail',
	'getUserByAnyEmail',
	'getUsers',
	'getUserOrUserStubById',
	'ensureUniqueEmailAddress',
].map (method) ->
	metrics.timeAsyncMethod UserGetter, method, 'mongo.UserGetter', logger
