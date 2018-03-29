
var exec = require('cordova/exec');

var PLUGIN_NAME = 'PermanentConnection';

var PermanentConnection = {
  startdownload: function(url, cb) {
    exec(cb, null, PLUGIN_NAME, 'startdownload', [url]);
  },
  pausedownload: function(downloadid, cb) {
    exec(cb, null, PLUGIN_NAME, 'pausedownload', [downloadid]);
  },
  resumedownload: function(downloadid, cb) {
    exec(cb, null, PLUGIN_NAME, 'resumedownload', [downloadid]);
  },
  stopdownload: function(downloadid, cb) {
    exec(cb, null, PLUGIN_NAME, 'stopdownload', [downloadid]);
  },
  stopalldownload: function(downloadid, cb) {
    exec(cb, null, PLUGIN_NAME, 'stopalldownload', []);
  },
  resumealldownload: function(downloadidarray, cb) {
    exec(cb, null, PLUGIN_NAME, 'resumealldownload', downloadidarray);
  },
  deletealldownload: function(cb) {
    exec(cb, null, PLUGIN_NAME, 'deletealldownload', []);
  }
};

module.exports = PermanentConnection;