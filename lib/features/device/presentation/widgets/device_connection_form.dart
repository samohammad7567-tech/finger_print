import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/device_settings_model.dart';
import '../cubit/device_cubit.dart';

/// Where the terminal lives and how to talk to it.
class DeviceConnectionForm extends StatefulWidget {
  const DeviceConnectionForm({super.key, required this.settings});

  final DeviceSettingsModel settings;

  @override
  State<DeviceConnectionForm> createState() => _DeviceConnectionFormState();
}

class _DeviceConnectionFormState extends State<DeviceConnectionForm> {
  late final TextEditingController _ip;
  late final TextEditingController _port;
  late final TextEditingController _commKey;

  late bool _useTcp;
  late bool _skipPing;
  late bool _importEmployees;
  late bool _liveSync;
  late int _autoSyncMinutes;

  static const _intervals = [0, 5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _ip = TextEditingController(text: widget.settings.ip);
    _port = TextEditingController(text: '${widget.settings.port}');
    _commKey = TextEditingController(text: widget.settings.commKey);
    _useTcp = widget.settings.useTcp;
    _skipPing = widget.settings.skipPing;
    _importEmployees = widget.settings.importEmployees;
    _liveSync = widget.settings.liveSync;
    _autoSyncMinutes = widget.settings.autoSyncMinutes;
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    _commKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LangKeys.deviceConnection.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _label(LangKeys.deviceIp.tr()),
          AppTextField(
            controller: _ip,
            hint: LangKeys.deviceIpHint.tr(),
            prefixIcon: Icons.lan,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 10),
          _label(LangKeys.devicePort.tr()),
          AppTextField(
            controller: _port,
            prefixIcon: Icons.numbers,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          _label(LangKeys.deviceCommKey.tr()),
          AppTextField(
            controller: _commKey,
            hint: LangKeys.deviceCommKeyHint.tr(),
            prefixIcon: Icons.key,
            obscureText: true,
          ),
          const SizedBox(height: 8),
          _toggle(
            title: LangKeys.deviceUseTcp.tr(),
            subtitle: LangKeys.deviceUseTcpHint.tr(),
            value: _useTcp,
            onChanged: (v) => setState(() => _useTcp = v),
          ),
          _toggle(
            title: LangKeys.deviceSkipPing.tr(),
            subtitle: LangKeys.deviceSkipPingHint.tr(),
            value: _skipPing,
            onChanged: (v) => setState(() => _skipPing = v),
          ),
          _toggle(
            title: LangKeys.deviceLiveSync.tr(),
            subtitle: LangKeys.deviceLiveSyncHint.tr(),
            value: _liveSync,
            onChanged: (v) => setState(() => _liveSync = v),
          ),
          _toggle(
            title: LangKeys.deviceImportEmployees.tr(),
            subtitle: LangKeys.deviceImportEmployeesHint.tr(),
            value: _importEmployees,
            onChanged: (v) => setState(() => _importEmployees = v),
          ),
          const SizedBox(height: 8),
          _label(LangKeys.deviceAutoSync.tr()),
          Wrap(spacing: 8, children: _intervals.map(_intervalChip).toList()),
          const SizedBox(height: 16),
          AppPrimaryButton(
            onPressed: _save,
            label: LangKeys.deviceSaveSettings.tr(),
            icon: Icons.save,
          ),
        ],
      ),
    );
  }

  Widget _intervalChip(int minutes) {
    return ChoiceChip(
      label: Text(
        minutes == 0
            ? LangKeys.deviceAutoSyncOff.tr()
            : LangKeys.deviceEveryMinutes.tr(args: ['$minutes']),
        style: const TextStyle(fontSize: 11),
      ),
      selected: _autoSyncMinutes == minutes,
      onSelected: (_) => setState(() => _autoSyncMinutes = minutes),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );

  Widget _toggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  void _save() {
    FocusScope.of(context).unfocus();
    context.read<DeviceCubit>().saveSettings(
      widget.settings.copyWith(
        ip: _ip.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 4370,
        commKey: _commKey.text,
        useTcp: _useTcp,
        skipPing: _skipPing,
        importEmployees: _importEmployees,
        liveSync: _liveSync,
        autoSyncMinutes: _autoSyncMinutes,
      ),
    );
  }
}
