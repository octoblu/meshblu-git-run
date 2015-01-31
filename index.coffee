'use strict';
_              = require 'lodash'
child_process  = require 'child_process'
debug          = require('debug')('meshblu-git-run')
fs             = require 'fs-extra'
path           = require 'path'
util           = require 'util'
{EventEmitter} = require 'events'

MESSAGE_SCHEMA =
  type: 'object'
  properties:
    command:
      type: 'string'
      required: true
      enum: ['start', 'stop']

OPTIONS_SCHEMA =
  type: 'object'
  properties:
    gitRepo:
      type: 'string'
      required: true
      default: 'https://github.com/org/project'
    setup:
      type: 'string'
      required: true
      default: 'npm install'
    run:
      type: 'string'
      required: true
      default: 'npm start'

class Plugin extends EventEmitter
  constructor: ->
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA
    @commands = {start: @startCommand, stop: @stopCommand}
    @tmpDir = path.join __dirname, 'tmp'

  onMessage: (message) =>
    payload = message.payload;
    command = @commands[payload.command]
    return unless command?
    command (error, stdout, stderr) =>
      if  error?
        @emit 'error', error
        @emit 'message', devices: '*', error: error
        return

      @emit 'message', devices: '*', stdout: stdout, stderr

  onConfig: (device) =>
    @setOptions device.options

  setOptions: (options={}) =>
    @options = options
    projectDirName = path.basename @options.gitRepo, '.git'
    @dir = path.join @tmpDir, projectDirName

  setUuid: (@uuid={}) =>

  startCommand: (callback=->) =>
    @setup (error) =>
      return callback error if error?

      @runCommand @options.run, callback

  setup: (callback=->) =>
    @setupDirs (error) =>
      return callback error if error?
      @runCommand @options.setup, callback

  setupDirs: (callback=->) =>
    fs.mkdirp @tmpDir, (error) =>
      return callback error if error?
      fs.remove @dir, (error) =>
        return callback error if error?
        command =  "git clone #{@options.gitRepo}"
        @runCommand command, @tmpDir, callback

  runCommand: (command, cwd, callback=->) =>
    if _.isFunction cwd
      callback = cwd
      cwd      = @dir

    debug 'run', cwd: cwd, command

    child_process.exec command, cwd: cwd, (error, stdout, stderr) =>
      if error?
        error.stdout = stdout
        error.stderr = stderr
        return callback error
      callback null, stdout, stderr


module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
