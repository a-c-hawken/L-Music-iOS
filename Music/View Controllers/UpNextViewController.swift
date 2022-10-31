//
//  UpNextViewController.swift
//  Music
//
//  Created by Lucas Alward on 4/10/22.
//

import UIKit

class UpNextViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func backBarButtonItemPressed(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    var songCategories: [MusicAPI.SongCategory] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.songCategories = MusicAPI.shared.upNext()
        self.tableView.reloadData()
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
        MusicAPI.shared.songSelected(songCategories[indexPath.section].items[indexPath.row], from: .upnext) {
            DispatchQueue.main.async {
                tableView.deselectRow(at: indexPath, animated: true)
                self.songCategories = MusicAPI.shared.upNext()
                tableView.reloadSections(IndexSet(integersIn: 0...self.songCategories.count - 1), with: .automatic)
            }
        }
    }
}
