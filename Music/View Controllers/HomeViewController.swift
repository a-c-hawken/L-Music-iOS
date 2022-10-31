//
//  HomeViewController.swift
//  Music
//
//  Created by Lucas Alward on 2/10/22.
//

import UIKit
import SDWebImage

class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var nowPlayingImageView: UIImageView!
    @IBOutlet weak var nowPlayingTitleLabel: UILabel!
    @IBOutlet weak var nowPlayingArtistLabel: UILabel!
    @IBOutlet weak var nowPlayingPauseButton: UIButton!
    @IBOutlet weak var nowPlayingPlayButton: UIButton!
    @IBOutlet weak var nowPlayingNextTrackButton: UIButton!
    
    @IBAction func nowPlayingPauseButtonPressed(_ sender: Any) {
        if !MusicAPI.shared.isPaused() {
            MusicAPI.shared.pause()
        }
    }
    
    @IBAction func nowPlayingPlayButtonPressed(_ sender: Any) {
        if MusicAPI.shared.isPaused() {
            MusicAPI.shared.play()
        }
    }
    
    @IBAction func nowPlayingNextTrackButtonPressed(_ sender: Any) {
        if MusicAPI.shared.canGoNextTrack() {
            MusicAPI.shared.nextTrack()
        }
    }
    
    var songCategories: [MusicAPI.SongCategory] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        MusicAPI.shared.register(for: .songState) {
            guard let song = MusicAPI.shared.currentlyPlayingSong() else {
                self.nowPlayingTitleLabel.text = "Not Playing"
                self.nowPlayingArtistLabel.text = ""
                self.nowPlayingImageView.image = UIImage(named: "musicCoverImagePlaceholder")
                
                self.nowPlayingPauseButton.isHidden = true
                self.nowPlayingNextTrackButton.isHidden = true
                self.nowPlayingPlayButton.isHidden = false
                self.nowPlayingPlayButton.isEnabled = false
                return
            }
            
            self.nowPlayingTitleLabel.text = song.title
            self.nowPlayingArtistLabel.text = song.artists.joined(separator: ", ")
            self.nowPlayingImageView.sd_setImage(with: URL(string: song.image.url), placeholderImage: UIImage(named: "musicCoverImagePlaceholder"))
            
            self.nowPlayingNextTrackButton.isHidden = false
            
            self.nowPlayingPauseButton.isEnabled = true
            self.nowPlayingPlayButton.isEnabled = true
            self.nowPlayingPauseButton.isHidden = MusicAPI.shared.isPaused()
            self.nowPlayingPlayButton.isHidden = !MusicAPI.shared.isPaused()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        MusicAPI.shared.browse { songCategories in
            self.songCategories = songCategories
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return songCategories.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songCategories[section].items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return songCategories[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "musicCell", for: indexPath) as! SongListTableViewCell
        cell.show(songCategories[indexPath.section].items[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        MusicAPI.shared.songSelected(songCategories[indexPath.section].items[indexPath.row], from: .browse) {
            DispatchQueue.main.async {
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.reloadSections(IndexSet(integersIn: 0...self.songCategories.count - 1), with: .automatic)
            }
        }
    }
}
