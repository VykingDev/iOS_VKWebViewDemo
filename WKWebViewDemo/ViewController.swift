//
//  ViewController.swift
//  WKWebViewDemo
//
//  Created by Chris Klimpke on 03/07/2024.
//

import UIKit
@preconcurrency import WebKit

import Foundation
import UIKit
import Network
import Photos

class ViewController: UIViewController {
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
  private var vykingWebView: WKWebView!

  private let key = "io.vyking"
  private let config = "https://sneaker-window.vyking.io/vyking-examples/vanilla/assets/config/modeld.foot.config"
  private var isPreWarmOfTensorflowModelComplete: Bool = false

//  private let vykingApparelUrl = URL(string:"https://192.168.0.20:1236/vanilla/examples/in-app-vyking-apparel-camera.html")!

  private let vykingApparelUrl = URL(string:"https://sneaker-window.vyking.io/vyking-examples/with-service-worker/examples/in-app-vyking-apparel-camera.html")!
//  private let vykingApparelUrl = URL(string:"https://sneaker-window.vyking.io/vyking-examples/vanilla/examples/in-app-vyking-apparel-camera.html")!

  private let modelViewerUrl = URL(string:"https://sneaker-window.vyking.io/vyking-examples/with-service-worker/examples/in-app-model-viewer.html")!
//  private let modelViewerUrl = URL(string:"https://sneaker-window.vyking.io/vyking-examples/vanilla/examples/in-app-model-viewer.html")!

  private let vykWebViewLogHandler = "logHandler"
  private let vykWebViewInfoHandler = "infoHandler"
  private let vykWebViewErrorHandler = "errorHandler"
  private let vykWebViewOnPreWarmTensorflowModelCompleteHandler = "vykWebViewOnPreWarmTensorflowModelCompleteHandler"

  enum ViewMode {
    case vykingApparel
    case modelViewer
  }
  private var viewMode: ViewMode = ViewMode.modelViewer

  private var shoeSelector: Int = 0
  private let shoeList = [
    ["New Balance", "https://sneaker-window.vyking.io/vyking-assets/customer/vyking-io/NB01/offsets.json"],
    ["Nike", "https://sneaker-window.vyking.io/vyking-assets/customer/vyking-io/NIKE06/offsets.json"],
    ["Adidas", "https://sneaker-window.vyking.io/vyking-assets/customer/vyking-io/IE2165/offsets.json"]
  ]

  @IBOutlet weak var viewModelToggleButtonReference: UIButton!
  @IBAction func viewModelToggleButtonAction(_ sender: UIButton) {
    NSLog("WKWebViewDemo.viewModelToggleButtonAction")

    switch viewMode {
    case .vykingApparel:
      viewMode = .modelViewer
    case .modelViewer:
      viewMode = .vykingApparel
    }

    removeVykingWebView()
    addVykingWebView()

    view.bringSubviewToFront(viewModelToggleButtonReference)
    view.bringSubviewToFront(NextShoeButtonReference)
  }

  @IBOutlet weak var NextShoeButtonReference: UIButton!
  @IBAction func NextShoeButtonAction(_ sender: UIButton) {
    NSLog("WKWebViewDemo.NextShoeButtonAction")

    shoeSelector = (shoeSelector + 1) % shoeList.count
    vykingReplaceApparel(url: shoeList[ shoeSelector ][1], name: shoeList[ shoeSelector ][0]) { (result, error) in
      NSLog("WKWebViewDemo.NextShoeButtonAction vykingReplaceApparel")
    }
  }

  override func viewDidLoad() {
    NSLog("WKWebViewDemo.viewDidLoad version: \(String(describing: appVersion))")

    super.viewDidLoad()

    addVykingWebView()

    // Keep this button hidden until the pre-warming of the Tensorflow model has completed.
    // This will occur during the presentation of the model-viewer WKWebView.
    viewModelToggleButtonReference.isHidden = true

    view.bringSubviewToFront(viewModelToggleButtonReference)
    view.bringSubviewToFront(NextShoeButtonReference)
  }
}

