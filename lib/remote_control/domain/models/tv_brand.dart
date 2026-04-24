enum TvBrand {
  samsung,
  lg,
  hisense,
}

extension TvBrandDisplay on TvBrand {
  String get displayName => switch (this) {
    TvBrand.samsung => 'Samsung',
    TvBrand.lg => 'LG',
    TvBrand.hisense => 'Hisense',
  };
}
