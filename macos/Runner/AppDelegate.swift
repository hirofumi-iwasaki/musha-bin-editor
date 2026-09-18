import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Updates titles that are owned by this app. System-provided controls (such
  /// as the contents of Services) remain under macOS's localization control.
  func setMenuLanguage(_ language: String) {
    let menu = NativeMenuText(language: language)
    guard let mainMenu = NSApp.mainMenu else { return }
    localize(menu: mainMenu, with: menu)
  }

  private func localize(menu: NSMenu, with text: NativeMenuText) {
    for item in menu.items {
      if let title = text.title(for: item.tag) {
        item.title = title
        item.submenu?.title = title
      }
      if let submenu = item.submenu {
        localize(menu: submenu, with: text)
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

private struct NativeMenuText {
  private let isJapanese: Bool
  private let appName: String

  init(language: String) {
    isJapanese = language == "ja"
    appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
      ?? "Mushagaeshi Binary Editor"
  }

  func title(for tag: Int) -> String? {
    let english: [Int: String] = [
      100: appName, 101: "About \(appName)", 102: "Preferences…", 103: "Services",
      104: "Hide \(appName)", 105: "Hide Others", 106: "Show All", 107: "Quit \(appName)",
      200: "Edit", 201: "Undo", 202: "Redo", 203: "Cut", 204: "Copy", 205: "Paste",
      206: "Paste and Match Style", 207: "Delete", 208: "Select All", 209: "Find",
      210: "Find…", 211: "Find and Replace…", 212: "Find Next", 213: "Find Previous",
      214: "Use Selection for Find", 215: "Jump to Selection", 216: "Spelling and Grammar",
      218: "Show Spelling and Grammar", 219: "Check Document Now",
      220: "Check Spelling While Typing", 221: "Check Grammar With Spelling",
      222: "Correct Spelling Automatically", 223: "Substitutions", 224: "Show Substitutions",
      225: "Smart Copy/Paste", 226: "Smart Quotes", 227: "Smart Dashes", 228: "Smart Links",
      229: "Data Detectors", 230: "Text Replacement", 231: "Transformations",
      232: "Make Upper Case", 233: "Make Lower Case", 234: "Capitalize", 235: "Speech",
      236: "Start Speaking", 237: "Stop Speaking", 300: "View", 301: "Enter Full Screen",
      400: "Window", 401: "Minimize", 402: "Zoom", 403: "Bring All to Front", 500: "Help",
    ]
    let japanese: [Int: String] = [
      100: appName, 101: "\(appName)について", 102: "環境設定…", 103: "サービス",
      104: "\(appName)を隠す", 105: "ほかを隠す", 106: "すべてを表示", 107: "\(appName)を終了",
      200: "編集", 201: "取り消す", 202: "やり直す", 203: "カット", 204: "コピー", 205: "ペースト",
      206: "ペーストしてスタイルを合わせる", 207: "削除", 208: "すべてを選択", 209: "検索",
      210: "検索…", 211: "検索と置換…", 212: "次を検索", 213: "前を検索",
      214: "選択部分を検索に使用", 215: "選択部分に移動", 216: "スペルと文法",
      218: "スペルと文法を表示", 219: "今すぐ書類をチェック",
      220: "入力中にスペルチェック", 221: "スペルチェックと文法チェック",
      222: "スペルを自動修正", 223: "置換", 224: "置換を表示",
      225: "スマートコピー／ペースト", 226: "スマート引用符", 227: "スマートダッシュ", 228: "スマートリンク",
      229: "データ検出", 230: "テキスト置換", 231: "変換",
      232: "大文字にする", 233: "小文字にする", 234: "先頭を大文字にする", 235: "スピーチ",
      236: "読み上げを開始", 237: "読み上げを停止", 300: "表示", 301: "フルスクリーンにする",
      400: "ウインドウ", 401: "しまう", 402: "拡大／縮小", 403: "すべてを手前に移動", 500: "ヘルプ",
    ]
    return (isJapanese ? japanese : english)[tag]
  }
}
