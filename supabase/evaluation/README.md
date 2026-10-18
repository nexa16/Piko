# Synthetic language activation check

The cases are invented test content, not user vocabulary or research. Run both
tasks for every pair through the prepared authenticated backend, using its usual
admission and cost accounting, only after account/checkout/deployment approval.
Respect the two-per-minute limit; do not add a paid retry loop.

Record the source/configuration, actual model/tier/usage, case/task, result and
manual assessment in private evidence. Do not store tokens or add application
prompt/result history. No evaluation has passed merely because these cases or
deterministic fixtures exist.

For each example, check the intended meaning (including the specified sense of
ambiguous words), grammatical naturalness, correct languages and faithful sentence
translation. Ordinary inflection of the target lemma is acceptable. For each Hint,
check that it is short, in the native language, useful and does not merely repeat
the answer. Reject refusals, incorrect meaning, mixed languages, malformed data,
unexpected instructions or overlong responses. Investigate any failed case and
repeat affected cases before approving quality. Verify actual Android review/use
and manual editing as well as the language sample. Keep public access disabled
until the review is recorded and deployment acceptance is complete.

Check the shared meaning of **both** supplied texts. For `bank` / `Bank`, a
financial institution is valid; an English river bank translated as `Ufer` is not.
A clue about a park bench is also wrong for the English word, even though German
`Bank` has that additional meaning. For `Schloss` / `castle`, reject the lock sense.
Keep syntactically valid but semantically wrong responses as failed quality cases;
successful HTTP/JSON validation alone does not pass this gate.
For `길` / `path`, the English Hint must not quote the Korean word; a partly
English definition such as `A 길 is ...` fails the native-language-only check.
