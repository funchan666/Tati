# Tati Prada integration — 2026-10-22

Current source of truth: `contract.json`. App ID **48859669**, API origin **https://api.afterhou.top**, Bundle ID **com.tatifood.kitchennotes**. This work uses the installed Prada skill, the existing SwiftUI architecture, original Tati artwork, and static Duo layout/state review. No audit/device/time-based feature filtering was added.

## Import

Select App **48859669** in the configuration console. Import `generated/接口模板-48859669.json` and `generated/配置模板-48859669.json`, then validate and save that App. These are the only two import files. Internal response sources, manifests, CSVs, request examples and theme protocol are maintenance material, not additional console imports.

There are five POST JSON interfaces: authentication, purchase confirmation, table catalog, cooking notebook and kitchen offers. The configuration has exactly 14 entries: seven request mappings, three web parameter mappings, four core event slots. Paths and fields are frozen for this project; authentication is `/tati/table/pantry-welcome`. The domain was supplied by the user; no production business endpoint was called during integration.

The authentication response's `table_entry` is deployment-only. The client reads only the mapped connection container and takes web destinations from validated realtime events. Dynamic placeholders must be expanded by the platform. A full signed `wss` URL is required; the app does not construct credentials or fetch a second connection URL.

## Data provenance and runtime loading

The original Swift literal arrays and the previous complete editorial manifest were exported before their production removal. `source-inventory.json` records the original source hashes, ordered member/film IDs and counts. Export preserved 49 members, 10 rooms, 16 movies (10 feed, 6 room), 49 photos, eight gifts, nine coin packs, six recipes, two recipe chapters and eight cooking answers, plus all authored comments, room activity, filters, prompts and support articles. Changes after export are limited to a required city field, room summary fields, and correcting obsolete purchase-recovery guidance. IDs, monetary offers, original media URLs and media allocation remain stable.

`KitchenContentRepository` POSTs `{}` to all three content routes concurrently. It requires valid envelopes, complete DTOs and valid cross-record references before one atomic snapshot installation. A new batch removes the old snapshot first. Failure shows an in-page error/retry; there is no bundled JSON, previous content response, seed array or disk-response fallback. Domain facades return empty collections before installation. Snapshot reads are synchronized because image-cache actors also resolve media references.

Production content JSON was removed from `Tati/Resources`. Deployment JSON is outside the app target. Local image/video originals remain deleted as requested. R2 references and bounded image/poster caches remain; genuine member imports, edits, drafts, follow/block/hide choices, wallet history and transaction evidence remain in their existing storage.

For future media edits, `python3 Scripts/import_content.py` updates the deployment catalog only. Then regenerate from the frozen contract:

```sh
python3 "$PRADA_SKILL_DIR/scripts/render_contract.py" Docs/BackendAPI/contract.json --out Docs/BackendAPI/generated --replace
```

Set `PRADA_SKILL_DIR` to the installed Prada skill directory before running this maintenance command. If the contract changes, copy both generated Swift constant files to `Tati/Integration`; preserve the project's ordinary-comment cleanup. Content-only edits do not change runtime constants.

## Call-chain inspection

