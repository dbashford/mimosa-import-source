"use strict";
var fs;

fs = require('fs');

exports.defaults = function() {
  return {
    importSource: {
      copy: []
    }
  };
};

exports.placeholder = function() {
  return "\t\n\n  # importSource:\n    # copy: []       # an array of folders and or files to copy and where to copy them, for\n                     # more information see https://github.com/dbashford/mimosa-import-source\n";
};

exports.validate = function(config, validators) {
  var c, errors, fromPath, stat, _i, _len, _ref;

  errors = [];
  if (validators.ifExistsIsObject(errors, "importSource config", config.importSource)) {
    if (config.importSource.copy != null) {
      if (validators.isArray(errors, "importSource.copy", config.importSource.copy)) {
        _ref = config.importSource.copy;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          c = _ref[_i];
          if (typeof c === "object" && !Array.isArray(c)) {
            if (c.from != null) {
              if (typeof c.from === "string") {
                fromPath = validators.determinePath(c.from, config.root);
                if (fs.existsSync(fromPath)) {
                  stat = fs.statSync(fromPath);
                  c.from = fromPath;
                  c.isDirectory = stat.isDirectory();
                } else {
                  errors.push("importSource.copy.from [[ " + c.from + " ]] must exist.");
                }
              } else {
                errors.push("importSource.copy.from must be a string.");
              }
            } else {
              errors.push("importSource.copy entries must have a from property.");
            }
            if (c.to != null) {
              if (typeof c.to === "string") {
                c.to = validators.determinePath(c.to, config.root);
              } else {
                errors.push("importSource.copy.to must be a string.");
              }
            } else {
              errors.push("importSource.copy entries must have a to property.");
            }
            if (c.from != null) {
              validators.ifExistsFileExcludeWithRegexAndString(errors, "importSource.copy.exclude", c, c.from);
            }
          } else {
            errors.push("importSource.copy must be an array of objects");
            break;
          }
        }
      }
    }
  }
  return errors;
};
