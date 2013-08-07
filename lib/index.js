"use strict";
var config, fs, logger, mimosaConf, path, registration, watch, wrench, _, __checkForEdit, __cleanDirectories, __cleanFiles, __copy, __delete, __do, __importSource, __isExcluded, __makeFromPath, __makeToPath, __protectDestination, __startCopy, _cleanDirectories, _cleanFiles, _importSource;

fs = require('fs');

path = require('path');

watch = require('chokidar');

wrench = require('wrench');

logger = require('logmimosa');

_ = require("lodash");

config = require('./config');

mimosaConf = false;

registration = function(mimosaConfig, register) {
  mimosaConf = mimosaConfig;
  register(['preBuild'], 'init', _importSource);
  register(['postClean'], 'init', _cleanFiles);
  return register(['postClean'], 'init', _cleanDirectories);
};

_cleanFiles = function(mimosaConfig, options, next) {
  return __do(mimosaConfig, __cleanFiles, next);
};

_importSource = function(mimosaConfig, options, next) {
  return __do(mimosaConfig, __importSource, next);
};

_cleanDirectories = function(mimosaConfig, options, next) {
  return __do(mimosaConfig, __cleanDirectories, next);
};

__do = function(mimosaConfig, execute, next) {
  var copy, done, i, _i, _len, _ref, _ref1, _ref2, _results;
  if (((_ref = mimosaConfig.importSource) != null ? (_ref1 = _ref.copy) != null ? _ref1.length : void 0 : void 0) > 0) {
    i = 0;
    done = function() {
      if (++i === mimosaConfig.importSource.copy.length) {
        return next();
      }
    };
    _ref2 = mimosaConfig.importSource.copy;
    _results = [];
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      copy = _ref2[_i];
      _results.push(execute(copy, done));
    }
    return _results;
  } else {
    return next();
  }
};

__cleanFiles = function(copyConfig, cb) {
  return fs.exists(copyConfig.to, function(exists) {
    var allFiles, file, files, outPath, _i, _len;
    if (!exists) {
      return cb();
    }
    allFiles = copyConfig.isDirectory ? wrench.readdirSyncRecursive(copyConfig.from).map(function(f) {
      return path.join(copyConfig.from, f);
    }) : [copyConfig.from];
    files = allFiles.filter(function(f) {
      return !__isExcluded(copyConfig, f) && fs.statSync(f).isFile();
    });
    for (_i = 0, _len = files.length; _i < _len; _i++) {
      file = files[_i];
      outPath = __makeToPath(file, copyConfig.from, copyConfig.to);
      if (fs.existsSync(outPath)) {
        fs.unlinkSync(outPath);
        logger.info("mimosa-import-source: Deleted file [[ " + outPath + " ]]");
      }
    }
    return cb();
  });
};

__cleanDirectories = function(copyConfig, cb) {
  return fs.exists(copyConfig.to, function(exists) {
    var allFiles, dirs;
    if (!exists) {
      return cb();
    }
    if (!copyConfig.isDirectory) {
      return cb();
    }
    allFiles = wrench.readdirSyncRecursive(copyConfig.from).map(function(f) {
      return path.join(copyConfig.from, f);
    });
    dirs = allFiles.filter(function(f) {
      return fs.statSync(f).isDirectory();
    });
    _.sortBy(dirs, 'length').reverse().forEach(function(dirPath) {
      dirPath = __makeToPath(dirPath, copyConfig.from, copyConfig.to);
      if (fs.existsSync(dirPath)) {
        return fs.rmdir(dirPath, function(err) {
          if ((err != null ? err.code : void 0) === !"ENOTEMPTY") {
            logger.error("Unable to delete directory, " + dirPath);
            return logger.error(err);
          } else {
            return logger.info("mimosa-import-source: Deleted empty directory [[ " + dirPath + " ]]");
          }
        });
      }
    });
    return cb();
  });
};

__importSource = function(copyConfig, cb) {
  var files, numFiles;
  numFiles = copyConfig.isDirectory ? (files = wrench.readdirSyncRecursive(copyConfig.from).filter(function(f) {
    f = path.join(copyConfig.from, f);
    return !__isExcluded(copyConfig, f) && fs.statSync(f).isFile();
  }), files.length) : 1;
  if (numFiles === 0) {
    return cb();
  } else {
    return __startCopy(copyConfig, numFiles, cb);
  }
};

