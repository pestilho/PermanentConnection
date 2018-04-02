
var exec = require('cordova/exec');

var PLUGIN_NAME = 'PermanentConnection';

var PermanentConnection = {
  path : "",
  activedownloads : [],
  startdownload: function(url, cb) {
    function customCallback(returndata){
      var returnObj = JSON.parse(returndata);
      if(returnObj.type === "downloadpath"){
        PermanentConnection.path = returnObj.data;
      }
      else if(returnObj.type === "downloadid"){
        console.log('AAB: '+returnObj.data+'');
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
      console.log("AAA: "+PermanentConnection.activedownloads);
      window.localStorage.setItem("activedownloads", JSON.stringify(PermanentConnection.activedownloads));
      window.localStorage.setItem("path", PermanentConnection.path);
      cb(returndata);
    }
    console.log("ACTIVE "+window.localStorage.getItem("activedonwloads"));
    exec(customCallback, null, PLUGIN_NAME, 'startdownload', [url]);
  },
  pausedownload: function(downloadid, cb) {
    PermanentConnection.activedownloads = JSON.parse(window.localStorage.getItem("activedonwloads"));
    console.log("ACTIVE "+window.localStorage.getItem("activedonwloads"));
    exec(cb, null, PLUGIN_NAME, 'pausedownload', [downloadid]);
  },
  resumedownload: function(downloadid, cb) {
    PermanentConnection.activedownloads = JSON.parse(window.localStorage.getItem("activedonwloads"));
    console.log("ACTIVE "+window.localStorage.getItem("activedonwloads"));
    exec(cb, null, PLUGIN_NAME, 'resumedownload', [downloadid]);
  },
  stopdownload: function(downloadid, cb) {
    PermanentConnection.activedownloads = JSON.parse(window.localStorage.getItem("activedonwloads"));
    var downloadindex = PermanentConnection.activedownloads.indexOf(downloadid);
    if (downloadindex !== -1) PermanentConnection.activedownloads.splice(downloadindex, 1);

    window.localStorage.setItem("activedownloads", JSON.stringify(PermanentConnection.activedownloads));

    console.log("ACTIVE "+window.localStorage.getItem("activedonwloads"));
    exec(cb, null, PLUGIN_NAME, 'stopdownload', [downloadid]);
  },
  stopalldownload: function(downloadid, cb) {
    PermanentConnection.activedownloads = [];

    window.localStorage.setItem("activedownloads", JSON.stringify(PermanentConnection.activedownloads));

    console.log("ACTIVE "+window.localStorage.getItem("activedonwloads"));
    exec(cb, null, PLUGIN_NAME, 'stopalldownload', []);
  },
  resumealldownload: function(downloadidarray, cb) {
    PermanentConnection.activedownloads = JSON.parse(window.localStorage.getItem("activedonwloads"));
    for(var d = 0; d < PermanentConnection.activedownloads.length; d++){
      exec(cb, null, PLUGIN_NAME, 'resumedownload', [PermanentConnection.activedownloads[d]]);
    }

    console.log("ACTIVE "+window.localStorage.getItem("activedonwloads"));
    //exec(cb, null, PLUGIN_NAME, 'resumealldownload', downloadidarray);
  }
};

module.exports = PermanentConnection;