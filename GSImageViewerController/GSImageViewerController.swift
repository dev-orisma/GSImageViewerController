//
//  GSImageViewerController.swift
//  GSImageViewerControllerExample
//
//  Created by Gesen on 15/12/22.
//  Copyright © 2015年 Gesen. All rights reserved.
//

import UIKit

public struct GSImageInfo {
    
    public enum ImageMode : Int {
        case aspectFit  = 1
        case aspectFill = 2
    }
    
    public let image     : UIImage
    public let imageMode : ImageMode
    public var imageHD   : URL?
    public var saveToFileName: String?
    
    public var contentMode : UIViewContentMode {
        return UIViewContentMode(rawValue: imageMode.rawValue)!
    }
    
    public init(image: UIImage, imageMode: ImageMode) {
        self.image     = image
        self.imageMode = imageMode
    }
    
    public init(image: UIImage, imageMode: ImageMode, imageHD: URL?) {
        self.init(image: image, imageMode: imageMode)
        self.imageHD = imageHD
    }
    
    public init(image: UIImage, imageMode: ImageMode, imageHD: URL?, saveToFileName: String? ) {
        self.init(image: image, imageMode: imageMode)
        self.imageHD = imageHD
        self.saveToFileName = saveToFileName
    }
    
    func calculateRect(_ size: CGSize) -> CGRect {
        
        let widthRatio  = size.width  / image.size.width
        let heightRatio = size.height / image.size.height
        
        switch imageMode {
            
        case .aspectFit:
            
            return CGRect(origin: CGPoint.zero, size: size)
            
        case .aspectFill:
            
            return CGRect(
                x      : 0,
                y      : 0,
                width  : image.size.width  * max(widthRatio, heightRatio),
                height : image.size.height * max(widthRatio, heightRatio)
            )
            
        }
    }
    
    func calculateMaximumZoomScale(_ size: CGSize) -> CGFloat {
        return max(2, max(
            image.size.width  / size.width,
            image.size.height / size.height
        ))
    }
    
}

open class GSTransitionInfo {
    
    open var duration: TimeInterval = 0.35
    open var canSwipe: Bool           = true
    
    public init(fromView: UIView) {
        self.fromView = fromView
    }
    
    weak var fromView : UIView?
    
    fileprivate var convertedRect : CGRect?
    
}

open class GSImageViewerController: UIViewController, URLSessionDataDelegate, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate  {
    
    open let imageInfo      : GSImageInfo
    open var transitionInfo : GSTransitionInfo?
    
    fileprivate let imageView  = UIImageView()
    fileprivate let scrollView = UIScrollView()
    fileprivate var loadingView = UIView()
    fileprivate var progressView = UIProgressView()
    fileprivate var progressLabel = UILabel()
    fileprivate var saveButton = UIButton()
    fileprivate var closeButton = UIButton()
    public let screen_height = UIScreen.main.bounds.height
    public let screen_width = UIScreen.main.bounds.width
    
 
    
