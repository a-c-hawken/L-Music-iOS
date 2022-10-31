//
//  MusicAPI.swift
//  Music
//
//  Created by Lucas Alward on 2/10/22.
//

import Foundation
import AVFAudio
import AVFoundation
import MediaPlayer
import PythonSupport
import YoutubeDL

public protocol MusicAPIBaseSong {
    var title: String { get set }
    var songId: String { get set }
    var artists: [String] { get set }
    var image: MusicAPI.SongImage { get set }
    var likeStatus: MusicAPI.Like { get set }
}

public class MusicAPI: NSObject {
    public enum Source {
        case browse, search, upnext, queue, downloads
    }
    
    public struct Like: Codable {
        public enum Status: String, Codable {
            case like, dislike, indifferent
        }
        
        var status: Status
    }
    
    public struct SongCategory: Decodable {
        var title: String
        var items: [SongSmall]
    }
    
    public struct SongImage: Codable {
        var url: String
        var width: Int
        var height: Int
    }
    
    public struct SongSmall: MusicAPIBaseSong, Decodable {
        public var title: String
        public var songId: String
        public var artists: [String]
        public var image: SongImage
        public var likeStatus: Like = Like(status: .indifferent)
    }
    
    public struct Song: MusicAPIBaseSong, Decodable {
        public struct VideoPlayback: Decodable {
            var url: String
            var format: String
        }
        
        public var title: String
        public var songId: String
        public var artists: [String]
        public var image: SongImage
        var videoplayback: VideoPlayback
        public var likeStatus: Like = Like(status: .indifferent)
        
        func toSongSmall() -> SongSmall {
            return SongSmall(title: self.title, songId: self.songId, artists: self.artists, image: self.image, likeStatus: self.likeStatus)
        }
    }
    
    public struct Lyrics: Decodable {
        var lyrics: String
        var source: String
    }
    
    public struct Watchlist: Decodable {
        var watchlist: [SongSmall]
        var currentSong: SongSmall
    }
    
    public struct DownloadedSong: MusicAPIBaseSong, Codable {
        struct Path: Codable {
            var path: String
            var format: String
            
            func url() -> URL {
                return MusicAPI.shared.documentsDirectory().appendingPathComponent(path)
            }
        }
        
        public var title: String
        public var songId: String
        public var artists: [String]
        public var image: MusicAPI.SongImage
        public var likeStatus: MusicAPI.Like = Like(status: .indifferent)
        
        var path: Path
        
        init(from song: Song, path: Path) {
            self.title = song.title
            self.songId = song.songId
            self.artists = song.artists
            self.image = song.image
            self.likeStatus = song.likeStatus
            self.path = path
        }
        
        func toSongSmall() -> SongSmall {
            return SongSmall(title: self.title, songId: self.songId, artists: self.artists, image: self.image, likeStatus: self.likeStatus)
        }
        
        func toSong() -> Song {
            return Song(title: self.title, songId: self.songId, artists: self.artists, image: self.image, videoplayback: Song.VideoPlayback(url: MusicAPI.shared.documentsDirectory().appendingPathComponent(self.path.path).absoluteString, format: self.path.format), likeStatus: self.likeStatus)
        }
    }
    
    public enum UpdateType {
        case songState, playbackTime
    }
    
    public struct Settings: Codable {
        var host: String
        var authKey: String
        var dataSaver: Bool
    }
    
    public static let shared = MusicAPI()
    public var offline = true
    private var key = "nil"
    private var url = URL(string: "https://music.lucasalward.com/api/v1")!
    private var songQueue: [Song] = []
    private var previousSongQueue: [Song] = []
    private var endTimeObserver: Any?
    private var playbackTimeObserver: Any?
    private var registeredUpdates: [UpdateType: [() -> ()]] = [:]
    private var youtubeDL: YoutubeDL? = nil
    private var reachability: Reachability?
    private var playingFrom = ""
    private var offlineOverData = true
    
    public func settings() -> Settings {
        return Settings(host: url.absoluteString, authKey: key, dataSaver: offlineOverData)
    }
    
    public func settings(_ settings: Settings) {
        saveSettings(settings)
        
        if let url = URL(string: settings.host) {
            self.url = url
        }
        self.key = settings.authKey
        self.offlineOverData = settings.dataSaver
    }
    
