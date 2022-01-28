//
//  VideoFrameReader.swift
//  Lesson3-DrawVideo
//
//  Created by zhang.wenhai on Friday2022/1/28.
//

import Foundation
import AVFoundation

class VideoFrameReader: NSObject {
    
    let asset: AVAsset
    
    private let player = AVPlayer()
    private let playerItem: AVPlayerItem
    private var videoOutput: AVPlayerItemVideoOutput!
    
    init(asset: AVAsset) {
        self.asset = asset
        self.playerItem = AVPlayerItem(asset: asset)
        super.init()
        setupPlayer()
    }
}

extension VideoFrameReader {
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func getFrame(at timeStamp: TimeInterval) -> CVPixelBuffer? {
        let hostTime = videoOutput.itemTime(forHostTime: timeStamp)
        return videoOutput.copyPixelBuffer(forItemTime: hostTime, itemTimeForDisplay: nil)
    }
}

private extension VideoFrameReader {
    func setupPlayer() {
        player.replaceCurrentItem(with: playerItem)
        player.actionAtItemEnd = .none
        
        var naturalSize: CGSize = .zero
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            naturalSize = videoTrack.naturalSize
        }
        
        var attibutes: [String: Any] = [:]
        attibutes[kCVPixelBufferPixelFormatTypeKey as String] = kCVPixelFormatType_32BGRA
        attibutes[kCVPixelBufferWidthKey as String] = naturalSize.width
        attibutes[kCVPixelBufferHeightKey as String] = naturalSize.height
        
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: attibutes)
        videoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: 1.0/30.0)
        playerItem.add(videoOutput)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: playerItem,
                                               queue: .main) { [weak self] noti in
            self?.playerItem.seek(to: .zero, completionHandler: nil)
        }
    }
}
