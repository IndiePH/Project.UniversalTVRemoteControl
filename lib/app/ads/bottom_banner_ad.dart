import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Anchored adaptive banner shown at the bottom of the remote.
///
/// Renders nothing until the ad is fully loaded so the layout does not reserve
/// an empty placement bar while sizing/fetching is in flight.
class BottomBannerAd extends StatefulWidget {
  const BottomBannerAd({super.key, required this.adUnitId});

  final String adUnitId;

  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

class _BottomBannerAdState extends State<BottomBannerAd> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoaded = false;
  int _lastKnownWidth = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAdaptiveBannerIfNeeded();
  }

  Future<void> _loadAdaptiveBannerIfNeeded() async {
    final availableWidth = MediaQuery.sizeOf(context).width.truncate();
    if (availableWidth <= 0 || availableWidth == _lastKnownWidth) {
      return;
    }

    final previousBanner = _bannerAd;
    if (mounted) {
      setState(() {
        _isLoaded = false;
        _bannerAd = null;
        _adSize = null;
      });
    }
    await previousBanner?.dispose();

    _lastKnownWidth = availableWidth;
    final adaptiveSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      availableWidth,
    );
    if (!mounted || adaptiveSize == null) {
      return;
    }

    final bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: adaptiveSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _bannerAd = null;
            _adSize = null;
            _isLoaded = false;
          });
        },
      ),
    );

    setState(() {
      _bannerAd = bannerAd;
      _adSize = adaptiveSize;
      _isLoaded = false;
    });
    bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    final adSize = _adSize;

    if (!_isLoaded || ad == null || adSize == null) {
      return const SizedBox.shrink();
    }

    final width = adSize.width.toDouble();
    final height = adSize.height.toDouble();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
