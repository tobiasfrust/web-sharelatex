SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../../app/js/Features/Editor/EditorHttpController'

describe "EditorHttpController", ->
	beforeEach ->
		@EditorHttpController = SandboxedModule.require modulePath, requires:
			'../Project/ProjectEntityUpdateHandler' : @ProjectEntityUpdateHandler = {}
			'../Project/ProjectDeleter' : @ProjectDeleter = {}
			'../Project/ProjectGetter' : @ProjectGetter = {}
			'../User/UserGetter' : @UserGetter = {}
			"../Authorization/AuthorizationManager": @AuthorizationManager = {}
			'../Project/ProjectEditorHandler': @ProjectEditorHandler = {}
			"./EditorRealTimeController": @EditorRealTimeController = {}
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
			"./EditorController": @EditorController = {}
			'metrics-sharelatex': @Metrics = {inc: sinon.stub()}
			"../Collaborators/CollaboratorsHandler": @CollaboratorsHandler = {}
			"../Collaborators/CollaboratorsInviteHandler": @CollaboratorsInviteHandler = {}
			"../TokenAccess/TokenAccessHandler": @TokenAccessHandler = {}
			"../Authentication/AuthenticationController": @AuthenticationController = {}

		@project_id = "mock-project-id"
		@doc_id = "mock-doc-id"
		@user_id = "mock-user-id"
		@parent_folder_id = "mock-folder-id"
		@userId = 1234
		@AuthenticationController.getLoggedInUserId = sinon.stub().returns(@userId)
		@req = {}
		@res =
			send: sinon.stub()
			sendStatus: sinon.stub()
			json: sinon.stub()
		@callback = sinon.stub()
		@TokenAccessHandler.getRequestToken = sinon.stub().returns(@token = null)
		@TokenAccessHandler.protectTokens = sinon.stub()
			
	describe "joinProject", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
			@req.query =
				user_id: @user_id
			@projectView = {
				_id: @project_id
			}
			@EditorHttpController._buildJoinProjectView = sinon.stub().callsArgWith(3, null, @projectView, "owner")
			@ProjectDeleter.unmarkAsDeletedByExternalSource = sinon.stub()
			
		describe "successfully", ->
			beforeEach ->
				@EditorHttpController.joinProject @req, @res
				
			it "should get the project view", ->
				@EditorHttpController._buildJoinProjectView
					.calledWith(@req, @project_id, @user_id)
					.should.equal true
					
			it "should return the project and privilege level", ->
				@res.json
					.calledWith({
						project: @projectView
						privilegeLevel: "owner"
					})
					.should.equal true
					
			it "should not try to unmark the project as deleted", ->
				@ProjectDeleter.unmarkAsDeletedByExternalSource 
					.called
					.should.equal false
					
			it "should send an inc metric", ->
				@Metrics.inc
					.calledWith("editor.join-project")
					.should.equal true
					
		describe "when the project is marked as deleted", ->	
			beforeEach ->
				@projectView.deletedByExternalDataSource = true
				@EditorHttpController.joinProject @req, @res
				
			it "should unmark the project as deleted", ->
				@ProjectDeleter.unmarkAsDeletedByExternalSource 
					.calledWith(@project_id)
					.should.equal true
					
		describe "with an anonymous user", ->
			beforeEach ->
				@req.query =
					user_id: "anonymous-user"
				@EditorHttpController.joinProject @req, @res
			
			it "should pass the user id as null", ->
				@EditorHttpController._buildJoinProjectView
					.calledWith(@req, @project_id, null)
					.should.equal true

	describe "_buildJoinProjectView", ->
		beforeEach ->
			@project =
				_id: @project_id
				owner_ref:{_id:"something"}
			@user =
				_id: @user_id = "user-id"
				projects: {}
			@members = ["members", "mock"]
			@tokenMembers = ['one', 'two']
			@projectModelView = 
				_id: @project_id
				owner:{_id:"something"}
				view: true
			@invites = [
				{_id: "invite_one", email: "user-one@example.com", privileges: "readOnly", projectId: @project._id}
				{_id: "invite_two", email: "user-two@example.com", privileges: "readOnly", projectId: @project._id}
			]
			@ProjectEditorHandler.buildProjectModelView = sinon.stub().returns(@projectModelView)
			@ProjectGetter.getProjectWithoutDocLines = sinon.stub().callsArgWith(1, null, @project)
			@CollaboratorsHandler.getInvitedMembersWithPrivilegeLevels = sinon.stub().callsArgWith(1, null, @members)
			@CollaboratorsHandler.getTokenMembersWithPrivilegeLevels = sinon.stub().callsArgWith(1, null, @tokenMembers)
			@CollaboratorsInviteHandler.getAllInvites = sinon.stub().callsArgWith(1, null, @invites)
			@UserGetter.getUser = sinon.stub().callsArgWith(2, null, @user)
				
		describe "when authorized", ->
			beforeEach ->
				@AuthorizationManager.getPrivilegeLevelForProject =
					sinon.stub().callsArgWith(3, null, "owner")
				@EditorHttpController._buildJoinProjectView(@req, @project_id, @user_id, @callback)
				
			it "should find the project without doc lines", ->
				@ProjectGetter.getProjectWithoutDocLines
					.calledWith(@project_id)
					.should.equal true

			it "should get the list of users in the project", ->
				@CollaboratorsHandler.getInvitedMembersWithPrivilegeLevels
					.calledWith(@project_id)
					.should.equal true

			it "should check the privilege level", ->
				@AuthorizationManager.getPrivilegeLevelForProject
					.calledWith(@user_id, @project_id, @token)
					.should.equal true

			it 'should include the invites', ->
				@CollaboratorsInviteHandler.getAllInvites
					.calledWith(@project._id)
					.should.equal true

			it "should return the project model view, privilege level and protocol version", ->
				@callback.calledWith(null, @projectModelView, "owner").should.equal true
				
		describe "when not authorized", ->
			beforeEach ->
				@AuthorizationManager.getPrivilegeLevelForProject =
					sinon.stub().callsArgWith(3, null, null)
				@EditorHttpController._buildJoinProjectView(@req, @project_id, @user_id, @callback)
				
			it "should return false in the callback", ->
				@callback.calledWith(null, null, false).should.equal true

	describe "addDoc", ->
		beforeEach ->
			@doc = { "mock": "doc" }
			@req.params =
				Project_id: @project_id
			@req.body =
				name: @name = "doc-name"
				parent_folder_id: @parent_folder_id
			@EditorController.addDoc = sinon.stub().callsArgWith(6, null, @doc)

		describe "successfully", ->
			beforeEach ->
				@EditorHttpController.addDoc @req, @res

			it "should call EditorController.addDoc", ->
				@EditorController.addDoc
					.calledWith(@project_id, @parent_folder_id, @name, [], "editor", @userId)
					.should.equal true

			it "should send the doc back as JSON", ->
				@res.json
					.calledWith(@doc)
					.should.equal true

		describe "unsuccesfully", ->
			beforeEach ->
				@req.body.name = ""
				@EditorHttpController.addDoc @req, @res

			it "should send back a bad request status code", ->
				@res.sendStatus.calledWith(400).should.equal true

	describe "addFolder", ->
		beforeEach ->
			@folder = { "mock": "folder" }
			@req.params =
				Project_id: @project_id
			@req.body =
				name: @name = "folder-name"
				parent_folder_id: @parent_folder_id
			@EditorController.addFolder = sinon.stub().callsArgWith(4, null, @folder)

		describe "successfully", ->
			beforeEach ->
				@EditorHttpController.addFolder @req, @res

			it "should call EditorController.addFolder", ->
				@EditorController.addFolder
					.calledWith(@project_id, @parent_folder_id, @name, "editor")
					.should.equal true

			it "should send the folder back as JSON", ->
				@res.json
					.calledWith(@folder)
					.should.equal true

		describe "unsuccesfully", ->

			beforeEach ->
				@req.body.name = ""
				@EditorHttpController.addFolder @req, @res

			it "should send back a bad request status code", ->
				@res.sendStatus.calledWith(400).should.equal true


	describe "renameEntity", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@req.body =
				name: @name = "new-name"
			@EditorController.renameEntity = sinon.stub().callsArg(5)
			@EditorHttpController.renameEntity @req, @res

		it "should call EditorController.renameEntity", ->
			@EditorController.renameEntity
				.calledWith(@project_id, @entity_id, @entity_type, @name, @userId)
				.should.equal true

		it "should send back a success response", ->
			@res.sendStatus.calledWith(204).should.equal true

	describe "renameEntity with long name", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@req.body =
				name: @name = "EDMUBEEBKBXUUUZERMNSXFFWIBHGSDAWGMRIQWJBXGWSBVWSIKLFPRBYSJEKMFHTRZBHVKJSRGKTBHMJRXPHORFHAKRNPZGGYIOTEDMUBEEBKBXUUUZERMNSXFFWIBHGSDAWGMRIQWJBXGWSBVWSIKLFPRBYSJEKMFHTRZBHVKJSRGKTBHMJRXPHORFHAKRNPZGGYIOT"
			@EditorController.renameEntity = sinon.stub().callsArg(4)
			@EditorHttpController.renameEntity @req, @res

		it "should send back a bad request status code", ->
			@res.sendStatus.calledWith(400).should.equal true

	describe "rename entity with 0 length name", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@req.body =
				name: @name = ""
			@EditorController.renameEntity = sinon.stub().callsArg(4)
			@EditorHttpController.renameEntity @req, @res

		it "should send back a bad request status code", ->
			@res.sendStatus.calledWith(400).should.equal true

	describe "moveEntity", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@req.body =
				folder_id: @folder_id = "folder-id-123"
			@EditorController.moveEntity = sinon.stub().callsArg(5)
			@EditorHttpController.moveEntity @req, @res

		it "should call EditorController.moveEntity", ->
			@EditorController.moveEntity
				.calledWith(@project_id, @entity_id, @folder_id, @entity_type, @userId)
				.should.equal true

		it "should send back a success response", ->
			@res.sendStatus.calledWith(204).should.equal true

	describe "deleteEntity", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@EditorController.deleteEntity = sinon.stub().callsArg(5)
			@EditorHttpController.deleteEntity @req, @res

		it "should call EditorController.deleteEntity", ->
			@EditorController.deleteEntity
				.calledWith(@project_id, @entity_id, @entity_type, "editor", @userId)
				.should.equal true

		it "should send back a success response", ->
			@res.sendStatus.calledWith(204).should.equal true
