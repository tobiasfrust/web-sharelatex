ExportsHandler = require("./ExportsHandler")
AuthenticationController = require("../Authentication/AuthenticationController")
logger = require("logger-sharelatex")

module.exports =

	exportProject: (req, res, next) ->
		{project_id, brand_variation_id} = req.params
		user_id = AuthenticationController.getLoggedInUserId(req)
		export_params = {
			project_id: project_id,
			brand_variation_id: brand_variation_id,
			user_id: user_id
		}

		if req.body
			export_params.first_name = req.body.firstName.trim() if req.body.firstName
			export_params.last_name = req.body.lastName.trim() if req.body.lastName
			# additional parameters for gallery exports
			export_params.title = req.body.title.trim() if req.body.title
			export_params.description = req.body.description.trim() if req.body.description
			export_params.author = req.body.author.trim() if req.body.author
			export_params.license = req.body.license.trim() if req.body.license
			export_params.show_source = req.body.showSource if req.body.showSource?

		ExportsHandler.exportProject export_params, (err, export_data) ->
			return next(err) if err?
			logger.log
				user_id:user_id
				project_id: project_id
				brand_variation_id:brand_variation_id
				export_v1_id:export_data.v1_id
				"exported project"
			res.send export_v1_id: export_data.v1_id

	exportStatus: (req, res) ->
		{export_id} = req.params
		ExportsHandler.fetchExport export_id, (err, export_json) ->
			if err?
				json = {
					status_summary: 'failed',
					status_detail: err.toString,
				}
				res.send export_json: json
				return err
			parsed_export = JSON.parse(export_json)
			json = {
				status_summary: parsed_export.status_summary,
				status_detail: parsed_export.status_detail,
				partner_submission_id: parsed_export.partner_submission_id,
				token: parsed_export.token
			}
			res.send export_json: json

	exportDownload: (req, res, next) ->
		{type, export_id} = req.params

		AuthenticationController.getLoggedInUserId(req)
		ExportsHandler.fetchDownload export_id, type, (err, export_file_url) ->
			return next(err) if err?

			res.redirect export_file_url
