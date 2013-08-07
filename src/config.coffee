"use strict"

fs = require 'fs'

exports.defaults = ->
  importSource:
    interval: 500
    binaryInterval: 1000
    copy:[]

exports.placeholder = ->
  """
  \t

    # importSource:
      # interval: 500         # Interval of file system polling
      # binaryInterval: 1000  # Interval of file system polling for binary files
      # copy: []              # an array of folders and or files to copy and where to copy them,
                              # for more information see https://github.com/dbashford/mimosa-import-source

  """

exports.validate = (config, validators) ->
  errors = []

  if validators.ifExistsIsObject(errors, "importSource config", config.importSource)

    validators.isNumber(errors, "importSource.interval", config.importSource.interval)
    validators.isNumber(errors, "importSource.binaryInterval", config.importSource.binaryInterval)

    if config.importSource.copy?
      if validators.isArray(errors, "importSource.copy", config.importSource.copy)
        for c in config.importSource.copy
          if typeof c is "object" and not Array.isArray(c)

            if c.from?
              if typeof c.from is "string"
                fromPath = validators.determinePath c.from, config.root
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
                c.to = validators.determinePath c.to, config.root
              else
                errors.push "importSource.copy.to must be a string."
            else
              errors.push "importSource.copy entries must have a to property."

            if c.from?
              validators.ifExistsFileExcludeWithRegexAndString(errors, "importSource.copy.exclude", c, c.from)

          else
            errors.push "importSource.copy must be an array of objects"
            break

  errors