extension ViewController {
  func addVykingWebView() {
    let webConfiguration = WKWebViewConfiguration()
    webConfiguration.allowsInlineMediaPlayback = true
    webConfiguration.mediaTypesRequiringUserActionForPlayback = []
    webConfiguration.limitsNavigationsToAppBoundDomains = true // Requires plist property WKAppBoundDomains defined

    let webPreferences = WKPreferences()
    NSLog("WKWebViewDemo.loadView webPreferences \(webPreferences)")
    NSLog("WKWebViewDemo.loadView webPreferences \(webPreferences.dictionaryWithValues(forKeys: [] ))")
    webConfiguration.preferences = webPreferences

    let logSource = """
        let originalLog = console.log;
        function captureLog(msg, ...args) {
          originalLog(msg, args);
          window.webkit.messageHandlers.logHandler.postMessage(msg);
        }
        window.console.log = captureLog;
        """
    let logScript = WKUserScript(source: logSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    webConfiguration.userContentController.addUserScript(logScript)
    webConfiguration.userContentController.add(self, name: vykWebViewLogHandler)

    let infoSource = """
        let originalInfo = console.info;
        function captureInfo(msg, ...args) {
          originalInfo(msg, args);
          window.webkit.messageHandlers.infoHandler.postMessage(msg);
        }
        window.console.info = captureInfo;
        """
    let infoScript = WKUserScript(source: infoSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    webConfiguration.userContentController.addUserScript(infoScript)
    webConfiguration.userContentController.add(self, name: vykWebViewInfoHandler)

    let errorSource = """
        let originalerror = console.error;
        function captureError(msg, ...args) {
          originalerror(msg, args);
          window.webkit.messageHandlers.errorHandler.postMessage(msg);
        }
        window.console.error = captureError;
        """
    let errorScript = WKUserScript(source: errorSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    webConfiguration.userContentController.addUserScript(errorScript)
    webConfiguration.userContentController.add(self, name: vykWebViewErrorHandler)

    // Add a function that can be called when pre-warming the Tensorfow model completes
    let onPreWarmTensorflowModelCompleteSource = """
        function onPreWarmTensorflowModelComplete(msg) {
          window.webkit.messageHandlers.vykWebViewOnPreWarmTensorflowModelCompleteHandler.postMessage(msg);
        }
        """
    let onPreWarmTensorflowModelCompleteScript = WKUserScript(source: onPreWarmTensorflowModelCompleteSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    webConfiguration.userContentController.addUserScript(onPreWarmTensorflowModelCompleteScript)
    webConfiguration.userContentController.add(self, name: vykWebViewOnPreWarmTensorflowModelCompleteHandler)

    vykingWebView = WKWebView(frame: CGRect(
      x: 0,
      y: 0,
      width: UIScreen.main.bounds.width,
      height: UIScreen.main.bounds.height),
      configuration: webConfiguration
    )

    vykingWebView.navigationDelegate = self
    vykingWebView.uiDelegate         = self
    vykingWebView.autoresizingMask   = [.flexibleWidth, .flexibleHeight]
    vykingWebView.allowsBackForwardNavigationGestures = false
    vykingWebView.becomeFirstResponder()

    if #available(macOS 13.3, iOS 16.4, tvOS 16.4, *) {
      vykingWebView.isInspectable = true
    }

    let url = switch viewMode {
    case .vykingApparel: vykingApparelUrl
    case .modelViewer: modelViewerUrl
    }

    let urlRq = URLRequest(
      url: url,
      cachePolicy: .reloadRevalidatingCacheData,
      timeoutInterval: 60.0
    )
    vykingWebView.load( urlRq )

    let label = switch viewMode {
    case .vykingApparel: "View Model"
    case .modelViewer: "Try-on"
    }
    viewModelToggleButtonReference.setTitle(label, for: .normal)

    view.addSubview(vykingWebView)
  }

  func removeVykingWebView() {
    vykingWebView.removeFromSuperview()
    vykingWebView = nil
  }

  func vykingConfigure(config: String, key: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
    vykingWebView.evaluateJavaScript("""
        document.querySelector('vyking-apparel')?.setAttribute('config-key', '\(key)');
        document.querySelector('vyking-apparel')?.setAttribute('config', '\(config)');
      """, completionHandler: completionHandler)

    // It can take a long time to compile the Tensorflow model's shaders, therefore we provide a javascript that can be run to do this before
    // the VTO is required. This typically only needs to be done the first time the app is launched after installation and after a device restart,
    // however for simplicity this demo app does this on each app start.
    //It is assumed this completion handler has been called by a WKWebView displayed before the VTO WKWebView is needed.
    if (!isPreWarmOfTensorflowModelComplete) {
      vykingWebView.evaluateJavaScript("""
        const preWarmTensorflowModel = (configUrl, configKey) => {
          import('https://sneaker-window.vyking.io/vyking-apparel/1/preWarmTensorflowModel.js')
            .then(module => {
              return module.preWarmTensorflowModel(configUrl, configKey)
            .then(() => {
              console.log('Pre-warmed TensorFlow model')
            })
          })
          .catch((error) => {
            console.error('Error pre-warming TensorFlow model:', error)
          })
          .finally(() => {
              // Just because the pre-warming failed, it doesn't mean the VTO won't run
              onPreWarmTensorflowModelComplete({})
          })
        }
        preWarmTensorflowModel('\(config)', '\(key)')
        """, completionHandler: { (object, error) in
          NSLog("WKWebViewDemo.webView.didFinish navigation completion object: \(String(describing: object)), error: \(String(describing: error))")
        self.isPreWarmOfTensorflowModelComplete = true
      })
    }
  }

  func vykingReplaceApparel(url: String, name: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
    vykingWebView.evaluateJavaScript("""
        document.querySelector('vyking-apparel')?.setAttribute('alt', '\(name)');
        document.querySelector('vyking-apparel')?.setAttribute('apparel', '\(url)');

        document.querySelector('model-viewer')?.setAttribute('alt', '\(name)');
        document.querySelector('model-viewer')?.setAttribute('vyking-src', '\(url)');
      """, completionHandler: completionHandler)
  }

  func vykingRemoveApparel(completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
    vykingWebView.evaluateJavaScript("""
        document.querySelector('vyking-apparel')?.removeAttribute('alt');
        document.querySelector('vyking-apparel')?.removeAttribute('apparel');

        document.querySelector('model-viewer')?.removeAttribute('alt');
        document.querySelector('model-viewer')?.removeAttribute('vyking-src');
      """, completionHandler: completionHandler)
  }
}

extension ViewController: WKUIDelegate {
  func webView(
    _ webView: WKWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping () -> Void ) {

      let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
      alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
        completionHandler()
      }))

      present(alertController, animated: true, completion: nil)
    }

  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping (Bool) -> Void) {

    let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)

    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
      completionHandler(true)
    }))

    alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in
      completionHandler(false)
    }))

    present(alertController, animated: true, completion: nil)
  }

  func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping (String?) -> Void) {
    let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .actionSheet)

    alertController.addTextField { (textField) in
      textField.text = defaultText
    }

    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
      if let text = alertController.textFields?.first?.text {
        completionHandler(text)
      } else {
        completionHandler(defaultText)
      }
    }))

    alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in
      completionHandler(nil)
    }))

    present(alertController, animated: true, completion: nil)
  }

  @available(iOS 15, *)
  public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                      decisionHandler: @escaping (WKPermissionDecision) -> Void
  ) {
    NSLog("WKWebViewDemo.webView.requestMediaCapturePermissionFor")

    decisionHandler(.grant)
  }
}

