# cryptoOS

Coinbase-style crypto tracker for iPhone.

- **Holdings** — local portfolio (nothing leaves the phone), live-priced total balance with 24h change
- **Markets** — top 100 coins with 7-day sparklines, search, full detail view
- **Charts** — scrub with one finger for price-at-point; **hold two fingers to see the change between any two points** (Apple Stocks style); ranges 1H → All
- **News** — merged CoinDesk / Cointelegraph / Decrypt feeds, in-app reader

Data: CoinGecko free API + public RSS. No accounts, no API keys.

## Build

XcodeGen project — `project.yml` is the source of truth:

```
xcodegen generate
xcodebuild -project CryptoOS.xcodeproj -scheme CryptoOS build
```

CI builds unsigned on every push and uploads to TestFlight when ASC secrets are present.
