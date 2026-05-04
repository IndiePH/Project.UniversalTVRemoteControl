enum TvBrand {
  samsung,
  lg,
  hisense,
  androidTv,
}

extension TvBrandDisplay on TvBrand {
  String get displayName => switch (this) {
    TvBrand.samsung => 'Samsung',
    TvBrand.lg => 'LG',
    TvBrand.hisense => 'Hisense',
    TvBrand.androidTv => 'Android TV',
  };
}
