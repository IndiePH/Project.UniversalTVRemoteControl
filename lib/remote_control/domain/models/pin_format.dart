enum PinFormat {
  fourDigitNumeric,
  sixCharHex,

  /// No fixed length/charset — Sony BRAVIA's `actRegister` PIN is validated
  /// entirely server-side (confirmed via `pybravia` and Home Assistant's
  /// `braviatv` config flow, neither of which constrain it client-side).
  freeform,
}
