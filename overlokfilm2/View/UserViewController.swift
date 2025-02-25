//
//  UserViewController.swift
//  overlokfilm2
//
//  Created by hyasar on 7.11.2022.
//

import Foundation
import UIKit
import Firebase
import FirebaseStorage
import SDWebImage

final class UserViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - variables
    
    @IBOutlet weak var userFilmsTableView: UITableView!
    
    private var userViewModel : UserVcViewModel!
    private var justUserViewModel : JustUserViewModel!
    var webService = WebService()
    var userVSM = UserViewSingletonModel.sharedInstance
    
    var username = ""
    
    @IBOutlet private weak var profileImage: UIImageView!
    @IBOutlet private weak var postsLabel: UILabel!
    @IBOutlet private weak var followersLabel: UILabel!
    @IBOutlet private weak var followingLabel: UILabel!
    @IBOutlet private weak var followButton: UIButton!
    @IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var bioLabel: UILabel!
    
    
    // MARK: - viewDidLoad and viewWillAppear
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userFilmsTableView.delegate = self
        userFilmsTableView.dataSource = self
        
        getCurrentUsername { curName in
            
            if self.username == curName {
                
                // in here, we activate clickable feature on image
                self.profileImage.isUserInteractionEnabled = true
            }
            
        }
        
        // and here, we describe gesture recognizer for upload with click on image
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(chooseProfileImage))
        profileImage.addGestureRecognizer(gestureRecognizer)
        
        //data refresh
        userFilmsTableView.refreshControl = UIRefreshControl()
        userFilmsTableView.refreshControl?.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        setAllPageDatas()
        setAppearance()
        
        getCurrentUsername { curName in
            
            if curName == self.usernameLabel.text {
                
                // in here, we activate clickable feature on image
                self.profileImage.isUserInteractionEnabled = true
            }
        }
        
    }
    
    
    // MARK: - tableView functions
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.userViewModel == nil ? 0 : self.userViewModel.numberOfRowsInSection()
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = userFilmsTableView.dequeueReusableCell(withIdentifier: "cellOfUserView", for: indexPath) as! UserFeedCell
        
        let postViewModel = self.userViewModel.postAtIndex(index: indexPath.row)
        
        cell.filmLabel.text = "\(indexPath.row + 1) - " + "\(postViewModel.postMovieName)" + " (\(postViewModel.postMovieYear))"
        
        return cell
        
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let postViewModel = self.userViewModel.postAtIndex(index: indexPath.row)
        
        userVSM = UserViewSingletonModel.sharedInstance
        
        userVSM.postId = postViewModel.postId
        
        performSegue(withIdentifier: "toPostDetailVC", sender: indexPath)
        
        // this command prevent gray colour when come back after selection
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    // MARK: - functions
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "toPostDetailVC" {
            
            let destinationVC = segue.destination as! PostDetailViewController
            
            destinationVC.postId = userVSM.postId
            
        }
        
        if segue.identifier == "toLikesVC" {
            
            let destinationVC = segue.destination as! LikesViewController
            
            destinationVC.username = self.usernameLabel.text!
        }
        
        if segue.identifier == "toWatchlistsVC" {
            
            let destinationVC = segue.destination as! WatchlistsViewController
            
            destinationVC.username = self.usernameLabel.text!
        }
        
        if segue.identifier == "toBlocklistVC" {
            
            let destinationVC = segue.destination as! BlocklistViewController
            
            destinationVC.username = self.usernameLabel.text!
        }
        
    }
    
    
    func getData(uName : String){
        
        webService.downloadDataUserVC (uName: uName) { postList in
            
            self.userViewModel = UserVcViewModel(postList: postList)
            
            DispatchQueue.main.async {
                
                self.userFilmsTableView.reloadData()
            }
        }
        
    }
    
    
    func getUserFields(uName: String){
        
        webService.downloadDataForUserFields(username: uName) { user in
            
            self.justUserViewModel = JustUserViewModel(user: user)
            
            self.setProfileImage(userJVM: self.justUserViewModel)
            self.setBio(userJVM: self.justUserViewModel)
            self.setCounts(userJVM: self.justUserViewModel)
            
        }
        
    }
    
    @objc func chooseProfileImage(){
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "change", style: .default, handler: { action in
            
            // we describe picker controller stuff for reach to user gallery
            let pickerController = UIImagePickerController()
            // we assign self to picker controller delegate so we can call some methods that we will use
            pickerController.delegate = self
            pickerController.sourceType = .photoLibrary
            self.present(pickerController, animated: true, completion: nil)
            
        }))
        
        
        alert.addAction(UIAlertAction(title: "delete", style: .destructive, handler: { action in
            
            // storage
            
            let storage = Storage.storage()
            let storageReference = storage.reference()
            let imageData = storageReference.child("userDefaultProfileImage/userDefaultImage.png")
            
            imageData.downloadURL { url, error in
                
                if error == nil {
                    
                    let imageUrl = url?.absoluteString
                    
                    self.profileImage.sd_setImage(with: URL(string: "\(imageUrl!)"))
                    
                    
                    // delete from database (actually we changing with default image)
                    
                    let cuid = Auth.auth().currentUser?.uid as? String
                    
                    let firestoreDatabase = Firestore.firestore()
                    
                    firestoreDatabase.collection("users").document(cuid!).setData(["profileImageUrl" : imageUrl!], merge: true)
                    
                    // to update old post's profile images
                    
                    self.getCurrentUsername { curUsername in
                        
                        firestoreDatabase.collection("posts").whereField("postedBy", isEqualTo: "\(curUsername)").getDocuments(source: .server) { snapshot, error in
                            
                            if error != nil {
                                
                                print(error?.localizedDescription ?? "error")
                                self.makeAlert(titleInput: "error", messageInput: "\n\(String(describing: error?.localizedDescription))")
                            }else {
                                
                                for document in snapshot!.documents {
                                    
                                    document.reference.updateData(["userIconUrl" : "\(imageUrl!)"])
                                }
                                
                            }
                            
                        }
                        self.makeAlert(titleInput: "", messageInput: "\nyour profile image has been deleted.")
                    }
                    
                }
                
            }
            
            
        }))
        
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel, handler: { action in }))
        
        DispatchQueue.main.async {
            
            self.present(alert, animated: true, completion: nil)
        }
        
    }
    
    // here is about what is gonna happen after choose image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        profileImage.image = info[.originalImage] as? UIImage
        self.dismiss(animated: true, completion: nil)
        
        // update profile image on storage and database
        updateProfileImageOnDB()
        
    }
    
    
    
    
    @IBAction func followButtonClicked(_ sender: Any) {
        
        // if we have not followed yet, we can follow her/him in here
        
        if self.followButton.titleLabel?.text == "follow" {
            
            guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
            
            getClickedUserId { clickedUserId in
                
                let firestoreDatabase = Firestore.firestore()
                
                let ref = firestoreDatabase.collection("following").document(cuid)
                
                let values = [clickedUserId: 1]
                
                DispatchQueue.global().async {
                    
                    ref.setData(values, merge: true) { error in
                        
                        if error != nil {
                            
                            print(error?.localizedDescription ?? "error")
                            self.makeAlert(titleInput: "error", messageInput: "\nan error occured. \nlease try again later.")
                            
                        }else {
                            
                            DispatchQueue.main.async {
                                
                                self.increaseFollowersCountClickedUser()
                                self.increaseFollowingCountCurUser()
                                
                                self.followButton.setTitle("unfollow", for: .normal)
                                self.followButton.backgroundColor = .systemBackground
                                
                                self.setFollowCounts(user: self.justUserViewModel)
                                self.makeAlert(titleInput: "", messageInput: "\nyou followed \(self.username)")
                            }
                            
                        }
                        
                    }
                }
                
            }
            
        }else {
            
            // if we already have followed clickedUser, we can unfollow her/him here
            
            if self.followButton.titleLabel?.text == "unfollow" &&  self.followButton.titleLabel?.text != "edit profile" {
                
                guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
                
                self.getClickedUserId { clickedUserId in
                    
                    let firestoreDatabase = Firestore.firestore()
                    
                    DispatchQueue.global().async {
                        
                        firestoreDatabase.collection("following").document("\(cuid)").updateData(["\(clickedUserId)" : FieldValue.delete()]) { error in
                            
                            if let error = error {
                                
                                print("error: \(error.localizedDescription)")
                                self.makeAlert(titleInput: "error", messageInput: "\nan error occured. \nlease try again later.")
                                
                            }else {
                                
                                DispatchQueue.main.async {
                                    
                                    self.decreaseFollowersCountClickedUser()
                                    self.decreaseFollowingCountCurUser()
                                    
                                    self.followButton.setTitle("follow", for: .normal)
                                    self.followButton.backgroundColor = .systemGray5
                                    
                                    self.setFollowCounts(user: self.justUserViewModel)
                                    self.makeAlert(titleInput: "", messageInput: "\nyou unfollowed \(self.username)")
                                }
                                
                            }
                        }
                    }
                    
                }
                
            }else if self.followButton.titleLabel?.text == "edit profile" {
                
                performSegue(withIdentifier: "toEditBioVC", sender: nil)
                
            }
            
        }
        
    }
    
    
    func increaseFollowingCountCurUser() {
        
        
        guard let cuid = Auth.auth().currentUser?.uid as? String else {return}
        
        let firestoreDb = Firestore.firestore()
        
        firestoreDb.collection("users").document(cuid).getDocument(source: .server) { document, error in
            
            if error != nil{
                
                print("error: \(String(describing: error?.localizedDescription))")
            }else {
                
                if let document = document, document.exists {
                    
                    DispatchQueue.global().async {
                        
                        if let followingCount = document.get("followingCount") as? Int {
                            
                            // we are setting new postCount
                            let followingCountDic = ["followingCount" : followingCount + 1] as [String : Any]
                            
                            firestoreDb.collection("users").document(cuid).setData(followingCountDic, merge: true)
                            
                        } else {
                            print("\ndocument field was not gotten")
                        }
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func increaseFollowersCountClickedUser(){
        
        
        getClickedUserId { clickedUserId in
            
            let firestoreDb = Firestore.firestore()
            
            firestoreDb.collection("users").document(clickedUserId).getDocument(source: .server) { document, error in
                
                if error != nil{
                    
                    print("error: \(String(describing: error?.localizedDescription))")
                }else {
                    
                    if let document = document, document.exists {
                        
                        DispatchQueue.global().async {
                            
                            if let followersCount = document.get("followersCount") as? Int {
                                
                                // we are setting new postCount
                                let followersCountDic = ["followersCount" : followersCount + 1] as [String : Any]
                                
                                firestoreDb.collection("users").document(clickedUserId).setData(followersCountDic, merge: true)
                                
                            } else {
                                print("\ndocument field was not gotten")
                            }
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func decreaseFollowingCountCurUser(){
        
        
        guard let cuid = Auth.auth().currentUser?.uid as? String else {return}
        
        let firestoreDb = Firestore.firestore()
        
        firestoreDb.collection("users").document(cuid).getDocument(source: .server) { document, error in
            
            if error != nil{
                
                print("error: \(String(describing: error?.localizedDescription))")
            }else {
                
                if let document = document, document.exists {
                    
                    DispatchQueue.global().async {
                        
                        if let followingCount = document.get("followingCount") as? Int {
                            
                            // we are setting new postCount
                            let followingCountDic = ["followingCount" : followingCount - 1] as [String : Any]
                            
                            firestoreDb.collection("users").document(cuid).setData(followingCountDic, merge: true)
                            
                        } else {
                            print("\ndocument field was not gotten")
                        }
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func decreaseFollowersCountClickedUser(){
        
        
        getClickedUserId { clickedUserId in
            
            let firestoreDb = Firestore.firestore()
            
            firestoreDb.collection("users").document(clickedUserId).getDocument(source: .server) { document, error in
                
                if error != nil{
                    
                    print("error: \(String(describing: error?.localizedDescription))")
                }else {
                    
                    if let document = document, document.exists {
                        
                        DispatchQueue.global().async {
                            
                            if let followersCount = document.get("followersCount") as? Int {
                                
                                // we are setting new postCount
                                let followersCountDic = ["followersCount" : followersCount - 1] as [String : Any]
                                
                                firestoreDb.collection("users").document(clickedUserId).setData(followersCountDic, merge: true)
                                
                            } else {
                                print("\ndocument field was not gotten")
                            }
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    
    
    func setAllPageDatas(){
        
        
        if self.username == "" {
            
            getCurrentUsername { curUsername in
                
                self.usernameLabel.text = curUsername
                self.followButton.setTitle("edit profile", for: .normal)
                
                self.getData(uName: self.usernameLabel.text!)
                self.getUserFields(uName: self.usernameLabel.text!)
                
            }
            
        }else {
            
            getCurrentUsername { curName in
                
                if curName == self.username {
                    
                    
                    self.usernameLabel.text = self.username
                    self.followButton.setTitle("edit profile", for: .normal)
                    
                    self.getData(uName: self.usernameLabel.text!)
                    self.getUserFields(uName: self.usernameLabel.text!)
                    
                } else {
                    
                    
                    self.usernameLabel.text = self.username
                    self.followButton.setTitle("follow", for: .normal)
                    
                    self.getData(uName: self.usernameLabel.text!)
                    self.getUserFields(uName: self.usernameLabel.text!)
                    
                    
                    // we are looking for whether current user follows the clickedUser if yes our button should show "unfollow" if no it should show "follow"
                    
                    guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
                    
                    self.getClickedUserId { clickedUserId in
                        
                        let firestoreDatabase = Firestore.firestore()
                        
                        
                        firestoreDatabase.collection("following").document(cuid).getDocument(source: .server) { document, error in
                            
                            if error != nil {
                                
                                print(error?.localizedDescription ?? "error")
                                self.makeAlert(titleInput: "error", messageInput: "\n\(String(describing: error?.localizedDescription))")
                                
                            }else {
                                
                                if let document = document, document.exists {
                                    
                                    if let data = document.get("\(clickedUserId)") as? Int {
                                        
                                        DispatchQueue.main.async {
                                            
                                            self.usernameLabel.text = self.username
                                            self.followButton.setTitle("unfollow", for: .normal)
                                            
                                            self.followButton.backgroundColor = .systemBackground
                                            self.followButton.layer.cornerRadius = 15
                                            self.followButton.layer.borderColor = UIColor.gray.cgColor
                                            self.followButton.layer.borderWidth = 1
                                            
                                            self.getData(uName: self.usernameLabel.text!)
                                            self.getUserFields(uName: self.usernameLabel.text!)
                                            
                                        }
                                        
                                    }else{
                                        print("\nthere is no field like this in following.")
                                    }
                                    
                                }else {
                                    print("\ndocument doesn't exist in following.")
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    
    func setBio(userJVM: JustUserViewModel) {
        
        DispatchQueue.main.async {
            
            self.bioLabel.text = userJVM.user.bio
        }
        
        
    }
    
    func setCounts(userJVM: JustUserViewModel) {
        
        DispatchQueue.main.async {
            
            self.postsLabel.text = "\(userJVM.user.postCount)"
            self.followersLabel.text = "\(userJVM.user.followersCount)"
            self.followingLabel.text = "\(userJVM.user.followingCount)"
        }
        
    }
    
    
    func setFollowCounts(user: JustUserViewModel){
        
        DispatchQueue.main.async {
            
            self.followersLabel.text = "\(user.user.followersCount)"
            self.followingLabel.text = "\(user.user.followingCount)"
        }
        
    }
    
    func setProfileImage(userJVM: JustUserViewModel) {
        
        DispatchQueue.main.async {
            
            self.profileImage.sd_setImage(with: URL(string: userJVM.user.profileImageUrl))
        }
        
    }
    
    func updateProfileImageOnDB() {
        
        var firestoreListener : ListenerRegistration?
        firestoreListener?.remove()
        
        // storage
        
        let storage = Storage.storage()
        let storageReference = storage.reference()
        
        let userPPMediaFolder = storageReference.child("userProfileImages")
        
        
        if let data = profileImage.image?.jpegData(compressionQuality: 0.5) {
            
            // now we can save this data to storage
            
            let uuid = UUID().uuidString
            
            let imageReference = userPPMediaFolder.child("\(uuid).jpg")
            
            imageReference.putData(data, metadata: nil) { metadata, error in
                
                if error != nil{
                    self.makeAlert(titleInput: "error", messageInput: "\nan error occured. \nlease try again later.")
                }else {
                    
                    imageReference.downloadURL { url, error in
                        
                        if error == nil {
                            
                            let imageUrl = url?.absoluteString
                            
                            // database
                            
                            let cuid = Auth.auth().currentUser?.uid as? String
                            
                            let firestoreDatabase = Firestore.firestore()
                            
                            firestoreDatabase.collection("users").document(cuid!).setData(["profileImageUrl" : imageUrl!], merge: true)
                            
                            // to update old post's profile images
                            
                            self.getCurrentUsername { curUsername in
                                
                                firestoreDatabase.collection("posts").whereField("postedBy", isEqualTo: "\(curUsername)").getDocuments(source: .server) { snapshot, error in
                                    
                                    if error != nil {
                                        
                                        print(error?.localizedDescription ?? "error")
                                        self.makeAlert(titleInput: "error", messageInput: "\n\(String(describing: error?.localizedDescription))")
                                    }else {
                                        
                                        for document in snapshot!.documents {
                                            
                                            document.reference.updateData(["userIconUrl" : "\(imageUrl!)"])
                                        }
                                        
                                    }
                                    
                                }
                                self.makeAlert(titleInput: "", messageInput: "\nyour profile image has been changed.")
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    @objc private func didPullToRefresh(){
        
        getData(uName: self.username)
        
        DispatchQueue.main.asyncAfter(deadline: .now()+2) {
            
            self.userFilmsTableView.refreshControl?.endRefreshing()
        }
    }
    
    
    
    func setAppearance() {
        
        followButton.layer.masksToBounds = true
        followButton.backgroundColor = .systemGray5
        followButton.layer.cornerRadius = 15
        followButton.layer.borderColor = UIColor.gray.cgColor
        followButton.layer.borderWidth = 1
        
        profileImage.contentMode = .scaleAspectFill
        profileImage.clipsToBounds = true  // what does this do?
        
        profileImage.layer.cornerRadius = profileImage.frame.size.height/2
        profileImage.layer.masksToBounds = true
        profileImage.layer.borderColor = UIColor.gray.cgColor
        profileImage.layer.borderWidth = 1
        
    }
    
    func getClickedUserId(completion: @escaping (String) -> Void) {
        
        let firestoreDb = Firestore.firestore()
        
        firestoreDb.collection("users").whereField("username", isEqualTo: "\(self.username)").getDocuments(source: .server) { snapshot, error in
            
            if error != nil {
                
                print(error?.localizedDescription ?? "error")
            }else {
                
                DispatchQueue.global().async {
                    
                    for document in snapshot!.documents {
                        
                        let clickedUserId = document.documentID
                        completion(clickedUserId)
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    
    func getCurrentUsername(complation: @escaping (String) -> Void) {
        
        
        guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
        
        let firestoreDb = Firestore.firestore()
        
        firestoreDb.collection("users").document(cuid).getDocument(source: .server) { document, error in
            
            if error != nil{
                
                self.usernameLabel.text = "overlokcu"
                self.makeAlert(titleInput: "error", messageInput: "\npage couldn't load. \nplease try again later.")
                
            }else {
                
                if let document = document, document.exists {
                    
                    if let dataDescription = document.get("username") as? String{
                        
                        complation(dataDescription)
                        
                    } else {
                        print("\ndocument field was not gotten")
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func getUsername(uid : String, completion: @escaping (String) -> Void) {
        
        let firestoreDb = Firestore.firestore()
        
        firestoreDb.collection("users").document(uid).getDocument(source: .server) { document, error in
            
            if error != nil{
                
                print("error: \(String(describing: error?.localizedDescription))")
                
            }else {
                
                if let document = document, document.exists {
                    
                    //DispatchQueue.global().async {
                    
                    if let usernameData = document.get("username") as? String{
                        
                        completion(usernameData)
                        
                    } else {
                        print("\n document field was not gotten")
                    }
                    
                    //}
                    
                }
                
            }
            
        }
    }
    
    
    
    func decreaseFollowers(completion: @escaping (Bool) -> Void){
                
        guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
        
        let firestoreDatabase = Firestore.firestore()
        
        firestoreDatabase.collection("following").document(cuid).getDocument(source: .server) { document, error in
                
                if let document = document, document.exists{
                    
                    guard let userIdsDictionary = document.data() as? [String : Int] else {return}
                    
                    userIdsDictionary.forEach { (key, value) in
                        
                        // we are decreasing followers count
                        firestoreDatabase.collection("users").document(key).getDocument(source: .server) { document, error in
                            
                            if error != nil{
                                
                                print("error: \(String(describing: error?.localizedDescription))")
                            }else {
                                
                                if let document = document, document.exists {
                                    
                                    if let followersCount = document.get("followersCount") as? Int {
                                        
                                        // we are decreasing followers count
                                        let followersCountDic = ["followersCount" : followersCount - 1] as [String : Any]
                                        
                                        firestoreDatabase.collection("users").document(key).setData(followersCountDic, merge: true)
                                        
                                    } else {
                                        print("\ndocument field was not gotten")
                                    }
                                    
                                    
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    completion(true)
                }
            
        }
        
    }
    
    
    func deleteAllFieldsBelongDeletingUserFromFollowing(completion: @escaping (Bool) -> Void){
                
        // we are deleting fields in related that user who delete account from following collection
        
        guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
        
        let firestoreDatabase = Firestore.firestore()
        
        firestoreDatabase.collection("following").whereField("\(cuid)", isEqualTo: 1).getDocuments(source: .server) { querySnapshot, error in
            
            if let error = error {
                print("\n error getting documents: \(error)")
            } else {
                                    
                    for document in querySnapshot!.documents{
                                                
                        let docId = document.reference.documentID // docId is the userId at the same time
                        
                        firestoreDatabase.collection("users").document(docId).getDocument(source: .server) { document, error in
                            
                            if error != nil{
                                
                                print("error: \(String(describing: error?.localizedDescription))")
                            }else {
                                
                                if let document = document, document.exists {
                                    
                                        
                                        if let followingCount = document.get("followingCount") as? Int {
                                                                                        
                                            // we are decreasing followings count
                                            let followingCountDic = ["followingCount" : followingCount - 1] as [String : Any]
                                            
                                            firestoreDatabase.collection("users").document(docId).setData(followingCountDic, merge: true)
                                            
                                        } else {
                                            print("\ndocument field was not gotten")
                                        }
                                    
                                }
                                
                            }
                            
                        }
                        
                        document.reference.updateData(["\(cuid)" : FieldValue.delete()])
                    }
                
                completion(true)
            }
        }
        
    }
    
    func deleteMediaAndPosts(completion: @escaping (Bool) -> Void){
                
        guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
        
        let firestoreDatabase = Firestore.firestore()
        
        self.getUsername(uid: cuid) { uName in
                        
            firestoreDatabase.collection("posts").whereField("postedBy", isEqualTo: "\(uName)").getDocuments(source: .server) { querySnapshot, error in
                                
                if let error = error {
                    
                    print("Error getting documents: \(error)")
                } else {
                                            
                        for document in querySnapshot!.documents{
                                                        
                            if let postId = document.get("postId") as? String {
                                                                
                                let storage = Storage.storage()
                                let storageReference = storage.reference()
                                
                                let imageWillBeDelete = storageReference.child("media").child("\(postId).jpg")
                                
                                imageWillBeDelete.delete { error in
                                                                        
                                    if let error = error {
                                        print("error: \(error.localizedDescription)")
                                        
                                    }else{
                                        document.reference.delete()
                                    }
                                    
                                }
                                
                            }
                            
                        }
                        
                    completion(true)
                }
            }
            
        }
        
    }
    
    func removeDocumentFromFollowing(completion: @escaping (Bool) -> Void){
                
        guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
        
        let firestoreDatabase = Firestore.firestore()
        
        firestoreDatabase.collection("following").document(cuid).getDocument(source: .server) { document, error in
            
            if let document = document, document.exists{
                
                document.reference.delete()
                completion(true)
                
            }else{
                print("document doesn^t exist")
            }
        }
    }
    
    func removeDocumentFromUsers(completion: @escaping (Bool) -> Void){
                
        guard let cuid = Auth.auth().currentUser?.uid as? String else { return }
        
        let firestoreDatabase = Firestore.firestore()
        
        firestoreDatabase.collection("users").document(cuid).getDocument(source: .server) { document, error in
            
            if let document = document, document.exists{
                
                document.reference.delete()
                completion(true)
            }else{
                print("document doesn^t exist")
            }
            
        }
        
    }
    
    func deleteAccount(){
                
        let user = Auth.auth().currentUser
        
        user?.delete { error in
            if let error = error {
            } else {
                do{
                    self.performSegue(withIdentifier: "toViewController", sender: nil)
                }catch{
                    print("error")
                }
            }
        }
        
    }
    
    
    @IBAction func userMenuClicked(_ sender: Any) {
        
        if self.username == "" {
            
            self.showNormalUserMenu()
            
        }else {
            
            getCurrentUsername { curName in
                
                if self.username == curName {
                    
                    self.showNormalUserMenu()
                }else{
                    
                    self.showClickedUserMenu()
                    
                }
                
            }
            
        }
        
    }
    
    // MARK: menus
    
    func showNormalUserMenu() {
        
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let likesButton = UIAlertAction(title: "likes", style: .default){ action  in
            
            self.performSegue(withIdentifier: "toLikesVC", sender: nil)
        }
        let watchlistButton = UIAlertAction(title: "watchlist", style: .default){ action in
            
            self.performSegue(withIdentifier: "toWatchlistsVC", sender: nil)
        }
        let servicesButton = UIAlertAction(title: "services", style: .default) { action in
            
            let alertSer = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            let contactUsButton = UIAlertAction(title: "contact us", style: .default)
            let privacyButton = UIAlertAction(title: "privacy", style: .default)
            let aboutUsButton = UIAlertAction(title: "about us", style: .default)
            let deleteAccountButton = UIAlertAction(title: "delete account", style: .destructive){ action in
                
                print("\n xx delete account clicked")
                
                self.decreaseFollowers { result in
                    self.deleteAllFieldsBelongDeletingUserFromFollowing { result in
                        self.removeDocumentFromFollowing { result in
                            self.deleteMediaAndPosts { result in
                                self.removeDocumentFromUsers { result in
                                    self.deleteAccount()
                                }
                            }
                        }
                    }
                }
                
            }
            
            let cancelButton = UIAlertAction(title: "cancel", style: .cancel)
            
            alertSer.addAction(contactUsButton)
            alertSer.addAction(privacyButton)
            alertSer.addAction(aboutUsButton)
            alertSer.addAction(deleteAccountButton)
            alertSer.addAction(cancelButton)
            
            DispatchQueue.main.async {
                self.present(alertSer, animated: true, completion: nil)
            }
        }
        
        let blocklistButton = UIAlertAction(title: "blocklist", style: .default){ action in
            
            self.performSegue(withIdentifier: "toBlocklistVC", sender: nil)
        }
        
        let logoutButton = UIAlertAction(title: "logout", style: .destructive) { action in
            
            let alerto = UIAlertController(title: "", message: "log out of your account?", preferredStyle: .alert)
            
            let logoutButton = UIAlertAction(title: "yes, logout", style: .destructive) { action in
                
                do{
                    try Auth.auth().signOut()
                    self.performSegue(withIdentifier: "toViewController", sender: nil)
                }catch{
                    print("error")
                }
                
                
            }
            let cancelButton = UIAlertAction(title: "cancel", style: .cancel)
            
            alerto.addAction(logoutButton)
            alerto.addAction(cancelButton)
            
            DispatchQueue.main.async {
                self.present(alerto, animated: true, completion: nil)
            }
            
        }
        let cancelButton = UIAlertAction(title: "cancel", style: .cancel)
        
        alert.addAction(likesButton)
        alert.addAction(watchlistButton)
        alert.addAction(servicesButton)
        alert.addAction(blocklistButton)
        alert.addAction(logoutButton)
        alert.addAction(cancelButton)
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
        
        
    }
    
    func showClickedUserMenu() {
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let likesButton = UIAlertAction(title: "likes", style: .default){ action in
            
            self.performSegue(withIdentifier: "toLikesVC", sender: nil)
        }
        let watchlistButton =  UIAlertAction(title: "watchlist", style: .default){ action in
            
            self.performSegue(withIdentifier: "toWatchlistsVC", sender: nil)
        }
        let cancelButton = UIAlertAction(title: "cancel", style: .cancel)
        
        alert.addAction(likesButton)
        alert.addAction(watchlistButton)
        alert.addAction(cancelButton)
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
        
    }
    
    // MARK: makeAlert
    
    func makeAlert(titleInput: String, messageInput: String){
        
        let alert = UIAlertController(title: titleInput, message: messageInput, preferredStyle: UIAlertController.Style.alert)
        let okButton = UIAlertAction(title: "ok", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(okButton)
        self.present(alert, animated: true, completion: nil)
    }
    
    
}





