//
//  ViewController.swift
//  DelegateProxyDemo
//
//  Created by DS on 2020/6/23.
//  Copyright © 2020 DS. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    
    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let my = MyClass()
        
        my.rx.nums.subscribe { (event) in
            print(event)
        }.disposed(by: disposeBag)
        
        my.rx.strs.subscribe { (event) in
            print(event)
        }.disposed(by: disposeBag)
        
        my.start()
        
    }


}

@objc public protocol MyDelegate{
  
    func printNum(num: Int)
    
    @objc optional func printStr(str: String)
    
}

class MyClass: NSObject {
    
    public weak var delegate: MyDelegate?
    
    var timer: Timer?
    
    override init() {}
    
    func start() {
        timer = .init(timeInterval: 1, repeats: true, block: { _ in
            self.delegate?.printNum(num: 1)
            self.delegate?.printStr?(str: "这是字符串")
        })
        RunLoop.current.add(timer!, forMode: .default)
        timer?.fire()
    }
    
    func stop() {
        timer?.invalidate()
    }
}

class RxMyDelegateProxy: DelegateProxy<MyClass,MyDelegate>,DelegateProxyType,MyDelegate {
    
    
    init(my: MyClass) {
        super.init(parentObject: my, delegateProxy: RxMyDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        self.register { (parent) -> RxMyDelegateProxy in
            RxMyDelegateProxy(my: parent)
        }
    }
    
    static func currentDelegate(for object: MyClass) -> MyDelegate? {
        return object.delegate
    }
    
    static func setCurrentDelegate(_ delegate: MyDelegate?, to object: MyClass) {
        object.delegate = delegate
    }
    
    override func setForwardToDelegate(_ delegate: DelegateProxy<MyClass, MyDelegate>.Delegate?, retainDelegate: Bool) {
        super.setForwardToDelegate(delegate, retainDelegate: true)
    }
    
    internal lazy var nums = PublishSubject<Int>()

    func printNum(num: Int) {
        _forwardToDelegate?.printNum(num: num)
        self.nums.onNext(num)
    }

    deinit {
        self.nums.onCompleted()
    }
}

extension Reactive where Base: MyClass{
    
    var delegate: DelegateProxy<MyClass,MyDelegate>{
        return RxMyDelegateProxy.proxy(for: base)
    }
    
    var nums: Observable<Int>{
        return RxMyDelegateProxy.proxy(for: base).nums.asObservable()
    }
    
    var strs: Observable<String>{
        return delegate.methodInvoked(#selector(MyDelegate.printStr(str:))).map {
            return $0[0] as! String
        }
    }
    
}
