// Placeholder so static analysis can resolve web/index.html.
// Flutter writes the real loader to build/web/ when you run:
//   flutter run -d chrome
//   flutter build web
if (typeof window !== 'undefined' && !window._flutter?.buildConfig) {
  console.warn(
    'web/flutter_bootstrap.js is a source placeholder. Run flutter run -d chrome or flutter build web.',
  );
}
