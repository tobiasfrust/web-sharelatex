fs = require "fs"
PackageVersions = require "./app/coffee/infrastructure/PackageVersions"
Settings = require "settings-sharelatex"
require('es6-promise').polyfill()

module.exports = (grunt) ->
	grunt.loadNpmTasks 'grunt-contrib-coffee'
	grunt.loadNpmTasks 'grunt-contrib-less'
	grunt.loadNpmTasks 'grunt-contrib-clean'
	grunt.loadNpmTasks 'grunt-mocha-test'
	grunt.loadNpmTasks 'grunt-available-tasks'
	grunt.loadNpmTasks 'grunt-contrib-requirejs'
	grunt.loadNpmTasks 'grunt-bunyan'
	grunt.loadNpmTasks 'grunt-sed'
	grunt.loadNpmTasks 'grunt-git-rev-parse'
	grunt.loadNpmTasks 'grunt-file-append'
	grunt.loadNpmTasks 'grunt-file-append'
	grunt.loadNpmTasks 'grunt-env'
	grunt.loadNpmTasks 'grunt-newer'
	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.loadNpmTasks 'grunt-parallel'
	grunt.loadNpmTasks 'grunt-exec'
	grunt.loadNpmTasks 'grunt-postcss'
	grunt.loadNpmTasks 'grunt-forever'
	grunt.loadNpmTasks 'grunt-shell'
	# grunt.loadNpmTasks 'grunt-contrib-imagemin'
	# grunt.loadNpmTasks 'grunt-sprity'

	config =

		exec:
			run:
				command:"node app.js | ./node_modules/logger-sharelatex/node_modules/bunyan/bin/bunyan --color"
			cssmin_sl:
				command:"node_modules/clean-css/bin/cleancss --s0 --source-map -o public/stylesheets/style.css public/stylesheets/style.css"
			cssmin_ol:
				command:"node_modules/clean-css/bin/cleancss --s0 --source-map -o public/stylesheets/ol-style.css public/stylesheets/ol-style.css"
			cssmin_ol_light:
				command:"node_modules/clean-css/bin/cleancss --s0 --source-map -o public/stylesheets/ol-light-style.css public/stylesheets/ol-light-style.css"

		forever:
			app:
				options:
					index: "app.js"
					logFile: "app.log"

		watch:
			coffee:
				files: 'public/**/*.coffee'
				tasks: ['quickcompile:coffee']
				options: {}

			less:
				files: '**/*.less'
				tasks: ['compile:css']
				options: {}


		parallel:
			run:
				tasks:['exec', 'watch']
				options:
					grunt:true
					stream:true


		# imagemin:
		# 	dynamic:                       
		# 		files: [{
		# 			expand: true
		# 			cwd: 'public/img/'
		# 			src: ['**/*.{png,jpg,gif}']
		# 			dest: 'public/img/'
		# 		}]
		# 	options:
		# 		interlaced:false
		# 		optimizationLevel: 7

		# sprity:
		# 	sprite:
		# 		options:
		# 			cssPath:"/img/"
		# 			'style': '../../public/stylesheets/app/sprites.less'
		# 			margin: 0
		# 		src: ['./public/img/flags/24/*.png']
		# 		dest: './public/img/sprite'


		coffee:
			app_dir: 
				expand: true,
				flatten: false,
				cwd: 'app/coffee',
				src: ['**/*.coffee'],
				dest: 'app/js/',
				ext: '.js'

			app: 
				src: 'app.coffee'
				dest: 'app.js'

			sharejs:
				options:
					join: true
				files:
					"public/js/libs/sharejs.js": [
						"public/coffee/ide/editor/sharejs/header.coffee"
						"public/coffee/ide/editor/sharejs/vendor/types/helpers.coffee"
						"public/coffee/ide/editor/sharejs/vendor/types/text.coffee"
						"public/coffee/ide/editor/sharejs/vendor/types/text-api.coffee"
						"public/coffee/ide/editor/sharejs/vendor/client/microevent.coffee"
						"public/coffee/ide/editor/sharejs/vendor/client/doc.coffee"
						"public/coffee/ide/editor/sharejs/vendor/client/ace.coffee"
						"public/coffee/ide/editor/sharejs/vendor/client/cm.coffee"
					]

			client:
				expand: true,
				flatten: false,
				cwd: 'public/coffee',
				src: ['**/*.coffee'],
				dest: 'public/js/',
				ext: '.js',
				options:
					sourceMap: true

			smoke_tests:
				expand: true,
				flatten: false,
				cwd: 'test/smoke/coffee',
				src: ['**/*.coffee'],
				dest: 'test/smoke/js/',
				ext: '.js'

			unit_tests: 
				expand: true,
				flatten: false,
				cwd: 'test/unit/coffee',
				src: ['**/*.coffee'],
				dest: 'test/unit/js/',
				ext: '.js'

			acceptance_tests: 
				expand: true,
				flatten: false,
				cwd: 'test/acceptance/coffee',
				src: ['**/*.coffee'],
				dest: 'test/acceptance/js/',
				ext: '.js'

		less:
			app:
				options:
					sourceMap: true
					sourceMapFilename: "public/stylesheets/style.css.map"
					sourceMapBasepath: "public/stylesheets"
					globalVars:
						'is-overleaf': false
						'is-overleaf-light': false
						'show-rich-text': Settings.showRichText
				files:
					"public/stylesheets/style.css": "public/stylesheets/style.less"
			ol:
				options:
					sourceMap: true
					sourceMapFilename: "public/stylesheets/ol-style.css.map"
					sourceMapBasepath: "public/stylesheets"
					globalVars:
						'is-overleaf': true
						'is-overleaf-light': false
						'show-rich-text': Settings.showRichText
				files:
					"public/stylesheets/ol-style.css": "public/stylesheets/ol-style.less"

			'ol-light':
				options:
					sourceMap: true
					sourceMapFilename: "public/stylesheets/ol-light-style.css.map"
					sourceMapBasepath: "public/stylesheets"
					globalVars:
						'is-overleaf': true
						'is-overleaf-light': true
						'show-rich-text': Settings.showRichText
				files:
					"public/stylesheets/ol-light-style.css": "public/stylesheets/ol-light-style.less"

		postcss:
			options:
				map: 
					prev: "public/stylesheets/"
					inline: false
					sourcesContent: true
				processors: [
					require('autoprefixer')({browsers: [ 'last 2 versions', 'ie >= 10' ]})
				]
			dist:
				src: [ "public/stylesheets/style.css", "public/stylesheets/ol-style.css", "public/stylesheets/ol-light-style.css" ]

		env:
			run:
				add: 
					NODE_TLS_REJECT_UNAUTHORIZED:0



		requirejs:
			compile:
				options:
					optimize:"uglify2"
					uglify2:
						mangle: false
					appDir: "public/js"
					baseUrl: "./"
					dir: "public/minjs"
					inlineText: false
					generateSourceMaps: true
					preserveLicenseComments: false
					paths:
						"moment": "libs/#{PackageVersions.lib('moment')}"
						"mathjax": "/js/libs/mathjax/MathJax.js?config=TeX-AMS_HTML"
						"pdfjs-dist/build/pdf": "libs/#{PackageVersions.lib('pdfjs')}/pdf"
						"ace": "#{PackageVersions.lib('ace')}"
						"fineuploader": "libs/#{PackageVersions.lib('fineuploader')}"
					shim:
						"pdfjs-dist/build/pdf":
							deps: ["libs/#{PackageVersions.lib('pdfjs')}/compatibility"]

					skipDirOptimize: true
					modules: [
						{
							name: "main",
							exclude: ["libraries"]
						}, {
							name: "ide",
							exclude: ["pdfjs-dist/build/pdf", "libraries"]
						},{
							name: "libraries"
						},{
							name: "ace/mode-latex"
						},{
							name: "ace/worker-latex"
						}

					]

		clean:
			app: ["app/js"]
			unit_tests: ["test/unit/js"]
			acceptance_tests: ["test/acceptance/js"]

		mochaTest:
			unit:
				src: ["test/unit/js/#{grunt.option('feature') or '**'}/*.js"]
				options:
					reporter: grunt.option('reporter') or 'spec'
					grep: grunt.option("grep")
			smoke:
				src: ['test/smoke/js/**/*.js']
				options:
					reporter: grunt.option('reporter') or 'spec'
					grep: grunt.option("grep")
			acceptance:
				src: ["test/acceptance/js/#{grunt.option('feature') or '**'}/*.js"]
				options:
					timeout: 40000
					reporter: grunt.option('reporter') or 'spec'
					grep: grunt.option("grep")

		"git-rev-parse":
			version:
				options:
					prop: 'commit'


		file_append:
			default_options: files: [ {
				append: '\n//ide.js is complete - used for automated testing'
				input: 'public/minjs/ide.js'
				output: 'public/minjs/ide.js'
			}]

		sed:
			version:
				path: "app/views/sentry.pug"
				pattern: '@@COMMIT@@',
				replacement: '<%= commit %>',
			release:
				path: "app/views/sentry.pug"
				pattern: "@@RELEASE@@"
				replacement: process.env.BUILD_NUMBER || "(unknown build)"

		shell:
			fullAcceptanceTests:
				command: "bash ./test/acceptance/scripts/full-test.sh"
			dockerTests:
				command: 'docker run -v "$(pwd):/app" --env SHARELATEX_ALLOW_PUBLIC_ACCESS=true --rm sharelatex/acceptance-test-runner'

		availabletasks:
			tasks:
				options:
					filter: 'exclude',
					tasks: [
						'coffee'
						'less'
						'clean'
						'mochaTest'
						'availabletasks'
						'wrap_sharejs'
						'requirejs'
						'execute'
						'bunyan'
					]
					groups:
						"Compile tasks": [
							"compile:server"
							"compile:client"
							"compile:tests"
							"compile"
							"compile:unit_tests"
							"compile:smoke_tests"
							"compile:css"
							"compile:minify"
							"install"
						]
						"Test tasks": [
							"test:unit"
							"test:acceptance"
						]
						"Run tasks": [
							"run"
							"default"
						]
						"Misc": [
							"help"
						]

	moduleCompileServerTasks = []
	moduleCompileUnitTestTasks = []
	moduleUnitTestTasks = []
	moduleCompileClientTasks = []
	moduleIdeClientSideIncludes = []
	moduleMainClientSideIncludes = []
	if fs.existsSync "./modules"
		for module in fs.readdirSync "./modules"
			if fs.existsSync "./modules/#{module}/index.coffee"
				config.coffee["module_#{module}_server"] = {
					expand: true,
					flatten: false,
					cwd: "modules/#{module}/app/coffee",
					src: ['**/*.coffee'],
					dest: "modules/#{module}/app/js",
					ext: '.js'
				}
				config.coffee["module_#{module}_index"] = {
					src: "modules/#{module}/index.coffee",
					dest: "modules/#{module}/index.js"
				}
				
				moduleCompileServerTasks.push "coffee:module_#{module}_server"
				moduleCompileServerTasks.push "coffee:module_#{module}_index"
				
				config.coffee["module_#{module}_unit_tests"] = {
					expand: true,
					flatten: false,
					cwd: "modules/#{module}/test/unit/coffee",
					src: ['**/*.coffee'],
					dest: "modules/#{module}/test/unit/js",
					ext: '.js'
				}
				config.mochaTest["module_#{module}_unit"] = {
					src: ["modules/#{module}/test/unit/js/**/*.js"]
					options:
						reporter: grunt.option('reporter') or 'spec'
						grep: grunt.option("grep")
				}
				
				moduleCompileUnitTestTasks.push "coffee:module_#{module}_unit_tests"
				moduleUnitTestTasks.push "mochaTest:module_#{module}_unit"
				
			if fs.existsSync "./modules/#{module}/public/coffee/ide/index.coffee"
				config.coffee["module_#{module}_client_ide"] = {
					expand: true,
					flatten: false,
					cwd: "modules/#{module}/public/coffee/ide",
					src: ['**/*.coffee'],
					dest: "public/js/ide/#{module}",
					ext: '.js'
				}
				moduleCompileClientTasks.push "coffee:module_#{module}_client_ide"
				moduleIdeClientSideIncludes.push "ide/#{module}/index"
				
			if fs.existsSync "./modules/#{module}/public/coffee/main/index.coffee"
				config.coffee["module_#{module}_client_main"] = {
					expand: true,
					flatten: false,
					cwd: "modules/#{module}/public/coffee/main",
					src: ['**/*.coffee'],
					dest: "public/js/main/#{module}",
					ext: '.js'
				}
				moduleCompileClientTasks.push "coffee:module_#{module}_client_main"
				moduleMainClientSideIncludes.push "main/#{module}/index"
	
	grunt.initConfig config

	grunt.registerTask 'wrap_sharejs', 'Wrap the compiled ShareJS code for AMD module loading', () ->
		content = fs.readFileSync "public/js/libs/sharejs.js"
		fs.writeFileSync "public/js/libs/sharejs.js", """
			define(["ace/ace"], function() {
				#{content}
				return window.sharejs;
			});
		"""

	grunt.registerTask 'help', 'Display this help list', 'availabletasks'

	grunt.registerTask 'compile:modules:server', 'Compile all the modules', moduleCompileServerTasks
	grunt.registerTask 'compile:modules:unit_tests', 'Compile all the modules unit tests', moduleCompileUnitTestTasks
	grunt.registerTask 'compile:modules:client', 'Compile all the module client side code', moduleCompileClientTasks
	grunt.registerTask 'compile:modules:inject_clientside_includes', () ->
		content = fs.readFileSync("public/js/ide.js").toString()
		content = content.replace(/, "__IDE_CLIENTSIDE_INCLUDES__"/g, moduleIdeClientSideIncludes.map((i) -> ", \"#{i}\"").join(""))
		fs.writeFileSync "public/js/ide.js", content
		
		content = fs.readFileSync("public/js/main.js").toString()
		content = content.replace(/, "__MAIN_CLIENTSIDE_INCLUDES__"/g, moduleMainClientSideIncludes.map((i) -> ", \"#{i}\"").join(""))
		fs.writeFileSync "public/js/main.js", content
	
	grunt.registerTask 'compile:server', 'Compile the server side coffee script', ['clean:app', 'coffee:app', 'coffee:app_dir', 'compile:modules:server']
	grunt.registerTask 'compile:client', 'Compile the client side coffee script', ['coffee:client', 'coffee:sharejs', 'wrap_sharejs', "compile:modules:client", 'compile:modules:inject_clientside_includes']
	grunt.registerTask 'compile:css', 'Compile the less files to css', ['less', 'postcss:dist']
	grunt.registerTask 'compile:minify', 'Concat and minify the client side js and css', ['requirejs', "file_append", "exec:cssmin_sl", "exec:cssmin_ol", "exec:cssmin_ol_light"]
	grunt.registerTask 'compile:unit_tests', 'Compile the unit tests', ['clean:unit_tests', 'coffee:unit_tests']
	grunt.registerTask 'compile:acceptance_tests', 'Compile the acceptance tests', ['clean:acceptance_tests', 'coffee:acceptance_tests']
	grunt.registerTask 'compile:smoke_tests', 'Compile the smoke tests', ['coffee:smoke_tests']
	grunt.registerTask 'compile:tests', 'Compile all the tests', ['compile:smoke_tests', 'compile:unit_tests', 'compile:acceptance_tests']
	grunt.registerTask 'compile', 'Compiles everything need to run web-sharelatex', ['compile:server', 'compile:client', 'compile:css']
	grunt.registerTask 'quickcompile:coffee', 'Compiles only changed coffee files',['newer:coffee']


	grunt.registerTask 'install', "Compile everything when installing as an npm module", ['compile']

	grunt.registerTask 'test:unit', 'Run the unit tests (use --grep=<regex> or --feature=<feature> for individual tests)', ['compile:server', 'compile:modules:server', 'compile:unit_tests', 'compile:modules:unit_tests', 'mochaTest:unit'].concat(moduleUnitTestTasks)
	grunt.registerTask 'test:acceptance', 'Run the acceptance tests (use --grep=<regex> or --feature=<feature> for individual tests)', ['compile:acceptance_tests', 'mochaTest:acceptance']
	grunt.registerTask 'test:smoke', 'Run the smoke tests', ['compile:smoke_tests', 'mochaTest:smoke']
	
	grunt.registerTask(
		'test:acceptance:full',
		"Start server and run acceptance tests",
		['shell:fullAcceptanceTests']
	)

	grunt.registerTask(
		'test:acceptance:docker',
		"Run acceptance tests inside docker container",
		['compile:acceptance_tests', 'shell:dockerTests']
	)
	
	grunt.registerTask 'test:modules:unit', 'Run the unit tests for the modules', ['compile:modules:server', 'compile:modules:unit_tests'].concat(moduleUnitTestTasks)

	grunt.registerTask 'run:watch', "Compile and run the web-sharelatex server", ['compile', 'env:run', 'parallel']
	grunt.registerTask 'run', "Compile and run the web-sharelatex server", ['compile', 'env:run', 'exec']

	grunt.registerTask 'default', 'run'

	grunt.registerTask 'version', "Write the version number into sentry.pug", ['git-rev-parse', 'sed']

