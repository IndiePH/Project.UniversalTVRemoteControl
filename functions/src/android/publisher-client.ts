import { google, androidpublisher_v3 } from 'googleapis';

let androidPublisherClient: androidpublisher_v3.Androidpublisher | null = null;

export function getAndroidPublisherClient(): androidpublisher_v3.Androidpublisher {
  if (androidPublisherClient == null) {
    // Reuse one client per function instance; GoogleAuth caches ADC tokens.
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    androidPublisherClient = google.androidpublisher({
      version: 'v3',
      auth,
    });
  }
  return androidPublisherClient;
}
