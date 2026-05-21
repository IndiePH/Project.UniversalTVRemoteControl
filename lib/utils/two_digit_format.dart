/// Converts numbers to two-character strings (e.g. `3` -> `03`).
String formatTwoDigits(int value) => value.toString().padLeft(2, '0');
