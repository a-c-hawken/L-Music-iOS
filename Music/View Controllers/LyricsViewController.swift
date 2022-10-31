//
//  LyricsViewController.swift
//  Music
//
//  Created by Lucas Alward on 4/10/22.
//

import UIKit

class LyricsViewController: UIViewController {

    @IBAction func backBarButtonItemPressed(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var loadingPopupView: UIView!
    
    var currentSongWhenLoaded: MusicAPIBaseSong?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if currentSongWhenLoaded?.songId != MusicAPI.shared.currentlyPlayingSong()?.songId {
            self.textView.text = ""
            loadingPopupView.isHidden = false
            currentSongWhenLoaded = MusicAPI.shared.currentlyPlayingSong()
            
            MusicAPI.shared.lyrics { lyrics in
                DispatchQueue.main.async {
                    self.loadingPopupView.isHidden = true
                    self.textView.text = "\(lyrics.lyrics)\n\n\(lyrics.source)"
                }
            }
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
