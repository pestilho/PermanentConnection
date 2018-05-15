
var exec = require('cordova/exec');

var PLUGIN_NAME = 'PermanentConnection';

var PermanentConnection = {
  path : "",
  activedownloads : [],
  oedidmanager : {},
  startdownload: function(url, cb) {
    function customCallback(returndata){
      console.log("Pestilho: "+returndata);
      var returnObj = JSON.parse(returndata);
      if(returnObj.type === "downloadpath"){
        PermanentConnection.path = returnObj.data;
      }
      else if(returnObj.type === "downloadid"){
        PermanentConnection.activedownloads.push(returnObj.data+'');
      }
      else if(returnObj.type === "downloadstop"){
        var downloadindex = PermanentConnection.activedownloads.indexOf(returnObj.data+'');
        if (downloadindex !== -1) PermanentConnection.activedownloads.splice(downloadindex, 1);
      }
      else if(returnObj.type === "downloadcomplete"){
        var downloadindex = PermanentConnection.activedownloads.indexOf(returnObj.data+'');
        if (downloadindex !== -1) PermanentConnection.activedownloads.splice(downloadindex, 1);

      }

      NativeStorage.setItem("activedownloads", JSON.stringify(PermanentConnection.activedownloads), function(successobj){}, function(error){});
      NativeStorage.setItem("path", PermanentConnection.path, function(successobj){}, function(error){});

      cb(returndata);
    }
    
    NativeStorage.getItem("activedownloads", function(successobj){ console.log("ACTIVE "+successobj); }, function(error){});
    exec(customCallback, null, PLUGIN_NAME, 'startdownload', [url]);
  },
  getdownloadprogress: function(oedid){
    return this.oedidmanager[oedid+''];
  },
  pausedownload: function(downloadid, cb) {
    NativeStorage.getItem("activedownloads", function(successobj){ 
      PermanentConnection.activedownloads = JSON.parse(successobj);
    }, function(error){});
    NativeStorage.getItem("activedownloads", function(successobj){ console.log("ACTIVE "+successobj); }, function(error){});
    exec(cb, null, PLUGIN_NAME, 'pausedownload', [downloadid]);
  },
  resumedownload: function(downloadid, cb) {
    exec(cb, null, PLUGIN_NAME, 'resumedownload', [downloadid]);
  },
  stopdownload: function(downloadid, cb) {
    NativeStorage.getItem("activedownloads", function(successobj){ 
      PermanentConnection.activedownloads = JSON.parse(successobj);
    }, function(error){});
    var downloadindex = PermanentConnection.activedownloads.indexOf(downloadid);
    if (downloadindex !== -1) PermanentConnection.activedownloads.splice(downloadindex, 1);

    NativeStorage.setItem("activedownloads", JSON.stringify(PermanentConnection.activedownloads), function(successobj){}, function(error){});

    NativeStorage.getItem("activedownloads", function(successobj){ console.log("ACTIVE "+successobj); }, function(error){});
    exec(cb, null, PLUGIN_NAME, 'stopdownload', [downloadid]);
  },
  stopalldownload: function(downloadid, cb) {
    NativeStorage.getItem("activedownloads", function(successobj){ 
      PermanentConnection.activedownloads = JSON.parse(successobj);
    }, function(error){});

    if(PermanentConnection.activedownloads.length > 0){
      exec(cb, null, PLUGIN_NAME, 'stopalldownload', PermanentConnection.activedownloads);
    }

    PermanentConnection.activedownloads = [];

    NativeStorage.getItem("activedownloads", function(successobj){ console.log("ACTIVE "+successobj); }, function(error){});
  },
  resumealldownload: function(downloadidarray, cb) {
    NativeStorage.getItem("activedownloads", function(successobj){ 
      PermanentConnection.activedownloads = JSON.parse(successobj);
    }, function(error){});
    for(var d = 0; d < PermanentConnection.activedownloads.length; d++){
      exec(cb, null, PLUGIN_NAME, 'resumedownload', [PermanentConnection.activedownloads[d]]);
    }

    NativeStorage.getItem("activedownloads", function(successobj){ console.log("ACTIVE "+successobj); }, function(error){});
    //exec(cb, null, PLUGIN_NAME, 'resumealldownload', downloadidarray);
  }
};

module.exports = PermanentConnection;