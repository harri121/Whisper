//
//  ShoutView.swift
//  Whisper
//
//  Created by Daniel Hariri on 09.06.16.
//  Copyright © 2016 Hyper Interaktiv AS. All rights reserved.
//

import UIKit

protocol ShoutViewDelegate:class{
    func shoutViewDidHide(_ shoutView:ShoutView)
}

open class ShoutView: UIView {
    public struct Dimensions {
        public static let indicatorHeight: CGFloat = 6
        public static let indicatorWidth: CGFloat = 50
        public static let imageSize: CGFloat = 48
        public static let imageOffset: CGFloat = 18
        public static var height: CGFloat = UIApplication.shared.isStatusBarHidden ? 70 : 80
        public static var textOffset: CGFloat = 75
    }
    
    open fileprivate(set) lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = ColorList.Shout.background
        view.alpha = 0.98
        view.clipsToBounds = true
        
        return view
    }()
    
    open fileprivate(set) lazy var gestureContainer: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        
        return view
    }()
    
    open fileprivate(set) lazy var indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = ColorList.Shout.dragIndicator
        view.layer.cornerRadius = Dimensions.indicatorHeight / 2
        view.isUserInteractionEnabled = true
        
        return view
    }()
    
    open fileprivate(set) lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = Dimensions.imageSize / 2
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        
        return imageView
    }()
    
    open fileprivate(set) lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = FontList.Shout.title
        label.textColor = ColorList.Shout.title
        label.numberOfLines = 1
        
        return label
    }()
    
    open fileprivate(set) lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = FontList.Shout.subtitle
        label.textColor = ColorList.Shout.subtitle
        label.numberOfLines = 1
        
        return label
    }()
    
    open fileprivate(set) lazy var tapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(self.handleTapGestureRecognizer))
        
        return gesture
        }()
    
    open fileprivate(set) lazy var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in
        let gesture = UIPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(self.handlePanGestureRecognizer))
        
        return gesture
        }()
    
    open fileprivate(set) var announcement: Announcement?
    open fileprivate(set) var displayTimer = Timer()
    open fileprivate(set) var panGestureActive = false
    open fileprivate(set) var shouldSilent = false
    open fileprivate(set) var completion: (() -> ())?
    
    
    weak var delegate:ShoutViewDelegate?
    
    // MARK: - Initializers
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(backgroundView)
        [indicatorView, imageView, titleLabel, subtitleLabel, gestureContainer].forEach {
            backgroundView.addSubview($0) }
        
        clipsToBounds = false
        isUserInteractionEnabled = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 0.5)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 0.5
        
        addGestureRecognizer(tapGestureRecognizer)
        gestureContainer.addGestureRecognizer(panGestureRecognizer)
        
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(announcement: Announcement, completion: (() -> ())? = {}) {
        self.init()
        
        Dimensions.height = UIApplication.shared.isStatusBarHidden ? 70 : 80
        
        panGestureActive = false
        shouldSilent = false
        self.announcement = announcement
        self.completion = completion
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    // MARK: - Configuration
    
    open func craft(_ announcement: Announcement, to: UIViewController, completion: (() -> ())?) {
        configureView(announcement)
        shout(to: to)
    }
    
    open func configureView(_ announcement: Announcement) {
        imageView.image = announcement.image
        titleLabel.text = announcement.title
        subtitleLabel.text = announcement.subtitle ?? ""
        
        [titleLabel, subtitleLabel].forEach {
            $0.sizeToFit()
        }
        
        if imageView.image == nil { Dimensions.textOffset = 18 }
        
        displayTimer.invalidate()
        displayTimer = Timer.scheduledTimer(timeInterval: announcement.duration,
                                                              target: self, selector: #selector(self.displayTimerDidFire), userInfo: nil, repeats: false)
        setupFrames()
    }
    
    open func shout(to controller: UIViewController) {
        
        let width = UIScreen.main.bounds.width
        controller.view.addSubview(self)
        
        frame = CGRect(x: 0, y: 0, width: width, height: 0)
        backgroundView.frame = CGRect(x: 0, y: 0, width: width, height: 0)
        
        UIView.animate(withDuration: 0.35, animations: {
            self.frame.size.height = Dimensions.height
            self.backgroundView.frame.size.height = self.frame.height
        })
    }
    
    // MARK: - Setup
    
    open func setupFrames() {
        let totalWidth = UIScreen.main.bounds.width
        let offset: CGFloat = UIApplication.shared.isStatusBarHidden ? 2.5 : 5
        
        backgroundView.frame.size = CGSize(width: totalWidth, height: Dimensions.height)
        gestureContainer.frame = CGRect(x: 0, y: Dimensions.height - 20, width: totalWidth, height: 20)
        indicatorView.frame = CGRect(x: (totalWidth - Dimensions.indicatorWidth) / 2,
                                     y: Dimensions.height - Dimensions.indicatorHeight - 5, width: Dimensions.indicatorWidth, height: Dimensions.indicatorHeight)
        imageView.frame = CGRect(x: Dimensions.imageOffset, y: (Dimensions.height - Dimensions.imageSize) / 2 + offset,
                                 width: Dimensions.imageSize, height: Dimensions.imageSize)
        titleLabel.frame.origin = CGPoint(x: Dimensions.textOffset, y: imageView.frame.origin.y + 3)
        subtitleLabel.frame.origin = CGPoint(x: Dimensions.textOffset, y: titleLabel.frame.maxY + 2.5)
        
        if let text = subtitleLabel.text , text.isEmpty {
            titleLabel.center.y = imageView.center.y - 2.5
        }
        
        [titleLabel, subtitleLabel].forEach {
            $0.frame.size.width = totalWidth - Dimensions.imageSize - (Dimensions.imageOffset * 2) }
    }
    
    // MARK: - Actions
    
    open func silent() {
        UIView.animate(withDuration: 0.35, animations: {
            self.frame.size.height = 0
            self.backgroundView.frame.size.height = self.frame.height
            }, completion: { finished in
                self.completion?()
                self.displayTimer.invalidate()
                self.removeFromSuperview()
                self.delegate?.shoutViewDidHide(self)
        })
        
    }
    
    // MARK: - Timer methods
    
    open func displayTimerDidFire() {
        shouldSilent = true
        
        if panGestureActive { return }
        silent()
    }
    
    // MARK: - Gesture methods
    
    @objc fileprivate func handleTapGestureRecognizer() {
        guard let announcement = announcement else { return }
        announcement.action?()
        silent()
    }
    
    @objc fileprivate func handlePanGestureRecognizer() {
        let translation = panGestureRecognizer.translation(in: self)
        var duration: TimeInterval = 0
        
        if panGestureRecognizer.state == .changed || panGestureRecognizer.state == .began {
            panGestureActive = true
            if translation.y >= 12 {
                frame.size.height = Dimensions.height + 12 + (translation.y) / 25
            } else {
                frame.size.height = Dimensions.height + translation.y
            }
        } else {
            panGestureActive = false
            let height = translation.y < -5 || shouldSilent ? 0 : Dimensions.height
            
            duration = 0.2
            UIView.animate(withDuration: duration, animations: {
                self.frame.size.height = height
                }, completion: { _ in if translation.y < -5 {
                    self.silent()
                    }})
        }
        
        UIView.animate(withDuration: duration, animations: {
            self.backgroundView.frame.size.height = self.frame.height
            self.gestureContainer.frame.origin.y = self.frame.height - 20
            self.indicatorView.frame.origin.y = self.frame.height - Dimensions.indicatorHeight - 5
        })
    }
}
