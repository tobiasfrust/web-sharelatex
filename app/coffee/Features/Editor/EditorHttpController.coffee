ProjectEntityUpdateHandler = require "../Project/ProjectEntityUpdateHandler"
ProjectDeleter = require "../Project/ProjectDeleter"
logger = require "logger-sharelatex"
EditorRealTimeController = require "./EditorRealTimeController"
EditorController = require "./EditorController"
ProjectGetter = require('../Project/ProjectGetter')
UserGetter = require('../User/UserGetter')
AuthorizationManager = require("../Authorization/AuthorizationManager")
ProjectEditorHandler = require('../Project/ProjectEditorHandler')
Metrics = require('metrics-sharelatex')
CollaboratorsHandler = require("../Collaborators/CollaboratorsHandler")
CollaboratorsInviteHandler = require("../Collaborators/CollaboratorsInviteHandler")
PrivilegeLevels = require "../Authorization/PrivilegeLevels"
TokenAccessHandler = require '../TokenAccess/TokenAccessHandler'
AuthenticationController = require "../Authentication/AuthenticationController"

module.exports = EditorHttpController =
	joinProject: (req, res, next) ->
		project_id = req.params.Project_id
		user_id = req.query.user_id
		if user_id == "anonymous-user"
			user_id = null
		logger.log {user_id, project_id}, "join project request"
		Metrics.inc "editor.join-project"
		EditorHttpController._buildJoinProjectView req, project_id, user_id, (error, project, privilegeLevel) ->
			return next(error) if error?
			# Hide access tokens if this is not the project owner
			TokenAccessHandler.protectTokens(project, privilegeLevel)
			res.json {
				project: project
				privilegeLevel: privilegeLevel
			}
			# Only show the 'renamed or deleted' message once
			if project?.deletedByExternalDataSource
				ProjectDeleter.unmarkAsDeletedByExternalSource project_id

	_buildJoinProjectView: (req, project_id, user_id, callback = (error, project, privilegeLevel) ->) ->
		logger.log {project_id, user_id}, "building the joinProject view"
		ProjectGetter.getProjectWithoutDocLines project_id, (error, project) ->
			return callback(error) if error?
			return callback(new Error("not found")) if !project?
			CollaboratorsHandler.getInvitedMembersWithPrivilegeLevels project_id, (error, members) ->
				return callback(error) if error?
				token = TokenAccessHandler.getRequestToken(req, project_id)
				AuthorizationManager.getPrivilegeLevelForProject user_id, project_id, token, (error, privilegeLevel) ->
					return callback(error) if error?
					if !privilegeLevel? or privilegeLevel == PrivilegeLevels.NONE
						logger.log {project_id, user_id, privilegeLevel}, "not an acceptable privilege level, returning null"
						return callback null, null, false
					CollaboratorsInviteHandler.getAllInvites project_id, (error, invites) ->
						return callback(error) if error?
						logger.log {project_id, user_id, memberCount: members.length, inviteCount: invites.length, privilegeLevel}, "returning project model view"
						callback(null,
							ProjectEditorHandler.buildProjectModelView(project, members, invites),
							privilegeLevel
						)

	_nameIsAcceptableLength: (name)->
		return name? and name.length < 150 and name.length != 0

	addDoc: (req, res, next) ->
		project_id = req.params.Project_id
		name = req.body.name
		parent_folder_id = req.body.parent_folder_id
		user_id = AuthenticationController.getLoggedInUserId(req)
		logger.log project_id:project_id, name:name, parent_folder_id:parent_folder_id, "getting request to add doc to project"
		if !EditorHttpController._nameIsAcceptableLength(name)
			return res.sendStatus 400
		EditorController.addDoc project_id, parent_folder_id, name, [], "editor", user_id, (error, doc) ->
			if error == "project_has_to_many_files"
				res.status(400).json(req.i18n.translate("project_has_to_many_files"))
			else if error?
				next(error)
			else
				res.json doc

	addFolder: (req, res, next) ->
		project_id = req.params.Project_id
		name = req.body.name
		parent_folder_id = req.body.parent_folder_id
		if !EditorHttpController._nameIsAcceptableLength(name)
			return res.sendStatus 400
		EditorController.addFolder project_id, parent_folder_id, name, "editor", (error, doc) ->
			if error == "project_has_to_many_files"
				res.status(400).json(req.i18n.translate("project_has_to_many_files"))
			else if error?.message == 'invalid element name'
				res.status(400).json(req.i18n.translate('invalid_file_name'))
			else if error?
				next(error)
			else
				res.json doc

	renameEntity: (req, res, next) ->
		project_id  = req.params.Project_id
		entity_id   = req.params.entity_id
		entity_type = req.params.entity_type
		name = req.body.name
		if !EditorHttpController._nameIsAcceptableLength(name)
			return res.sendStatus 400
		user_id = AuthenticationController.getLoggedInUserId(req)
		EditorController.renameEntity project_id, entity_id, entity_type, name, user_id, (error) ->
			return next(error) if error?
			res.sendStatus 204

	moveEntity: (req, res, next) ->
		project_id  = req.params.Project_id
		entity_id   = req.params.entity_id
		entity_type = req.params.entity_type
		folder_id = req.body.folder_id
		user_id = AuthenticationController.getLoggedInUserId(req)
		EditorController.moveEntity project_id, entity_id, folder_id, entity_type, user_id, (error) ->
			return next(error) if error?
			res.sendStatus 204

	deleteDoc: (req, res, next)->
		req.params.entity_type  = "doc"
		EditorHttpController.deleteEntity(req, res, next)

	deleteFile: (req, res, next)->
		req.params.entity_type = "file"
		EditorHttpController.deleteEntity(req, res, next)

	deleteFolder: (req, res, next)->
		req.params.entity_type = "folder"
		EditorHttpController.deleteEntity(req, res, next)

	deleteEntity: (req, res, next) ->
		project_id  = req.params.Project_id
		entity_id   = req.params.entity_id
		entity_type = req.params.entity_type
		user_id = AuthenticationController.getLoggedInUserId(req)
		EditorController.deleteEntity project_id, entity_id, entity_type, "editor", user_id, (error) ->
			return next(error) if error?
			res.sendStatus 204
