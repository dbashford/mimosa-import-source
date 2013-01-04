"use strict"

fs = require 'fs'
path = require 'path'
watch = require 'chokidar'
wrench = require 'wrench'
logger = require 'logmimosa'
_ = require "lodash"

config = require './config'

isBuild = false

registration = (mimosaConfig, register) ->
  isBuild = mimosaConfig.isBuild

  register ['preBuild'], 'init', _importSource
  register ['postClean'], 'init', _cleanFiles
  register ['postClean'], 'complete', _cleanDirectories

_cleanFiles = (mimosaConfig, options, next) ->
  __do mimosaConfig, __cleanFiles, next

_importSource = (mimosaConfig, options, next) ->
  __do mimosaConfig, __importSource, next

_cleanDirectories = (mimosaConfig, options, next) ->
  __do mimosaConfig, __cleanDirectories, next

__do = (mimosaConfig, execute, next) ->
  if mimosaConfig.importSource?.copy?.length > 0
    i = 0
    done = ->
      if ++i is mimosaConfig.importSource.copy.length
        next()

    for copy in mimosaConfig.importSource.copy
      execute copy, done
  else
    next()

__cleanFiles = (copyConfig, cb) ->
  fs.exists copyConfig.to, (exists) ->
    return cb() unless exists

    allFiles = if copyConfig.isDirectory
      wrench.readdirSyncRecursive(copyConfig.from).map (f) -> path.join copyConfig.from, f
    else
      [copyConfig.from]
    files = allFiles.filter (f) -> not __isExcluded(copyConfig, f) and fs.statSync(f).isFile()

    for file in files
      outPath = __makeToPath file, copyConfig.from, copyConfig.to
      if fs.existsSync outPath
        fs.unlinkSync outPath
        logger.info "mimosa-import-source: Deleted file [[ #{outPath} ]]"

    cb()

__cleanDirectories = (copyConfig, cb) ->
  fs.exists copyConfig.to, (exists) ->
    return cb() unless exists
    return cb() unless copyConfig.isDirectory

    allFiles = wrench.readdirSyncRecursive(copyConfig.from).map (f) -> path.join copyConfig.from, f
    dirs =  allFiles.filter (f) -> fs.statSync(f).isDirectory()

    _.sortBy(dirs, 'length').reverse().forEach (dirPath) ->
      dirPath = __makeToPath dirPath, copyConfig.from, copyConfig.to
      if fs.existsSync dirPath
        fs.rmdir dirPath, (err) ->
          if err?.code is not "ENOTEMPTY"
            logger.error "Unable to delete directory, #{dirPath}"
            logger.error err
          else
            logger.info "mimosa-import-source: Deleted empty directory [[ #{dirPath} ]]"

    cb()

__importSource = (copyConfig, cb) ->
  numFiles = if copyConfig.isDirectory
    files = wrench.readdirSyncRecursive(copyConfig.from).filter (f) ->
      f = path.join copyConfig.from, f
      not __isExcluded(copyConfig, f) and fs.statSync(f).isFile()
    files.length
  else
    1

  if numFiles is 0
    cb()
  else
    __startCopy copyConfig, numFiles, cb

__isExcluded = (copyConfig, file) ->
  if copyConfig.excludeRegex and file.match copyConfig.excludeRegex
    true
  else if copyConfig.exclude?.indexOf(file) > -1
    true
  else
    false

__startCopy = (copyConfig, howManyFiles, cb) ->

  i = 0
  done = ->
    if ++i is howManyFiles
      # error when file from orig project is edited in dest project
      if isBuild
        cb()
      else
        __protectDestination copyConfig, howManyFiles, cb

  ignored = (file) -> __isExcluded(copyConfig, file)

  watcher = watch.watch(copyConfig.from, {ignored:ignored, persistent:!isBuild})
  watcher.on "error", (error) ->
    logger.warn "File watching error: #{error}"
    done()
  watcher.on "change", (f) -> __copy f, copyConfig
  watcher.on "unlink", (f) -> __delete f, copyConfig
  watcher.on "add", (f) -> __copy f, copyConfig, done

__protectDestination = (copyConfig, howManyFiles, cb) ->
  initDone = false
  totalProcessed = 0
  watcher = watch.watch(copyConfig.to, {persistent:true})
  watcher.on "error", (error) ->
    logger.warn "File watching error: #{error}"
    done()
  watcher.on "all", (dontcare, f) ->
    if initDone
      __checkForEdit f, copyConfig
    else
      if ++totalProcessed is howManyFiles
        initDone = true

  cb()

__checkForEdit = (file, copyConfig) ->
  origFile = __makeFromPath file, copyConfig.from, copyConfig.to
  fs.exists origFile, (exists) ->
    if exists
      ostat = fs.statSync(file).mtime.getTime()
      dstat = fs.statSync(origFile).mtime.getTime()
      if ostat - 2000 > dstat
        logger.warn "import-source: file [[ #{file} ]] changed in 'to' location directly.  These changes are likely to be overwritten."
    else
      logger.debug "import-source: file changed in 'to' directory does not exist in 'from' source"

__copy = (file, copyConfig, cb) ->
  if fs.statSync(file).isDirectory()
    cb() if cb
    return

  # if cb then is add, determine if add needed
  fs.readFile file, (err, data) ->
    if err
      logger.error "Error reading file [[ #{file} ]], #{err}"
      cb() if cb
      return

    outFile = __makeToPath file, copyConfig.from, copyConfig.to
    unless fs.existsSync path.dirname(outFile)
      wrench.mkdirSyncRecursive path.dirname(outFile), 0o0777

    fs.writeFile outFile, data, (err) ->
      if err
        logger.error "Error reading file [[ #{file} ]], #{err}"
      else
        logger.info "File copied to destination [[ #{outFile} ]]."
      cb() if cb

__delete = (f, copyConfig, cb) ->
  outFile = __makeToPath file, copyConfig.from, copyConfig.to
  fs.exists outFile, (exists) ->
    if exists
      fs.unlink outFile, (err) ->
        if err
          logger.error "Error deleting file [[ #{outFile} ]], #{err}"
        else
          logger.info "File [[ #{outFile} ]] deleted."
        cb()
    else
      cb()

__makeToPath = (file, from, to) ->
  f = file.replace from, ''
  path.join to, f

__makeFromPath = (file, from, to) ->
  f = file.replace to, ''
  path.join from, f

module.exports =
  registration: registration
  defaults:     config.defaults
  placeholder:  config.placeholder
  validate:     config.validate