should = require('chai').should()
SandboxedModule = require('sandboxed-module')
assert = require('assert')
path = require('path')
modulePath = path.join __dirname, '../../../../app/js/Features/User/UserRegistrationHandler'
sinon = require("sinon")
expect = require("chai").expect
EmailHelper = require '../../../../app/js/Features/Helpers/EmailHelper'

describe "UserRegistrationHandler", ->

	beforeEach ->
		@user =
			_id: @user_id = "31j2lk21kjl"
		@User = 
			update: sinon.stub().callsArgWith(2)
		@UserGetter =
			getUserByAnyEmail: sinon.stub()
		@UserCreator = 
			createNewUser:sinon.stub().callsArgWith(1, null, @user)
		@AuthenticationManager =
			validateEmail: sinon.stub().returns(null)
			validatePassword: sinon.stub().returns(null)
			setUserPassword: sinon.stub().callsArgWith(2)
		@NewsLetterManager =
			subscribe: sinon.stub().callsArgWith(1)
		@EmailHandler =
			sendEmail:sinon.stub().callsArgWith(2)
		@OneTimeTokenHandler =
			getNewToken: sinon.stub()
		@handler = SandboxedModule.require modulePath, requires:
			"../../models/User": {User:@User}
			"./UserGetter": @UserGetter
			"./UserCreator": @UserCreator
			"../Authentication/AuthenticationManager":@AuthenticationManager
			"../Newsletter/NewsletterManager":@NewsLetterManager
			"logger-sharelatex": @logger = { log: sinon.stub() }
			"crypto": @crypto = {}
			"../Email/EmailHandler": @EmailHandler
			"../Security/OneTimeTokenHandler": @OneTimeTokenHandler
			"../Analytics/AnalyticsManager": @AnalyticsManager = { recordEvent: sinon.stub() }
			"settings-sharelatex": @settings = {siteUrl: "http://sl.example.com"}
			"../Helpers/EmailHelper": EmailHelper

		@passingRequest = {email:"something@email.com", password:"123"}


	describe 'validate Register Request', ->
		it 'allows passing validation through', ->
			result = @handler._registrationRequestIsValid @passingRequest
			result.should.equal true

		describe 'failing email validation', ->
			beforeEach ->
				@AuthenticationManager.validateEmail.returns({ message: 'email not set' })

			it 'does not allow through', ->
				result = @handler._registrationRequestIsValid @passingRequest
				result.should.equal false

		describe 'failing password validation', ->
			beforeEach ->
				@AuthenticationManager.validatePassword.returns({ message: 'password is too short' })

			it 'does not allow through', ->
				result = @handler._registrationRequestIsValid @passingRequest
				result.should.equal false

	describe "registerNewUser", ->

		describe "holdingAccount", (done)->

			beforeEach ->
				@user.holdingAccount = true
				@handler._registrationRequestIsValid = sinon.stub().returns true
				@UserGetter.getUserByAnyEmail.callsArgWith(1, null, @user)

			it "should not create a new user if there is a holding account there", (done)->
				@handler.registerNewUser @passingRequest, (err)=>
					@UserCreator.createNewUser.called.should.equal false
					done()

			it "should set holding account to false", (done)->
				@handler.registerNewUser @passingRequest, (err)=>
					update = @User.update.args[0]
					assert.deepEqual update[0], {_id:@user._id}
					assert.deepEqual update[1], {"$set":{holdingAccount:false}}
					done()

		describe "invalidRequest", ->

			it "should not create a new user if the the request is not valid", (done)->
				@handler._registrationRequestIsValid = sinon.stub().returns false
				@handler.registerNewUser @passingRequest, (err)=>
					expect(err).to.exist
					@UserCreator.createNewUser.called.should.equal false
					done()

			it "should return email registered in the error if there is a non holdingAccount there", (done)->
				@UserGetter.getUserByAnyEmail.callsArgWith(1, null, @user = {holdingAccount:false})
				@handler.registerNewUser @passingRequest, (err, user)=>
					err.should.deep.equal new Error("EmailAlreadyRegistered")
					user.should.deep.equal @user
					done()

		describe "validRequest", ->
			beforeEach ->
				@handler._registrationRequestIsValid = sinon.stub().returns true
				@UserGetter.getUserByAnyEmail.callsArgWith 1

			it "should create a new user", (done)->
				@handler.registerNewUser @passingRequest, (err)=>
					@UserCreator.createNewUser.calledWith({email:@passingRequest.email, holdingAccount:false, first_name:@passingRequest.first_name, last_name:@passingRequest.last_name}).should.equal true
					done()

			it 'lower case email', (done)->
				@passingRequest.email = "soMe@eMail.cOm"
				@handler.registerNewUser @passingRequest, (err)=>
					@UserCreator.createNewUser.args[0][0].email.should.equal "some@email.com"
					done()

			it 'trim white space from email', (done)->
				@passingRequest.email = " some@email.com "
				@handler.registerNewUser @passingRequest, (err)=>
					@UserCreator.createNewUser.args[0][0].email.should.equal "some@email.com"
					done()


			it "should set the password", (done)->
				@handler.registerNewUser @passingRequest, (err)=>
					@AuthenticationManager.setUserPassword.calledWith(@user._id, @passingRequest.password).should.equal true
					done()			

			it "should add the user to the newsletter if accepted terms", (done)->
				@passingRequest.subscribeToNewsletter = "true"
				@handler.registerNewUser @passingRequest, (err)=>
					@NewsLetterManager.subscribe.calledWith(@user).should.equal true
					done()

			it "should not add the user to the newsletter if not accepted terms", (done)->
				@handler.registerNewUser @passingRequest, (err)=>
					@NewsLetterManager.subscribe.calledWith(@user).should.equal false
					done()

			it "should track the registration event", (done)->
				@handler.registerNewUser @passingRequest, (err)=>
					@AnalyticsManager.recordEvent
						.calledWith(@user._id, "user-registered")
						.should.equal true
					done()


		it "should call the ReferalAllocator", (done)->
			done()

	describe "registerNewUserAndSendActivationEmail", ->
		beforeEach ->
			@email = "email@example.com"
			@crypto.randomBytes = sinon.stub().returns({toString: () => @password = "mock-password"})
			@OneTimeTokenHandler.getNewToken.yields(null, @token = "mock-token")
			@handler.registerNewUser = sinon.stub()
			@callback = sinon.stub()
		
		describe "with a new user", ->
			beforeEach ->
				@handler.registerNewUser.callsArgWith(1, null, @user)
				@handler.registerNewUserAndSendActivationEmail @email, @callback
			
			it "should ask the UserRegistrationHandler to register user", ->
				@handler.registerNewUser
					.calledWith({
						email: @email
						password: @password
					}).should.equal true
					
			it "should generate a new password reset token", ->
				
				@OneTimeTokenHandler.getNewToken
					.calledWith('password', @user_id, expiresIn: 7 * 24 * 60 * 60)
					.should.equal true

			it "should send a registered email", ->
				@EmailHandler.sendEmail
					.calledWith("registered", {
						to: @user.email
						setNewPasswordUrl: "#{@settings.siteUrl}/user/activate?token=#{@token}&user_id=#{@user_id}"
					})
					.should.equal true
			
			it "should return the user", ->
				@callback
					.calledWith(null, @user, "#{@settings.siteUrl}/user/activate?token=#{@token}&user_id=#{@user_id}")
					.should.equal true

		describe "with a user that already exists", ->
			beforeEach ->
				@handler.registerNewUser.callsArgWith(1, new Error("EmailAlreadyRegistered"), @user)
				@handler.registerNewUserAndSendActivationEmail @email, @callback
				
			it "should still generate a new password token and email", ->
				@OneTimeTokenHandler.getNewToken.called.should.equal true
				@EmailHandler.sendEmail.called.should.equal true