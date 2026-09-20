import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/department_model.dart';
import '../../data/repos/departments_repo.dart';

class DepartmentsState {
  final List<DepartmentModel> departments;
  final bool isLoading;
  final bool isSaving;

  /// Localization keys, never sentences — the screen translates them.
  final String? errorKey;
  final String? successKey;

  const DepartmentsState({
    this.departments = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.errorKey,
    this.successKey,
  });

  /// What the employee form offers besides "no department".
  List<String> get names => [for (final d in departments) d.name];

  bool get isEmpty => !isLoading && departments.isEmpty;

  DepartmentsState copyWith({
    List<DepartmentModel>? departments,
    bool? isLoading,
    bool? isSaving,
    String? errorKey,
    String? successKey,
  }) => DepartmentsState(
    departments: departments ?? this.departments,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    // Feedback is spent once shown, so it is never carried forward by a
    // copy that did not ask for it.
    errorKey: errorKey,
    successKey: successKey,
  );
}

/// The department list an admin maintains, and the source of the choices the
/// employee form offers.
class DepartmentsCubit extends Cubit<DepartmentsState> {
  final DepartmentsRepo _repo;

  DepartmentsCubit(this._repo) : super(const DepartmentsState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      emit(
        state.copyWith(
          departments: await _repo.getDepartments(),
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorKey: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(isLoading: false, errorKey: LangKeys.errorLoadFailed),
      );
    }
  }

  /// Returns the name that was stored, so the caller can select it — the form
  /// adds a department mid-edit and expects the employee to land in it.
  Future<String?> add(String name) async {
    return _write(() => _repo.createDepartment(name), LangKeys.departmentAdded);
  }

  Future<String?> rename(DepartmentModel department, String name) async {
    return _write(
      () => _repo.renameDepartment(department, name),
      LangKeys.departmentRenamed,
    );
  }

  /// The employees in it are left without a department rather than blocked —
  /// [DepartmentModel.inUse] is what the confirm dialog warns with.
  Future<void> remove(DepartmentModel department) async {
    await _write(() async {
      await _repo.deleteDepartment(department);
      return null;
    }, LangKeys.departmentDeleted);
  }

  /// One write, then a reload. The list is rebuilt from the database rather
  /// than patched in memory, because a rename moves employees between
  /// departments and the counts shift with them.
  Future<String?> _write(
    Future<DepartmentModel?> Function() action,
    String successKey,
  ) async {
    if (state.isSaving) return null;
    emit(state.copyWith(isSaving: true));

    try {
      final result = await action();
      final departments = await _repo.getDepartments();
      emit(
        state.copyWith(
          departments: departments,
          isLoading: false,
          isSaving: false,
          successKey: successKey,
        ),
      );
      return result?.name;
    } on ApiException catch (e) {
      emit(state.copyWith(isSaving: false, errorKey: e.errorKey));
      return null;
    } catch (_) {
      emit(state.copyWith(isSaving: false, errorKey: LangKeys.errorSaveFailed));
      return null;
    }
  }
}
