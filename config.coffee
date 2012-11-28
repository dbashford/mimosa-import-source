"use strict"

path = require 'path'
fs = require 'fs'

windowsDrive = /^[A-Za-z]:\\/

exports.defaults = ->
  importSource:
    copy:[]

exports.placeholder = ->
  """
  \t

    # importSource:
      # copy: []       # an array of folders and or files to copy and where to copy them, for
                       # more information see https://github.com/dbashford/mimosa-import-source

  """

exports.validate = (config) ->
  errors = []

  if config.importSource?
    importSource = config.importSource
    if typeof importSource is "object" and not Array.isArray(importSource)
      if importSource.copy?
        copies = importSource.copy
        if Array.isArray(copies)
          for c in copies
            if typeof c is "object" and not Array.isArray(c)

              if c.from?
                if typeof c.from is "string"
                  fromPath = __determinePath c.from, config.root
                  if fs.existsSync fromPath
                    stat = fs.statSync fromPath
                    c.from = fromPath
                    c.isDirectory = stat.isDirectory()
                  else
                    errors.push "importSource.copy.from [[ #{c.from} ]] must exist."
                else
                  errors.push "importSource.copy.from must be a string."
              else
                errors.push "importSource.copy entries must have a from property."

              if c.to?
                if typeof c.to is "string"
                  c.to = __determinePath c.to, config.root
                else
                  errors.push "importSource.copy.to must be a string."
              else
                errors.push "importSource.copy entries must have a to property."

              if c.from?
                if c.exclude?
                  if Array.isArray(c.exclude)
                    regexes = []
                    newExclude = []
                    for exclude in c.exclude
                      if typeof exclude is "string"
                        newExclude.push __determinePath exclude, c.from
                      else if exclude instanceof RegExp
                        regexes.push exclude.source
                      else
                        errors.push "importSource.copy.exclude must be an array of strings and/or regexes."
                        break

                    if regexes.length > 0
                      c.excludeRegex = new RegExp regexes.join("|"), "i"

                    c.exclude = newExclude
                  else
                    errors.push "importSource.copy.exclude must be an array."
                else
                  c.excludeRegex = new RegExp /(^[.#]|(?:__|~)$)/

            else
              errors.push "importSource.copy must be an array of objects"
              break
        else
          errors.push "importSource.copy must be an array"
    else
      errors.push "importSource config must be an object."

  errors


__determinePath = (thePath, relativeTo) ->
  return thePath if windowsDrive.test thePath
  return thePath if thePath.indexOf("/") is 0
  path.join relativeTo, thePath