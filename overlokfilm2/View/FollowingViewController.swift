//
//  FollowingViewController.swift
//  overlokfilm2
//
//  Created by hyasar on 7.11.2022.
//

import Foundation
import UIKit
import Firebase

class FollowingViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, FollowingFeedCellDelegate {

    
    @IBOutlet weak var followingTableView: UITableView!
    
    private var followingViewModel : FollowingViewModel!
    var webService = WebService()
    var followingVSM = FollowingViewSingletonModel.sharedInstance
    
    override func viewDidLoad() {
        
        super.viewDidLoad()

        followingTableView.delegate = self
        followingTableView.dataSource = self
        
        //getData()
        
        //page refresh
        followingTableView.refreshControl = UIRefreshControl()
        followingTableView.refreshControl?.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        getData()
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        
        return self.followingViewModel == nil ? 0 : self.followingViewModel.numberOfRowsInSection()
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = followingTableView.dequeueReusableCell(withIdentifier: "cellOfFollowing", for: indexPath) as! FollowingFeedCell
        
        let postViewModel = self.followingViewModel.postAtIndex(index: indexPath.row)
        
        cell.movieNameLabel.text = "\(postViewModel.postMovieName)" + " (\(postViewModel.postMovieYear))"
        cell.directorNameLabel.text = postViewModel.postMovieDirector
        cell.commentLabel.text = postViewModel.postMovieComment
        cell.dateLabel.text = postViewModel.postDate
        cell.usernameLabel.text = postViewModel.postedBy
        cell.userImage.sd_setImage(with: URL(string: postViewModel.userIconUrl))
        
        let gestureRecognizer = CustomTapGestureRecog(target: self, action: #selector(userImageTapped))
        let gestureRecognizer2 = CustomTapGestureRecog(target: self, action: #selector(usernameLabelTapped))
        cell.userImage.addGestureRecognizer(gestureRecognizer)
        cell.usernameLabel.addGestureRecognizer(gestureRecognizer2)
        gestureRecognizer.username = cell.usernameLabel.text!
        gestureRecognizer2.username = cell.usernameLabel.text!
        
        cell.delegate = self
        return cell
        
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let postViewModel = self.followingViewModel.postAtIndex(index: indexPath.row)
        
        followingVSM.postId = postViewModel.postId
        
        performSegue(withIdentifier: "toPostDetailVCFromFollowing", sender: nil)
        
        // this command prevent gray colour when come back after selection
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "toPostDetailVCFromFollowing" {
            
            let destinationVC = segue.destination as! PostDetailViewController
            
            destinationVC.postId = followingVSM.postId
        }
        
        if segue.identifier == "toUserVCFromFollowingVC" {
            
            let destinationVC = segue.destination as! UserViewController
            
            destinationVC.username = sender as! String
        }
        
    }
    
    
    func getData(){
        
        webService.downloadDataFollowingVC { postList in
            
            self.followingViewModel = FollowingViewModel(postList: postList)
            
            self.followingViewModel.postList.sort { p1, p2 in
                
                return p1.postDate.compare(p2.postDate) == .orderedDescending
            }
            
            DispatchQueue.main.async {
                
                self.followingTableView.reloadData()
            }
            
        }
        
    }
    
    func likeButtonDidTap(cell: FollowingFeedCell) {
        
        print("like button tapped")
    }
    
    func watchListButtonDidTap(cell: FollowingFeedCell) {
        
        print("watchlist button button tapped")
    }
    
    func threeDotMenuButtonDidTap(cell: FollowingFeedCell) {
                                
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            let sharebutton = UIAlertAction(title: "share", style: .default)
            let reportButton =  UIAlertAction(title: "report", style: .default)
            let cancelButton =  UIAlertAction(title: "cancel", style: .cancel)
            
            alert.addAction(sharebutton)
            alert.addAction(reportButton)
            alert.addAction(cancelButton)
            
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
    }
                    
  
    @objc func userImageTapped(sender: CustomTapGestureRecog) {
        
        let username = sender.username
        
        performSegue(withIdentifier: "toUserVCFromFollowingVC", sender: username)
    }
    
    
    @objc func usernameLabelTapped(sender: CustomTapGestureRecog) {
        
        let username = sender.username
        
        performSegue(withIdentifier: "toUserVCFromFollowingVC", sender: username)
    }
    
    @objc private func didPullToRefresh(){
        
        getData()
        
        DispatchQueue.main.asyncAfter(deadline: .now()+2) {
            
            self.followingTableView.refreshControl?.endRefreshing()
        }
    }
    
    
    func makeAlert (titleInput: String, messageInput: String){
        
        let alert = UIAlertController(title: titleInput, message: messageInput, preferredStyle: UIAlertController.Style.alert)
        let okButton = UIAlertAction(title: "ok", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(okButton)
        self.present(alert, animated: true, completion: nil)
    }
    
    

}


class CustomTapGestureRecog: UITapGestureRecognizer {
    
    var username = String()
}

