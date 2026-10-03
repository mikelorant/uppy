import AppKit

final class SettingsContentView: NSView {
  private let scrollView = UppyEndpointScrollView()
  let loginControl = LaunchAtLoginControl()
  private let title = NSTextField(labelWithString: "Endpoints")
  private let instructions = NSTextField(labelWithString: "Manage which endpoints are checked.")

  init(tableView: NSTableView) {
    super.init(frame: .zero)
    configureList(tableView)
    configureLabels()
    buildLayout()
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  var preferredSize: NSSize {
    NSSize(
      width: 684,
      height: 21.6 + title.intrinsicContentSize.height
        + 3.6 + instructions.intrinsicContentSize.height + 12.6 + 54 * 6 + 12.6
        + loginControl.button.intrinsicContentSize.height + 21.6)
  }

  private func configureList(_ table: NSTableView) {
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.scrollerStyle = .overlay
    scrollView.backgroundColor = .textBackgroundColor
    scrollView.documentView = table
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.wantsLayer = true
    scrollView.layer?.borderWidth = 1
    scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
    scrollView.layer?.cornerRadius = 7.2
    scrollView.layer?.masksToBounds = true
  }

  private func configureLabels() {
    title.font = .systemFont(ofSize: 21.6, weight: .semibold)
    instructions.font = .systemFont(ofSize: 16.2)
    instructions.textColor = .secondaryLabelColor
    title.translatesAutoresizingMaskIntoConstraints = false
    instructions.translatesAutoresizingMaskIntoConstraints = false
  }

  private func buildLayout() {
    let rule = NSBox()
    rule.boxType = .separator
    rule.translatesAutoresizingMaskIntoConstraints = false
    for view in [rule, title, instructions, scrollView, loginControl.button] {
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      rule.topAnchor.constraint(equalTo: topAnchor),
      rule.leadingAnchor.constraint(equalTo: leadingAnchor),
      rule.trailingAnchor.constraint(equalTo: trailingAnchor),
      title.topAnchor.constraint(equalTo: topAnchor, constant: 21.6),
      title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 21.6),
      title.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -21.6),
      instructions.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3.6),
      instructions.leadingAnchor.constraint(equalTo: title.leadingAnchor),
      instructions.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -21.6),
      scrollView.topAnchor.constraint(equalTo: instructions.bottomAnchor, constant: 12.6),
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 21.6),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -21.6),
      scrollView.heightAnchor.constraint(equalToConstant: 54 * 6),
      loginControl.button.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12.6),
      loginControl.button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 21.6),
      loginControl.button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -21.6),
    ])
  }
}
