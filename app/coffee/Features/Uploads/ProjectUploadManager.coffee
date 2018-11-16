path = require "path"
rimraf = require "rimraf"
ArchiveManager          = require "./ArchiveManager"
FileSystemImportManager = require "./FileSystemImportManager"
ProjectCreationHandler  = require "../Project/ProjectCreationHandler"
ProjectRootDocManager   = require "../Project/ProjectRootDocManager"
ProjectDetailsHandler   = require "../Project/ProjectDetailsHandler"

module.exports = ProjectUploadHandler =
	createProjectFromZipArchive: (owner_id, proposedName, zipPath, callback = (error, project) ->) ->
		ProjectDetailsHandler.generateUniqueName owner_id, proposedName, (error, name) =>
			return callback(error) if error?
			ProjectCreationHandler.createBlankProject owner_id, name, (error, project) =>
				return callback(error) if error?
				@insertZipArchiveIntoFolder owner_id, project._id, project.rootFolder[0]._id, zipPath, (error) ->
					return callback(error) if error?
					ProjectRootDocManager.setRootDocAutomatically project._id, (error) ->
						return callback(error) if error?
						callback(error, project)

	insertZipArchiveIntoFolder: (owner_id, project_id, folder_id, path, callback = (error) ->) ->
		destination = @_getDestinationDirectory path
		ArchiveManager.extractZipArchive path, destination, (error) ->
			return callback(error) if error?
			ArchiveManager.findTopLevelDirectory destination, (error, topLevelDestination) ->
				return callback(error) if error?
				FileSystemImportManager.addFolderContents owner_id, project_id, folder_id, topLevelDestination, false, (error) ->
					return callback(error) if error?
					rimraf(destination, callback)

	_getDestinationDirectory: (source) ->
		return path.join(path.dirname(source), "#{path.basename(source, ".zip")}-#{Date.now()}")
		
