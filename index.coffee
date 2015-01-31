'use strict';
util           = require 'util'
{EventEmitter} = require 'events'
debug          = require('debug')('meshblu-git-run')
child_process  = require 'child_process'
fs             = require 'fs-extra'
path           = require 'path'

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
    @dir = path.join __dirname, 'tmp'

  onMessage: (message) =>
    payload = message.payload;
    command = @commands[payload.command]
    return unless command?
    command (error, stdout) =>
      if error?
        @emit 'error', error
        @emit 'message', error: error
        return

      @emit 'message', stdout: stdout

  onConfig: (device) =>
    @setOptions device.options

  setOptions: (@options={}) =>
  setUuid: (@uuid={}) =>

  startCommand: (callback=->) =>
    @setup (error) =>
      return callback error if error?

      @runCommand @options.start, callback

  setup: (callback=->) =>
    mkdirp @dir, (error) =>
      return callback error if error?
      @runCommand @options.setup, callback

  runCommand: (command, callback=->) =>
    child_process.exec command, cwd: @dir, (error, stdout, stderr) =>
      if error?
        error.stdout = stdout
        error.stderr = stderr
        return callback error
      callback null, stdout


module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
