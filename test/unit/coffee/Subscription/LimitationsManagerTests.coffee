SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../../app/js/Features/Subscription/LimitationsManager'
Settings = require("settings-sharelatex")

describe "LimitationsManager", ->
	beforeEach ->
		@project = { _id: @project_id = "project-id" }
		@user = { _id: @user_id = "user-id", features:{} }
		@ProjectGetter =
			getProject: (project_id, fields, callback) =>
				if project_id == @project_id
					callback null, @project
				else
					callback null, null
		@UserGetter =
			getUser: (user_id, filter, callback) =>
				if user_id == @user_id
					callback null, @user
				else
					callback null, null

		@SubscriptionLocator =
			getUsersSubscription: sinon.stub()
			getSubscription: sinon.stub()

		@LimitationsManager = SandboxedModule.require modulePath, requires:
			'../Project/ProjectGetter': @ProjectGetter
			'../User/UserGetter' : @UserGetter
			'./SubscriptionLocator':@SubscriptionLocator
			'settings-sharelatex' : @Settings = {}
			"../Collaborators/CollaboratorsHandler": @CollaboratorsHandler = {}
			"../Collaborators/CollaboratorsInviteHandler": @CollaboratorsInviteHandler = {}
			"./V1SubscriptionManager": @V1SubscriptionManager = {}
			'logger-sharelatex':log:->

	describe "allowedNumberOfCollaboratorsInProject", ->
		describe "when the project is owned by a user without a subscription", ->
			beforeEach ->
				@Settings.defaultFeatures = collaborators: 23
				@project.owner_ref = @user_id
				delete @user.features
				@callback = sinon.stub()
				@LimitationsManager.allowedNumberOfCollaboratorsInProject(@project_id, @callback)

			it "should return the default number", ->
				@callback.calledWith(null, @Settings.defaultFeatures.collaborators).should.equal true

		describe "when the project is owned by a user with a subscription", ->
			beforeEach ->
				@project.owner_ref = @user_id
				@user.features =
					collaborators: 21
				@callback = sinon.stub()
				@LimitationsManager.allowedNumberOfCollaboratorsInProject(@project_id, @callback)

			it "should return the number of collaborators the user is allowed", ->
				@callback.calledWith(null, @user.features.collaborators).should.equal true

	describe "allowedNumberOfCollaboratorsForUser", ->
		describe "when the user has no features", ->
			beforeEach ->
				@Settings.defaultFeatures = collaborators: 23
				delete @user.features
				@callback = sinon.stub()
				@LimitationsManager.allowedNumberOfCollaboratorsForUser(@user_id, @callback)

			it "should return the default number", ->
				@callback.calledWith(null, @Settings.defaultFeatures.collaborators).should.equal true

		describe "when the user has features", ->
			beforeEach ->
				@user.features =
					collaborators: 21
				@callback = sinon.stub()
				@LimitationsManager.allowedNumberOfCollaboratorsForUser(@user_id, @callback)

			it "should return the number of collaborators the user is allowed", ->
				@callback.calledWith(null, @user.features.collaborators).should.equal true

	describe "canAddXCollaborators", ->
		describe "when the project has fewer collaborators than allowed", ->
			beforeEach ->
				@current_number = 1
				@allowed_number = 2
				@invite_count = 0
				@CollaboratorsHandler.getInvitedCollaboratorCount = (project_id, callback) => callback(null, @current_number)
				@CollaboratorsInviteHandler.getInviteCount = (project_id, callback) => callback(null, @invite_count)
				sinon.stub @LimitationsManager, "allowedNumberOfCollaboratorsInProject", (project_id, callback) =>
					callback(null, @allowed_number)
				@callback = sinon.stub()
				@LimitationsManager.canAddXCollaborators(@project_id, 1, @callback)

			it "should return true", ->
				@callback.calledWith(null, true).should.equal true

		describe "when the project has fewer collaborators and invites than allowed", ->
			beforeEach ->
				@current_number = 1
				@allowed_number = 4
				@invite_count = 1
				@CollaboratorsHandler.getInvitedCollaboratorCount = (project_id, callback) => callback(null, @current_number)
				@CollaboratorsInviteHandler.getInviteCount = (project_id, callback) => callback(null, @invite_count)
				sinon.stub @LimitationsManager, "allowedNumberOfCollaboratorsInProject", (project_id, callback) =>
					callback(null, @allowed_number)
				@callback = sinon.stub()
				@LimitationsManager.canAddXCollaborators(@project_id, 1, @callback)

			it "should return true", ->
				@callback.calledWith(null, true).should.equal true

		describe "when the project has fewer collaborators than allowed but I want to add more than allowed", ->
			beforeEach ->
				@current_number = 1
				@allowed_number = 2
				@invite_count = 0
				@CollaboratorsHandler.getInvitedCollaboratorCount = (project_id, callback) => callback(null, @current_number)
				@CollaboratorsInviteHandler.getInviteCount = (project_id, callback) => callback(null, @invite_count)
				sinon.stub @LimitationsManager, "allowedNumberOfCollaboratorsInProject", (project_id, callback) =>
					callback(null, @allowed_number)
				@callback = sinon.stub()
				@LimitationsManager.canAddXCollaborators(@project_id, 2, @callback)

			it "should return false", ->
				@callback.calledWith(null, false).should.equal true

		describe "when the project has more collaborators than allowed", ->
			beforeEach ->
				@current_number = 3
				@allowed_number = 2
				@invite_count = 0
				@CollaboratorsHandler.getInvitedCollaboratorCount = (project_id, callback) => callback(null, @current_number)
				@CollaboratorsInviteHandler.getInviteCount = (project_id, callback) => callback(null, @invite_count)
				sinon.stub @LimitationsManager, "allowedNumberOfCollaboratorsInProject", (project_id, callback) =>
					callback(null, @allowed_number)
				@callback = sinon.stub()
				@LimitationsManager.canAddXCollaborators(@project_id, 1, @callback)

			it "should return false", ->
				@callback.calledWith(null, false).should.equal true

		describe "when the project has infinite collaborators", ->
			beforeEach ->
				@current_number = 100
				@allowed_number = -1
				@invite_count = 0
				@CollaboratorsHandler.getInvitedCollaboratorCount = (project_id, callback) => callback(null, @current_number)
				@CollaboratorsInviteHandler.getInviteCount = (project_id, callback) => callback(null, @invite_count)
				sinon.stub @LimitationsManager, "allowedNumberOfCollaboratorsInProject", (project_id, callback) =>
					callback(null, @allowed_number)
				@callback = sinon.stub()
				@LimitationsManager.canAddXCollaborators(@project_id, 1, @callback)

			it "should return true", ->
				@callback.calledWith(null, true).should.equal true

		describe 'when the project has more invites than allowed', ->
			beforeEach ->
				@current_number = 0
				@allowed_number = 2
				@invite_count = 2
				@CollaboratorsHandler.getInvitedCollaboratorCount = (project_id, callback) => callback(null, @current_number)
				@CollaboratorsInviteHandler.getInviteCount = (project_id, callback) => callback(null, @invite_count)
				sinon.stub @LimitationsManager, "allowedNumberOfCollaboratorsInProject", (project_id, callback) =>
					callback(null, @allowed_number)
				@callback = sinon.stub()
				@LimitationsManager.canAddXCollaborators(@project_id, 1, @callback)

			it "should return false", ->
				@callback.calledWith(null, false).should.equal true

		describe 'when the project has more invites and collaborators than allowed', ->
			beforeEach ->
				@current_number = 1
				@allowed_number = 2
				@invite_count = 1
				@CollaboratorsHandler.getInvitedCollaboratorCount = (project_id, callback) => callback(null, @current_number)
				@CollaboratorsInviteHandler.getInviteCount = (project_id, callback) => callback(null, @invite_count)
				sinon.stub @LimitationsManager, "allowedNumberOfCollaboratorsInProject", (project_id, callback) =>
					callback(null, @allowed_number)
				@callback = sinon.stub()
				@LimitationsManager.canAddXCollaborators(@project_id, 1, @callback)

			it "should return false", ->
				@callback.calledWith(null, false).should.equal true

	describe "userHasV2Subscription", ->
		beforeEach ->
			@SubscriptionLocator.getUsersSubscription = sinon.stub()

		it "should return true if the recurly token is set", (done)->
			@SubscriptionLocator.getUsersSubscription.callsArgWith(1, null, recurlySubscription_id : "1234")
			@LimitationsManager.userHasV2Subscription @user, (err, hasSubscription)->
				hasSubscription.should.equal true
				done()

		it "should return false if the recurly token is not set", (done)->
			@SubscriptionLocator.getUsersSubscription.callsArgWith(1, null, {})
			@subscription = {}
			@LimitationsManager.userHasV2Subscription @user, (err, hasSubscription)->
				hasSubscription.should.equal false
				done()

		it "should return false if the subscription is undefined", (done)->
			@SubscriptionLocator.getUsersSubscription.callsArgWith(1)
			@LimitationsManager.userHasV2Subscription @user, (err, hasSubscription)->
				hasSubscription.should.equal false
				done()

		it "should return the subscription", (done)->
			stubbedSubscription = {freeTrial:{}, token:""}
			@SubscriptionLocator.getUsersSubscription.callsArgWith(1, null, stubbedSubscription)
			@LimitationsManager.userHasV2Subscription @user, (err, hasSubOrIsGroupMember, subscription)->
				subscription.should.deep.equal stubbedSubscription
				done()

		describe "when user has a custom account", ->

			beforeEach ->
				@fakeSubscription = {customAccount: true}
				@SubscriptionLocator.getUsersSubscription.callsArgWith(1, null, @fakeSubscription)

			it 'should return true', (done) ->
				@LimitationsManager.userHasV2Subscription @user, (err, hasSubscription, subscription)->
					hasSubscription.should.equal true
					done()

			it 'should return the subscription', (done) ->
				@LimitationsManager.userHasV2Subscription @user, (err, hasSubscription, subscription)=>
					subscription.should.deep.equal @fakeSubscription
					done()

	describe "userIsMemberOfGroupSubscription", ->
		beforeEach ->
			@SubscriptionLocator.getMemberSubscriptions = sinon.stub()

		it "should return false if there are no groups subcriptions", (done)->
			@SubscriptionLocator.getMemberSubscriptions.callsArgWith(1, null, [])
			@LimitationsManager.userIsMemberOfGroupSubscription @user, (err, isMember)->
				isMember.should.equal false
				done()

		it "should return true if there are no groups subcriptions", (done)->
			@SubscriptionLocator.getMemberSubscriptions.callsArgWith(1, null, subscriptions = ["mock-subscription"])
			@LimitationsManager.userIsMemberOfGroupSubscription @user, (err, isMember, retSubscriptions)->
				isMember.should.equal true
				retSubscriptions.should.equal subscriptions
				done()

	describe "hasPaidSubscription", ->
		beforeEach ->
			@LimitationsManager.userIsMemberOfGroupSubscription = sinon.stub().yields(null, false)
			@LimitationsManager.userHasV2Subscription = sinon.stub().yields(null, false)
			@LimitationsManager.userHasV1Subscription = sinon.stub().yields(null, false)

		it "should return true if userIsMemberOfGroupSubscription", (done)->
			@LimitationsManager.userIsMemberOfGroupSubscription = sinon.stub().yields(null, true)
			@LimitationsManager.hasPaidSubscription @user, (err, hasSubOrIsGroupMember)->
				hasSubOrIsGroupMember.should.equal true
				done()

		it "should return true if userHasV2Subscription", (done)->
			@LimitationsManager.userHasV2Subscription = sinon.stub().yields(null, true)
			@LimitationsManager.hasPaidSubscription @user, (err, hasSubOrIsGroupMember)->
				hasSubOrIsGroupMember.should.equal true
				done()

		it "should return true if userHasV1Subscription", (done)->
			@LimitationsManager.userHasV1Subscription= sinon.stub().yields(null, true)
			@LimitationsManager.hasPaidSubscription @user, (err, hasSubOrIsGroupMember)->
				hasSubOrIsGroupMember.should.equal true
				done()

		it "should return false if none are true", (done)->
			@LimitationsManager.hasPaidSubscription @user, (err, hasSubOrIsGroupMember)->
				hasSubOrIsGroupMember.should.equal false
				done()

		it "should have userHasSubscriptionOrIsGroupMember alias", (done)->
			@LimitationsManager.userHasSubscriptionOrIsGroupMember @user, (err, hasSubOrIsGroupMember)->
				hasSubOrIsGroupMember.should.equal false
				done()

	describe "userHasV1OrV2Subscription", ->
		beforeEach ->
			@LimitationsManager.userHasV2Subscription = sinon.stub().yields(null, false)
			@LimitationsManager.userHasV1Subscription = sinon.stub().yields(null, false)

		it "should return true if userHasV2Subscription", (done)->
			@LimitationsManager.userHasV2Subscription = sinon.stub().yields(null, true)
			@LimitationsManager.userHasV1OrV2Subscription @user, (err, hasSub)->
				hasSub.should.equal true
				done()

		it "should return true if userHasV1Subscription", (done)->
			@LimitationsManager.userHasV1Subscription = sinon.stub().yields(null, true)
			@LimitationsManager.userHasV1OrV2Subscription @user, (err, hasSub)->
				hasSub.should.equal true
				done()

		it "should return false if none are true", (done)->
			@LimitationsManager.userHasV1OrV2Subscription @user, (err, hasSub)->
				hasSub.should.equal false
				done()

	describe "hasGroupMembersLimitReached", ->

		beforeEach ->
			@subscriptionId = "12312"
			@subscription =
				membersLimit: 3
				member_ids: ["", ""]
				teamInvites: [
					{ email: "bob@example.com", sentAt: new Date(), token: "hey" }
				]

		it "should return true if the limit is hit (including members and invites)", (done)->
			@SubscriptionLocator.getSubscription.callsArgWith(1, null, @subscription)
			@LimitationsManager.hasGroupMembersLimitReached @subscriptionId, (err, limitReached)->
				limitReached.should.equal true
				done()

		it "should return false if the limit is not hit (including members and invites)", (done)->
			@subscription.membersLimit = 4
			@SubscriptionLocator.getSubscription.callsArgWith(1, null, @subscription)
			@LimitationsManager.hasGroupMembersLimitReached @subscriptionId, (err, limitReached)->
				limitReached.should.equal false
				done()

		it "should return true if the limit has been exceded (including members and invites)", (done)->
			@subscription.membersLimit = 2
			@SubscriptionLocator.getSubscription.callsArgWith(1, null, @subscription)
			@LimitationsManager.hasGroupMembersLimitReached @subscriptionId, (err, limitReached)->
				limitReached.should.equal true
				done()

	describe 'userHasV1Subscription', ->
		it 'should return true if v1 returns has_subscription = true', (done) ->
			@V1SubscriptionManager.getSubscriptionsFromV1 = sinon.stub().yields(null, { has_subscription: true })
			@LimitationsManager.userHasV1Subscription @user, (error, result) =>
				@V1SubscriptionManager.getSubscriptionsFromV1.calledWith(@user_id).should.equal true
				result.should.equal true
				done()

		it 'should return false if v1 returns has_subscription = false', (done) ->
			@V1SubscriptionManager.getSubscriptionsFromV1 = sinon.stub().yields(null, { has_subscription: false })
			@LimitationsManager.userHasV1Subscription @user, (error, result) =>
				@V1SubscriptionManager.getSubscriptionsFromV1.calledWith(@user_id).should.equal true
				result.should.equal false
				done()

		it 'should return false if v1 returns nothing', (done) ->
			@V1SubscriptionManager.getSubscriptionsFromV1 = sinon.stub().yields(null, null)
			@LimitationsManager.userHasV1Subscription @user, (error, result) =>
				@V1SubscriptionManager.getSubscriptionsFromV1.calledWith(@user_id).should.equal true
				result.should.equal false
				done()