| Item | Production owner and entry | Static result / boundary |
| --- | --- | --- |
| F01 contract | `IntegrationContract.generated.swift`, `KitchenAuthentication`, `KitchenHTTP` | Frozen origin/path/aliases; POST only; integer delivery mode 2; no redirects for API requests. |
| F02 content | `KitchenContentRepository.reload → fetch → validate → install` | Three related responses install together. Final template payloads equal source responses. Counts and IDs match source inventory. No old content fallback. |
| F03 target | `project.yml`, generated Xcode project, Info/Privacy plists, entitlements | All 40 Swift files are target members. Alamofire is resolved/locked at 5.12.2. Device ID uses a dedicated Keychain entry. Existing source/media contracts retained. |
| F04 startup | `TatiApp.task → install → purchases.start`, `begin` | Original SK2 owner starts bounded consumable cleanup. Auth/content wait for that gate; network preheat/APNs initialize separately. One auth constructor handles login, saved-session restoration and refresh. |
| F05 entry | `WelcomeView → session.begin` | One consent-gated button; terms below, initially unchecked. No pre-login config endpoint exists, so there is no authoritative B-enabled state to auto-select consent before authentication. Button feedback lasts through final route decision. Welcome reward popup removed; actual grant remains idempotent. |
| F06 messages | `ConfiguredRealtimeClient.onMessage → TableMessageChannel.post → TableBusinessReceiver.receive → ConfiguredIncomingEvent.parse → dispatcher` | Complete business JSON and decoding metadata travel with captured session/scene. Receiver is registered first and validates source/context synchronously. Template transport owns 4/10/11/15, ACK/watchdog/recovery. No SDK or parallel business parser. |
| F07 web | `SupperWebOwner.prepare/beginLoad`, `TableWebLayer` | One real WKWebView, inline/AirPlay/autoplay options before creation. Valid current HTTP+HTML didFinish and mounted bounds commit B. Navigation generations, bounded timeouts and retry/error states. Same-origin securityOrigin permissions coalesce genuine system requests; denial is quiet. Old capture callbacks are denied once; capture is stopped on replacement/exit. No media-suspension counter or global audio configuration is introduced. Existing native audio release queue is drained before web loading. |
| F08 route | `TableSessionCoordinator` | Only coordinator commits A/B. No credentials means ordinary A; bad nonempty configuration is an error. First ready starts a cancellable three-second URL window; synchronous valid page reception cancels it. A commit excludes late startup page events. No A tab is installed beneath initial B preparation. |
| F09 purchase | `KitchenCoinPurchases.checkout/process → transaction.finish → KitchenAuthentication.confirm` | Single original SK2 consumer. Verified current checkout freezes source/profile/offer/reference. Real App receipt, never JWS. Finish precedes one bounded confirmation; Apple lock released before HTTP wait. Only 2xx + strict integer code 0 credits local coins once; realtime checkout reloads its web owner instead. No order Keychain or automatic order resubmission. |
| F10 theme | `KitchenThemeInbox.accept/drain/reconnect/flush` | Authenticated follower changes update followers; film safety updates a separate server-hidden set, preserving user hiding/blocking. Pending data, revisions, dedup and receipts persist atomically with account state. Stable receipt retries survive reconnect/foreground; transport ACK does not delete them, explicit backend ack does. Per-entity replay cursors avoid a guessed global revision. |
| F11 lifecycle | `signedOut/clearSession`, `becameActive`, `onOpenURL` | Session identity invalidates before cleanup. Device Keychain and historical wallet evidence retained. Bundle scheme only wakes the same owner, never asserts payment/auth success. WK callbacks, timers and notification consumers are isolated across sessions. |

Permission purpose declarations preserve valid existing camera/microphone copy and add the missing photo selection purpose in six languages. This does not add broad photo authorization requests. The Release URL scheme is `com.tatifood.kitchennotes`; APNs entitlements use development in Debug and production in Release. Actual Team/provisioning/APNs registration are not validated by source inspection.

## Backend and purchase boundaries

The success payment response is the platform's post-verification success structure. It **must only be used after actual Apple receipt/order verification and idempotent handling succeed**. Verification/order failures must return failure. This repository has no backend implementation and does not establish that the supplied deployment supports verification with and without a backend order reference. The client omits an absent reference and rejects an explicit invalid one. Actual verification, idempotency and both purchase entry paths remain unverified.

Cold startup freezes consumable transaction identities and releases verified terminal leftovers for at most ten seconds; late old callbacks cannot become a new checkout. Pending approval is not a transaction to finish. Unknown/nonconsumable types are not included. Old intent/credit evidence remains readable but is not used to automatically resubmit orders or infer a new account's ownership.

**Finishing before confirmation without automatic resubmission means interruption can leave a charged purchase without credited coins.** No old-order recovery promise is made. Wallet Purchase help directs unresolved payments to `hudden.serudiv22@gmail.com` with Apple order details. Account deletion/log-out and source matching remain distinct from Apple transaction release.

Theme events, receipts/acks and replay require a real authorized backend publisher. Their internal contract is in `generated/theme-event-protocol.json`; the console's four event slots do not deploy that service. Real live broadcasting, RTC, remote chat delivery, moderation/report processing and server wallet synchronization are not created by importing fixed display JSON. Existing truthful local/preview boundaries remain.

The native WebView can display backend-selected pages after authentication. App Review notes and privacy disclosures must describe those accessible pages and features; do not present remote behavior as a purely local food feed. User-provided agreement pages/links were retained unchanged as requested.

## Privacy and static evidence

Known new transmissions (installation/APNs identifiers, profile replay identifier, Apple transaction/receipt information) are declared for app functionality. The socket watchdog's local elapsed-time use declares `SystemBootTime / 35F9.1`; no boot-time value is transmitted. The declaration follows [Apple data-collection manifest guidance](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest) and [required-reason API guidance](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). Backend/web collection, retention and App Store privacy answers still require the operator's accurate service information.

Executed: XcodeGen generation, SPM dependency resolution only, JSON/plist/Python structural inspection, complete source-to-template/target/resource inspection and `git diff --check`. Offline reports: `static-inspection.json`, `Documentation/Kitchen-delivery-inspection.json`. Two older localization gaps around recipe timing/servings and missing proper-name entries were filled while restoring the inspector.

**Not executed:** Swift compilation/type-checking, unit/UI tests, App/simulator/device launch, screenshots, Duo posture transitions, API authentication/content calls, WebSocket connection, web loading/media/RTC, APNs registration, Apple transactions or backend verification. Static inspection does not establish compilation, real-service success or App Review approval.
