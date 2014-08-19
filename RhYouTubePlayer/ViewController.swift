//
//  ViewController.swift
//  RhYouTubePlayer
//
//  Created by Ratha Hin on 8/13/14.
//  Copyright (c) 2014 rathahin. All rights reserved.
//

import UIKit

class ViewController: UIViewController, RhYouTubePlayerViewDelegate {
  @IBOutlet weak var playerView: YTPlayerView!
                            
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    let videoId:NSString = "M7lc1UVf-VE"
    let playerVars = [
      "controls": 0,
      "playsinline": 1,
      "autohide": 1,
      "showinfo": 0,
      "modestbranding": 1]
    self.playerView.delegate = self
    self.playerView.loadWithVideoId(videoId, playerVars: playerVars)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


}

