# Chrome ChatGPT Setup

Community preview for macOS users whose ChatGPT Chrome Web Store listing reports “This item is not available.”

Run `/usr/bin/ruby prepare.rb` from the downloaded repository. The script fetches the current CRX3 from Google's extension update service, verifies the signature against the expected extension ID, and prepares a versioned directory. It prints the directory to select. Open `chrome://extensions`, enable Developer mode, and choose **Load unpacked**. Keep the prepared directory in place while Chrome uses it. Review the extension permissions before loading it, including access to websites, browsing history and tab debugging.

The script accepts an optional output directory. It refuses to overwrite an existing version directory. To remove the preview, remove the extension in Chrome first, then remove its prepared version directory.

## Connecting to ChatGPT or Codex

The desktop app's Chrome integration also needs its native messaging host. Use the desktop app's browser extension setup and check whether Chrome appears in the desktop browser picker. If it does not, run the bundled diagnostic:

```sh
resources="/Applications/ChatGPT.app/Contents/Resources"
"$resources/cua_node/bin/node" \
  "$resources/plugins/openai-bundled/plugins/chrome/scripts/check-native-host-manifest.js" \
  --browser chrome --json
```

A missing manifest means the desktop connection still needs repair. This preview automates package preparation only. It does not install the native messaging host, edit Chrome preferences, or configure enterprise policies.

## Validation status

- Script tested with macOS arm64 and Chrome 157.0.8103.51. Download, signature verification and extraction passed for 1.26.1102.11740.
- The same extension version, loaded manually with a separately repaired native host, survived a full Chrome quit and automatically reconnected to Codex on one Mac.
- Clean-profile end-to-end connection, other platforms, extension upgrade and rollback are unverified. Google's update service returned no newer version during testing.
- Chrome requires user interaction to load the prepared directory. See [Chrome's distribution documentation](https://developer.chrome.com/docs/extensions/how-to/distribute).

Issues and PRs are welcome. Include OS, Chrome and desktop app versions, the operation tested, expected and actual results, and redacted diagnostics. Please omit profile data, account details and browsing history.

The preparation script is MIT licensed. The repository does not distribute the ChatGPT extension or desktop binaries. This community project is independent of Google and OpenAI.
