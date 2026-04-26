import 'package:one_remote/remote_control/domain/models/tv_brand.dart';

abstract interface class PrePairingStepsRegistry {
  List<String>? stepsFor(TvBrand brand, String protocolVariant);
}
