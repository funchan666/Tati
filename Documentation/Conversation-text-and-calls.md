# Text conversation and call actions — 2026-10-22

## Requested surface

`ConversationView` is now a text-only private-chat composer. The voice-message, photo attachment and gift controls and their presentation states were removed. The old ambiguous toolbar follow/add control was replaced by separately labelled Voice call and Video call actions; following remains available in the person's linked profile.

The header and keyboard-aware composer use warm apricot surfaces over a cream conversation background. Incoming bubbles are white; outgoing bubbles use olive with cream text, with time/outbox state outside the bubble. Empty conversations show Tati's original message illustration and an accurate reciprocal-follow explanation. There is no fabricated online state, delivery receipt or conversation history.

The original two-cell `conversation-call-icons` atlas was generated with the built-in image tool in Garden Host-Native mode. It contains a cream/olive/pink telephone receiver and video camera on transparent alpha (1774 × 887). Original generated output was copied into the project without overwriting another asset. The app only crops the cells for display; it draws no replacement icons in code.

## Behavior and boundaries

Both call buttons preserve `requireMutualFollow`. Voice call opens `VoiceCallView` with the genuine microphone permission flow and a Settings recovery action after denial. It does not activate audio capture, recording or an audio session. Video call retains the existing asynchronous local camera preparation flow, adds Settings recovery for denied capture permissions, and stops capture on dismissal, backgrounding or relationship/account invalidation. Both surfaces clearly state that remote calls are not connected. No RTC transport, remote ringing, call duration, connection success or recipient notification was fabricated.

`attemptMessage` has one caller: this text composer. It now requires nonempty text and never reads/attaches a legacy photo draft. A failed save retains text. Existing image messages remain readable, and historical photo draft files remain referenced without being attached or silently deleted. The conversation-list draft check uses text only. Outbox entries retain the real `Waiting to send` status; this change does not add a remote messaging transport.

Personal-message report/block controls remain available. Text drafts still use the existing coalesced persistence and flush before a call/when leaving. Width changes retain input and presentation state. Controls remain inside the safe area, only background colors extend. At accessibility text sizes, call actions stack and collapse during typing to preserve input space; the text composer caps visible lines while remaining internally scrollable.

Twenty call/chat labels, permission states and recovery descriptions have English, Simplified Chinese, Spanish, French, German and Japanese translations.

## Static verification

Performed: source/caller and diff review; original artwork/atlas alpha and aspect inspection; JSON and six-language completeness checks; checks that attachment/gift/voice-message controls are absent from the conversation and that the text send path does not consume draft images.

Not performed: compilation, tests, app launch, native rendered-screen review, permission prompts on a device, camera/microphone hardware, actual keyboard/Dynamic Type/Duo postures or remote calls/messages. Remote communication remains unavailable without its service integration.
