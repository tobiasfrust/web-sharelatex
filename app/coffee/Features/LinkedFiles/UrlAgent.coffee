request = require 'request'
_ = require "underscore"
urlValidator = require 'valid-url'
{ InvalidUrlError, UrlFetchFailedError } = require './LinkedFilesErrors'
LinkedFilesHandler = require './LinkedFilesHandler'
UrlHelper = require '../Helpers/UrlHelper'

module.exports = UrlAgent = {

	createLinkedFile: (project_id, linkedFileData, name, parent_folder_id, user_id, callback) ->
		linkedFileData = @._sanitizeData(linkedFileData)
		@_getUrlStream project_id, linkedFileData, user_id, (err, readStream) ->
			return callback(err) if err?
			readStream.on "error", callback
			readStream.on "response", (response) ->
				if 200 <= response.statusCode < 300
					readStream.resume()
					LinkedFilesHandler.importFromStream project_id,
						readStream,
						linkedFileData,
						name,
						parent_folder_id,
						user_id,
						(err, file) ->
							return callback(err) if err?
							callback(null, file._id) # Created
				else
					error = new UrlFetchFailedError("url fetch failed: #{linkedFileData.url}")
					error.statusCode = response.statusCode
					callback(error)

	refreshLinkedFile: (project_id, linkedFileData, name, parent_folder_id, user_id, callback) ->
		@createLinkedFile project_id, linkedFileData, name, parent_folder_id, user_id, callback

	_sanitizeData: (data) ->
		return {
			provider: data.provider
			url: UrlHelper.prependHttpIfNeeded(data.url)
		}

	_getUrlStream: (project_id, data, current_user_id, callback = (error, fsPath) ->) ->
		callback = _.once(callback)
		url = data.url
		if !urlValidator.isWebUri(url)
			return callback(new InvalidUrlError("invalid url: #{url}"))
		url = UrlHelper.wrapUrlWithProxy(url)
		readStream = request.get(url)
		readStream.pause()
		callback(null, readStream)

}
