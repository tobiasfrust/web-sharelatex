ProjectEntityHandler = require "./ProjectEntityHandler"
ProjectEntityUpdateHandler = require "./ProjectEntityUpdateHandler"
ProjectGetter = require "./ProjectGetter"
Path = require "path"
async = require("async")
_ = require("underscore")

module.exports = ProjectRootDocManager =
	setRootDocAutomatically: (project_id, callback = (error) ->) ->

		ProjectEntityHandler.getAllDocs project_id, (error, docs) ->
			return callback(error) if error?


			root_doc_id = null
			jobs = _.map docs, (doc, path)->
				return (cb)->
					rootDocId = null
					for line in doc.lines || []
						# We've had problems with this regex locking up CPU.
						# Previously /.*\\documentclass/ would totally lock up on lines of 500kb (data text files :()
						# This regex will only look from the start of the line, including whitespace so will return quickly
						# regardless of line length.
						match = /^\s*\\documentclass/.test(line)
						isRootDoc = /\.R?tex$/.test(Path.extname(path)) and match
						if isRootDoc
							rootDocId = doc?._id
					cb(rootDocId)

			async.series jobs, (root_doc_id)->
				if root_doc_id?
					ProjectEntityUpdateHandler.setRootDoc project_id, root_doc_id, callback
				else
					callback()

	setRootDocFromName: (project_id, rootDocName, callback = (error) ->) ->
		ProjectEntityHandler.getAllDocPathsFromProjectById project_id, (error, docPaths) ->
			return callback(error) if error?
			# strip off leading and trailing quotes from rootDocName
			rootDocName = rootDocName.replace(/^\'|\'$/g,"")
			# prepend a slash for the root folder if not present
			rootDocName = "/#{rootDocName}" if rootDocName[0] isnt '/'
			# find the root doc from the filename
			root_doc_id = null
			for doc_id, path of docPaths
				# docpaths have a leading / so allow matching "folder/filename" and "/folder/filename"
				if path == rootDocName
					root_doc_id = doc_id
			# try a basename match if there was no match
			if !root_doc_id
				for doc_id, path of docPaths
					if Path.basename(path) == Path.basename(rootDocName)
						root_doc_id = doc_id
			# set the root doc id if we found a match
			if root_doc_id?
				ProjectEntityUpdateHandler.setRootDoc project_id, root_doc_id, callback
			else
				callback()

	ensureRootDocumentIsSet: (project_id, callback = (error) ->) ->
		ProjectGetter.getProject project_id, rootDoc_id: 1, (error, project) ->
			return callback(error) if error?
			if !project?
				return callback new Error("project not found")

			if project.rootDoc_id?
				callback()
			else
				ProjectRootDocManager.setRootDocAutomatically project_id, callback

	ensureRootDocumentIsValid: (project_id, callback = (error) ->) ->
		ProjectGetter.getProject project_id, rootDoc_id: 1, (error, project) ->
			return callback(error) if error?
			if !project?
				return callback new Error("project not found")

			if project.rootDoc_id?
				ProjectEntityHandler.getAllDocPathsFromProjectById project_id, (error, docPaths) ->
					return callback(error) if error?
					rootDocValid = false
					for doc_id, _path of docPaths
						if doc_id == project.rootDoc_id
							rootDocValid = true
					if rootDocValid
						callback()
					else
						ProjectEntityUpdateHandler.setRootDoc project_id, null, ->
							ProjectRootDocManager.setRootDocAutomatically project_id, callback
			else
				ProjectRootDocManager.setRootDocAutomatically project_id, callback
