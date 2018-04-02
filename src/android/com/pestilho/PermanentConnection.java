package com.pestilho.permanentconnection;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.apache.cordova.PluginResult.Status;
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

import android.util.Log;
import android.content.Context;
import android.os.Environment;

import com.downloader.*;
import com.downloader.utils.Utils;
import com.downloader.Error;

import java.io.File;
import java.util.Date;

public class PermanentConnection extends CordovaPlugin {
  private static final String TAG = "PermanentConnection";
  public int auxDownloadID = 0;

  @Override
  public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    super.initialize(cordova, webView);

    Log.d(TAG, "Initializing PermanentConnection");
    PRDownloader.initialize(this.cordova.getActivity().getApplicationContext());
  }

  
  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
    if(action.equals("startdownload")) {
      String urlstring = args.getString(0);
      String filename = urlstring.substring(urlstring.lastIndexOf('/') + 1, urlstring.lastIndexOf('.'));
      File root = this.cordova.getActivity().getFilesDir();
      this.createDirIfNotExists(this.cordova.getActivity(), "pc-downloads");
      String folderPathString = this.cordova.getActivity().getFilesDir()+"/pc-downloads";
      Log.d(TAG, "DIRECTORY: "+folderPathString);

      try {
        JSONObject item = new JSONObject();
        item.put("type", "downloadpath");
        item.put("data", folderPathString);

        PluginResult result = new PluginResult(PluginResult.Status.OK, item.toString());
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);
     } catch (JSONException e) {
        Log.d(TAG, e.toString());
     }


      int downloadId = PRDownloader.download(urlstring, folderPathString, filename)
                                   .build()
                                   .setOnStartOrResumeListener(new OnStartOrResumeListener() {
                                        @Override
                                        public void onStartOrResume() {
                                            Log.d(TAG, "onStartOrResume");
                                            try {
                                                JSONObject item = new JSONObject();
                                                item.put("type", "downloadid");
                                                item.put("data", auxDownloadID);

                                                PluginResult result = new PluginResult(PluginResult.Status.OK, item.toString());
                                                result.setKeepCallback(true);
                                                callbackContext.sendPluginResult(result);
                                            } catch (JSONException e) {
                                                Log.d(TAG, e.toString());
                                            }
                                        }
                                   })
                                   .setOnPauseListener(new OnPauseListener() {
                                        @Override
                                        public void onPause() {
                                            Log.d(TAG, "onPause");
                                        }
                                   })
                                   .setOnCancelListener(new OnCancelListener() {
                                        @Override
                                        public void onCancel() {
                                            Log.d(TAG, "onCancel");
                                            try {
                                                JSONObject item = new JSONObject();
                                                item.put("type", "downloadstop");
                                                item.put("data", auxDownloadID);

                                                PluginResult result = new PluginResult(PluginResult.Status.OK, item.toString());
                                                result.setKeepCallback(true);
                                                callbackContext.sendPluginResult(result);
                                            } catch (JSONException e) {
                                                Log.d(TAG, e.toString());
                                            }
                                        }
                                   })
                                   .setOnProgressListener(new OnProgressListener() {
                                        @Override
                                        public void onProgress(Progress progress) {
                                            Log.d(TAG, "onProgress");

                                            try {
                                                JSONObject item = new JSONObject();
                                                item.put("type", "downloadprogress");
                                                item.put("data", progress);

                                                PluginResult result = new PluginResult(PluginResult.Status.OK, item.toString());
                                                result.setKeepCallback(true);
                                                callbackContext.sendPluginResult(result);
                                            } catch (JSONException e) {
                                                Log.d(TAG, e.toString());
                                            }
                                        }
                                   })
                                   .start(new OnDownloadListener() {
                                        @Override
                                        public void onDownloadComplete() {
                                            Log.d(TAG, "onDownloadComplete");
                                             try {
                                                JSONObject item = new JSONObject();
                                                item.put("type", "downloadcomplete");
                                                item.put("data", auxDownloadID);

                                                PluginResult result = new PluginResult(PluginResult.Status.OK, item.toString());
                                                result.setKeepCallback(true);
                                                callbackContext.sendPluginResult(result);
                                            } catch (JSONException e) {
                                                Log.d(TAG, e.toString());
                                            }
                                        }

                                        @Override
                                        public void onError(Error error) {
                                            Log.d(TAG, "onError");

                                            try {
                                                JSONObject item = new JSONObject();
                                                item.put("type", "downloaderror");
                                                item.put("data", auxDownloadID);

                                                PluginResult result = new PluginResult(PluginResult.Status.OK, item.toString());
                                                result.setKeepCallback(true);
                                                callbackContext.sendPluginResult(result);
                                            } catch (JSONException e) {
                                                Log.d(TAG, e.toString());
                                            }
                                        }
                                   });
                                   
        auxDownloadID = downloadId;
        return true;
    } 
    else if(action.equals("pausedownload")) {
      String downloadid = args.getString(0);
      PRDownloader.pause(Integer.parseInt(downloadid));

      return true;
    } 
    else if(action.equals("stopdownload")) {
      String downloadid = args.getString(0);
      PRDownloader.cancel(Integer.parseInt(downloadid));

      return true;
    } 
    else if(action.equals("stopalldownload")) {
      PRDownloader.cancelAll();
      return true;
    } 
    else if(action.equals("resumedownload")) {
      String downloadid = args.getString(0);
      PRDownloader.resume(Integer.parseInt(downloadid));

      return true;
    }

    return true;
  }

  public static boolean createDirIfNotExists(Context appContext, String path) {
        boolean ret = true;

        File file = new File(appContext.getFilesDir(), path);
        if (!file.exists()) {
            if (!file.mkdirs()) {
                Log.e("TravellerLog :: ", "Problem creating Image folder");
                ret = false;
            }
        }

        return ret;
    }
}


