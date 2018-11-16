expect = require("chai").expect
async = require("async")
User = require "./helpers/User"
request = require "./helpers/request"
settings = require "settings-sharelatex"
redis = require "./helpers/redis"
MockV1Api = require './helpers/MockV1Api'

describe "Sessions", ->
	before (done) ->
		@timeout(20000)
		@user1 = new User()
		@site_admin = new User({email: "admin@example.com"})
		async.series [
			(cb) => @user1.login cb
			(cb) => @user1.logout cb
		], done

	describe "one session", ->

		it "should have one session in UserSessions set", (done) ->
			async.series(
				[
					(next) =>
						redis.clearUserSessions @user1, next

					# login, should add session to set
					, (next) =>
						@user1.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 1
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							next()

					# should be able to access project list page
					, (next) =>
						@user1.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 200
							next()

					# logout, should remove session from set
					, (next) =>
						@user1.logout (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 0
							next()

				], (err, result) =>
					if err
						throw err
					done()
			)

	describe "two sessions", ->

		before ->
			# set up second session for this user
			@user2 = new User()
			@user2.email = @user1.email
			@user2.password = @user1.password

		it "should have two sessions in UserSessions set", (done) ->
			async.series(
				[
					(next) =>
						redis.clearUserSessions @user1, next

					# login, should add session to set
					, (next) =>
						@user1.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 1
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							next()

					# login again, should add the second session to set
					, (next) =>
						@user2.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 2
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							expect(sessions[1].slice(0, 5)).to.equal 'sess:'
							next()

					# both should be able to access project list page
					, (next) =>
						@user1.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 200
							next()

					, (next) =>
						@user2.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 200
							next()

					# logout first session, should remove session from set
					, (next) =>
						@user1.logout (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 1
							next()

					# first session should not have access to project list page
					, (next) =>
						@user1.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 302
							next()

					# second session should still have access to settings
					, (next) =>
						@user2.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 200
							next()

					# logout second session, should remove last session from set
					, (next) =>
						@user2.logout (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 0
							next()

					# second session should not have access to project list page
					, (next) =>
						@user2.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 302
							next()

				], (err, result) =>
					if err
						throw err
					done()
			)

	describe 'three sessions, password reset', ->

		before ->
			# set up second session for this user
			@user2 = new User()
			@user2.email = @user1.email
			@user2.password = @user1.password
			@user3 = new User()
			@user3.email = @user1.email
			@user3.password = @user1.password

		it "should erase both sessions when password is reset", (done) ->
			async.series(
				[
					(next) =>
						redis.clearUserSessions @user1, next

					# login, should add session to set
					, (next) =>
						@user1.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 1
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							next()

					# login again, should add the second session to set
					, (next) =>
						@user2.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 2
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							expect(sessions[1].slice(0, 5)).to.equal 'sess:'
							next()

					# login third session, should add the second session to set
					, (next) =>
						@user3.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 3
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							expect(sessions[1].slice(0, 5)).to.equal 'sess:'
							next()

					# password reset from second session, should erase two of the three sessions
					, (next) =>
						@user2.changePassword (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user2, (err, sessions) =>
							expect(sessions.length).to.equal 1
							next()

					# users one and three should not be able to access project list page
					, (next) =>
						@user1.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 302
							next()

					, (next) =>
						@user3.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 302
							next()

					# user two should still be logged in, and able to access project list page
					, (next) =>
						@user2.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 200
							next()

					# logout second session, should remove last session from set
					, (next) =>
						@user2.logout (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 0
							next()

				], (err, result) =>
					if err
						throw err
					done()
			)

	describe 'three sessions, sessions page', ->

		before (done) ->
			# set up second session for this user
			@user2 = new User()
			@user2.email = @user1.email
			@user2.password = @user1.password
			@user3 = new User()
			@user3.email = @user1.email
			@user3.password = @user1.password
			async.series [
				@user2.login.bind(@user2)
				@user2.activateSudoMode.bind(@user2)
			], done

		it "should allow the user to erase the other two sessions", (done) ->
			async.series(
				[
					(next) =>
						redis.clearUserSessions @user1, next

					# login, should add session to set
					, (next) =>
						@user1.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 1
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							next()

					# login again, should add the second session to set
					, (next) =>
						@user2.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 2
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							expect(sessions[1].slice(0, 5)).to.equal 'sess:'
							next()

					# login third session, should add the second session to set
					, (next) =>
						@user3.login (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 3
							expect(sessions[0].slice(0, 5)).to.equal 'sess:'
							expect(sessions[1].slice(0, 5)).to.equal 'sess:'
							next()

					# enter sudo-mode
					, (next) =>
						@user2.getCsrfToken (err) =>
							expect(err).to.be.oneOf [null, undefined]
							@user2.request.post {
								uri: '/confirm-password',
								json:
									password: @user2.password
							}, (err, response, body) =>
								expect(err).to.be.oneOf [null, undefined]
								expect(response.statusCode).to.equal 200
								next()

					# check the sessions page
					, (next) =>
						@user2.request.get {
							uri: '/user/sessions'
						}, (err, response, body) =>
							expect(err).to.be.oneOf [null, undefined]
							expect(response.statusCode).to.equal 200
							next()

					# clear sessions from second session, should erase two of the three sessions
					, (next) =>
						@user2.getCsrfToken (err) =>
							expect(err).to.be.oneOf [null, undefined]
							@user2.request.post {
								uri: '/user/sessions/clear'
							}, (err) ->
								next(err)

					, (next) =>
						redis.getUserSessions @user2, (err, sessions) =>
							expect(sessions.length).to.equal 1
							next()

					# users one and three should not be able to access project list page
					, (next) =>
						@user1.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 302
							next()

					, (next) =>
						@user3.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 302
							next()

					# user two should still be logged in, and able to access project list page
					, (next) =>
						@user2.getProjectListPage (err, statusCode) =>
							expect(err).to.equal null
							expect(statusCode).to.equal 200
							next()

					# logout second session, should remove last session from set
					, (next) =>
						@user2.logout (err) ->
							next(err)

					, (next) =>
						redis.getUserSessions @user1, (err, sessions) =>
							expect(sessions.length).to.equal 0
							next()

				], (err, result) =>
					if err
						throw err
					done()
			)
