"use strict"

config = require './config'

registration = (mimosaConfig, register) ->
  register ['beforeBuild'], 'init', _importSource

_importSource = (mimosaConfig, options, next) ->

  console.log "importing source"
  console.log JSON.stringify(mimosaConfig.importSource, null, 2)

  # error when file from orig project is edited in dest project

  next()

module.exports =
  registration: registration
  defaults:     config.defaults
  placeholder:  config.placeholder
  validate:     config.validate