    private func saveSettings(_ settings: Settings) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(settings) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: "musicAPISettings")
        }
    }
    
    private func loadSettings() {
        if let udefault = UserDefaults.standard.object(forKey: "musicAPISettings") as? Data {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(Settings.self, from: udefault) {
                settings(decoded)
            }
        }
    }
    
    public func login(headers: String) {
        // TODO Implement
    }
    
    public func browse(callback: @escaping ([SongCategory]) -> ()) {
        print("BROWSE")
        if offline {
            callback([])
            return
        }
        
        var urlComponents = URLComponents(url: self.url.appendingPathComponent("browse"), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let url = urlComponents?.url else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let songCategories = try? JSONDecoder().decode([SongCategory].self, from: data) {
                    callback(songCategories)
                } else {
                    print("Invalid Response")
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }
        task.resume()
    }
    
    public func search(for q: String, callback: @escaping ([SongCategory]) -> ()) {
        if offline {
            callback([])
            return
        }
        
        var urlComponents = URLComponents(url: self.url.appendingPathComponent("search"), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = [URLQueryItem(name: "key", value: key), URLQueryItem(name: "q", value: q)]
        guard let url = urlComponents?.url else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let songCategories = try? JSONDecoder().decode([SongCategory].self, from: data) {
                    callback(songCategories)
                } else {
                    print("Invalid Response")
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }
        task.resume()
    }
    
    private var downloaded_songs: [DownloadedSong] = []
    
    public func download(song: Song? = nil, callback: @escaping (String) -> ()) {
        var song = song
        
        if song == nil {
            song = self.currentlyPlayingSong()
        }
        
        guard let song = song else {
            callback("Download Failed 174")
            return
        }
        
        guard !downloaded_songs.contains(where: { $0.songId == song.songId }) else {
            callback("Song Already Downloaded")
            return
        }
        
        if offline {
            callback("You're offline - you can't download songs")
            return
        }

        guard
            let url = URL(string: song.videoplayback.url),
            song.videoplayback.format != "unavailable"
        else {
            callback("Download Failed 182")
            return
        }
        
        print("[DOWNLOAD]", url)
        
        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            print("[DOWNLOAD] result")
            guard
                let location = location,
                error == nil
            else {
                print("[DOWNLOAD] 191")
                callback("Download Failed 191")
                return
            }
            
            do {
                //let downloaded_songs_directory = self.documentsDirectory().appendingPathComponent("downloaded_songs/")//.appendingPathComponent(song.songId)
                //try FileManager.default.createDirectory(atPath: downloaded_songs_directory.absoluteString, withIntermediateDirectories: true, attributes: nil)
                
                let destination = self.documentsDirectory().appendingPathComponent("downloaded_song_" + song.songId)//.appendingPathComponent(song.songId)
                
                print("[DOWNLOAD]", destination)
                try FileManager.default.moveItem(at: location, to: destination)
                
                self.downloaded_songs.append(DownloadedSong(from: song, path: DownloadedSong.Path(path: destination.lastPathComponent, format: song.videoplayback.format)))
                self.saveDownloadedSongs()
                print("[DOWNLOAD] done")
                callback("Song Successfully Downloaded")
            } catch let error {
                print("[DOWNLOAD] 203")
                print("[DOWNLOAD]", error)
                callback("Download Failed 203")
            }
        }
        print("[DOWNLOAD] starting")
        task.resume()
    }
    
    public func deleteDownloaded(song: MusicAPIBaseSong? = nil, callback: @escaping (_ title: String, _ message: String) -> ()) {
        var song = song
        
        if song == nil {
            song = self.currentlyPlayingSong()
        }
        
        guard let song = song else {
            callback("Error", "Deleting this song failed. Error 301")
            return
        }
        
        guard downloaded_songs.contains(where: { $0.songId == song.songId }) else {
            callback("Error", "Deleting this song failed. Error 306")
            return
        }
        
        do {
            let destination = self.documentsDirectory().appendingPathComponent("downloaded_song_" + song.songId)
            
            try FileManager.default.removeItem(at: destination)
            
            self.downloaded_songs.removeAll { $0.songId == song.songId }
            self.saveDownloadedSongs()
            
            callback("Song Deleted", "This song was deleted")
        } catch _ {
            callback("Error", "Deleting this song failed. Error 320")
        }
    }
    
    public func downloadedSongs() -> [SongCategory] {
        return [SongCategory(title: "Downloads", items: downloaded_songs.map { $0.toSongSmall() })]
    }
    
    private func saveDownloadedSongs() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(downloaded_songs) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: "downloadedSongs")
        }
    }
    
    private func loadDownloadedSongs() {
        if let udefault = UserDefaults.standard.object(forKey: "downloadedSongs") as? Data {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([DownloadedSong].self, from: udefault) {
                self.downloaded_songs = decoded
            }
        }
    }
    
    private func fixDownloadedSongs() {
        //loadDownloadedSongs()
        
        /*let format_to_ext = [
            "mp4": "m4a",
            "mpeg": "mp3",
            "wav": "wav",
            "ogg": "ogg"
        ]*/
        
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: self.documentsDirectory(), includingPropertiesForKeys: nil)
            
            for file in allFiles {
                downloaded_songs.append(DownloadedSong(from: Song(title: file.lastPathComponent, songId: file.lastPathComponent, artists: [], image: SongImage(url: "", width: 0, height: 0), videoplayback: Song.VideoPlayback(url: "", format: ""), likeStatus: Like(status: .indifferent)), path: DownloadedSong.Path(path: file.lastPathComponent, format: "mp4")))
            }
        } catch {
            print("[FIX]", "ERROR", "all_files")
        }
        
        saveDownloadedSongs()
                
        //print("[HHJDF]", downloaded_songs)
        /*
        var index = 0
        
        for downloaded_song in downloaded_songs {
            print("[HHJDF]", downloaded_song)
            /*let origin_path = downloaded_song.path.url
            
            origin_path
            
            let destination_path = origin_path.deletingLastPathComponent().appendingPathComponent("downloaded_song_with_ext_" + downloaded_song.songId).appendingPathExtension(format_to_ext[downloaded_song.path.format]!)
            
            print("[FIX]", "origin_path exists", FileManager.default.fileExists(atPath: origin_path.absoluteString))
            print("[FIX]", "destination_path exists", FileManager.default.fileExists(atPath: destination_path.absoluteString))
            
            print("[FIX]", "origin_path", origin_path)
            print("[FIX]", "destination_path", destination_path)
            
            do {
                try FileManager.default.moveItem(at: origin_path, to: destination_path)
            } catch let error {
                print("[FIX]", downloaded_song.songId, error)
            }*/
            
            downloaded_songs[index].path.path = downloaded_song.path.url.path
            print("[HHJDF]", downloaded_songs[index].path.path)
            
            index += 1
        }
        */
        //saveDownloadedSongs()
    }
    
    private var local_song_queue: [(MusicAPIBaseSong, (Song?) -> ())] = []
    private var local_song_clear_queue_and_stop = false
    
    private func local_song(_ song: MusicAPIBaseSong, disregardQueue: Bool = false, callback: @escaping (Song?) -> ()) {
        if offline {
            return
        }
        
        print("{Y}", song.songId, "disregardQueue", disregardQueue, "local_song_queue.count", local_song_queue.count)
        
        if !disregardQueue {
            local_song_queue.append((song, callback))
            guard local_song_queue.count == 1 else { return }
        }
        
        print("CALLED FOR ", song.songId)
        
        var urlComponents = URLComponents(url: URL(string: "https://www.youtube.com/")!.appendingPathComponent("watch"), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = [URLQueryItem(name: "v", value: song.songId)]
        guard let url = urlComponents?.url else { return }
        
        guard let youtubeDL = youtubeDL else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (_, info) = try youtubeDL.extractInfo(url: url)
                                            
                guard let formats = info?.formats else { return }
                
                var resultSong: Song?
                if let m4a = formats.last(where: { $0.isAudioOnly && $0.ext == "m4a" }) {
                    guard let url = m4a.url else { return }
                    
                    resultSong = Song(title: song.title, songId: song.songId, artists: song.artists, image: song.image, videoplayback: .init(url: url, format: "mp4"), likeStatus: song.likeStatus)
                } else if let mp3 = formats.last(where: { $0.isAudioOnly && $0.ext == "mp3" }) {
                    guard let url = mp3.url else { return }
                    
                    resultSong = Song(title: song.title, songId: song.songId, artists: song.artists, image: song.image, videoplayback: .init(url: url, format: "mpeg"), likeStatus: song.likeStatus)
                } else if let wav = formats.last(where: { $0.isAudioOnly && $0.ext == "wav" }) {
                    guard let url = wav.url else { return }
                    
                    resultSong = Song(title: song.title, songId: song.songId, artists: song.artists, image: song.image, videoplayback: .init(url: url, format: "wav"), likeStatus: song.likeStatus)
                } else if let ogg = formats.last(where: { $0.isAudioOnly && $0.ext == "ogg" }) {
                    guard let url = ogg.url else { return }
                    
                    resultSong = Song(title: song.title, songId: song.songId, artists: song.artists, image: song.image, videoplayback: .init(url: url, format: "ogg"), likeStatus: song.likeStatus)
                }
                
                guard let resultSong = resultSong else { return }
                
                guard !self.local_song_clear_queue_and_stop else {
                    self.local_song_clear_queue_and_stop = false
                    DispatchQueue.main.async {
                        self.local_song_queue.remove(at: 0)
                        print("STOPPED, REMOVED SELF. MOVING TO NEXT QUEUE ITEM")
                        if self.local_song_queue.count > 0 {
                            self.local_song(self.local_song_queue[0].0, disregardQueue: true, callback: self.local_song_queue[0].1)
                        }
                    }
                    return
                }
                
                callback(resultSong)
                print("{Y} CALLBACK DONE FOR", song.songId)
                
                DispatchQueue.main.async {
                    self.local_song_queue.remove(at: 0)
                    print(self.local_song_queue.count, "QUEUE ITEMS REMAINING")
                    if self.local_song_queue.count > 0 {
                        print("MOVING TO NEXT QUEUE ITEM")
                        self.local_song(self.local_song_queue[0].0, disregardQueue: true, callback: self.local_song_queue[0].1)
                    }
                }
            } catch {
                print("[YOUTUBEDL] Error extracting info")
                callback(nil)
                return
            }
        }
    }
    
    private func song(_ song: MusicAPIBaseSong, callback: @escaping (Song) -> ()) {
        if offline {
            return
        }
        
        var urlComponents = URLComponents(url: self.url.appendingPathComponent("song"), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = [URLQueryItem(name: "key", value: key), URLQueryItem(name: "songId", value: song.songId)]
        guard let url = urlComponents?.url else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let song = try? JSONDecoder().decode(Song.self, from: data) {
                    callback(song)
                } else {
                    print("Invalid Response")
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }
        task.resume()
    }
    
    private func watchlist(_ song: MusicAPIBaseSong, callback: @escaping (Watchlist) -> ()) {
        if offline {
            return
        }
        
        var urlComponents = URLComponents(url: self.url.appendingPathComponent("watchlist"), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = [URLQueryItem(name: "key", value: key), URLQueryItem(name: "songId", value: song.songId)]
        guard let url = urlComponents?.url else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let watchlist = try? JSONDecoder().decode(Watchlist.self, from: data) {
                    callback(watchlist)
                } else {
                    print("Invalid Response")
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }
        task.resume()
    }
    
    public func songSelected(_ song: MusicAPIBaseSong, from source: Source, callback: (() -> ())? = nil) {
        if source == .upnext {
            guard
                let songQueueIndex = songQueue.firstIndex(where: { $0.songId == song.songId }),
                songQueueIndex != 0
            else {
                guard let previousSongQueueIndex = self.previousSongQueue.firstIndex(where: { $0.songId == song.songId }) else {
                    callback?()
                    return
                }
                
                print("STARTING")
                print(self.previousSongQueue.count)
                
                for i in (previousSongQueueIndex...(self.previousSongQueue.count - 1)).reversed() {
                    print(i)
                    guard
                        let url = URL(string: self.previousSongQueue[i].videoplayback.url),
                        self.songQueue[i].videoplayback.format != "unavailable"
                    else {
                        callback?()
                        return
                    }
                    let item = AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/\(self.songQueue[i].videoplayback.format)"]))
                    
                    guard let currentItem = self.player.currentItem else { return }
                    self.player.insert(item, after: currentItem)
                    self.player.remove(currentItem)
                    self.player.insert(currentItem, after: item)
                    self.songQueue.insert(self.previousSongQueue[i], at: 0)
                    self.previousSongQueue.remove(at: i)
                }
                
                self.setupMPInfo(for: currentlyPlayingSong()!)
                self.update(.songState)
                self.player.currentItem?.addObserver(self, forKeyPath: "duration", context: nil)
                
                callback?()
                return
            }
            
            for _ in 1...songQueueIndex {
                self.player.advanceToNextItem()
                self.previousSongQueue.append(self.songQueue[0])
                self.songQueue.remove(at: 0)
            }
            
            // canGoNextTrack returning true means it must be safe to access the currently playing song. If not, it should be a fatal error anyway
            self.setupMPInfo(for: currentlyPlayingSong()!)
            self.update(.songState)
            self.player.currentItem?.addObserver(self, forKeyPath: "duration", context: nil)
            
            // Check if the new song (now currently playing) can go to the next track. If not, start fetching new items for the queue
            if !canGoNextTrack() {
                print("FETCHING NEW QUEUE ITEMS")
                self.watchlist(self.currentlyPlayingSong()!) { watchlist in
                    for song in watchlist.watchlist {
                        self.local_song(song) { song in
                            guard
                                let song = song,
                                let url = URL(string: song.videoplayback.url),
                                song.videoplayback.format != "unavailable"
                            else { return }
                            let item = AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/\(song.videoplayback.format)"]))
                            
                            guard self.player.canInsert(item, after: nil) else { return }
                            self.player.insert(item, after: nil)
                            
                            self.songQueue.append(song)
                            
                            self.update(.songState)
                        }
                    }
                }
            }
            
            callback?()
            return
        }
        
        if source == .browse || source == .search {
            playingFrom = "\(song.title) - Radio"
        }
        
        if source == .downloads {
            playingFrom = "Downloads"
        }
        
        self.player.pause()
        
        if offline || source == .downloads {
            guard let downloadedSong = downloaded_songs.first(where: { $0.songId == song.songId }) else {
                callback?()
                return
            }
            
            let item = AVPlayerItem(asset: AVURLAsset(url: downloadedSong.path.url(), options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/\(downloadedSong.path.format)"]))

            self.songQueue = []
            self.previousSongQueue = []
            
            self.songQueue.append(downloadedSong.toSong())
            
            self.player.removeAllItems()
            
            self.player.replaceCurrentItem(with: item)
            
            self.player.actionAtItemEnd = .pause
            
            self.setupMPInfo(for: downloadedSong.toSong())
            self.update(.songState)
            
            self.player.play()
            
            callback?()
            
            self.player.currentItem?.addObserver(self, forKeyPath: "duration", context: nil)
            
            for downloaded_song in downloaded_songs {
                if downloaded_song.songId == downloadedSong.songId {
                    continue
                }
                
                let item = AVPlayerItem(asset: AVURLAsset(url: downloaded_song.path.url(), options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/\(downloaded_song.path.format)"]))
                
                guard self.player.canInsert(item, after: nil) else { return }
                self.player.insert(item, after: nil)
                
                self.songQueue.append(downloaded_song.toSong())
                
                self.update(.songState)
            }
            
            return
        }
        
        if self.local_song_queue.count != 0 {
            if self.local_song_queue.count > 1 {
                self.local_song_queue.removeSubrange(1...self.local_song_queue.count - 1)
            }
            self.local_song_clear_queue_and_stop = true
        }
        
        self.local_song(song) { song in
            guard
                let song = song,
                let url = URL(string: song.videoplayback.url),
                song.videoplayback.format != "unavailable"
            else {
                callback?()
                return
            }
            let item = AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/\(song.videoplayback.format)"]))
            
            self.songQueue = []
            self.previousSongQueue = []
            
            self.songQueue.append(song)
            
            self.player.removeAllItems()
            
            self.player.replaceCurrentItem(with: item)
            
            self.player.actionAtItemEnd = .pause
            
            self.setupMPInfo(for: song)
            self.update(.songState)
            
            self.player.play()
            
            callback?()
            
            /*self.player.observe(\.status, options: [.initial, .new, .old, .prior]) { _, _ in
                print("STATUS CHANGED", self.player.status)
            }*/
            self.player.currentItem?.addObserver(self, forKeyPath: "duration", context: nil)
            
            self.watchlist(song) { watchlist in
                self.songQueue[0].likeStatus = watchlist.currentSong.likeStatus
                self.songQueue[0].image = watchlist.currentSong.image
                self.setupMPInfo(for: song)
                self.update(.songState)
                
                //DispatchQueue.global(qos: .utility).async {
                    for song in watchlist.watchlist {
                        // self.local_song Perhaps overloaded?
                        //let group = DispatchGroup()
                        //group.enter()
                        
                        self.local_song(song) { song in
                            guard
                                let song = song,
                                let url = URL(string: song.videoplayback.url),
                                song.videoplayback.format != "unavailable"
                            else { return }
                            let item = AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/\(song.videoplayback.format)"]))
                            
                            guard self.player.canInsert(item, after: nil) else { return }
                            self.player.insert(item, after: nil)
                            
                            self.songQueue.append(song)
                            
                            self.update(.songState)
                            
                            //group.leave()
                        }
                        
                        //group.wait()
                    }
                //}
            }
        }
    }
    
    public func like(song: MusicAPIBaseSong? = nil, callback: ((Like) -> ())? = nil) {
        var song = song
        var isCurrentlyPlayingSong = false
        
        if song == nil {
            song = self.currentlyPlayingSong()
            isCurrentlyPlayingSong = true
        }
        guard let song = song else { return }
        
        var urlComponents: URLComponents?
        
        switch song.likeStatus.status {
        case .like:
            urlComponents = URLComponents(url: self.url.appendingPathComponent("unrate"), resolvingAgainstBaseURL: true)
        default:
            urlComponents = URLComponents(url: self.url.appendingPathComponent("like"), resolvingAgainstBaseURL: true)
        }
        
        urlComponents?.queryItems = [URLQueryItem(name: "key", value: key), URLQueryItem(name: "songId", value: song.songId)]
        guard let url = urlComponents?.url else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let like = try? JSONDecoder().decode(Like.self, from: data) {
                    callback?(like)
                    if isCurrentlyPlayingSong {
                        self.songQueue[0].likeStatus = like
                    }
                } else {
                    print("Invalid Response")
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }
        task.resume()
    }
    
    public func dislike(song: MusicAPIBaseSong? = nil, callback: ((Like) -> ())? = nil) {
        var song = song
        var isCurrentlyPlayingSong = false
        
        if song == nil {
            song = self.currentlyPlayingSong()
            isCurrentlyPlayingSong = true
        }
        guard let song = song else { return }
        
        var urlComponents: URLComponents?
        
        switch song.likeStatus.status {
        case .dislike:
            urlComponents = URLComponents(url: self.url.appendingPathComponent("unrate"), resolvingAgainstBaseURL: true)
        default:
            urlComponents = URLComponents(url: self.url.appendingPathComponent("dislike"), resolvingAgainstBaseURL: true)
        }
        
        urlComponents?.queryItems = [URLQueryItem(name: "key", value: key), URLQueryItem(name: "songId", value: song.songId)]
        guard let url = urlComponents?.url else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let like = try? JSONDecoder().decode(Like.self, from: data) {
                    callback?(like)
                    if isCurrentlyPlayingSong {
                        self.songQueue[0].likeStatus = like
                    }
                } else {
                    print("Invalid Response")
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }
        task.resume()
    }
    
    public func lyrics(for song: MusicAPIBaseSong? = nil, callback: ((Lyrics) -> ())? = nil) {
        var song = song
        
        if song == nil {
            song = self.currentlyPlayingSong()
        }
        guard let song = song else { return }
        
        var urlComponents = URLComponents(url: self.url.appendingPathComponent("lyrics"), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = [URLQueryItem(name: "key", value: key), URLQueryItem(name: "songId", value: song.songId)]
        
        guard let url = urlComponents?.url else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let lyrics = try? JSONDecoder().decode(Lyrics.self, from: data) {
                    callback?(lyrics)
                } else {
                    print("Invalid Response")
                    callback?(Lyrics(lyrics: "An unexpected error occurred while fetching lyrics for this song", source: ""))
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
                callback?(Lyrics(lyrics: "An unexpected error occurred while fetching lyrics for this song", source: ""))
            }
        }
        task.resume()
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "duration" {
            self.refreshMPInfoTiming()
            
            print("DUR", self.getDurationSeconds())
            
            self.update(.songState)
            
            if let endTimeObserver = endTimeObserver {
                self.player.removeTimeObserver(endTimeObserver)
            }
            endTimeObserver = self.player.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTime(seconds: self.getDurationSeconds() - 0.1, preferredTimescale: 1000))], queue: .main) {
                print("DONE")
                /*self.songQueue.remove(at: 0)
                //print(self.songQueue)
                self.setupMPInfo(for: self.currentlyPlayingSong())
                self.player.currentItem?.addObserver(self, forKeyPath: "duration", context: nil)
                //self.player.removeTimeObserver(observer)*/
                self.nextTrack()
            }
            
            self.player.currentItem?.removeObserver(self, forKeyPath: "duration")
        }
    }
    
    public func register(for type: UpdateType, callback: @escaping () -> ()) {
        if registeredUpdates[type] != nil {
            registeredUpdates[type]?.append(callback)
        } else {
            registeredUpdates[type] = [callback]
        }
        
        callback()
    }
    
    private func update(_ type: UpdateType) {
        DispatchQueue.main.async {
            if let updates = self.registeredUpdates[type] {
                for update in updates {
                    update()
                }
            }
        }
    }
    
    private func documentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    // Music Player
    
    private var player = AVQueuePlayer(items: [])
    
    private func setupMPRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { event in
            if self.isPaused() {
                self.play()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { event in
            if !self.isPaused() {
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: event.positionTime)
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { event in
            if self.canGoNextTrack() {
                self.nextTrack()
                return .success
            }
            return .noSuchContent
        }
        
        commandCenter.previousTrackCommand.addTarget { event in
            if self.canGoPreviousTrack() {
                self.previousTrack()
                return .success
            }
            return .noSuchContent
        }
        
        commandCenter.likeCommand.addTarget { event in
            self.refreshMPInfoTiming()
            return .commandFailed
        }
        
        commandCenter.dislikeCommand.addTarget { event in
            return .commandFailed
        }
    }
    
    private func setupMPInfo(for song: Song) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artists.joined(separator: ", ")
        
        var image: UIImage?
        if let url = URL(string: song.image.url) {
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    guard let imageLoaded = UIImage(data: data) else { return }
                    image = imageLoaded
                    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] =
                    MPMediaItemArtwork(boundsSize: CGSize(width: song.image.width, height: song.image.height)) { size in
                        if let image = image {
                            return image
                        } else {
                            return UIImage(named: "musicCoverImagePlaceholder")!
                        }
                    }
                } else if let error = error {
                    print("HTTP Request Failed \(error)")
                }
            }
            task.resume()
        } else {
            image = UIImage(named: "musicCoverImagePlaceholder")
        }
        
        nowPlayingInfo[MPMediaItemPropertyArtwork] =
        MPMediaItemArtwork(boundsSize: CGSize(width: song.image.width, height: song.image.height)) { size in
            if let image = image {
                return image
            } else {
                return UIImage(named: "musicCoverImagePlaceholder")!
            }
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = getPlaybackTimeSeconds()
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = getDurationSeconds()
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player.rate
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    public func refreshMPInfoTiming() {
        print("getPlaybackTimeString()", getPlaybackTimeString())
        print("getDurationString()", getDurationString())
        print("self.player.status", self.player.status == .readyToPlay ? "READY TO PLAY" : self.player.status == .failed ? "FAILED" : "UNKNOWN")
        print("self.player.timeControlStatus", self.player.timeControlStatus == .playing ? "PLAYING" : self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate ? "WAITING FOR NETWORK" : "PAUSED")
        print("self.player.error", self.player.error)
        print("self.currentlyPlayingSong()", self.currentlyPlayingSong())
        print("self.currentlyPlayingSong()?.videoplayback", self.currentlyPlayingSong()?.videoplayback)
        print("self.currentlyPlayingSong()?.videoplayback.url", self.currentlyPlayingSong()?.videoplayback.url)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = getPlaybackTimeSeconds()
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = getDurationSeconds()
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = self.player.rate
    }
    
    public func isPaused() -> Bool {
        return self.player.rate == 0.0
    }
    
    public func play() {
        if isPaused() {
            self.player.play()
            self.refreshMPInfoTiming()
            self.update(.songState)
        }
    }
    
    public func pause() {
        if !isPaused() {
            self.player.pause()
            self.refreshMPInfoTiming()
            self.update(.songState)
        }
    }
    
    public func canGoNextTrack() -> Bool {
        return self.player.items().count > 1
    }
    
    public func nextTrack() {
        if canGoNextTrack() {
            self.player.advanceToNextItem()
            self.previousSongQueue.append(self.songQueue[0])
            self.songQueue.remove(at: 0)
            // canGoNextTrack returning true means it must be safe to access the currently playing song. If not, it should be a fatal error anyway
            self.setupMPInfo(for: currentlyPlayingSong()!)
            self.update(.songState)
            self.player.currentItem?.addObserver(self, forKeyPath: "duration", context: nil)
            
            // Check if the new song (now currently playing) can go to the next track. If not, start fetching new items for the queue
            if !canGoNextTrack() && !offline && playingFrom != "Downloads" {
                print("FETCHING NEW QUEUE ITEMS")
                self.watchlist(self.currentlyPlayingSong()!) { watchlist in
                    for song in watchlist.watchlist {
                        self.local_song(song) { song in
                            guard
                                let song = song,
                                let url = URL(string: song.videoplayback.url),
                                song.videoplayback.format != "unavailable"
                            else { return }
                            let item = AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/\(song.videoplayback.format)"]))
                            
                            guard self.player.canInsert(item, after: nil) else { return }
                            self.player.insert(item, after: nil)
                            
                            self.songQueue.append(song)
                            
                            self.update(.songState)
                        }
                    }
                }
            }
        }
    }
    
    public func canGoPreviousTrack() -> Bool {
        return self.getPlaybackTimeSeconds() < 2 ? self.previousSongQueue.count > 0 : true
    }
    
    public func previousTrack() {
        if self.getPlaybackTimeSeconds() >= 2 {
            self.seek(to: 0)
        } else if self.canGoPreviousTrack() {
            guard let song = self.previousSongQueue.last else { return }
            
            guard
                let url = URL(string: song.videoplayback.url),
                song.videoplayback.format != "unavailable"
            else { return }
            let item = AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/\(song.videoplayback.format)"]))
            
            guard let currentItem = self.player.currentItem else { return }
            self.player.insert(item, after: currentItem)
            self.player.remove(currentItem)
            self.player.insert(currentItem, after: item)
            self.previousSongQueue.remove(at: self.previousSongQueue.count - 1)
            self.songQueue.insert(song, at: 0)
            self.setupMPInfo(for: currentlyPlayingSong()!)
            self.update(.songState)
            self.player.currentItem?.addObserver(self, forKeyPath: "duration", context: nil)
        }
    }
    
    public func simulatePlaybackTimeRemainingSeconds(for time: TimeInterval) -> TimeInterval {
        return self.getDurationSeconds() - time
    }
    
    public func getPlaybackTimeSeconds() -> TimeInterval {
        return self.player.currentItem?.currentTime().seconds ?? 0
    }

    public func getDurationSeconds() -> TimeInterval {
        guard
            let duration = self.player.currentItem?.duration,
            !CMTIME_IS_INDEFINITE(duration)
        else { return 0 }
        return CMTimeGetSeconds(duration) / 2
    }
    
    public func getPlaybackTimeRemainingSeconds() -> TimeInterval {
        return self.getDurationSeconds() - self.getPlaybackTimeSeconds()
    }
    
    public func simulatePlaybackTimeString(for time: TimeInterval) -> String {
        return format(timeInterval: time)
    }
    
    public func simulatePlaybackTimeRemainingString(for time: TimeInterval) -> String {
        return format(timeInterval: simulatePlaybackTimeRemainingSeconds(for: time))
    }

    public func getPlaybackTimeString() -> String {
        return format(timeInterval: getPlaybackTimeSeconds())
    }

    public func getDurationString() -> String {
        return format(timeInterval: getDurationSeconds())
    }
    
    public func getPlaybackTimeRemainingString() -> String {
        return format(timeInterval: getPlaybackTimeRemainingSeconds())
    }
    
    public func currentlyPlayingSong() -> Song? {
        return self.songQueue.count > 0 ? self.songQueue[0] : nil
    }
    
    public func upNext() -> [SongCategory] {
        var playingFromItems = self.previousSongQueue.map { $0.toSongSmall() }
        var upNextItems = self.songQueue.map { $0.toSongSmall() }
        
        playingFromItems.append(upNextItems[0])
        upNextItems.remove(at: 0)
        
        return [SongCategory(title: "Playing from: \(self.playingFrom)", items: playingFromItems), SongCategory(title: "Up Next", items: upNextItems)]
    }
    
    public func upNextSong() -> Song? {
        return self.songQueue.count > 1 ? self.songQueue[1] : nil
    }
    
    public func stop() {
        if self.local_song_queue.count != 0 {
            if self.local_song_queue.count > 1 {
                self.local_song_queue.removeSubrange(1...self.local_song_queue.count - 1)
            }
            self.local_song_clear_queue_and_stop = true
        }
        
        self.player.pause()
        self.player.removeAllItems()
        self.songQueue = []
        self.previousSongQueue = []
        self.update(.songState)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }
    
    public func seek(to time: TimeInterval) {
        //let rate = self.player.rate
        //self.player.rate = 0
        //MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = self.player.rate
        //self.player.pause()
        let time = min(max(time, 0), getDurationSeconds())
        
        self.refreshMPInfoTiming()
        self.player.currentItem?.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(1000))) { success in
            if success {
                //self.player.play()
                self.refreshMPInfoTiming()
                //self.player.rate = rate
                //MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = self.player.rate
            }
        }
    }

    private func format(timeInterval: TimeInterval) -> String {
        let interval = Int(timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    @objc private func reachabilityChanged() {
        self.offline = self.offlineOverData ? self.reachability?.connection != .wifi : self.reachability?.connection != .unavailable
        print("OFFLINE", self.offline)
    }
    
    // Init
    
    private override init() {
        super.init()
        self.setupMPRemoteControls()
        PythonSupport.initialize()
        self.player.preventsDisplaySleepDuringVideoPlayback = false
        playbackTimeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main, using: { _ in
            self.update(.playbackTime)
        })
        self.loadDownloadedSongs()
        self.loadSettings()
        
        do {
            self.reachability = try Reachability()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reachabilityChanged),
                name: .reachabilityChanged,
                object: reachability
            )
            try self.reachability?.startNotifier()
        } catch {
            print("Reachability Error")
        }
        
        let pythonModuleDownloadDispatchGroup = DispatchGroup()
        
        pythonModuleDownloadDispatchGroup.enter()
        
        pythonModuleDownloadDispatchGroup.notify(queue: .main) {
            do {
                self.youtubeDL = try YoutubeDL()
            } catch {
                print("[YOUTUBEDL] Error during initialization")
            }
        }
        
        if YoutubeDL.shouldDownloadPythonModule {
            print("[YOUTUBEDL] Downloading Python Module")
            YoutubeDL.downloadPythonModule { error in
                if let error = error {
                    print("[YOUTUBEDL] Error while downloading Python Module", error)
                } else {
                    print("[YOUTUBEDL] Python Module Downloaded")
                    
                    pythonModuleDownloadDispatchGroup.leave()
                }
            }
        } else {
            pythonModuleDownloadDispatchGroup.leave()
        }
    }
    
    deinit {
        self.player.removeTimeObserver(playbackTimeObserver as Any)
    }
}

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}

extension UIColor {
    var isDarkColor: Bool {
        var r, g, b, a: CGFloat
        (r, g, b, a) = (0, 0, 0, 0)
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return lum < 0.50
    }
}
