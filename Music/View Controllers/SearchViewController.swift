//
//  SearchViewController.swift
//  Music
//
//  Created by Lucas Alward on 3/10/22.
//

import UIKit

class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    let searchController = UISearchController(searchResultsController: nil)
    var songCategories: [MusicAPI.SongCategory] = []
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Song Library..."
        navigationItem.searchController = searchController
        definesPresentationContext = true
        
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
        searchController.dismiss(animated: true)
        MusicAPI.shared.songSelected(songCategories[indexPath.section].items[indexPath.row], from: .search) {
            DispatchQueue.main.async {
                tableView.deselectRow(at: indexPath, animated: true)
                tableView.reloadSections(IndexSet(integersIn: 0...self.songCategories.count - 1), with: .automatic)
            }
        }
    }
}

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard
            let query = searchController.searchBar.text,
            query.trimmingCharacters(in: .whitespacesAndNewlines) != ""
        else { return }
        MusicAPI.shared.search(for: query) { songCategories in
            self.songCategories = songCategories
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            
        }
    }
}
