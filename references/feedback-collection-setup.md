# Feedback collection setup

OneRemote sends in-app feedback with a **POST JSON** request to a Google Apps Script web app that appends rows to a **Google Sheet**. There is no email, external form, or other fallback channel in the app.

## Recommended: Google Sheet via Apps Script

**Deployed web app (OneRemote default):**

- Deployment ID: `AKfycbxx5TXjDYZ2hEl-IdqEGHB0Q776pVR90q2iIEFePRISOINcIfq9eoBKOjS87N2F-dlg`
- URL: `https://script.google.com/macros/s/AKfycbxx5TXjDYZ2hEl-IdqEGHB0Q776pVR90q2iIEFePRISOINcIfq9eoBKOjS87N2F-dlg/exec`

The app default in `FeedbackConfig.webhookUrl` points at this URL. Override per environment with `--dart-define=FEEDBACK_WEBHOOK_URL=...` if needed.

Opening the URL in a **browser** uses GET. You will see `Script function not found: doGet` until you add `doGet` below (harmless for the app; the app uses **POST** via `doPost`).

1. Create a Google Sheet with a tab named **`Feedback`** and header row: `submittedAt`, `category`, `platform`, `appVersion`, `message`.
2. Open **Extensions → Apps Script**, paste the script below, **Save**, then **Deploy → Manage deployments → Edit → New version → Deploy** (required after code changes).
3. Deploy as **Web app** → execute as **Me** → access **Anyone** (or **Anyone with Google account**).

Optional token: set Script property `FEEDBACK_TOKEN` and build with `--dart-define=FEEDBACK_WEBHOOK_TOKEN=...`.

```javascript
function doGet() {
  return ContentService.createTextOutput(
    'OneRemote feedback webhook is running. Submit feedback from the app (POST).'
  ).setMimeType(ContentService.MimeType.TEXT);
}

function doPost(e) {
  const token = PropertiesService.getScriptProperties().getProperty('FEEDBACK_TOKEN');
  if (token) {
    const headerToken = (e.parameter && e.parameter.token) ||
      (e.headers && (e.headers['X-Feedback-Token'] || e.headers['x-feedback-token']));
    if (headerToken !== token) {
      return jsonResponse({ ok: false, error: 'unauthorized' });
    }
  }
  const body = JSON.parse(e.postData.contents);
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Feedback');
  if (!sheet) {
    return jsonResponse({ ok: false, error: 'missing Feedback sheet tab' });
  }
  sheet.appendRow([
    body.submittedAt || '',
    body.category || '',
    body.platform || '',
    body.appVersion || '',
    body.message || '',
  ]);
  return jsonResponse({ ok: true });
}

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
```

## Production checklist

- [x] Default `FEEDBACK_WEBHOOK_URL` in app points at deployed Apps Script web app (override with dart-define if needed).
- [ ] Apps Script project has `doPost` + `Feedback` sheet tab; redeploy after script edits.
- [ ] Set `FEEDBACK_WEBHOOK_TOKEN` and validate it in the receiver.
- [ ] Privacy policy mentions that users may submit free-text feedback (no automatic log upload).

See also `references/compliance-and-release-requirements.md` §1.5.
