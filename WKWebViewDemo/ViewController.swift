//
//  ViewController.swift
//  WKWebViewDemo
//
//  Created by Chris Klimpke on 03/07/2024.
//

import UIKit
import WebKit

import Foundation
import UIKit
import Network
import Photos

class ViewController: UIViewController {
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
  private var vykingWebView: WKWebView!

  private let key = "io.vyking"
  private let config = "../assets/config/modeld.foot.bin"

  private let vykingApparelUrl = URL(string:"https://sneaker-window.vyking.io/vyking-examples/with-service-worker/examples/in-app-vyking-apparel-camera.html")!
  private let modelViewerUrl = URL(string:"https://sneaker-window.vyking.io/vyking-examples/with-service-worker/examples/in-app-model-viewer.html")!

  private let vykWebViewLogHandler = "logHandler"
  private let vykWebViewInfoHandler = "infoHandler"
  private let vykWebViewErrorHandler = "errorHandler"
  private let vykWebViewMessageHandler = "vykWebViewMessageHandler"

  enum ViewMode {
    case vykingApparel
    case modelViewer
  }
  private var viewMode: ViewMode = ViewMode.modelViewer

  private var shoeSelector: Int = 0
  private let shoeList = [
    ["Yeezy Boost 700 carbon_blue", "https://sneaker-window.vyking.io/vyking-assets/customer/vyking-io/yeezy_boost_700_carbon_blue/offsets.json"],
    ["Adidas GY1121", "https://sneaker-window.vyking.io/vyking-assets/customer/vyking-io/adidas_GY1121/offsets.json"],
    ["Air Jordon 1 Turbo Green", "https://sneaker-window.vyking.io/vyking-assets/customer/vyking-io/air_jordan_1_turbo_green/offsets.json"],
    ["Jordon Off-white", "https://sneaker-window.vyking.io/vyking-assets/customer/vyking-io/jordan_off_white_chicago/offsets.json"],
    ["Monte Runner", "https://sneaker-window.vyking.io/vyking-assets/customer/vyking-io/H209A4M00080M2056P04_Monte_Runner_Trainers/offsets.json"]
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
        document.querySelector('vyking-apparel')?.setAttribute('key', '\(key)');
        document.querySelector('vyking-apparel')?.setAttribute('config', '\(config)');

        document.querySelector('model-viewer')?.setAttribute('vto', true);
        document.querySelector('model-viewer')?.setAttribute('vto-share', true);
        document.querySelector('model-viewer')?.setAttribute('vto-key', '\(key)');
        document.querySelector('model-viewer')?.setAttribute('vto-config', '\(config)');
      """, completionHandler: completionHandler)
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
    default:
      break
    }
  }
}