__isExcluded = function(copyConfig, file) {
  var _ref;
  if (copyConfig.excludeRegex && file.match(copyConfig.excludeRegex)) {
    return true;
  } else if (((_ref = copyConfig.exclude) != null ? _ref.indexOf(file) : void 0) > -1) {
    return true;
  } else {
    return false;
  }
};

__startCopy = function(copyConfig, howManyFiles, cb) {
  var done, i, watchSettings, watcher;
  i = 0;
  done = function() {
    if (++i === howManyFiles) {
      if (mimosaConf.isBuild) {
        return cb();
      } else {
        return __protectDestination(copyConfig, howManyFiles, cb);
      }
    }
  };
  watchSettings = {
    ignored: function(file) {
      return __isExcluded(copyConfig, file);
    },
    persistent: !mimosaConf.isBuild,
    interval: mimosaConf.importSource.interval,
    binaryInterval: mimosaConf.importSource.binaryInterval
  };
  watcher = watch.watch(copyConfig.from, watchSettings);
  watcher.on("error", function(error) {
    logger.warn("File watching error: " + error);
    return done();
  });
  watcher.on("change", function(f) {
    return __copy(f, copyConfig);
  });
  watcher.on("unlink", function(f) {
    return __delete(f, copyConfig);
  });
  return watcher.on("add", function(f) {
    return __copy(f, copyConfig, done);
  });
};

__protectDestination = function(copyConfig, howManyFiles, cb) {
  var initDone, totalProcessed, watcher;
  initDone = false;
  totalProcessed = 0;
  watcher = watch.watch(copyConfig.to, {
    persistent: true
  });
  watcher.on("error", function(error) {
    return logger.warn("File watching error: " + error);
  });
  watcher.on("all", function(dontcare, f) {
    if (initDone) {
      return __checkForEdit(f, copyConfig);
    } else {
      if (++totalProcessed === howManyFiles) {
        return initDone = true;
      }
    }
  });
  return cb();
};

__checkForEdit = function(file, copyConfig) {
  var origFile;
  origFile = __makeFromPath(file, copyConfig.from, copyConfig.to);
  return fs.exists(origFile, function(exists) {
    var dstat, ostat;
    if (exists) {
      ostat = fs.statSync(file).mtime.getTime();
      dstat = fs.statSync(origFile).mtime.getTime();
      if (ostat - mimosaConf.importSource.interval > dstat) {
        return logger.warn("import-source: file [[ " + file + " ]] changed in 'to' location directly.  These changes are likely to be overwritten.");
      }
    } else {
      return logger.debug("import-source: file changed in 'to' directory does not exist in 'from' source");
    }
  });
};

__copy = function(file, copyConfig, cb) {
  if (fs.statSync(file).isDirectory()) {
    if (cb) {
      cb();
    }
    return;
  }
  return fs.readFile(file, function(err, data) {
    var outFile;
    if (err) {
      logger.error("Error reading file [[ " + file + " ]], " + err);
      if (cb) {
        cb();
      }
      return;
    }
    outFile = __makeToPath(file, copyConfig.from, copyConfig.to);
    if (!fs.existsSync(path.dirname(outFile))) {
      wrench.mkdirSyncRecursive(path.dirname(outFile), 0x1ff);
    }
    return fs.writeFile(outFile, data, function(err) {
      if (err) {
        logger.error("Error reading file [[ " + file + " ]], " + err);
      } else {
        logger.info("File copied to destination [[ " + outFile + " ]].");
      }
      if (cb) {
        return cb();
      }
    });
  });
};

__delete = function(file, copyConfig) {
  var outFile;
  outFile = __makeToPath(file, copyConfig.from, copyConfig.to);
  return fs.exists(outFile, function(exists) {
    if (exists) {
      return fs.unlink(outFile, function(err) {
        if (err) {
          return logger.error("Error deleting file [[ " + outFile + " ]], " + err);
        } else {
          return logger.info("File [[ " + outFile + " ]] deleted.");
        }
      });
    }
  });
};

__makeToPath = function(file, from, to) {
  var f;
  f = file.replace(from, '');
  return path.join(to, f);
};

__makeFromPath = function(file, from, to) {
  var f;
  f = file.replace(to, '');
  return path.join(from, f);
};

module.exports = {
  registration: registration,
  defaults: config.defaults,
  placeholder: config.placeholder,
  validate: config.validate
};
