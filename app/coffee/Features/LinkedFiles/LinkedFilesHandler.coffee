FileWriter = require '../../infrastructure/FileWriter'
EditorController = require '../Editor/EditorController'
ProjectLocator = require '../Project/ProjectLocator'
Project = require("../../models/Project").Project
ProjectGetter = require("../Project/ProjectGetter")
_ = require 'underscore'
{
	ProjectNotFoundError,
	V1ProjectNotFoundError,
	BadDataError
} = require './LinkedFilesErrors'


module.exports = LinkedFilesHandler =

	getFileById: (project_id, file_id, callback=(err, file)->) ->
		ProjectLocator.findElement {
			project_id,
			element_id: file_id,
			type: 'file'
		}, (err, file, path, parentFolder) ->
			return callback(err) if err?
			callback(null, file, path, parentFolder)

	getSourceProject: (data, callback=(err, project)->) ->
		projection = {_id: 1, name: 1}
		if data.v1_source_doc_id?
			Project.findOne {'overleaf.id': data.v1_source_doc_id}, projection, (err, project) ->
				return callback(err) if err?
				if !project?
					return callback(new V1ProjectNotFoundError())
				callback(null, project)
		else if data.source_project_id?
			ProjectGetter.getProject data.source_project_id, projection, (err, project) ->
				return callback(err) if err?
				if !project?
					return callback(new ProjectNotFoundError())
				callback(null, project)
		else
			callback(new BadDataError('neither v1 nor v2 id present'))

	importFromStream: (
		project_id,
		readStream,
		linkedFileData,
		name,
		parent_folder_id,
		user_id,
		callback=(err, file)->
	) ->
		callback = _.once(callback)
		FileWriter.writeStreamToDisk project_id, readStream, (err, fsPath) ->
			return callback(err) if err?
			EditorController.upsertFile project_id,
				parent_folder_id,
				name,
				fsPath,
				linkedFileData,
				"upload",
				user_id,
				(err, file) =>
					return callback(err) if err?
					callback(null, file)

	importContent: (
		project_id,
		content,
		linkedFileData,
		name,
		parent_folder_id,
		user_id,
		callback=(err, file)->
	) ->
		callback = _.once(callback)
		FileWriter.writeContentToDisk project_id, content, (err, fsPath) ->
			return callback(err) if err?
			EditorController.upsertFile project_id,
				parent_folder_id,
				name,
				fsPath,
				linkedFileData,
				"upload",
				user_id,
				(err, file) =>
					return callback(err) if err?
					callback(null, file)
