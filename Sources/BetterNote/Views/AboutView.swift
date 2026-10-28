import SwiftUI

struct AboutView: View {
    @State private var showingLicense = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96).padding(.top, 34)
            Text("BetterNote").font(.system(size: 24, weight: .semibold, design: .rounded)).padding(.top, 16)
            Text("Version \(version) (\(build))").font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 5)
            Text("A little room to think.").font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 14)

            HStack(spacing: 18) {
                Link("devded.com", destination: URL(string: "https://devded.com")!)
                Link("GitHub", destination: URL(string: "https://github.com/\(UpdateChecker.repository)")!)
                Link("Donate", destination: URL(string: "https://paypal.me/nuntates")!)
            }.font(.system(size: 12, weight: .medium)).padding(.top, 18)

            Spacer(minLength: 22)

            VStack(spacing: 5) {
                Text("Copyright © 2026 Bundit Nuntates").font(.system(size: 11))
                Button("MIT License") { showingLicense = true }.buttonStyle(.link).font(.system(size: 11))
            }.foregroundStyle(.secondary).padding(.bottom, 26)
        }
        .frame(width: 320, height: 320)
        .background(Theme.canvas)
        .sheet(isPresented: $showingLicense) {
            ScrollView {
                Text(AboutView.licenseText).font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }.frame(width: 440, height: 360)
        }
    }

    static let licenseText = """
    MIT License

    Copyright (c) 2026 Bundit Nuntates

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
}
