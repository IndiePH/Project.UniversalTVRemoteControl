# Feedback collection setup

OneRemote sends in-app feedback with a **POST JSON** request to a Google Apps Script web app that appends rows to a **Google Sheet**. There is no email, external form, or other fallback channel in the app.

## Recommended: Google Sheet via Apps Script

**Deployed web app (OneRemote default):**

- Deployment ID: `AKfycbyYdrlh8oVk1BwA2w5xa6JGW0kPwGSRaSElpqmClz2VyfhPpEX3rRvT3oTPbcS8w4HTWQ`
- URL: `https://script.google.com/macros/s/AKfycbyYdrlh8oVk1BwA2w5xa6JGW0kPwGSRaSElpqmClz2VyfhPpEX3rRvT3oTPbcS8w4HTWQ/exec`

The app default in `FeedbackConfig.webhookUrl` points at this URL. Override per environment with `--dart-define=FEEDBACK_WEBHOOK_URL=...` if needed.

Opening the URL in a **browser** uses GET. You should see a short “webhook is running” message from `doGet` (harmless for the app; the app uses **POST** via `doPost`).

### Sheet tabs

Create these tabs in the spreadsheet bound to the script:

| Tab | Purpose |
|-----|---------|
| **Setup** | Operator notes (spam rules, archive, redeploy) — paste content from [Setup tab text](#setup-tab-text) below |
| **Feedback** | **Only tab the script writes to** — canonical ingest (11 columns) |
| **Bugs** | Read-only `FILTER` view: `category = bug` |
| **Suggestions** | Read-only `FILTER` view: `category = suggestion` |
| **Other** | Read-only `FILTER` view: `category = other` |
| **Archive_YYYY_MM** | Optional monthly copies (manual archive; see [Monthly archive](#monthly-archive)) |

### Feedback header row

Row 1 on **Feedback** (script creates this if the tab is empty):

`id`, `receivedAt`, `submittedAt`, `date`, `category`, `platform`, `appVersion`, `versionMajor`, `messageLength`, `spam`, `message`

| Column | Source |
|--------|--------|
| `id` | Script UUID per row |
| `receivedAt` | Server ingest time (ISO UTC) |
| `submittedAt` | Client `body.submittedAt` |
| `date` | `yyyy-MM-dd` from `receivedAt` (quick date filter) |
| `category` | Normalized: `suggestion` \| `bug` \| `other` |
| `platform` | Client, trimmed |
| `appVersion` | Client |
| `versionMajor` | Parsed from `appVersion` (e.g. `1.2.3` from `1.2.3+4`) |
| `messageLength` | Character count after trim |
| `spam` | Heuristic `yes` \| `no` — **never blocks ingest**; filter manually in Sheets |
| `message` | Client text (trimmed, max 2000) |

### Category view formulas

On each view tab, put the formula in **cell A1** (headers flow from **Feedback** row 1):

| Tab | Cell A1 formula |
|-----|-----------------|
| **Bugs** | `=FILTER(Feedback!A:K, Feedback!E:E="bug")` |
| **Suggestions** | `=FILTER(Feedback!A:K, Feedback!E:E="suggestion")` |
| **Other** | `=FILTER(Feedback!A:K, Feedback!E:E="other")` |

Do not let operators edit these tabs for data entry — only **Feedback** receives POST rows.

### Quick setup

1. Create the tabs above; paste [Setup tab text](#setup-tab-text) into **Setup**.
2. Open **Extensions → Apps Script**, paste the [script](#apps-script) below, **Save**, then **Deploy → Manage deployments → Edit → New version → Deploy** (required after every code change).
3. Deploy as **Web app** → execute as **Me** → access **Anyone** (or **Anyone with Google account**).
4. Run the [smoke test](#smoke-test-curl) and confirm a row appears with `id` and `spam`.

Optional Script properties ( **Project settings → Script properties** ):

| Property | Purpose |
|----------|---------|
| `FEEDBACK_TOKEN` | Shared secret; app sends `X-Feedback-Token` when built with `--dart-define=FEEDBACK_WEBHOOK_TOKEN=...` |
| `SPAM_KEYWORDS` | Optional comma-separated blocklist (case-insensitive substring match on message) |

### Setup tab text

Paste into the **Setup** tab:

```
OneRemote feedback ingest
- Script writes ONLY to the Feedback tab.
- Bugs / Suggestions / Other are FILTER views — do not edit those for data entry.
- Redeploy web app after every Apps Script edit (Manage deployments → New version → Deploy).

Spam column (yes/no) — heuristic only; all valid submissions are stored:
- Duplicate message fingerprint within 6 hours → yes
- messageLength < 10 → yes
- More than 3 URLs in message → yes
- >80% uppercase letters (message length ≥ 20) → yes
- SPAM_KEYWORDS script property match → yes
Filter spam=yes in Feedback when triaging.

Suggested Sheet filters: date, category, platform, versionMajor, spam.
At ~3k+ rows/day: monthly archive (see feedback-collection-setup.md § Monthly archive).
```

## Apps Script

```javascript
var FEEDBACK_SHEET_NAME = 'Feedback';
var FEEDBACK_HEADERS = [
  'id', 'receivedAt', 'submittedAt', 'date', 'category', 'platform',
  'appVersion', 'versionMajor', 'messageLength', 'spam', 'message'
];
var MAX_MESSAGE_LENGTH = 2000;
var MIN_MESSAGE_LENGTH = 10;
var VALID_CATEGORIES = { suggestion: true, bug: true, other: true };
var DUPLICATE_CACHE_PREFIX = 'fb_dup:';
var DUPLICATE_CACHE_TTL_SEC = 21600; // 6 hours

function doGet() {
  return ContentService.createTextOutput(
    'OneRemote feedback webhook is running. Submit feedback from the app (POST).'
  ).setMimeType(ContentService.MimeType.TEXT);
}

function doPost(e) {
  if (!authorizeRequest_(e)) {
    return jsonResponse({ ok: false, error: 'unauthorized' });
  }

  var body;
  try {
    body = JSON.parse(e.postData.contents);
  } catch (err) {
    return jsonResponse({ ok: false, error: 'invalid json' });
  }

  var normalized = normalizeBody_(body);
  if (normalized.error) {
    return jsonResponse({ ok: false, error: normalized.error });
  }

  var sheet = ensureFeedbackSheet_();
  if (!sheet) {
    return jsonResponse({ ok: false, error: 'missing Feedback sheet tab' });
  }

  var receivedAt = new Date();
  var rowId = Utilities.getUuid();
  var spam = computeSpam_(normalized.message, normalized.messageLength);
  var row = [
    rowId,
    receivedAt.toISOString(),
    normalized.submittedAt,
    formatDateYmd_(receivedAt),
    normalized.category,
    normalized.platform,
    normalized.appVersion,
    parseVersionMajor_(normalized.appVersion),
    normalized.messageLength,
    spam,
    normalized.message
  ];

  sheet.appendRow(row);
  return jsonResponse({ ok: true, id: rowId });
}

function authorizeRequest_(e) {
  var token = PropertiesService.getScriptProperties().getProperty('FEEDBACK_TOKEN');
  if (!token) {
    return true;
  }
  var headerToken = (e.parameter && e.parameter.token) ||
    (e.headers && (e.headers['X-Feedback-Token'] || e.headers['x-feedback-token']));
  return headerToken === token;
}

function normalizeBody_(body) {
  var message = String(body.message || '').trim();
  if (!message) {
    return { error: 'empty message' };
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return { error: 'message too long' };
  }

  var category = String(body.category || '').trim().toLowerCase();
  if (!VALID_CATEGORIES[category]) {
    category = 'other';
  }

  return {
    message: message,
    messageLength: message.length,
    category: category,
    platform: String(body.platform || '').trim(),
    appVersion: String(body.appVersion || '').trim(),
    submittedAt: String(body.submittedAt || '').trim()
  };
}

function computeSpam_(message, messageLength) {
  if (messageLength < MIN_MESSAGE_LENGTH) {
    return 'yes';
  }
  if (isDuplicateMessage_(message)) {
    return 'yes';
  }
  if (countUrls_(message) > 3) {
    return 'yes';
  }
  if (isMostlyUppercase_(message)) {
    return 'yes';
  }
  if (matchesSpamKeywords_(message)) {
    return 'yes';
  }
  return 'no';
}

function isDuplicateMessage_(message) {
  var cache = CacheService.getScriptCache();
  var key = DUPLICATE_CACHE_PREFIX + messageFingerprint_(message);
  var existing = cache.get(key);
  cache.put(key, '1', DUPLICATE_CACHE_TTL_SEC);
  return existing !== null;
}

function messageFingerprint_(message) {
  var normalized = String(message)
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
  var digest = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    normalized,
    Utilities.Charset.UTF_8
  );
  return digest.map(function (byte) {
    var v = (byte < 0) ? byte + 256 : byte;
    return ('0' + v.toString(16)).slice(-2);
  }).join('');
}

function countUrls_(message) {
  var matches = String(message).match(/https?:\/\/[^\s]+/gi);
  return matches ? matches.length : 0;
}

function isMostlyUppercase_(message) {
  if (message.length < 20) {
    return false;
  }
  var letters = message.replace(/[^A-Za-z]/g, '');
  if (letters.length < 20) {
    return false;
  }
  var upper = letters.replace(/[^A-Z]/g, '').length;
  return upper / letters.length > 0.8;
}

function matchesSpamKeywords_(message) {
  var raw = PropertiesService.getScriptProperties().getProperty('SPAM_KEYWORDS');
  if (!raw) {
    return false;
  }
  var lower = String(message).toLowerCase();
  var parts = raw.split(',');
  for (var i = 0; i < parts.length; i++) {
    var keyword = parts[i].trim().toLowerCase();
    if (keyword && lower.indexOf(keyword) !== -1) {
      return true;
    }
  }
  return false;
}

function parseVersionMajor_(appVersion) {
  var match = String(appVersion).match(/(\d+(?:\.\d+){0,2})/);
  return match ? match[1] : '';
}

function formatDateYmd_(date) {
  return Utilities.formatDate(date, 'UTC', 'yyyy-MM-dd');
}

function ensureFeedbackSheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(FEEDBACK_SHEET_NAME);
  if (!sheet) {
    return null;
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(FEEDBACK_HEADERS);
    return sheet;
  }
  var firstRow = sheet.getRange(1, 1, 1, FEEDBACK_HEADERS.length).getValues()[0];
  var needsHeader = false;
  for (var i = 0; i < FEEDBACK_HEADERS.length; i++) {
    if (firstRow[i] !== FEEDBACK_HEADERS[i]) {
      needsHeader = true;
      break;
    }
  }
  if (needsHeader && sheet.getLastRow() === 1 && !firstRow[0]) {
    sheet.getRange(1, 1, 1, FEEDBACK_HEADERS.length).setValues([FEEDBACK_HEADERS]);
  }
  return sheet;
}

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
```

## Migration (existing 5-column Feedback tab)

If you already ingest into the old schema (`submittedAt`, `category`, `platform`, `appVersion`, `message`):

1. **Option A — fresh tab:** Rename the current tab to `Feedback_legacy`. Create a new **Feedback** tab; leave row 1 empty (the script writes headers on first POST) or paste the [11-column header row](#feedback-header-row).
2. **Option B — in place:** Insert new columns so the header matches the 11-column layout; map old columns into the new positions or leave legacy rows as-is (view `FILTER` formulas expect the new header on row 1 for new data).
3. Paste the [script](#apps-script) above → **Deploy → New version → Deploy**.
4. Add **Bugs** / **Suggestions** / **Other** `FILTER` formulas from [Category view formulas](#category-view-formulas).
5. Run the [smoke test](#smoke-test-curl).

Legacy rows remain readable on `Feedback_legacy` or misaligned rows; new POSTs use the full schema.

## Monthly archive

At sustained high volume (~3k+ rows/day), keep **Feedback** responsive:

1. Each month, copy all data rows (not necessarily the header) to a new tab `Archive_YYYY_MM` (e.g. `Archive_2026_05`).
2. Delete archived body rows from **Feedback** (keep row 1 headers).
3. **FILTER** views update automatically from **Feedback**.

Optional later: add a time-driven Apps Script trigger that copies rows older than N days — not required for initial rollout.

## Smoke test (curl)

Replace `YOUR_DEPLOYMENT_URL` and, if configured, `YOUR_TOKEN`.

```bash
curl -sS -X POST "YOUR_DEPLOYMENT_URL" \
  -H "Content-Type: application/json" \
  -H "X-Feedback-Token: YOUR_TOKEN" \
  -d "{\"submittedAt\":\"2026-05-21T12:00:00.000Z\",\"category\":\"bug\",\"platform\":\"android\",\"appVersion\":\"1.0.0+1\",\"message\":\"Smoke test from curl — layout editor freezes.\"}"
```

Expected JSON: `{"ok":true,"id":"<uuid>"}`.

Verify on **Feedback**:

- New row with `id`, `date`, `versionMajor` = `1.0.0`, `spam` = `no`.
- **Bugs** tab shows the row; **Suggestions** / **Other** do not.

Send the **same message** again within 6 hours: row is still stored, `spam` = `yes`.

## Production checklist

- [x] Default `FEEDBACK_WEBHOOK_URL` in app points at deployed Apps Script web app (override with dart-define if needed).
- [ ] Sheet has **Feedback** ingest tab + **Bugs** / **Suggestions** / **Other** view tabs with `FILTER` formulas.
- [ ] Apps Script uses enriched `doPost` (11 columns + `spam` heuristic); **redeploy web app** after every script edit (**Deploy → New version → Deploy**).
- [ ] Smoke test (curl) returns `ok: true` and populates `id` + `spam` on **Feedback**.
- [ ] Set `FEEDBACK_WEBHOOK_TOKEN` / Script property `FEEDBACK_TOKEN` and validate unauthorized POST is rejected.
- [ ] Privacy policy mentions that users may submit free-text feedback (no automatic log upload).

See also `references/compliance-and-release-requirements.md` §1.5.
