sinon = require('sinon')
chai = require('chai')
expect = require('chai').expect
modulePath = "../../../../app/js/Features/UserMembership/UserMembershipAuthorization.js"
SandboxedModule = require('sandboxed-module')
MockRequest = require "../helpers/MockRequest"
EntityConfigs = require("../../../../app/js/Features/UserMembership/UserMembershipEntityConfigs")
Errors = require("../../../../app/js/Features/Errors/Errors")

describe "UserMembershipAuthorization", ->
	beforeEach ->
		@req = new MockRequest()
		@req.params.id = 'mock-entity-id'
		@user = _id: 'mock-user-id'
		@subscription = { _id: 'mock-subscription-id'}

		@AuthenticationController =
			getSessionUser: sinon.stub().returns(@user)
		@UserMembershipHandler =
			getEntity: sinon.stub().yields(null, @subscription)
		@AuthorizationMiddlewear =
			redirectToRestricted: sinon.stub().yields()
		@UserMembershipAuthorization = SandboxedModule.require modulePath, requires:
			'../Authentication/AuthenticationController': @AuthenticationController
			'../Authorization/AuthorizationMiddlewear': @AuthorizationMiddlewear
			'./UserMembershipHandler': @UserMembershipHandler
			'./EntityConfigs': EntityConfigs
			'../Errors/Errors': Errors
			"logger-sharelatex":
				log: ->
				err: ->

	describe 'requireAccessToEntity', ->
		it 'get entity', (done) ->
			@UserMembershipAuthorization.requireGroupAccess @req, null, (error) =>
				expect(error).to.not.extist
				sinon.assert.calledWithMatch(
					@UserMembershipHandler.getEntity,
					@req.params.id,
					modelName: 'Subscription',
					@user
				)
				expect(@req.entity).to.equal @subscription
				expect(@req.entityConfig).to.exist
				done()

		it 'handle entity not found', (done) ->
			@UserMembershipHandler.getEntity.yields(null, null)
			@UserMembershipAuthorization.requireGroupAccess @req, null, (error) =>
				expect(error).to.extist
				sinon.assert.called(@AuthorizationMiddlewear.redirectToRestricted)
				sinon.assert.called(@UserMembershipHandler.getEntity)
				expect(@req.entity).to.not.exist
				done()

		it 'handle anonymous user', (done) ->
			@AuthenticationController.getSessionUser.returns(null)
			@UserMembershipAuthorization.requireGroupAccess @req, null, (error) =>
				expect(error).to.extist
				sinon.assert.called(@AuthorizationMiddlewear.redirectToRestricted)
				sinon.assert.notCalled(@UserMembershipHandler.getEntity)
				expect(@req.entity).to.not.exist
				done()

	describe 'requireEntityAccess', ->
		it 'handle team access', (done) ->
			@UserMembershipAuthorization.requireTeamAccess @req, null, (error) =>
				expect(error).to.not.extist
				sinon.assert.calledWithMatch(
					@UserMembershipHandler.getEntity,
					@req.params.id,
					fields: primaryKey: 'overleaf.id'
				)
				done()

		it 'handle group access', (done) ->
			@UserMembershipAuthorization.requireGroupAccess @req, null, (error) =>
				expect(error).to.not.extist
				sinon.assert.calledWithMatch(
					@UserMembershipHandler.getEntity,
					@req.params.id,
					translations: title: 'group_account'
				)
				done()

		it 'handle group managers access', (done) ->
			@UserMembershipAuthorization.requireGroupManagersAccess @req, null, (error) =>
				expect(error).to.not.extist
				sinon.assert.calledWithMatch(
					@UserMembershipHandler.getEntity,
					@req.params.id,
					translations: subtitle: 'managers_management'
				)
				done()

		it 'handle institution access', (done) ->
			@UserMembershipAuthorization.requireInstitutionAccess @req, null, (error) =>
				expect(error).to.not.extist
				sinon.assert.calledWithMatch(
					@UserMembershipHandler.getEntity,
					@req.params.id,
					modelName: 'Institution',
				)
				done()

		it 'handle graph access', (done) ->
			@req.query.resource_id = 'mock-resource-id'
			@req.query.resource_type = 'institution'
			middlewear = @UserMembershipAuthorization.requireGraphAccess
			middlewear @req, null, (error) =>
				expect(error).to.not.extist
				sinon.assert.calledWithMatch(
					@UserMembershipHandler.getEntity,
					@req.query.resource_id,
					modelName: 'Institution',
				)
				done()
