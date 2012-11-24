"use strict"

config = require './config'

registration = (mimosaConfig, register) ->
  register ['beforeBuild'], 'init', _importSource

_importSource = (mimosaConfig, options, next) ->

  console.log "importing source"

  next()

module.exports =
  registration: registration
  defaults:     config.defaults
  placeholder:  config.placeholder
  validate:     config.validate