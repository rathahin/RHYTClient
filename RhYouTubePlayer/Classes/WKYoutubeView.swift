//
//  WKYoutubeView.swift
//  RhYouTubePlayer
//
//  Created by Ratha Hin on 8/20/14.
//  Copyright (c) 2014 rathahin. All rights reserved.
//

import UIKit
import WebKit

class WKYoutubeView: UIView {

    /*
  autohide
  autoplay
  color
  controls
  enablejsapi // by default
  hl
  iv_load_policy
  list
  listType
  loop
  modestbranding
  origin
  playerapiid
  playlist
  playsinline
  rel
  showinfo
  start
  theme
  
  */
  
  var autohide:Bool?
  var autoplay:Bool?
  var color:UIColor?
  var controls:Bool?
  var hl:String?
  var iv_load_policy:Int? // later enum
  var loop:Bool?
  var modestbranding:Bool?
  var playerapiid:String?
  var playlist:NSArray?
  var playsinline:Bool?
  var rel:Bool?
  var showinfo:Bool?
  var start:Int?
  var theme:Int? // later enum
  
  // MARK:- Lazy
  private lazy var overlayWindow:UIWindow = {
    var topWindow:UIWindow?
    let frontToBackWindows:NSArray = UIApplication.sharedApplication().windows
    for window in frontToBackWindows {
      if window.windowLevel == UIWindowLevelNormal {
        topWindow = window as? UIWindow
      }
    }
    
    return topWindow!
    
    }()

  private lazy var wkWebView:WKWebView = {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaPlaybackRequiresUserAction = false
    let webview:WKWebView = WKWebView(frame: CGRectZero, configuration: configuration)
    webview.autoresizingMask = (UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight)
    webview.scrollView.scrollEnabled = false
    webview.scrollView.bounces = false
    var error:NSError?
    let path:NSString = NSBundle.mainBundle().pathForResource("YTPlayerView-iframe-player", ofType: "html", inDirectory: "Assets")!
    var embedHTMLTemplate = NSString.stringWithContentsOfFile(path, encoding: NSUTF8StringEncoding, error: &error)
    
    if error != nil {
      fatalError("YTPlayerView-iframe-player.html is not found in Assets")
    }
    
    // Render the playerVars as a JSON dictionary.
    let playerVars = [
      "controls": 1,
      "playsinline": 1,
      "autohide": 1,
      "rel":0,
      "showinfo": 0,
      "modestbranding": 1]
    let playerCallbacks:NSDictionary = [
      "onReady" : "onReady",
      "onStateChange" : "onStateChange",
      "onPlaybackQualityChange" : "onPlaybackQualityChange",
      "onError" : "onPlayerError"]
    
    let playerParams:NSMutableDictionary = NSMutableDictionary()
    playerParams.addEntriesFromDictionary(["videoId": "AjjzJiX4uZo", "playerVars": playerVars])
    playerParams.setValue("100%", forKey: "height")
    playerParams.setValue("100%", forKey: "width")
    playerParams.setValue(playerCallbacks, forKey: "events")
    
    if !(playerParams.objectForKey("playerVars") != nil) {
      playerParams.setValue(NSDictionary(), forKey: "playerVars")
    }
    
    var jsonRenderingError:NSError?
    let jsonDate:NSData = NSJSONSerialization.dataWithJSONObject(playerParams, options:.PrettyPrinted, error: &jsonRenderingError)!
    
    if ((jsonRenderingError) != nil) {
      NSLog("Attempted configuration of player with invalid playerVars: %@ \tError: %@", playerVars, jsonRenderingError!)
    }
    
    let playerVarsJsonString:String = NSString(data: jsonDate, encoding: NSUTF8StringEncoding)
    let embedHTML:String = NSString(format: embedHTMLTemplate, playerVarsJsonString)
    webview.loadHTMLString(embedHTML, baseURL: NSURL.URLWithString("about:blank"))
    
    return webview
    
  }()
  
  //MARK:- setup subview
  
  override func didMoveToSuperview() {
    
    if (self.wkWebView.superview == nil) {
      self.addSubview(self.wkWebView)
    }
    
  }
  
  override func layoutSubviews() {
    self.wkWebView.frame = self.wkWebView.superview!.bounds
  }
  
  // MARK:- Updating API
  
  func enterFullscreen() {
    self.overlayWindow.addSubview(self.wkWebView)
    self.wkWebView.frame = self.overlayWindow.bounds
  }
  
  func exitFullscreen() {

  }
  
  func commonSetupOnInit() {
    
  }
  
  /**
  * The 'redrawPlayer' function builds the SWF URL based on the selected video
  * and other parameters that the user may have selected. It also redraws the
  * player on the page.
  * @return {string} The SWF URL for the video player.
  */
  private func redrawPlayer() {
    
  }


}
