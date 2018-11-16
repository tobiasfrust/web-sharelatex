logger                  = require "logger-sharelatex"
Metrics                 = require "metrics-sharelatex"
ProjectGetter           = require('../Project/ProjectGetter')
ProjectZipStreamManager = require "./ProjectZipStreamManager"
DocumentUpdaterHandler  = require "../DocumentUpdater/DocumentUpdaterHandler"

module.exports = ProjectDownloadsController =
	downloadProject: (req, res, next) ->
		project_id = req.params.Project_id
		Metrics.inc "zip-downloads"
		logger.log project_id: project_id, "downloading project"
		DocumentUpdaterHandler.flushProjectToMongo project_id, (error)->
			return next(error) if error?
			ProjectGetter.getProject project_id, name: true, (error, project) ->
				return next(error) if error?
				ProjectZipStreamManager.createZipStreamForProject project_id, (error, stream) ->
					return next(error) if error?
					res.setContentDisposition(
						'attachment',
						{filename: "#{project.name}.zip"}
					)
					res.contentType('application/zip')
					stream.pipe(res)

	downloadMultipleProjects: (req, res, next) ->
		project_ids = req.query.project_ids.split(",")
		Metrics.inc "zip-downloads-multiple"
		logger.log project_ids: project_ids, "downloading multiple projects"
		DocumentUpdaterHandler.flushMultipleProjectsToMongo project_ids, (error) ->
			return next(error) if error?
			ProjectZipStreamManager.createZipStreamForMultipleProjects project_ids, (error, stream) ->
				return next(error) if error?
				res.setContentDisposition(
					'attachment',
					{filename: "Overleaf Projects (#{project_ids.length} items).zip"}
				)
				res.contentType('application/zip')
				stream.pipe(res)


