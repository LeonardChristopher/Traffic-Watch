# TrafficWatch

An iPhone app that monitors outgoing network traffic and identifies the organization each connection is destined for.

## How it works

- A Network Extension **content filter** (`NEFilterDataProvider`) observes every new outgoing socket flow on the device. It allows all traffic through (no blocking) and records the destination host/IP, port, transport, and originating app.
- Flow records are shared from the extension to the app through a shared App Group (`UserDefaults` + a Darwin notification for live updates).
- The app resolves each destination to an IP address and queries the IP's **RDAP record** (via `rdap.org`) to find the registering organization — e.g. `142.250.x.x → GOOGLE`, `13.107.x.x → Microsoft Corporation`.
- The main screen lists recent connections with the owning organization, the app that made them, and a relative timestamp.

## Requirements

- Xcode 15+
- iOS 16.0+
- An Apple Developer account (the Network Extension `content-filter` entitlement requires a paid team)

## Setup

1. Open `TrafficWatch.xcodeproj`.
2. Select your team in **Signing & Capabilities** for both targets (`TrafficWatch` and `FilterExtension`).
3. If you use a different bundle ID, update it in both targets and change the App Group (`group.com.trafficwatch.shared`) in the two `.entitlements` files and in `TrafficWatch/Shared/FlowEventStore.swift` to match.
4. Build and run on a device, then enable **Monitor outgoing traffic**. iOS will ask to allow the content filter in Settings → General → VPN & Device Management (or via a system permission prompt).

## Notes

- All traffic is allowed through untouched; the filter only observes.
- Organization attribution uses public RDAP/WHOIS data, which reflects network ownership (ISPs/CDNs/cloud providers), not necessarily the service name in the URL. For example, a request to a small website hosted on AWS shows the organization as Amazon.
- Connection history is capped at the most recent 400 flows and is stored locally only.

## Project layout

```
TrafficWatch.xcodeproj
TrafficWatch/
  TrafficWatch/            # App target (SwiftUI)
    ContentView.swift
    TrafficWatchModel.swift
    FilterController.swift     # Enables/disables the content filter
    OrganizationLookup.swift   # RDAP + DNS resolution
  FilterExtension/         # Content filter Network Extension
    FilterDataProvider.swift
  Shared/                   # Shared between app and extension
    FlowEvent.swift
    FlowEventStore.swift
```