extension ViewController: WKNavigationDelegate {
  public func webView(_: WKWebView,
                      didReceive: URLAuthenticationChallenge,
                      completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    // Allow development web servers that use self-signed certificates.
    guard didReceive.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust &&
             didReceive.protectionSpace.host == "192.168.0.20"   // For dev server
    else { return completionHandler(.performDefaultHandling, nil) }

    NSLog("webView \(didReceive.protectionSpace.host)")

    if let trust = didReceive.protectionSpace.serverTrust {
      DispatchQueue.global(qos: .background).async {
        completionHandler(.useCredential, URLCredential(trust: trust ))
      }
    } else {
      DispatchQueue.global(qos: .background).async {
        completionHandler(.cancelAuthenticationChallenge, nil)
      }
    }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    NSLog("WKWebViewDemo.webView.didFinish navigation view.frame \(view.frame)")
    vykingConfigure(config: config, key: key) { (result, error) in
      self.vykingReplaceApparel(url: self.shoeList[ self.shoeSelector ][1], name: self.shoeList[ self.shoeSelector ][0])
    }
  }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    switch message.name {
    case vykWebViewLogHandler:
      print("WEB-LOG: \(message.body)")
    case vykWebViewInfoHandler:
      print("WEB-INFO: \(message.body)")
    case vykWebViewErrorHandler:
      print("WEB-ERROR: \(message.body)")
    case vykWebViewOnPreWarmTensorflowModelCompleteHandler:
      print("WEB-nPreWarmTensorflowModelCompleteHandler: \(message.body)")
      // Now the pre-warm is complete we can enable the VTO button
      viewModelToggleButtonReference.isHidden = false
    default:
      break
    }
  }
}

