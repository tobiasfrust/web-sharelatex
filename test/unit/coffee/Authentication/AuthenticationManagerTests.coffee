sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/Authentication/AuthenticationManager.js"
SandboxedModule = require('sandboxed-module')
events = require "events"
ObjectId = require("mongojs").ObjectId

describe "AuthenticationManager", ->
	beforeEach ->
		@settings = { security: { bcryptRounds: 12 } }
		@AuthenticationManager = SandboxedModule.require modulePath, requires:
			"../../models/User": User: @User = {}
			"../../infrastructure/mongojs":
				db: @db =
					users: {}
				ObjectId: ObjectId
			"bcrypt": @bcrypt = {}
			"settings-sharelatex": @settings
		@callback = sinon.stub()

	describe "authenticate", ->
		describe "when the user exists in the database", ->
			beforeEach ->
				@user =
					_id: "user-id"
					email: @email = "USER@sharelatex.com"
				@unencryptedPassword = "banana"
				@User.findOne = sinon.stub().callsArgWith(1, null, @user)
		
			describe "when the hashed password matches", ->
				beforeEach (done) ->
					@user.hashedPassword = @hashedPassword = "asdfjadflasdf"
					@bcrypt.compare = sinon.stub().callsArgWith(2, null, true)
					@bcrypt.getRounds = sinon.stub().returns 12
					@AuthenticationManager.authenticate email: @email, @unencryptedPassword, (error, user) =>
						@callback(error, user)
						done()

				it "should look up the correct user in the database", ->
					@User.findOne.calledWith(email: @email).should.equal true

				it "should check that the passwords match", ->
					@bcrypt.compare
						.calledWith(@unencryptedPassword, @hashedPassword)
						.should.equal true

				it "should return the user", ->
					@callback.calledWith(null, @user).should.equal true

			describe "when the encrypted passwords do not match", ->
				beforeEach ->
					@AuthenticationManager._encryptPassword = sinon.stub().returns("Not the encrypted password")
					@AuthenticationManager.authenticate(email: @email, @unencryptedPassword, @callback)

				it "should not return the user", ->
					@callback.calledWith(null, null).should.equal true

			describe "when the hashed password matches but the number of rounds is too low", ->
				beforeEach (done) ->
					@user.hashedPassword = @hashedPassword = "asdfjadflasdf"
					@bcrypt.compare = sinon.stub().callsArgWith(2, null, true)
					@bcrypt.getRounds = sinon.stub().returns 7
					@AuthenticationManager.setUserPassword = sinon.stub().callsArgWith(2, null)
					@AuthenticationManager.authenticate email: @email, @unencryptedPassword, (error, user) =>
						@callback(error, user)
						done()

				it "should look up the correct user in the database", ->
					@User.findOne.calledWith(email: @email).should.equal true

				it "should check that the passwords match", ->
					@bcrypt.compare
						.calledWith(@unencryptedPassword, @hashedPassword)
						.should.equal true

				it "should check the number of rounds", ->
					@bcrypt.getRounds.called.should.equal true

				it "should set the users password (with a higher number of rounds)", ->
					@AuthenticationManager.setUserPassword
						.calledWith("user-id", @unencryptedPassword)
						.should.equal true

				it "should return the user", ->
					@callback.calledWith(null, @user).should.equal true

		describe "when the user does not exist in the database", ->
			beforeEach ->
				@User.findOne = sinon.stub().callsArgWith(1, null, null)
				@AuthenticationManager.authenticate(email: @email, @unencrpytedPassword, @callback)

			it "should not return a user", ->
				@callback.calledWith(null, null).should.equal true

	describe "validateEmail", ->
		describe "valid", ->
			it "should return null", ->
				result = @AuthenticationManager.validateEmail 'foo@example.com'
				expect(result).to.equal null

		describe "invalid", ->
			it "should return validation error object for no email", ->
				result = @AuthenticationManager.validateEmail ''
				expect(result).to.not.equal null
				expect(result.message).to.equal 'email not valid'

			it "should return validation error object for invalid", ->
				result = @AuthenticationManager.validateEmail 'notanemail'
				expect(result).to.not.equal null
				expect(result.message).to.equal 'email not valid'

	describe "validatePassword", ->
		it "should return null if valid", ->
			result = @AuthenticationManager.validatePassword 'banana'
			expect(result).to.equal null

		describe "invalid", ->
			beforeEach ->
				@settings.passwordStrengthOptions =
					length:
						max:10
						min:6

			it "should return validation error object if not set", ->
				result = @AuthenticationManager.validatePassword()
				expect(result).to.not.equal null
				expect(result.message).to.equal 'password not set'

			it "should return validation error object if too short", ->
				result = @AuthenticationManager.validatePassword 'dsd'
				expect(result).to.not.equal null
				expect(result.message).to.equal 'password is too short'

			it "should return validation error object if too long", ->
				result = @AuthenticationManager.validatePassword 'dsdsadsadsadsadsadkjsadjsadjsadljs'
				expect(result).to.not.equal null
				expect(result.message).to.equal 'password is too long'

	describe "setUserPassword", ->
		beforeEach ->
			@user_id = ObjectId()
			@password = "banana"
			@hashedPassword = "asdkjfa;osiuvandf"
			@salt = "saltaasdfasdfasdf"
			@bcrypt.genSalt = sinon.stub().callsArgWith(1, null, @salt)
			@bcrypt.hash = sinon.stub().callsArgWith(2, null, @hashedPassword)
			@db.users.update = sinon.stub().callsArg(2)

		describe "too long", ->
			beforeEach ->
				@settings.passwordStrengthOptions =
					length: 
						max:10
				@password = "dsdsadsadsadsadsadkjsadjsadjsadljs"

			it "should return and error", (done)->
				@AuthenticationManager.setUserPassword @user_id, @password, (err)->
					expect(err).to.exist
					done()

			it "should not start the bcrypt process", (done)->
				@AuthenticationManager.setUserPassword @user_id, @password, (err)=>
					@bcrypt.genSalt.called.should.equal false
					@bcrypt.hash.called.should.equal false
					done()

		describe "too short", ->
			beforeEach ->
				@settings.passwordStrengthOptions =
					length:
						max:10
						min:6
				@password = "dsd"

			it "should return and error", (done)->
				@AuthenticationManager.setUserPassword @user_id, @password, (err)->
					expect(err).to.exist
					done()

			it "should not start the bcrypt process", (done)->
				@AuthenticationManager.setUserPassword @user_id, @password, (err)=>
					@bcrypt.genSalt.called.should.equal false
					@bcrypt.hash.called.should.equal false
					done()

		describe "successful set", ->
			beforeEach -> 
				@AuthenticationManager.setUserPassword(@user_id, @password, @callback)

			it "should update the user's password in the database", ->
				args = @db.users.update.lastCall.args
				expect(args[0]).to.deep.equal {_id: ObjectId(@user_id.toString())}
				expect(args[1]).to.deep.equal {
					$set: {
						"hashedPassword": @hashedPassword
					}
					$unset: password: true
				}

			it "should hash the password", ->
				@bcrypt.genSalt
					.calledWith(12)
					.should.equal true
				@bcrypt.hash
					.calledWith(@password, @salt)
					.should.equal true

			it "should call the callback", ->
				@callback.called.should.equal true



