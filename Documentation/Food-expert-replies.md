# Built-in food replies

2026-10-22. The food-expert screen now provides authored cooking suggestions instead of the question-saved/unavailable dialog.

- Seven topic-specific replies cover crisping, plating, flavour balance, pasta, quick dinners, baking and vegetables. Questions are matched against supported-language keywords. Unmatched questions receive a clear invitation to choose a supported topic.
- The introduction labels the feature Built-in food tips. There is no external AI service, model inference, invented network progress or transmission of the question.
- Questions appear immediately; a chef-art status appears for approximately 1.05–1.55 seconds before revealing the selected reply. This is an asynchronous presentation delay and does not block the main thread. Repeated submissions are disabled while a reply is pending.
- The question is saved before clearing the composer. The reply then uses the existing verified account writer. An optional account field preserves compatibility with saved accounts from earlier versions; only the latest 40 exchanges are retained.
- Pending work is cancelled when the screen disappears or the scene becomes inactive. Returning resumes any saved pending question. The completion checks the account owner and exchange ID and cannot append duplicate replies or write into a newly created profile. Account deletion clears the exchanges through the existing account reset.
- Existing question drafts are restored into the input. Typing uses the existing coalesced draft saver, and failed saves retain the input. Storage failures during reply completion display an explicit recovery message.
- All new answer and status strings have English, Simplified Chinese, Spanish, French, German and Japanese translations. User questions retain their entered language. Prompt shortcuts use the selected app language.
- Conversation bubbles retain the existing original artwork, native text wrapping and container sizing. Status motion respects Reduce Motion and pauses outside the active scene; lazy rows limit long-history layout work.

Static review covered persistence ordering, account ownership, cancellation, duplicate submission/completion guards, original asset references and six-language answer coverage. JSON parsing and git diff --check passed. No compilation, tests, application launch, simulator/device checks or live AI requests were run.
