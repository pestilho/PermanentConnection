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
import android.os.Handler;

import com.downloader.*;
import com.downloader.utils.Utils;
import com.downloader.Error;

import java.io.File;
import java.util.Date;
import java.util.Timer;
import java.util.TimerTask;

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

        cordova.getThreadPool().execute(new Runnable() {
            public PluginResult progress_result = null;

            public void run(){
                Log.d("BACKGROUND THREAD", "backgroundThread");
                Timer timer = new Timer();

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

                                                        timer.schedule( new TimerTask(){
                                                            public void run() { 
                                                                Log.i("tag", "TIMEOUT : This'll run 250 milliseconds later");
                                                                if(progress_result != null){
                                                                    callbackContext.sendPluginResult(progress_result);
                                                                }
                                                            }
                                                        }, 1000, 1000);

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
                                                    timer.cancel();
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
                                                    Log.d(TAG, progress+"");

                                                    try {
                                                        JSONObject progressobj = new JSONObject();
                                                        double pvalue = ((double) progress.currentBytes / progress.totalBytes) * 100;
                                                        //Log.d("DOUBLE", String.valueOf(pvalue));
                                                        Log.d("DOUBLE", progress.currentBytes+" - "+progress.totalBytes);
                                                        progressobj.put("progressvalue", String.valueOf(pvalue));

                                                        JSONObject item = new JSONObject();
                                                        item.put("type", "downloadprogress");
                                                        item.put("data", progressobj);

                                                        progress_result = new PluginResult(PluginResult.Status.OK, item.toString());
                                                        progress_result.setKeepCallback(true);
                                                    } catch (JSONException e) {
                                                        Log.d(TAG, e.toString());
                                                    }
                                                }
                                        })
                                        .start(new OnDownloadListener() {
                                                @Override
                                                public void onDownloadComplete() {
                                                    Log.d(TAG, "onDownloadComplete");
                                                    timer.cancel();
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
                                                    timer.cancel();
                                                    
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

                //callbackContext.success();
                /*
                timer.schedule( new TimerTask(){
                    public void run() { 
                        Log.i("tag", "TIMEOUT : This'll run 250 milliseconds later");
                        if(progress_result != null){
                            callbackContext.sendPluginResult(progress_result);
                        }
                    }
                }, 1000, 1000);
                */
            }

            //callbackContext.sendPluginResult(result);
        });

        /*
        timeoutHandler.postDelayed(new Runnable() {
                                        @Override
                                        public void run() {
                                            Log.i("tag", "TIMEOUT : This'll run 250 milliseconds later");
                                            callbackContext.sendPluginResult(progress_result);
                                            timeoutHandler.postDelayed(this, 250);
                                        }
                                    }, 250);
                                    */

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


