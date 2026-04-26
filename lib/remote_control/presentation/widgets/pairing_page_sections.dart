import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page_data.dart';
import 'package:one_remote/theme/app_theme.dart';

/// Busy overlay shown while waiting for TV-side pairing confirmation.
class PairingBusyOverlay extends StatelessWidget {
  const PairingBusyOverlay({
    super.key,
    required this.visible,
    this.hint,
  });

  final bool visible;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    final appColors = AppTheme.colorsOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: ModalBarrier(
            dismissible: false,
            color: appColors.pairingModalBarrier,
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: appColors.remoteRaisedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: appColors.remoteOutline, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: appColors.pairingBusyOnCard,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Waiting for TV approval...',
                      style: TextStyle(
                        color: appColors.pairingBusyOnCard,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (hint != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: appColors.pairingBusyOnCard,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Section heading for the Remote Selection grouped list.
class RemoteSelectionSectionHeader extends StatelessWidget {
  const RemoteSelectionSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleSmall);
  }
}

/// Paired TV row — swipe left (endToStart) to reveal Delete.
///
/// [onConfirmDismiss] must always return false; visual removal is driven by
/// the parent list rebuilding after the underlying state update.
class PairedTvListItem extends StatefulWidget {
  const PairedTvListItem({
    super.key,
    required this.device,
    required this.pairingNote,
    required this.reachabilityService,
    required this.onConfirmDismiss,
    required this.onRename,
    required this.onTap,
  });

  final TvDevice device;
  final String? pairingNote;
  final TvReachabilityService reachabilityService;
  final Future<bool?> Function(DismissDirection) onConfirmDismiss;
  final VoidCallback onRename;
  final VoidCallback onTap;

  @override
  State<PairedTvListItem> createState() => _PairedTvListItemState();
}

class _PairedTvListItemState extends State<PairedTvListItem> {
  late final Future<bool> _reachableFuture;

  @override
  void initState() {
    super.initState();
    _reachableFuture = widget.reachabilityService.isReachable(widget.device);
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.device.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: widget.onConfirmDismiss,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Theme.of(context).colorScheme.surface,
        title: Text(
          widget.device.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          widget.pairingNote ?? widget.device.brand.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<bool>(
              future: _reachableFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  );
                }
                return Icon(
                  snapshot.data! ? Icons.wifi : Icons.wifi_off,
                  size: 18,
                  color: snapshot.data!
                      ? Colors.green
                      : Theme.of(context).disabledColor,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              iconSize: 18,
              tooltip: 'Rename',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onRename,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}

/// Available (scan result) TV row — tap to begin pairing.
class AvailableTvListItem extends StatelessWidget {
  const AvailableTvListItem({
    super.key,
    required this.device,
    required this.pairingNote,
    required this.onTap,
  });

  final TvDevice device;
  final String? pairingNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surface,
      title: Text(device.displayName),
      subtitle: pairingNote == null
          ? Text(device.brand.displayName)
          : Text('${device.brand.displayName} • $pairingNote'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Onboarding and fallback hints for discovery/pairing failures.
class PairingTroubleshootingGuidanceSection extends StatelessWidget {
  const PairingTroubleshootingGuidanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Need help finding your TV?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: ExpansionTile(
            title: const Text('Permission and network checklist'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '- Keep phone and TV on the same Wi-Fi network.\n'
                '- Allow local network/Wi-Fi permissions when prompted.\n'
                '- Disable client/AP isolation on your router if enabled.',
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            title: const Text('Cannot find TV? Try this'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '- Run Scan for TVs again and wait a few seconds.\n'
                '- Use Add Manually with the TV IP address.\n'
                '- Restart TV network, then re-open the pairing screen.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Manual brand/IP pairing form with recent IP shortcuts.
class PairingManualAddSection extends StatelessWidget {
  const PairingManualAddSection({
    super.key,
    required this.manualBrand,
    required this.manualIpController,
    required this.manualErrorMessage,
    required this.recentManualIps,
    required this.onManualBrandChanged,
    required this.onManualIpChanged,
    required this.onRecentIpSelected,
    required this.onAddManualDevice,
  });

  final TvBrand manualBrand;
  final TextEditingController manualIpController;
  final String? manualErrorMessage;
  final List<String> recentManualIps;
  final void Function(TvBrand brand) onManualBrandChanged;
  final VoidCallback onManualIpChanged;
  final void Function(String ip) onRecentIpSelected;
  final VoidCallback onAddManualDevice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Manual Pairing', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<TvBrand>(
          initialValue: manualBrand,
          decoration: const InputDecoration(
            labelText: 'TV brand',
            border: OutlineInputBorder(),
          ),
          items: TvBrand.values
              .map(
                (brand) => DropdownMenuItem<TvBrand>(
                  value: brand,
                  child: Text(brand.displayName),
                ),
              )
              .toList(),
          onChanged: (brand) {
            if (brand == null) {
              return;
            }
            onManualBrandChanged(brand);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: manualIpController,
          decoration: const InputDecoration(
            labelText: 'TV IP address',
            hintText: 'e.g. 192.168.1.20',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => onManualIpChanged(),
        ),
        if (recentManualIps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recentManualIps
                .map(
                  (ip) => ActionChip(
                    label: Text(ip),
                    onPressed: () => onRecentIpSelected(ip),
                  ),
                )
                .toList(),
          ),
        ],
        if (manualErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            manualErrorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        PairingActionButton(label: 'Add Manually', onPressed: onAddManualDevice),
      ],
    );
  }
}

/// Modal bottom sheet wrapping [PairingManualAddSection] with self-contained state.
///
/// Owns brand selection, IP input, and validation error — the parent page only
/// provides the recent-IP list and an async callback to initiate pairing.
class PairingManualAddSheet extends StatefulWidget {
  const PairingManualAddSheet({
    super.key,
    required this.recentManualIps,
    required this.onAdd,
  });

  final List<String> recentManualIps;
  final Future<void> Function(TvBrand brand, String ip) onAdd;

  @override
  State<PairingManualAddSheet> createState() => _PairingManualAddSheetState();
}

class _PairingManualAddSheetState extends State<PairingManualAddSheet> {
  final TextEditingController _ipController = TextEditingController();
  TvBrand _brand = TvBrand.samsung;
  String? _errorMessage;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() => _errorMessage = 'Enter a TV IP address.');
      return;
    }
    if (!PairingPageData.isValidIpv4(ip)) {
      setState(() =>
          _errorMessage = 'Enter a valid IPv4 address (e.g. 192.168.1.20).');
      return;
    }
    setState(() => _errorMessage = null);
    await widget.onAdd(_brand, ip);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: PairingManualAddSection(
          manualBrand: _brand,
          manualIpController: _ipController,
          manualErrorMessage: _errorMessage,
          recentManualIps: widget.recentManualIps,
          onManualBrandChanged: (brand) => setState(() => _brand = brand),
          onManualIpChanged: () {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          onRecentIpSelected: (ip) => setState(() {
            _ipController.text = ip;
            _errorMessage = null;
          }),
          onAddManualDevice: _submit,
        ),
      ),
    );
  }
}

class PairingActionButton extends StatelessWidget {
  const PairingActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
