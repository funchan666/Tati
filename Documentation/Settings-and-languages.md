# Settings and language behavior

Updated: 2026-10-21. Native SwiftUI implementation; static inspection only.

## Settings actions

| Entry | Implemented behavior |
| --- | --- |
| Blacklist | Lists every persisted blocked ID, including profiles no longer present in the content catalogue. Unblocking requires confirmation, persists the change and refreshes the list. It does not create follows or erase independent reports. |
| Privacy / user agreement | Opens the existing policy URL in WKWebView. Loading, transport errors and main-document HTTP errors have explicit states. Retry reloads the document; the failure screen also offers the browser. Existing remote legal text is not rewritten or translated by the client. |
| Delete profile | Confirms permanent removal of local profile data, imported media, drafts and coin balance. Reports file-cleanup failure. Retains transaction ownership, credits and processed transaction evidence, preventing old transactions from being credited to a new profile. Preserves the interface language. Active Apple purchases prevent deletion. |
| Log out | Confirms, persists signed-out state, preserves saved account data and stops media through the existing root lifecycle. Active Apple purchases prevent logout. |
| Language | English, Simplified Chinese, Spanish, French, German, Japanese, plus system default. Defaults to English when no preference is saved or the saved value is unsupported. Explicit language choices, including system default, remain unchanged. Saves stable codes through the existing atomic account writer and updates SwiftUI locale without rebuilding the navigation tree or clearing inputs. Legacy language display-name preferences are resolved. |
| Notifications | Explicitly offers daily check-in reminders at 19:00 device-local time, then requests genuine iOS authorization. Permission denial offers iPhone Settings. Uses one stable local notification ID to replace rather than duplicate reminders. Switching off, signing out or deleting the profile cancels the reminder. Foreground refresh reconciles revoked permissions; language changes update notification text. |

## Localization scope

`Tati/Resources/Localizable.xcstrings` contains 234 interface keys, each with all six translations. Coverage includes the settings flow and its confirmation/error states, shared navigation/buttons/empty states, report reasons, common browsing categories, profile editing labels and the food-expert introduction/prompts. Shared components treat interface strings as localization keys. User names, messages, captions and other user-authored content retain their original text.

Original raster logos/artwork and externally hosted legal pages retain their original language. This is not a claim that all long-form help, commerce and every feature-specific message has been translated: keys absent from the catalogue fall back to source English. The language-help article and its search text now reflect the implemented switch.

## Service boundaries

- The current account implementation is local. Delete profile removes the current local account; there is no server account-deletion endpoint in this project to call.
- Notifications are real scheduled **local** reminders. There is no APNs/server notification integration or fabricated message notification.
- Policy URLs remain `https://sites.google.com/view/tutu-terms-of-service/foodd` and `https://sites.google.com/view/tati-privacypolicy/foodd`. The web lookup could not retrieve them during this pass; their availability and legal content were not confirmed. No replacement legal URL was invented.

## Static verification

Inspected persistence, permission handling, profile ownership across asynchronous permission requests, serialized scheduling, cancellation, resource references and changes to purchase-evidence retention. Parsed the string catalogue and checked six-language coverage, nonempty values and format-placeholder consistency. Plist and Xcode project syntax inspections and `git diff --check` passed.

No compilation, tests, simulator/device sessions, actual permission requests, notification delivery, StoreKit transactions or live in-app policy navigation were run.

Runtime follow-up when authorized: change each language on the language page and return through navigation; restart and verify persistence; cancel/confirm logout and deletion; verify blacklist removal with a separately reported profile; grant/deny/revoke notifications and verify one 19:00 reminder, language replacement, cancellation on logout/deletion; load/retry both policy pages.

## Apple references

- [Requesting notification authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Preparing SwiftUI views for localization](https://developer.apple.com/documentation/swiftui/preparing-views-for-localization)
- [LocalizedStringKey](https://developer.apple.com/documentation/swiftui/localizedstringkey)
