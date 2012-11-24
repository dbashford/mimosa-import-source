"use strict"

exports.defaults = ->
  importSource:[]

exports.placeholder = ->
  """
  \t

    # importSource: []

  """

exports.validate = (config) ->
  errors = []
  errors