    // MARK: Initialization
    var session : URLSession {
        get {
            let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).downloadImg")
            
            // Warning: If an URLSession still exists from a previous download, it doesn't create
            // a new URLSession object but returns the existing one with the old delegate object attached!
            return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        }
    }
    
    
    public init(imageInfo: GSImageInfo) {
        self.imageInfo = imageInfo
        super.init(nibName: nil, bundle: nil)
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        
        DispatchQueue.main.async() {
            print("Run")
            self.progressView.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            self.progressLabel.text = "Downloading \(String(totalBytesWritten)) / \(String(totalBytesExpectedToWrite)) bytes"
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL ) {
        
        self.loadingView.isHidden = true
        self.saveButton.isHidden = false
        
        do {
            
            if let filename = imageInfo.saveToFileName {
                let paths = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString).appendingPathComponent(filename)
                let localUrls = URL(fileURLWithPath: paths)
                try FileManager.default.copyItem(at: location, to: localUrls)
                
                let imgURL = UIImage(contentsOfFile: paths)
                self.imageView.image = imgURL
                self.view.layoutIfNeeded()
            }
            
        }catch{
            print("FileManagerError")
        }
        
      
        
      
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            print("Failed to download data")
        }else {
            print("Data downloaded")
            
        }
        
        session.invalidateAndCancel()
    }
    
    public convenience init(imageInfo: GSImageInfo, transitionInfo: GSTransitionInfo) {
        self.init(imageInfo: imageInfo)
        self.transitionInfo = transitionInfo
        if let fromView = transitionInfo.fromView, let referenceView = fromView.superview {
            self.transitioningDelegate = self
            self.modalPresentationStyle = .custom
            transitionInfo.convertedRect = referenceView.convert(fromView.frame, to: nil)
        }
    }
    
    public convenience init(image: UIImage, imageMode: UIViewContentMode, imageHD: URL?, fromView: UIView?) {
        let imageInfo = GSImageInfo(image: image, imageMode: GSImageInfo.ImageMode(rawValue: imageMode.rawValue)!, imageHD: imageHD)
        if let fromView = fromView {
            self.init(imageInfo: imageInfo, transitionInfo: GSTransitionInfo(fromView: fromView))
        } else {
            self.init(imageInfo: imageInfo)
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Override
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupScrollView()
        setupImageView()
        setupGesture()
        setupSaveButton()
        setupImageHD()
       
        
        edgesForExtendedLayout = UIRectEdge()
        automaticallyAdjustsScrollViewInsets = false
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        imageView.frame = imageInfo.calculateRect(view.bounds.size)
        
        scrollView.frame = view.bounds
        scrollView.contentSize = imageView.bounds.size
        scrollView.maximumZoomScale = imageInfo.calculateMaximumZoomScale(scrollView.bounds.size)
    }
    
    // MARK: Setups
    
    fileprivate func setupView() {
        view.backgroundColor = UIColor.black
    }
    
    fileprivate func setupScrollView() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
    }
    
    fileprivate func setupImageView() {
        imageView.image = imageInfo.image
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
    }
    
    
    fileprivate func setupGesture() {
        let single = UITapGestureRecognizer(target: self, action: #selector(singleTap))
        let double = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        double.numberOfTapsRequired = 2
        single.require(toFail: double)
        scrollView.addGestureRecognizer(single)
        scrollView.addGestureRecognizer(double)
        
        if transitionInfo?.canSwipe == true {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            pan.delegate = self
            scrollView.addGestureRecognizer(pan)
        }
    }
    fileprivate func setupSaveButton() {
        self.saveButton = UIButton(frame: CGRect(x: screen_width - 60 , y: screen_height - 60, width: 50, height: 50))
        self.saveButton.backgroundColor = .red
        self.saveButton.setTitle("Save", for: .normal)
        self.saveButton.addTarget(self, action: #selector(self.saveImg), for: .touchUpInside)
        view.addSubview(self.saveButton)
        
        
       

        
        self.loadingView = UIView(frame: CGRect(x: 0 , y: 0 , width: screen_width, height: screen_height))
        self.loadingView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        
        
        let posY = (screen_height / 2) - 2
        
        self.progressLabel = UILabel(frame: CGRect(x: 0 , y: posY - 30 , width: screen_width, height: 20))
        self.progressLabel.text = "Downloading 0 / 0 byte"
        self.progressLabel.textAlignment = .center
        self.progressLabel.font = UIFont(name: "ThaiSansNeue-Italic", size: 20)
        self.progressLabel.textColor = UIColor.white
        self.loadingView.addSubview(self.progressLabel)
        
        
        self.progressView = UIProgressView(frame: CGRect(x: 30 , y: posY , width: screen_width - 60, height: 20))
        self.progressView.progressTintColor = UIColor.init(red: 186/255.0, green: 153/255.0, blue: 40/255.0, alpha: 1)
        self.progressView.transform = self.progressView.transform.scaledBy(x: 1, y: 2)
        self.loadingView.addSubview(self.progressView)
        
        
        
        
        
        
        self.loadingView.isHidden = true
        self.saveButton.isHidden = false
        
        view.addSubview(self.loadingView)
        
        self.closeButton  = UIButton(frame: CGRect(x: 10 , y: 10, width: 50, height: 50))
        self.closeButton.backgroundColor = .red
        self.closeButton.setTitle("Cls", for: .normal)
        self.closeButton.addTarget(self, action: #selector(self.closePreview), for: .touchUpInside)
        view.addSubview(self.closeButton)
    }
    
    @objc fileprivate func  saveImg() {
        if let uiimg = imageView.image {
            UIImageWriteToSavedPhotosAlbum(uiimg,  self,  #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    
    
    @objc fileprivate func closePreview() {
        if navigationController == nil || (presentingViewController != nil && navigationController!.viewControllers.count <= 1) {
            session.invalidateAndCancel()
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc fileprivate func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error")
        } else {
            let alert = UIAlertView(title: "Saved",
                                    message: "Your image has been saved",
                                    delegate: nil,
                                    cancelButtonTitle: "Ok")
            alert.show()
        }
    }

    
    public func setupImageHD() {
        guard let imageHD = imageInfo.imageHD else {   return   }
        
        self.loadingView.isHidden = false
        self.saveButton.isHidden = true
//            let configuration = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).downloadImg")
//            let session: URLSession = URLSession(configuration: configuration, delegate: self , delegateQueue: OperationQueue.main)
            let request = URLRequest(url: imageHD, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            let task = session.downloadTask(with: request)
            task.resume()
    }
    
    // MARK: Gesture
    
    @objc fileprivate func singleTap() {
        if navigationController == nil || (presentingViewController != nil && navigationController!.viewControllers.count <= 1) {
            session.invalidateAndCancel()
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc fileprivate func doubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: scrollView)
        
        if scrollView.zoomScale == 1.0 {
            scrollView.zoom(to: CGRect(x: point.x-40, y: point.y-40, width: 80, height: 80), animated: true)
        } else {
            scrollView.setZoomScale(1.0, animated: true)
        }
    }
    
    fileprivate var panViewOrigin : CGPoint?
    fileprivate var panViewAlpha  : CGFloat = 1
    
    @objc fileprivate func pan(_ gesture: UIPanGestureRecognizer) {
        
        func getProgress() -> CGFloat {
            let origin = panViewOrigin!
            let changeX = abs(scrollView.center.x - origin.x)
            let changeY = abs(scrollView.center.y - origin.y)
            let progressX = changeX / view.bounds.width
            let progressY = changeY / view.bounds.height
            return max(progressX, progressY)
        }
        
        func getChanged() -> CGPoint {
            let origin = scrollView.center
            let change = gesture.translation(in: view)
            return CGPoint(x: origin.x + change.x, y: origin.y + change.y)
        }
        
        func getVelocity() -> CGFloat {
            let vel = gesture.velocity(in: scrollView)
            return sqrt(vel.x*vel.x + vel.y*vel.y)
        }
        
        switch gesture.state {

        case .began:
            panViewOrigin = scrollView.center
            
        case .changed:
            scrollView.center = getChanged()
            panViewAlpha = 1 - getProgress()
            view.backgroundColor = UIColor(white: 0.0, alpha: panViewAlpha)
            gesture.setTranslation(CGPoint.zero, in: nil)

        case .ended:
            if getProgress() > 0.25 || getVelocity() > 1000 {
                dismiss(animated: true, completion: nil)
            } else {
                fallthrough
            }
            
        default:
            
            UIView.animate(withDuration: 0.3,
                animations: {
                    self.scrollView.center = self.panViewOrigin!
                    self.view.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
                },
                completion: { _ in
                    self.panViewOrigin = nil
                    self.panViewAlpha  = 1.0
                }
            )
            
        }
    }
    
}

extension GSImageViewerController: UIScrollViewDelegate {
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        imageView.frame = imageInfo.calculateRect(scrollView.contentSize)
    }
    
}

extension GSImageViewerController: UIViewControllerTransitioningDelegate {
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return GSImageViewerTransition(imageInfo: imageInfo, transitionInfo: transitionInfo!, transitionMode: .present)
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return GSImageViewerTransition(imageInfo: imageInfo, transitionInfo: transitionInfo!, transitionMode: .dismiss)
    }
    
}

class GSImageViewerTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    let imageInfo      : GSImageInfo
    let transitionInfo : GSTransitionInfo
    var transitionMode : TransitionMode
    
    enum TransitionMode {
        case present
        case dismiss
    }
    
    init(imageInfo: GSImageInfo, transitionInfo: GSTransitionInfo, transitionMode: TransitionMode) {
        self.imageInfo = imageInfo
        self.transitionInfo = transitionInfo
        self.transitionMode = transitionMode
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return transitionInfo.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        
        let tempMask = UIView()
            tempMask.backgroundColor = UIColor.black
        
        let tempImage = UIImageView(image: imageInfo.image)
            tempImage.layer.cornerRadius = transitionInfo.fromView!.layer.cornerRadius
            tempImage.layer.masksToBounds = true
            tempImage.contentMode = imageInfo.contentMode
        
        containerView.addSubview(tempMask)
        containerView.addSubview(tempImage)
        
        if transitionMode == .present {
            transitionInfo.fromView!.alpha = 0
            let imageViewer = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) as! GSImageViewerController
                imageViewer.view.layoutIfNeeded()
            
                tempMask.alpha = 0
                tempMask.frame = imageViewer.view.bounds
                tempImage.frame = transitionInfo.convertedRect!
            
            UIView.animate(withDuration: transitionInfo.duration,
                animations: {
                    tempMask.alpha  = 1
                    tempImage.frame = imageViewer.imageView.frame
                },
                completion: { _ in
                    tempMask.removeFromSuperview()
                    tempImage.removeFromSuperview()
                    containerView.addSubview(imageViewer.view)
                    transitionContext.completeTransition(true)
                }
            )
            
        }
        
        if transitionMode == .dismiss {
            
            let imageViewer = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) as! GSImageViewerController
                imageViewer.view.removeFromSuperview()
            
                tempMask.alpha = imageViewer.panViewAlpha
                tempMask.frame = imageViewer.view.bounds
                tempImage.frame = imageViewer.scrollView.frame
            
            UIView.animate(withDuration: transitionInfo.duration,
                animations: {
                    tempMask.alpha  = 0
                    tempImage.frame = self.transitionInfo.convertedRect!
                },
                completion: { _ in
                    tempMask.removeFromSuperview()
                    imageViewer.view.removeFromSuperview()
                    self.transitionInfo.fromView!.alpha = 1
                    transitionContext.completeTransition(true)
                }
            )
            
        }
        
    }
    
}

extension GSImageViewerController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            if scrollView.zoomScale != 1.0 {
                return false
            }
            if imageInfo.imageMode == .aspectFill && (scrollView.contentOffset.x > 0 || pan.translation(in: view).x <= 0) {
                return false
            }
        }
        return true
    }
    
}
