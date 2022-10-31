//
//  AudioPlayer.swift
//  Music
//
//  Created by Lucas Alward on 2/10/22.
//
/*
import Foundation
import AVFoundation

class AudioPlayer {
    public static let shared = AudioPlayer()
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    fileprivate let seekDuration: Float64 = 10

    public func load(url: URL) {
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
    }
    
    public func set
    
    public func isPlaying() -> Bool {
        return
    }

    public func isBuffering() -> Bool {
        return !(self.player?.currentItem?.isPlaybackLikelyToKeepUp ?? true)
    }

    public func getPlaybackTimeSeconds() -> TimeInterval {
        guard let playbackTime = playerItem?.currentTime() else { return 0 }
        return CMTimeGetSeconds(playbackTime)
    }

    public func getDurationSeconds() -> TimeInterval {
        guard let duration = playerItem?.asset.duration else { return 0 }
        return CMTimeGetSeconds(duration)
    }

    public func getPlaybackTimeString() -> String {
        return format(timeInterval: getPlaybackTimeSeconds())
    }

    public func getDurationString() -> String {
        return format(timeInterval: getDurationSeconds())
    }

    private func format(timeInterval: TimeInterval) -> String {
        let interval = Int(timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
*/
