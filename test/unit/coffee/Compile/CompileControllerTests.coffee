sinon = require('sinon')
chai = require('chai')
should = chai.should()
assert = require("chai").assert
expect = chai.expect
modulePath = "../../../../app/js/Features/Compile/CompileController.js"
SandboxedModule = require('sandboxed-module')
MockRequest = require "../helpers/MockRequest"
MockResponse = require "../helpers/MockResponse"

describe "CompileController", ->
	beforeEach ->
		@user_id = 'wat'
		@user =
			_id: @user_id
			email: 'user@example.com'
			features:
				compileGroup: "premium"
				compileTimeout: 100
		@CompileManager =
			compile: sinon.stub()
		@ClsiManager = {}
		@UserGetter =
			getUser:sinon.stub()
		@RateLimiter = {addCount:sinon.stub()}
		@settings =
			apis:
				clsi:
					url: "clsi.example.com"
				clsi_priority:
					url: "clsi-priority.example.com"
			defaultFeatures:
				compileGroup: 'standard'
				compileTimeout: 60
		@jar = {cookie:"stuff"}
		@ClsiCookieManager =
			getCookieJar:sinon.stub().callsArgWith(1, null, @jar)
		@AuthenticationController =
			getLoggedInUser: sinon.stub().callsArgWith(1, null, @user)
			getLoggedInUserId: sinon.stub().returns(@user_id)
			getSessionUser: sinon.stub().returns(@user)
			isUserLoggedIn: sinon.stub().returns(true)
		@CompileController = SandboxedModule.require modulePath, requires:
			"settings-sharelatex": @settings
			"request": @request = sinon.stub()
			'../Project/ProjectGetter': @ProjectGetter = {}
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
			"metrics-sharelatex": @Metrics =  { inc: sinon.stub() }
			"./CompileManager":@CompileManager
			"../User/UserGetter":@UserGetter
			"./ClsiManager": @ClsiManager
			"../Authentication/AuthenticationController": @AuthenticationController
			"../../infrastructure/RateLimiter":@RateLimiter
			"./ClsiCookieManager": ()=> @ClsiCookieManager
		@project_id = "project-id"
		@next = sinon.stub()
		@req = new MockRequest()
		@res = new MockResponse()

	describe "compile", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
			@req.session = {}
			@CompileManager.compile = sinon.stub().callsArgWith(3, null, @status = "success", @outputFiles = ["mock-output-files"])

		describe "when not an auto compile", ->
			beforeEach ->
				@CompileController.compile @req, @res, @next

			it "should look up the user id", ->
				@AuthenticationController.getLoggedInUserId
					.calledWith(@req)
					.should.equal true

			it "should do the compile without the auto compile flag", ->
				@CompileManager.compile
					.calledWith(@project_id, @user_id, { isAutoCompile: false })
					.should.equal true

			it "should set the content-type of the response to application/json", ->
				@res.contentType
					.calledWith("application/json")
					.should.equal true

			it "should send a successful response reporting the status and files", ->
				@res.statusCode.should.equal 200
				@res.body.should.equal JSON.stringify({
					status: @status
					outputFiles: @outputFiles
				})

		describe "when an auto compile", ->
			beforeEach ->
				@req.query =
					auto_compile: "true"
				@CompileController.compile @req, @res, @next

			it "should do the compile with the auto compile flag", ->
				@CompileManager.compile
					.calledWith(@project_id, @user_id, { isAutoCompile: true })
					.should.equal true

		describe "with the draft attribute", ->
			beforeEach ->
				@req.body =
					draft: true
				@CompileController.compile @req, @res, @next

			it "should do the compile without the draft compile flag", ->
				@CompileManager.compile
					.calledWith(@project_id, @user_id, { isAutoCompile: false, draft: true })
					.should.equal true

	describe "compileSubmission", ->
		beforeEach ->
			@submission_id = 'sub-1234'
			@req.params =
				submission_id: @submission_id
			@req.body = {}
			@ClsiManager.sendExternalRequest = sinon.stub()
				.callsArgWith(3, null, @status = "success", @outputFiles = ["mock-output-files"], \
					@clsiServerId = "mock-server-id", @validationProblems = null)

		it "should set the content-type of the response to application/json", ->
			@CompileController.compileSubmission @req, @res, @next
			@res.contentType
				.calledWith("application/json")
				.should.equal true

		it "should send a successful response reporting the status and files", ->
			@CompileController.compileSubmission @req, @res, @next
			@res.statusCode.should.equal 200
			@res.body.should.equal JSON.stringify({
				status: @status
				outputFiles: @outputFiles
				clsiServerId: 'mock-server-id'
				validationProblems: null
			})

		describe "with compileGroup and timeout", ->
			beforeEach ->
				@req.body =
					compileGroup: 'special'
					timeout: 600
				@CompileController.compileSubmission @req, @res, @next

			it "should use the supplied values", ->
				@ClsiManager.sendExternalRequest
					.calledWith(@submission_id, { compileGroup: 'special', timeout: 600 }, \
						{ compileGroup: 'special', timeout: 600 })
					.should.equal true

		describe "with other supported options but not compileGroup and timeout", ->
			beforeEach ->
				@req.body =
					rootResourcePath: 'main.tex'
					compiler: 'lualatex'
					draft: true
					check: 'validate'
				@CompileController.compileSubmission @req, @res, @next

			it "should use the other options but default values for compileGroup and timeout", ->
				@ClsiManager.sendExternalRequest
					.calledWith(@submission_id, \
						{rootResourcePath: 'main.tex', compiler: 'lualatex', draft: true, check: 'validate'}, \
						{rootResourcePath: 'main.tex', compiler: 'lualatex', draft: true, check: 'validate', \
						compileGroup: 'standard', timeout: 60})
					.should.equal true

	describe "downloadPdf", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id

			@req.query = {pdfng:true}
			@project = name: "test namè"
			@ProjectGetter.getProject = sinon.stub().callsArgWith(2, null, @project)

		describe "when downloading for embedding", ->
			beforeEach ->
				@CompileController.proxyToClsi = sinon.stub()
				@RateLimiter.addCount.callsArgWith(1, null, true)
				@CompileController.downloadPdf(@req, @res, @next)

			it "should look up the project", ->
				@ProjectGetter.getProject
					.calledWith(@project_id, {name: 1})
					.should.equal true

			it "should set the content-type of the response to application/pdf", ->
				@res.contentType
					.calledWith("application/pdf")
					.should.equal true

			it "should set the content-disposition header with a safe version of the project name", ->
				@res.setContentDisposition
					.calledWith('', filename: "test_nam_.pdf")
					.should.equal true

			it "should increment the pdf-downloads metric", ->
				@Metrics.inc
					.calledWith("pdf-downloads")
					.should.equal true

			it "should proxy the PDF from the CLSI", ->
				@CompileController.proxyToClsi.calledWith(@project_id, "/project/#{@project_id}/user/#{@user_id}/output/output.pdf", @req, @res, @next).should.equal true

		describe "when the pdf is not going to be used in pdfjs viewer", ->

			it "should check the rate limiter when pdfng is not set", (done)->
				@req.query = {}
				@RateLimiter.addCount.callsArgWith(1, null, true)
				@CompileController.proxyToClsi = (project_id, url)=>
					@RateLimiter.addCount.args[0][0].throttle.should.equal 1000
					done()
				@CompileController.downloadPdf @req, @res


			it "should check the rate limiter when pdfng is false", (done)->
				@req.query = {pdfng:false}
				@RateLimiter.addCount.callsArgWith(1, null, true)
				@CompileController.proxyToClsi = (project_id, url)=>
					@RateLimiter.addCount.args[0][0].throttle.should.equal 1000
					done()
				@CompileController.downloadPdf @req, @res

	describe "getFileFromClsiWithoutUser", ->
		beforeEach ->
			@submission_id = 'sub-1234'
			@build_id = 123456
			@file = 'project.pdf'
			@req.params =
				submission_id: @submission_id
				build_id: @build_id
				file: @file
			@req.body = {}
			@expected_url = "/project/#{@submission_id}/build/#{@build_id}/output/#{@file}"
			@CompileController.proxyToClsiWithLimits = sinon.stub()

		describe "without limits specified", ->
			beforeEach ->
				@CompileController.getFileFromClsiWithoutUser @req, @res, @next

			it "should proxy to CLSI with correct URL and default limits", ->
				@CompileController.proxyToClsiWithLimits
					.calledWith(@submission_id, @expected_url, {compileGroup: 'standard'})
					.should.equal true

		describe "with limits specified", ->
			beforeEach ->
				@req.body = {compileTimeout: 600, compileGroup: 'special'}
				@CompileController.getFileFromClsiWithoutUser @req, @res, @next

			it "should proxy to CLSI with correct URL and specified limits", ->
				@CompileController.proxyToClsiWithLimits
					.calledWith(@submission_id, @expected_url, {compileGroup: 'special'})
					.should.equal true

	describe "proxyToClsi", ->
		beforeEach ->
			@request.returns(@proxy = {
				pipe: sinon.stub()
				on: sinon.stub()
			})
			@upstream =
				statusCode: 204
				headers: { "mock": "header" }
			@req.method = "mock-method"
			@req.headers = {
				'Mock': 'Headers',
				'Range': '123-456'
				'If-Range': 'abcdef'
				'If-Modified-Since': 'Mon, 15 Dec 2014 15:23:56 GMT'
			}

		describe "old pdf viewer", ->
			describe "user with standard priority", ->
				beforeEach ->
					@CompileManager.getProjectCompileLimits = sinon.stub().callsArgWith(1, null, {compileGroup: "standard"})
					@CompileController.proxyToClsi(@project_id, @url = "/test", @req, @res, @next)

				it "should open a request to the CLSI", ->
					@request
						.calledWith(
							jar:@jar
							method: @req.method
							url: "#{@settings.apis.clsi.url}#{@url}",
							timeout: 60 * 1000
						)
						.should.equal true

				it "should pass the request on to the client", ->
					@proxy.pipe
						.calledWith(@res)
						.should.equal true

				it "should bind an error handle to the request proxy", ->
					@proxy.on.calledWith("error").should.equal true

			describe "user with priority compile", ->
				beforeEach ->
					@CompileManager.getProjectCompileLimits = sinon.stub().callsArgWith(1, null, {compileGroup: "priority"})
					@CompileController.proxyToClsi(@project_id, @url = "/test", @req, @res, @next)

			describe "user with standard priority via query string", ->
				beforeEach ->
					@req.query = {compileGroup: 'standard'}
					@CompileController.proxyToClsi(@project_id, @url = "/test", @req, @res, @next)

				it "should open a request to the CLSI", ->
					@request
						.calledWith(
							jar:@jar
							method: @req.method
							url: "#{@settings.apis.clsi.url}#{@url}",
							timeout: 60 * 1000
						)
						.should.equal true

				it "should pass the request on to the client", ->
					@proxy.pipe
						.calledWith(@res)
						.should.equal true

				it "should bind an error handle to the request proxy", ->
					@proxy.on.calledWith("error").should.equal true


			describe "user with non-existent priority via query string", ->
				beforeEach ->
					@req.query = {compileGroup: 'foobar'}
					@CompileController.proxyToClsi(@project_id, @url = "/test", @req, @res, @next)

				it "should proxy to the standard url", ()->
					@request
						.calledWith(
							jar:@jar
							method: @req.method
							url: "#{@settings.apis.clsi.url}#{@url}",
							timeout: 60 * 1000
						)
						.should.equal true

			describe "user with build parameter via query string", ->
				beforeEach ->
					@CompileManager.getProjectCompileLimits = sinon.stub().callsArgWith(1, null, {compileGroup: "standard"})
					@req.query = {build: 1234}
					@CompileController.proxyToClsi(@project_id, @url = "/test", @req, @res, @next)

				it "should proxy to the standard url without the build parameter", ()->
					@request
						.calledWith(
							jar:@jar
							method: @req.method
							url: "#{@settings.apis.clsi.url}#{@url}",
							timeout: 60 * 1000
						)
						.should.equal true

		describe "new pdf viewer", ->
			beforeEach ->
				@req.query = {pdfng: true}
			describe "user with standard priority", ->
				beforeEach ->
					@CompileManager.getProjectCompileLimits = sinon.stub().callsArgWith(1, null, {compileGroup: "standard"})
					@CompileController.proxyToClsi(@project_id, @url = "/test", @req, @res, @next)

				it "should open a request to the CLSI", ->
					@request
						.calledWith(
							jar:@jar
							method: @req.method
							url: "#{@settings.apis.clsi.url}#{@url}",
							timeout: 60 * 1000
							headers: {
								'Range': '123-456'
								'If-Range': 'abcdef'
								'If-Modified-Since': 'Mon, 15 Dec 2014 15:23:56 GMT'
							}
						)
						.should.equal true

				it "should pass the request on to the client", ->
					@proxy.pipe
						.calledWith(@res)
						.should.equal true

				it "should bind an error handle to the request proxy", ->
					@proxy.on.calledWith("error").should.equal true



			describe "user with build parameter via query string", ->
				beforeEach ->
					@CompileManager.getProjectCompileLimits = sinon.stub().callsArgWith(1, null, {compileGroup: "standard"})
					@req.query = {build: 1234, pdfng: true}
					@CompileController.proxyToClsi(@project_id, @url = "/test", @req, @res, @next)

				it "should proxy to the standard url with the build parameter", ()->
					@request.calledWith(
							jar:@jar
							method: @req.method
							qs: {build: 1234}
							url: "#{@settings.apis.clsi.url}#{@url}",
							timeout: 60 * 1000
							headers: {
								'Range': '123-456'
								'If-Range': 'abcdef'
								'If-Modified-Since': 'Mon, 15 Dec 2014 15:23:56 GMT'
							}
						)
						.should.equal true

	describe "deleteAuxFiles", ->
		beforeEach ->
			@CompileManager.deleteAuxFiles = sinon.stub().callsArg(2)
			@req.params =
				Project_id: @project_id
			@res.sendStatus = sinon.stub()
			@CompileController.deleteAuxFiles @req, @res, @next

		it "should proxy to the CLSI", ->
			@CompileManager.deleteAuxFiles
				.calledWith(@project_id)
				.should.equal true

		it "should return a 200", ->
			@res.sendStatus
				.calledWith(200)
				.should.equal true

	describe "compileAndDownloadPdf", ->
		beforeEach ->
			@req =
				params:
					project_id:@project_id
			@CompileManager.compile.callsArgWith(3)
			@CompileController.proxyToClsi = sinon.stub()
			@res =
				send:=>

		it "should call compile in the compile manager", (done)->
			@CompileController.compileAndDownloadPdf @req, @res
			@CompileManager.compile.calledWith(@project_id).should.equal true
			done()

		it "should proxy the res to the clsi with correct url", (done)->
			@CompileController.compileAndDownloadPdf @req, @res
			sinon.assert.calledWith @CompileController.proxyToClsi, @project_id, "/project/#{@project_id}/output/output.pdf", @req, @res

			@CompileController.proxyToClsi.calledWith(@project_id, "/project/#{@project_id}/output/output.pdf", @req, @res).should.equal true
			done()

	describe "wordCount", ->
		beforeEach ->
			@CompileManager.wordCount = sinon.stub().callsArgWith(3, null, {content:"body"})
			@req.params =
				Project_id: @project_id
			@res.send = sinon.stub()
			@res.contentType = sinon.stub()
			@CompileController.wordCount @req, @res, @next

		it "should proxy to the CLSI", ->
			@CompileManager.wordCount
				.calledWith(@project_id, @user_id, false)
				.should.equal true

		it "should return a 200 and body", ->
			@res.send
				.calledWith({content:"body"})
				.should.equal true
