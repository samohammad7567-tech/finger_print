import 'package:easy_localization/easy_localization.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/employee_management_cubit.dart';

/// Turns a success key into the sentence the admin actually needs.
///
/// A fetch or a push says *what it did* rather than only that it finished: an
/// admin who presses the button and sees nothing new appear needs to be told
/// whether that is because the terminal held people back or because there was
/// nothing to add.
///
/// Lives outside the body because it is string assembly, not layout — and
/// because it is the one piece of that file worth reading on its own.
String employeeSuccessText(EmployeeManagementState state) {
  final base = state.successKey!.tr();

  // A push says how many the terminal took and how many it refused. A push
  // that wrote sixty and had four refused is an ordinary outcome on a unit
  // that is nearly full, and "done" alone would hide it.
  final push = state.pushResult;
  if (push != null) {
    return <String>[
      base,
      '${LangKeys.devicePushWritten.tr()}: ${push.written}',
      if (push.hasFailures)
        '${LangKeys.devicePushRefused.tr()}: ${push.failed}',
      if (push.stopped) LangKeys.errorDevicePushStopped.tr(),
      if (push.hasUnlinked) '${LangKeys.deviceUnmapped.tr()}: ${push.unlinked}',
    ].join(' · ');
  }

  final result = state.deviceFetchResult;
  if (result == null) return base;

  final parts = <String>[
    '${LangKeys.deviceFetchRead.tr()}: ${result.readFromDevice}',
    '${LangKeys.deviceFetchCreated.tr()}: ${result.created}',
    if (result.pending > 0)
      '${LangKeys.deviceFetchHeld.tr()}: ${result.pending}',
    if (result.hasDeleted)
      '${LangKeys.deviceFetchDeleted.tr()}: ${result.deleted.length}',
  ];
  return '$base · ${parts.join(' · ')}';
}
