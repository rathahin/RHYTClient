//
//  RhYouTubePlayerView.swift
//  RhYouTubePlayer
//
//  Created by Ratha Hin on 8/13/14.
//  Copyright (c) 2014 rathahin. All rights reserved.
//  demo url = https://developers.google.com/youtube/youtube_player_demo
//  parameters = https://developers.google.com/youtube/player_parameters
//

import UIKit

/** These enums represent the state of the current video in the player. */
enum YTPlayerState:Int {
  
  case Unstarted
  case Ended
  case Playing
  case Paused
  case Buffering
  case Queued
  case Unknown
  
}

/** These enums represent the resolution of the currently loaded video. */
enum YTPlayBackQuality:Int {
  
  case Small
  case Medium
  case Large
  case HD720
  case HD1080
  case HighRes
  case Unknown // This should never be returned. It is here for future proofing.
  
}

/** These enums represent error codes thrown by the player. */
enum YTPlayerError:Int {
  
  case InvalidParam
  case HTML5Error
  case VideoNotFound  // Functionally equivalent error 100 and 105 have been collapsed into |PlayerErrorVideoNotFound
  case NotEmbeddable
  case Unknown
  
}

/**

A delegate for ViewCOntrollers to respond to YouTube player events outside
of the view, such as changes to video playback state or playback errors.
The callback functions correlate to the events fired by the JavaScript
API. For the full documentation, see the Javascript document on YouTube

*/

@objc protocol RhYouTubePlayerViewDelegate: NSObjectProtocol {
  
  optional func playerViewDidBecomeRead(playerView: YTPlayerView!)
  optional func playerView(playerView: YTPlayerView!, didChangeToState state:YTPlayerState.Raw)
  optional func playerView(playerView: YTPlayerView, didChangeToQuality quality:YTPlayBackQuality.Raw)
  optional func playerView(playerView: YTPlayerView, receivedError error:YTPlayerError.Raw)
  
}

// These are instances of NSString because we get them from parsing a URL. It would be silly to
// convert these into an integer just to have to convert the URL query string value into an integer
// as well for the sake of doing a value comparison. A full list of response error codes can be
// found here:
//      https://developers.google.com/youtube/iframe_api_reference

let kYTPlayerStateUnstartedCode:String = "-1";
let kYTPlayerStateEndedCode:String = "0";
let kYTPlayerStatePlayingCode:String = "1";
let kYTPlayerStatePausedCode:String = "2";
let kYTPlayerStateBufferingCode:String = "3";
let kYTPlayerStateCuedCode:String = "5";
let kYTPlayerStateUnknownCode:String = "unknown";

// Constants representing playback quality.
let kYTPlaybackQualitySmallQuality:String = "small";
let kYTPlaybackQualityMediumQuality:String = "medium";
let kYTPlaybackQualityLargeQuality:String = "large";
let kYTPlaybackQualityHD720Quality:String = "hd720";
let kYTPlaybackQualityHD1080Quality:String = "hd1080";
let kYTPlaybackQualityHighResQuality:String = "highres";
let kYTPlaybackQualityUnknownQuality:String = "unknown";

// Constants representing YouTube player errors.
let kYTPlayerErrorInvalidParamErrorCode:String = "2";
let kYTPlayerErrorHTML5ErrorCode:String = "5";
let kYTPlayerErrorVideoNotFoundErrorCode:String = "100";
let kYTPlayerErrorNotEmbeddableErrorCode:String = "101";
let kYTPlayerErrorCannotFindVideoErrorCode:String = "105";

// Constants representing player callbacks.
let kYTPlayerCallbackOnReady:String = "onReady";
let kYTPlayerCallbackOnStateChange:String = "onStateChange";
let kYTPlayerCallbackOnPlaybackQualityChange:String = "onPlaybackQualityChange";
let kYTPlayerCallbackOnError:String = "onError";
let kYTPlayerCallbackOnYouTubeIframeAPIReady:String = "onYouTubeIframeAPIReady";

let kYTPlayerEmbedUrlRegexPattern:String = "^http(s)://(www.)youtube.com/embed/(.*)$";

class YTPlayerView: UIView, UIWebViewDelegate {
  
  var webView: UIWebView?
  var delegate: RhYouTubePlayerViewDelegate?
  var originSuperView: UIView?
  var originFrame: CGRect?
  
