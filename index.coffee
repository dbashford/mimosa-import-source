###
TODO
- Handle clean. 'mimosa clean' should remove both the compiled files and the soruce files.
  Requires a meaty-though-necessary mimosa refactor
###

"use strict"

fs = require 'fs'
path = require 'path'
watch = require 'chokidar'
wrench = require 'wrench'
logger = require 'logmimosa'

config = require './config'

registration = (mimosaConfig, register) ->
  register ['preBuild'], 'init', _importSource

  if mimosaConfig.isClean
    register ['postClean'], 'init', _clean

_do = (mimosaConfig, execute, next) ->
  if mimosaConfig.importSource?.copy?.length > 0
    i = 0
    done = ->
      if ++i is mimosaConfig.importSource.copy.length
        next()

    for copy in mimosaConfig.importSource.copy
      execute copy, done
  else
    next()

_clean = (mimosaConfig, options, next) ->
  _do mimosaConfig, _cleanImports, next

_importSource = (mimosaConfig, options, next) ->
  _do mimosaConfig, _initCopy, next

_cleanImports = (copyConfig, cb) ->
  fs.exists copyConfig.to, (exists) ->
    if exists
      allFiles = wrench.readdirSyncRecursive(copyConfig.from).map (f) -> path.join copyConfig.from, f
      files = allFiles.filter (f) -> _isExcluded(copyConfig, f)
      dirs =  allFiles.filter (f) -> fs.statSync(f).isDirectory()

      for file in files
        outPath = _makeToPath file, copyConfig.from, copyConfig.to
        if fs.existsSync file
          logger.info "Removing file [[ #{file} ]]"
          fs.unlinkSync file

      _.sortBy(directories, 'length').reverse().forEach (dirPath) ->
        if fs.existsSync dirPath
          logger.info "Deleting directory [[ #{dirPath} ]]"
          fs.rmdir dirPath, (err) ->
            if err?.code is not "ENOTEMPTY"
              logger.error "Unable to delete directory, #{dirPath}"
              logger.error err
            else
              logger.success "Deleted empty directory [[ #{dirPath} ]]"

_initCopy = (copyConfig, cb) ->
  numFiles = if copyConfig.isDirectory
    files = wrench.readdirSyncRecursive(copyConfig.from).filter (f) ->
      f = path.join copyConfig.from, f
      not _isExcluded(copyConfig, f) and fs.statSync(f).isFile()
    files.length
  else
    1

  if numFiles is 0
    cb()
  else
    _startCopy copyConfig, numFiles, cb

_isExcluded = (copyConfig, file) ->
  if copyConfig.excludeRegex and file.match copyConfig.excludeRegex
    true
  else if copyConfig.exclude?.indexOf(file) > -1
    true
  else
    false

_startCopy = (copyConfig, howManyFiles, cb) ->

  i = 0
  done = ->
    if ++i is howManyFiles
      # error when file from orig project is edited in dest project
      _protectDestination copyConfig, howManyFiles, cb

  ignored = (file) -> _isExcluded(copyConfig, file)

  watcher = watch.watch(copyConfig.from, {ignored:ignored, persistent:true})
  watcher.on "error", (error) ->
    logger.warn "File watching error: #{error}"
    done()
  watcher.on "change", (f) -> _copy f, copyConfig
  watcher.on "unlink", (f) -> _delete f, copyConfig
  watcher.on "add", (f) -> _copy f, copyConfig, done

_protectDestination = (copyConfig, howManyFiles, cb) ->
  initDone = false
  totalProcessed = 0
  watcher = watch.watch(copyConfig.to, {persistent:true})
  watcher.on "error", (error) ->
    logger.warn "File watching error: #{error}"
    done()
  watcher.on "all", (dontcare, f) ->
    if initDone
      _checkForEdit f, copyConfig
    else
      if ++totalProcessed is howManyFiles
        initDone = true

  cb()

_checkForEdit = (file, copyConfig) ->
  origFile = _makeFromPath file, copyConfig.from, copyConfig.to
  fs.exists origFile, (exists) ->
    if exists
      ostat = fs.statSync(file).mtime.getTime()
      dstat = fs.statSync(origFile).mtime.getTime()
      if ostat - 2000 > dstat
        logger.warn "mimosa-import-source: file [[ #{file} ]] changed in 'to' location directly.  These changes are likely to be overwritten."
        console.log "File changed in dest directly!"
    else
      logger.debug "mimosa-import-source: file changed in 'to' directory does not exist in 'from' source"

_copy = (file, copyConfig, cb) ->
  if fs.statSync(file).isDirectory()
    cb() if cb
    return

  # if cb then is add, determine if add needed
  fs.readFile file, (err, data) ->
    if err
      logger.error "Error reading file [[ #{file} ]], #{err}"
      cb() if cb
      return

    outFile = _makeToPath file, copyConfig.from, copyConfig.to
    unless fs.existsSync path.dirname(outFile)
      wrench.mkdirSyncRecursive path.dirname(outFile), 0o0777

    fs.writeFile outFile, data, (err) ->
      if err
        logger.error "Error reading file [[ #{file} ]], #{err}"
      else
        logger.info "File copied to destination [[ #{outFile} ]]."
      cb() if cb

_delete = (f, copyConfig, cb) ->
  outFile = _makeToPath file, copyConfig.from, copyConfig.to
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

_makeToPath = (file, from, to) ->
  f = file.replace from, ''
  path.join to, f

_makeFromPath = (file, from, to) ->
  f = file.replace to, ''
  path.join from, f

module.exports =
  registration: registration
  defaults:     config.defaults
  placeholder:  config.placeholder
  validate:     config.validate