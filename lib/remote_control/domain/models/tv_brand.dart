enum TvBrand { samsung, lg, hisense, androidTv, roku, tcl }

extension TvBrandDisplay on TvBrand {
  String get displayName => switch (this) {
    TvBrand.samsung => 'Samsung',
    TvBrand.lg => 'LG',
    TvBrand.hisense => 'Hisense',
    TvBrand.androidTv => 'Android TV',
    TvBrand.roku => 'Roku TV',
    TvBrand.tcl => 'TCL',
  };
}