  // MARK:- Lazy
  private lazy var overlayWindow:UIWindow = {
    /*
     if(!self.overlayView.superview){
     NSEnumerator *frontToBackWindows = [[[UIApplication sharedApplication]windows]reverseObjectEnumerator];
     
     for (UIWindow *window in frontToBackWindows)
     if (window.windowLevel == UIWindowLevelNormal) {
     [window addSubview:self.overlayView];
     break;
     }
     }
     */
    var topWindow:UIWindow?
    let frontToBackWindows:NSArray = UIApplication.sharedApplication().windows
    for window in frontToBackWindows {
      if window.windowLevel == UIWindowLevelNormal {
        topWindow = window as? UIWindow
      }
    }
    
    return topWindow!
    
    }()
  
  override init(frame: CGRect) {
    // Initialize here the variables of the subclass
    super.init(frame: frame)
    self.commonSetupOnInit()
    // Initialize here the variables of the super class
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
 
  func loadWithVideoId(videoId:NSString, playerVars:NSDictionary = NSDictionary()) -> Bool{
    var playerVarsValue:NSDictionary? = playerVars
    
    if (playerVarsValue == nil) {
      playerVarsValue = NSDictionary()
    }
    
    let playerParams = ["videoId": videoId, "playerVars": playerVarsValue!]
    return self.loadWithPlayerParams(playerParams)
  }
  
  func loadWithPlaylistId(playlistId: NSString, playerVars:NSDictionary = NSDictionary()) -> Bool{
    
    // Mutable copy because we may have been passed an immutable config dictionary.
    let tempPlayerVars = NSMutableDictionary()
    tempPlayerVars.setValue("playlist", forKey: "listType")
    tempPlayerVars.setValue(playlistId, forKey: "list")
    tempPlayerVars.addEntriesFromDictionary(playerVars) // No-op if playerVars is null
    
    let playerParams = ["playerVars": tempPlayerVars]
    return self.loadWithPlayerParams(playerParams)
    
  }
  
// MARK: - Player methods
  
  func playVideo() {
    self.stringFromEvaluatingJavaScript("player.playVideo();")
  }
  
  func pauseVideo() {
    self.stringFromEvaluatingJavaScript("player.pauseVideo();")
  }
  
  func stopVideo() {
    self.stringFromEvaluatingJavaScript("player.stopVideo();")
  }
  
  func seekToSecond(seekToSeconds:Float, allowSeekAhead:Bool) {
    let secondsValue:NSNumber = NSNumber.numberWithFloat(seekToSeconds)
    let allowSeekAheadValue:NSString = self.stringForJSBoolean(allowSeekAhead)
    let command:NSString = NSString(format: "player.seekTo(%@, %@)", secondsValue, allowSeekAheadValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func clearVideo() {
    self.stringFromEvaluatingJavaScript("player.clearVideo();")
  }
  
// MARK: - Cueing methods
  
  func cueVideoById(videoId:NSString, startSeconds:Float, suggestedQuality:YTPlayBackQuality) {
    let startSecondsValue = NSNumber.numberWithFloat(startSeconds)
    let qualityValue:NSString = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command:NSString = NSString(format: "player.cueVideoById('%@', %@, '%@');",videoId, startSecondsValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func cueVideoById(videoId:NSString, startSeconds:Float, endSeconds:Float, suggestedQuality: YTPlayBackQuality) {
    let startSecondsValue = NSNumber.numberWithFloat(startSeconds)
    let endSecondValue = NSNumber.numberWithFloat(endSeconds)
    let qualityValue:NSString = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command:NSString = NSString(format: "player.cueVideoById('%@', %@, '%@', '%@');",videoId, startSecondsValue, endSecondValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func loadVideoById(videoId:NSString, startSeconds: Float, suggestedQuality:YTPlayBackQuality) {
    let startSecondsValue:NSNumber = NSNumber.numberWithFloat(startSeconds)
    let qualityValue:NSString = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command:NSString = NSString(format:"player.loadVideoById('%@', %@, '%@');", videoId, startSecondsValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func loadVideoById(videoId:NSString, startSeconds: Float, endSeconds: Float, suggestedQuality:YTPlayBackQuality) {
    let startSecondsValue:NSNumber = NSNumber.numberWithFloat(startSeconds)
    let endSecondValue = NSNumber.numberWithFloat(endSeconds)
    let qualityValue:NSString = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command:NSString = NSString(format:"player.loadVideoById('%@', %@, '%@', '%@');", videoId, startSecondsValue, endSecondValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func cueVideoByURL(videoURL:NSString, startSeconds:Float, suggestedQuality: YTPlayBackQuality) {
    let startSecondsValue:NSNumber = NSNumber.numberWithFloat(startSeconds)
    let qualityValue:NSString = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command:NSString = NSString(format:"player.cueVideoByUrl('%@', %@, '%@');", videoURL, startSecondsValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func cueVideoByURL(videoURL:NSString, startSeconds:Float, endSeconds: Float, suggestedQuality: YTPlayBackQuality) {
    let startSecondsValue:NSNumber = NSNumber.numberWithFloat(startSeconds)
    let endSecondValue = NSNumber.numberWithFloat(endSeconds)
    let qualityValue:NSString = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command:NSString = NSString(format:"player.cueVideoByUrl('%@', %@, '%@', '%@');", videoURL, startSecondsValue, endSecondValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func loadVideoByURL(videoURL:NSString, startSeconds:Float, suggestedQuality: YTPlayBackQuality) {
    let startSecondsValue:NSNumber = NSNumber.numberWithFloat(startSeconds)
    let qualityValue:NSString = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command:NSString = NSString(format:"player.loadVideoByUrl('%@', %@, '%@');", videoURL, startSecondsValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func loadVideoByURL(videoURL:NSString, startSeconds:Float, endSeconds: Float, suggestedQuality: YTPlayBackQuality) {
    let startSecondsValue:NSNumber = NSNumber.numberWithFloat(startSeconds)
    let endSecondValue = NSNumber.numberWithFloat(endSeconds)
    let qualityValue:NSString = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command:NSString = NSString(format:"player.loadVideoByUrl('%@', %@, '%@', '%@');", videoURL, startSecondsValue, endSecondValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  // MARK:- Cueing methods for lists
  func cuePlaylistByPlaylistId(playlistId:NSString, index:Int, startSeconds:Float, suggestedQuality:YTPlayBackQuality) {
    let playlistIdString = NSString(format: "%@", playlistId)
    self.cuePlaylist(playlistIdString, index: index, startSecond: startSeconds, suggestedQuality: suggestedQuality)
  }
  
  func cuePlaylistByVideos(videoIds:NSArray, index:Int, startSeconds:Float, suggestedQuality:YTPlayBackQuality) {
    self.cuePlaylist(self.stringFromVideoIdArray(videoIds), index: index, startSecond: startSeconds, suggestedQuality: suggestedQuality)
  }
  
  func loadPlaylistByPlaylistId(playlistId:NSString, index:Int, startSeconds:Float, suggestedQuality:YTPlayBackQuality) {
    let playlistIdString = NSString(format: "'%@'", playlistId)
    self.loadPlaylist(playlistIdString, index: index, startSecond: startSeconds, suggestedQuality: suggestedQuality)
  }
  
  func loadPlaylistByVideos(videoIds:NSArray, index:Int, startSeconds:Float, suggestedQuality: YTPlayBackQuality) {
    self.loadPlaylist(self.stringFromVideoIdArray(videoIds), index: index, startSecond: startSeconds, suggestedQuality: suggestedQuality)
  }
  
  // MARK:- Setting the playback rate
  func playbackRate() -> Float {
    
    let returnValue:NSString = self.stringFromEvaluatingJavaScript("player.getPlaybackRate();")
    return returnValue.floatValue
    
  }
  
  func setPlaybackRate(suggestedRate:Float) {
    let command = NSString(format: "player.setPlaybackRate(%f);", suggestedRate);
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func availablePlaybackRates() -> NSArray {
    
    let returnValue:NSString = self.stringFromEvaluatingJavaScript("player.getAvailablePlaybackRates();")
    let playbackRateData:NSData = returnValue.dataUsingEncoding(NSUTF8StringEncoding)!
    var jsonDeserializationError:NSError?
    let playbackRates:NSArray = NSJSONSerialization.JSONObjectWithData(playbackRateData, options: NSJSONReadingOptions.MutableContainers, error: &jsonDeserializationError) as NSArray
    
    if (jsonDeserializationError != nil) {
      return NSArray()
    }
    
    return playbackRates
  }
  
  // MARK:- Setting playback behavior for playlists
  func setLoop(loop:Bool) {
    let loopPlayListValue = self.stringForJSBoolean(loop)
    let command =  NSString(format: "player.setLoop(%@);", loopPlayListValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  func setShuffle(shuffle:Bool) {
    let loopPlayListValue = self.stringForJSBoolean(shuffle)
    let command =  NSString(format: "player.setLoop(%@);", loopPlayListValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  // MARK:- Playback Status
  func videoLoadedFraction() -> Float {
    return self.stringFromEvaluatingJavaScript("player.getVideoLoadedFraction();").floatValue
  }
  
  func playerState() -> YTPlayerState {
    let returnValue = self.stringFromEvaluatingJavaScript("player.getPlayerState();")
    return YTPlayerView.playerStateForString(returnValue)
  }
  
  func currentTime() -> Float {
    return self.stringFromEvaluatingJavaScript("player.getCurrentTime();").floatValue
  }
  
  func playbackQuality() -> YTPlayBackQuality {
    let qualityValue = self.stringFromEvaluatingJavaScript("player.getPlaybackQuality();")
    return YTPlayerView.playbackQualityForString(qualityValue)
  }
  
  func setPlaybackQuality(suggestedQuality:YTPlayBackQuality) {
    let qualityValue = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command = NSString(format: "player.setPlaybackQuality('%@');", qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  // MARK:- Video information methods
  
  func duration() -> Int {
    return self.stringFromEvaluatingJavaScript("player.getDuration();").integerValue
  }
  
  func videoUrl() -> NSURL {
    return NSURL.URLWithString(self.stringFromEvaluatingJavaScript("player.getVideoUrl();"))
  }
  
  func videoEmbedCode() -> NSString {
    return self.stringFromEvaluatingJavaScript("player.getVideoEmbedCode();")
  }
  
  // MARK:- Playlist
  func playlist() -> NSArray {
    let returnValue:NSString = self.stringFromEvaluatingJavaScript("player.getPlaylist();")
    let playlistData:NSData = returnValue.dataUsingEncoding(NSUTF8StringEncoding)!
    var jsonDeserializationError:NSError?
    let videoIds:NSArray = NSJSONSerialization.JSONObjectWithData(playlistData, options: NSJSONReadingOptions.MutableContainers, error: &jsonDeserializationError) as NSArray
    if jsonDeserializationError != nil {
      return NSArray()
    }
    
    return videoIds
  }
  
  func playlistIndex() -> Int {
    return self.stringFromEvaluatingJavaScript("player.getPlaylistIndex();").integerValue
  }
  
  func nextVideo() {
    self.stringFromEvaluatingJavaScript("player.nextVideo();")
  }
  
  func previousVideo() {
    self.stringFromEvaluatingJavaScript("player.previousVideo();")
  }
  
  func playVideoAt(index:Int) {
    let command = NSString(format: "player.playVideoAt(%@);", NSNumber.numberWithInteger(index))
    self.stringFromEvaluatingJavaScript(command)
  }
  
  // MARK:- Helper method
  func availableQualityLevels() -> NSArray {
    let returnValue:NSString = self.stringFromEvaluatingJavaScript("player.getAvailableQualityLevels();")
    let availableQualityLevelsData = returnValue.dataUsingEncoding(NSUTF8StringEncoding)
    var jsonDeserializationError:NSError?
    let rawQualityValues:NSArray = NSJSONSerialization.JSONObjectWithData(availableQualityLevelsData!, options: NSJSONReadingOptions.MutableContainers, error: &jsonDeserializationError) as NSArray
    if jsonDeserializationError != nil {
      return NSArray()
    }
    
    let levels:NSMutableArray = NSMutableArray()
    for rawQualityValue in rawQualityValues {
      let quality:YTPlayBackQuality = YTPlayerView.playbackQualityForString(rawQualityValue as NSString)
      levels.addObject(NSNumber.numberWithInteger(quality.toRaw()))
    }
    
    return levels
  }
  
  func webView(webView: UIWebView!, shouldStartLoadWithRequest request: NSURLRequest!, navigationType: UIWebViewNavigationType) -> Bool {
    let scheme = request.URL.scheme as NSString
    if scheme.isEqual("ytplayer") {
      self.notifyDelegateOfYouTubeCallbackUrl(request.URL)
      return false
    } else if scheme.isEqual("http") || scheme.isEqual("https") {
      return self.handleHttpNavigationToUrl(request.URL)
    }
    
    return true
  }
  
  func loadWithPlayerParams(additionalPlayerParams:NSDictionary!) -> Bool{
    let playerCallbacks:NSDictionary = [
      "onReady" : "onReady",
      "onStateChange" : "onStateChange",
      "onPlaybackQualityChange" : "onPlaybackQualityChange",
      "onError" : "onPlayerError"]
    
    let playerParams:NSMutableDictionary = NSMutableDictionary()
    playerParams.addEntriesFromDictionary(additionalPlayerParams)
    playerParams.setValue("100%", forKey: "height")
    playerParams.setValue("100%", forKey: "width")
    playerParams.setValue(playerCallbacks, forKey: "events")
    
    if !(playerParams.objectForKey("playerVars") != nil) {
      playerParams.setValue(NSDictionary(), forKey: "playerVars")
    }
    
    self.webView?.removeFromSuperview()
    self.webView = self.createNewWebView();
    self.addSubview(self.webView!)
    
    var error:NSError?
    let path:NSString = NSBundle.mainBundle().pathForResource("YTPlayerView-iframe-player", ofType: "html", inDirectory: "Assets")!
    var embedHTMLTemplate = NSString.stringWithContentsOfFile(path, encoding: NSUTF8StringEncoding, error: &error)
    
    if error != nil {
      NSLog("Received error rendering template: %@", error!)
      return false;
    }
    
    // Render the playerVars as a JSON dictionary.
    var jsonRenderingError:NSError?
    let jsonDate:NSData = NSJSONSerialization.dataWithJSONObject(playerParams, options:.PrettyPrinted, error: &jsonRenderingError)!
    
    if ((jsonRenderingError) != nil) {
      NSLog("Attempted configuration of player with invalid playerVars: %@ \tError: %@", playerParams, jsonRenderingError!)
      return false
    }
    
    let playerVarsJsonString:String = NSString(data: jsonDate, encoding: NSUTF8StringEncoding)
    let embedHTML:String = NSString(format: embedHTMLTemplate, playerVarsJsonString)
    self.webView!.loadHTMLString(embedHTML, baseURL: NSURL.URLWithString("about:blank"))
    self.webView!.allowsInlineMediaPlayback = true
    self.webView!.mediaPlaybackRequiresUserAction = false
    
    return true;
  }
  
  func createNewWebView() -> UIWebView {
    let webView = UIWebView(frame: self.bounds)
    webView.autoresizingMask = (UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight)
    webView.scrollView.scrollEnabled = false
    webView.scrollView.bounces = false
    webView.backgroundColor = UIColor.yellowColor()
    
    return webView
  }
  
  /**
  * Private method for cueing both cases of playlist ID and array of video IDs. Cueing
  * a playlist does not start playback.
  *
  * @param cueingString A JavaScript string representing an array, playlist ID or list of
  *                     video IDs to play with the playlist player.
  * @param index 0-index position of video to start playback on.
  * @param startSeconds Seconds after start of video to begin playback.
  * @param suggestedQuality Suggested YTPlaybackQuality to play the videos.
  * @return The result of cueing the playlist.
  */
  func cuePlaylist(cueingString:NSString, index:Int, startSecond:Float, suggestedQuality:YTPlayBackQuality) {
    let indexValue:NSNumber = NSNumber.numberWithInteger(index)
    let startSecondsValue = NSNumber.numberWithFloat(startSecond)
    let qualityValue = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command = NSString(format: "player.cuePlaylist(%@, %@, %@, '%@');", cueingString, indexValue, startSecondsValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  /**
  * Private method for loading both cases of playlist ID and array of video IDs. Loading
  * a playlist automatically starts playback.
  *
  * @param cueingString A JavaScript string representing an array, playlist ID or list of
  *                     video IDs to play with the playlist player.
  * @param index 0-index position of video to start playback on.
  * @param startSeconds Seconds after start of video to begin playback.
  * @param suggestedQuality Suggested YTPlaybackQuality to play the videos.
  * @return The result of cueing the playlist.
  */
  func loadPlaylist(cueingString:NSString, index:Int, startSecond:Float, suggestedQuality:YTPlayBackQuality) {
    let indexValue:NSNumber = NSNumber.numberWithInteger(index)
    let startSecondsValue = NSNumber.numberWithFloat(startSecond)
    let qualityValue = YTPlayerView.stringForPlaybackQuality(suggestedQuality)
    let command = NSString(format: "player.loadPlaylist(%@, %@, %@, '%@');", cueingString, indexValue, startSecondsValue, qualityValue)
    self.stringFromEvaluatingJavaScript(command)
  }
  
  /**
  * Private helper method for converting an NSArray of video IDs into its JavaScript equivalent.
  *
  * @param videoIds An array of video ID strings to convert into JavaScript format.
  * @return A JavaScript array in String format containing video IDs.
  */
  func stringFromVideoIdArray(videoIds:NSArray) -> NSString {
    let formattedVideoIds = NSMutableArray()
    
    for unformattedId in videoIds {
      formattedVideoIds.addObject(NSString(format: "'%@'",unformattedId as NSString))
    }
    
    return NSString(format: "[%@]", formattedVideoIds.componentsJoinedByString(", "))
  }
  
  /**
  * Private method for evaluating JavaScript in the WebView.
  *
  * @param jsToExecute The JavaScript code in string format that we want to execute.
  * @return JavaScript response from evaluating code.
  */
  
  func stringFromEvaluatingJavaScript(jsToExecute:NSString) -> NSString {
    
    return self.webView!.stringByEvaluatingJavaScriptFromString(jsToExecute)
    
  }
  
  /**
  * Private method to convert a Objective-C BOOL value to JS boolean value.
  *
  * @param boolValue Objective-C BOOL value.
  * @return JavaScript Boolean value, i.e. "true" or "false".
  */
  
  func stringForJSBoolean(boolValue:Bool) -> NSString{
    return boolValue ? "true":"false"
  }
  
// MARK:- Class Method
  
  /**
  * Convert a quality value from NSString to the typed enum value.
  *
  * @param qualityString A string representing playback quality. Ex: "small", "medium", "hd1080".
  * @return An enum value representing the playback quality.
  */
  class func playbackQualityForString(qualityString:NSString) -> YTPlayBackQuality{
    var quality:YTPlayBackQuality = .Unknown;
    
    if (qualityString.isEqualToString(kYTPlaybackQualitySmallQuality)) {
      quality = .Small;
    } else if (qualityString.isEqualToString(kYTPlaybackQualityMediumQuality)) {
      quality = .Medium;
    } else if (qualityString.isEqualToString(kYTPlaybackQualityLargeQuality)) {
      quality = .Large;
    } else if (qualityString.isEqualToString(kYTPlaybackQualityHD720Quality)) {
      quality = .HD720;
    } else if (qualityString.isEqualToString(kYTPlaybackQualityHD1080Quality)) {
      quality = .HD1080;
    } else if (qualityString.isEqualToString(kYTPlaybackQualityHighResQuality)) {
      quality = .HighRes;
    }
    
    return quality;
  }
  
  /**
  * Convert a |YTPlaybackQuality| value from the typed value to NSString.
  *
  * @param quality A |YTPlaybackQuality| parameter.
  * @return An |NSString| value to be used in the JavaScript bridge.
  */
  class func stringForPlaybackQuality(quality:YTPlayBackQuality) -> NSString {
    
    switch (quality) {
    case .Small:
      return kYTPlaybackQualitySmallQuality
    case .Medium:
      return kYTPlaybackQualityMediumQuality
    case .HD720:
      return kYTPlaybackQualityHD720Quality
    case .HD1080:
      return kYTPlaybackQualityHD1080Quality
    case .HighRes:
      return kYTPlaybackQualityHighResQuality
    default:
      return kYTPlaybackQualityUnknownQuality
    }
    
  }
  
  /**
  * Convert a state value from NSString to the typed enum value.
  *
  * @param stateString A string representing player state. Ex: "-1", "0", "1".
  * @return An enum value representing the player state.
  */
  class func playerStateForString(stateString:NSString) -> YTPlayerState {
    
    var state:YTPlayerState = .Unknown
    if stateString.isEqualToString(kYTPlayerStateUnstartedCode) {
      state = .Unstarted
    } else if stateString.isEqualToString(kYTPlayerStateEndedCode) {
      state = .Ended
    } else if stateString.isEqualToString(kYTPlayerStatePlayingCode) {
      state = .Playing
    } else if stateString.isEqualToString(kYTPlayerStatePausedCode) {
      state = .Paused
    } else if stateString.isEqualToString(kYTPlayerStateBufferingCode) {
      state = .Buffering
    } else if stateString.isEqualToString(kYTPlayerStateCuedCode) {
      state = .Queued
    }
    
    return state;
    
  }
  
  /**
  * Convert a state value from the typed value to NSString.
  *
  * @param quality A |YTPlayerState| parameter.
  * @return A string value to be used in the JavaScript bridge.
  */
  
  class func stringForPlayerState(state:YTPlayerState) -> NSString {
    switch (state) {
    case .Unstarted:
      return kYTPlayerStateUnstartedCode
    case .Ended:
      return kYTPlayerStateEndedCode
    case .Playing:
      return kYTPlayerStatePlayingCode
    case .Paused:
      return kYTPlayerStatePausedCode
    case .Buffering:
      return kYTPlayerStateBufferingCode
    case .Queued:
      return kYTPlayerStateCuedCode
    default:
      return kYTPlayerStateUnknownCode
    }
  }
  
  // MARK:- Private methods
  /**
  * Private method to handle "navigation" to a callback URL of the format
  * http://ytplayer/action?data=someData
  * This is how the UIWebView communicates with the containing Objective-C code.
  * Side effects of this method are that it calls methods on this class's delegate.
  *
  * @param url A URL of the format http://ytplayer/action.
  */
  func notifyDelegateOfYouTubeCallbackUrl(url:NSURL) {
    let action:NSString = url.host!
    
    // We know the query can only be of the format http://ytplayer?data=SOMEVALUE,
    // so we parse out the value.
    let query:NSString? = url.query!
    var dataString:NSString = ""
    
    if (query != nil) {
      dataString = query!.componentsSeparatedByString("=")[1] as NSString
    }
    
    if action.isEqual(kYTPlayerCallbackOnReady) {
      if let delegate = self.delegate {
        delegate.playerViewDidBecomeRead?(self)
      }
    } else if action.isEqual(kYTPlayerCallbackOnStateChange) {
      if let delegate = self.delegate {
        var state:YTPlayerState = .Unknown
        
        if dataString.isEqual(kYTPlayerStateEndedCode) {
          state = .Ended
        } else if dataString.isEqual(kYTPlayerStatePlayingCode) {
          state = .Playing
        } else if dataString.isEqual(kYTPlayerStateBufferingCode) {
          state = .Paused
        } else if dataString.isEqual(kYTPlayerStateCuedCode) {
          state = .Queued
        } else if dataString.isEqual(kYTPlayerStateUnstartedCode) {
          state = .Unstarted
        }
        
        delegate.playerView?(self, didChangeToState: state.toRaw())
      }
    } else if action.isEqual(kYTPlayerCallbackOnError) {
      if let delegate = self.delegate {
        var error:YTPlayerError = .Unknown
        
        if dataString.isEqual(kYTPlayerErrorInvalidParamErrorCode) {
          error = .InvalidParam
        } else if dataString.isEqual(kYTPlayerErrorHTML5ErrorCode) {
          error = .HTML5Error
        } else if dataString.isEqual(kYTPlayerErrorNotEmbeddableErrorCode) {
          error = .NotEmbeddable
        } else if dataString.isEqual(kYTPlayerErrorVideoNotFoundErrorCode) || dataString.isEqual(kYTPlayerErrorCannotFindVideoErrorCode) {
          error = .VideoNotFound
        }
        
        delegate.playerView?(self, receivedError: error.toRaw())
      }
    }
  }
  
  func handleHttpNavigationToUrl(url:NSURL) -> Bool {
    var error:NSError?
    let regex:NSRegularExpression = NSRegularExpression.regularExpressionWithPattern(kYTPlayerEmbedUrlRegexPattern, options: NSRegularExpressionOptions.CaseInsensitive, error: &error)!
    let absoluteString:NSString = url.absoluteString! as NSString
    let match:NSTextCheckingResult? = regex.firstMatchInString(absoluteString, options: NSMatchingOptions.ReportProgress, range: NSMakeRange(0, absoluteString.length))
    
    if (match != nil) {
      return true
    } else {
      UIApplication.sharedApplication().openURL(url)
      return false
    }
  }
  
  // MARK:- Updating API
  
  func enterFullscreen() {
    self.overlayWindow.addSubview(self.webView!)
    self.webView!.frame = self.overlayWindow.bounds
  }
  
  func exitFullscreen() {
    self.webView?.allowsInlineMediaPlayback = true
  }
  
  func commonSetupOnInit() {
    
  }
  
  /**
  * The 'redrawPlayer' function builds the SWF URL based on the selected video
  * and other parameters that the user may have selected. It also redraws the
  * player on the page.
  * @return {string} The SWF URL for the video player.
  */
  func redrawPlayer() {
    
  }
}
