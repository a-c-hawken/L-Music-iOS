//
//  SettingsTableViewController.swift
//  Music
//
//  Created by Lucas Alward on 6/10/22.
//

import UIKit

class SettingsTableViewController: UITableViewController {
    @IBOutlet weak var musicAPIHostTextField: UITextField!
    @IBOutlet weak var musicAPIAuthKeyTextField: UITextField!
    @IBOutlet weak var dataSaverSwitch: UISwitch!
    
    @IBAction func dataSaverSwitchToggled(_ sender: Any) {
        MusicAPI.shared.settings(MusicAPI.Settings(host: musicAPIHostTextField.text ?? "", authKey: musicAPIAuthKeyTextField.text ?? "", dataSaver: dataSaverSwitch.isOn))
    }
    
    @IBAction func musicAPISaveChangesButtonPressed(_ sender: Any) {
        MusicAPI.shared.settings(MusicAPI.Settings(host: musicAPIHostTextField.text ?? "", authKey: musicAPIAuthKeyTextField.text ?? "", dataSaver: dataSaverSwitch.isOn))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        musicAPIHostTextField.text = MusicAPI.shared.settings().host
        musicAPIAuthKeyTextField.text = MusicAPI.shared.settings().authKey
        dataSaverSwitch.isOn = MusicAPI.shared.settings().dataSaver
    }
}
