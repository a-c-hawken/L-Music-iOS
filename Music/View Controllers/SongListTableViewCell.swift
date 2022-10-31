//
//  SongListTableViewCell.swift
//  Music
//
//  Created by Lucas Alward on 5/10/22.
//

import UIKit

class SongListTableViewCell: UITableViewCell {
    @IBOutlet private weak var songImageView: UIImageView!
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var artistLabel: UILabel!
    
    @IBOutlet private weak var imageFadeView: UIView!
    @IBOutlet private weak var nowPlayingOverlayImageView: UIImageView!
    @IBOutlet private weak var loadingActivityIndicator: UIActivityIndicatorView!
    
    private enum State {
        case playing, loading, none
    }
    
    private var song: MusicAPI.SongSmall?
    
    func show(_ song: MusicAPI.SongSmall) {
        self.song = song
        
        self.titleLabel.text = song.title
        self.artistLabel.text = song.artists.joined(separator: ", ")
        self.songImageView.sd_setImage(with: URL(string: song.image.url), placeholderImage: UIImage(named: "musicCoverImagePlaceholder"))
        
        self.set(state: MusicAPI.shared.currentlyPlayingSong()?.songId == song.songId ? .playing : .none)
    }
    
    private func set(state: State) {
        switch state {
        case .playing:
            self.imageFadeView.isHidden = false
            self.nowPlayingOverlayImageView.isHidden = false
            self.loadingActivityIndicator.stopAnimating()
            self.loadingActivityIndicator.isHidden = true
        case .loading:
            self.imageFadeView.isHidden = false
            self.nowPlayingOverlayImageView.isHidden = true
            self.loadingActivityIndicator.startAnimating()
            self.loadingActivityIndicator.isHidden = false
        case .none:
            self.imageFadeView.isHidden = true
            self.nowPlayingOverlayImageView.isHidden = true
            self.loadingActivityIndicator.stopAnimating()
            self.loadingActivityIndicator.isHidden = true
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        self.set(state: selected ? .loading : MusicAPI.shared.currentlyPlayingSong()?.songId == self.song?.songId ? .playing : .none)
    }
}
