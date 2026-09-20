class LangKeys {
  LangKeys._();

  static const appName = 'app_name';
  static const attendanceSystem = 'attendance_system';
  static const signIn = 'sign_in';
  static const enterGuardCredentials = 'enter_guard_credentials';
  static const email = 'email';
  static const password = 'password';
  static const register = 'register';
  static const noAccount = 'no_account';
  static const alreadyHaveAccount = 'already_have_account';
  static const signingIn = 'signing_in';
  static const fillAllFields = 'fill_all_fields';
  static const contactAdmin = 'contact_admin';
  static const errorUserNotFound = 'error_user_not_found';
  static const errorWrongPassword = 'error_wrong_password';
  static const errorInvalidEmail = 'error_invalid_email';
  static const errorEmailInUse = 'error_email_in_use';
  static const errorWeakPassword = 'error_weak_password';
  static const errorInvalidCredentials = 'error_invalid_credentials';
  static const errorUnknown = 'error_unknown';
  static const errorLoadFailed = 'error_load_failed';
  static const errorSaveFailed = 'error_save_failed';
  static const permissionAlreadyExists = 'permission_already_exists';

  // Keys returned by the API in {"error": "..."} and by the transport layer.
  static const errorNetwork = 'error_network';
  static const errorTimeout = 'error_timeout';
  static const errorServer = 'error_server';
  static const errorUnauthorized = 'error_unauthorized';
  static const errorForbidden = 'error_forbidden';
  static const errorNotFound = 'error_not_found';
  static const errorConflict = 'error_conflict';
  static const errorInvalidRequest = 'error_invalid_request';
  static const errorAccountDisabled = 'error_account_disabled';
  static const errorEmployeeNotFound = 'error_employee_not_found';
  static const errorDuplicateRecord = 'error_duplicate_record';
  static const errorDuplicatePermission = 'error_duplicate_permission';
  static const errorDuplicateEmployeeNumber = 'error_duplicate_employee_number';
  static const errorInvalidResetToken = 'error_invalid_reset_token';

  static const dashboard = 'dashboard';
  static const attendance = 'attendance';
  static const checkInTab = 'check_in_tab';
  static const permits = 'permits';
  static const settings = 'settings';

  static const todaysSummary = 'todays_summary';
  static const quickActions = 'quick_actions';
  static const recentEntries = 'recent_entries';
  static const totalRecordsToday = 'total_records_today';

  static const present = 'present';
  static const late = 'late';
  static const absent = 'absent';
  static const earlyLeave = 'early_leave';
  static const travelPermission = 'travel_permission';
  static const notRecorded = 'not_recorded';
  static const pending = 'pending';

  static const attendanceList = 'attendance_list';
  static const searchByNameOrId = 'search_by_name_or_id';
  static const all = 'all';
  static const travel = 'travel';
  static const employees = 'employees';
  static const noResults = 'no_results';

  static const attendanceEntry = 'attendance_entry';
  static const checkIn = 'check_in';
  static const checkOut = 'check_out';
  static const markAbsent = 'mark_absent';
  static const permission = 'permission';
  static const searchEmployee = 'search_employee';
  static const employeeNameOrId = 'employee_name_or_id';
  static const scanQrCode = 'scan_qr_code';
  static const time = 'time';
  static const notesOptional = 'notes_optional';
  static const addNote = 'add_note';
  static const saving = 'saving';
  static const saved = 'saved';
  static const housing = 'housing';
  static const travelPerm = 'travel_perm';
  static const onLeaveStatus = 'on_leave_status';
  static const alreadyRecordedStatus = 'already_recorded_status';
  static const backToList = 'back_to_list';

  static const permissionsAndRequests = 'permissions_and_requests';
  static const add = 'add';
  static const search = 'search';
  static const addNewPermission = 'add_new_permission';
  static const employee = 'employee';
  static const selectEmployee = 'select_employee';
  static const permissionType = 'permission_type';
  static const travelPermissionType = 'travel_permission_type';
  static const housingEarlyLeave = 'housing_early_leave';
  static const approvedEarlyDeparture = 'approved_early_departure';
  static const vacation = 'vacation';
  static const date = 'date';
  static const reason = 'reason';
  static const reasonPlaceholder = 'reason_placeholder';
  static const savePermission = 'save_permission';
  static const approved = 'approved';
  static const by = 'by';
  static const noPermissions = 'no_permissions';

  static const notifications = 'notifications';
  static const lateEmployee = 'late_employee';
  static const missingCheckout = 'missing_checkout';
  static const hasNotCheckedOut = 'has_not_checked_out';
  static const notCheckedIn = 'not_checked_in';
  static const noAlerts = 'no_alerts';
  static const everythingGood = 'everything_good';

  static const appearance = 'appearance';
  static const darkMode = 'dark_mode';
  static const arabicRtl = 'arabic_rtl';
  static const notificationsSettings = 'notifications_settings';
  static const lateArrivalAlerts = 'late_arrival_alerts';
  static const missingCheckoutAlerts = 'missing_checkout_alerts';
  static const account = 'account';
  static const guard = 'guard';
  static const securityGuard = 'security_guard';
  static const securityGuardGate = 'security_guard_gate';
  static const aboutApp = 'about_app';
  static const signOut = 'sign_out';

  static const attendanceDetails = 'attendance_details';
  static const attendanceRate = 'attendance_rate';
  static const presentDays = 'present_days';
  static const lateDays = 'late_days';
  static const absentDays = 'absent_days';
  static const attendanceHistory = 'attendance_history';
  static const noRecords = 'no_records';
  static const noRecordsToday = 'no_records_today';
  static const offline = 'offline';

  static const adminDashboard = 'admin_dashboard';
  static const adminPanel = 'admin_panel';
  static const adminHome = 'admin_home';
  static const adminEmployees = 'admin_employees';
  static const adminReportsTab = 'admin_reports_tab';
  static const adminTotalEmployees = 'admin_total_employees';
  static const adminPresentToday = 'admin_present_today';
  static const adminTodayRecords = 'admin_today_records';
  static const adminUnregistered = 'admin_unregistered';
  static const adminAttendanceRateToday = 'admin_attendance_rate_today';
  static const adminEmployeeMgmt = 'admin_employee_mgmt';
  static const adminSearchEmployee = 'admin_search_employee';
  static const adminAddEmployee = 'admin_add_employee';
  static const adminEditEmployee = 'admin_edit_employee';
  static const adminEmployeeId = 'admin_employee_id';
  static const adminFullName = 'admin_full_name';
  static const adminDepartment = 'admin_department';
  static const adminPosition = 'admin_position';
  static const adminPhone = 'admin_phone';
  static const adminHasHousing = 'admin_has_housing';
  static const adminHasTravel = 'admin_has_travel';
  static const adminActiveEmployee = 'admin_active_employee';
  static const adminSave = 'admin_save';
  static const adminConfirmDelete = 'admin_confirm_delete';
  static const adminDeleteMsg = 'admin_delete_msg';
  static const adminCancel = 'admin_cancel';
  static const adminDelete = 'admin_delete';
  static const noEmployees = 'no_employees';
  static const addFirstEmployee = 'add_first_employee';
  static const employeeAdded = 'employee_added';
  static const employeeUpdated = 'employee_updated';
  static const employeeAddedDeviceFailed = 'employee_added_device_failed';
  static const employeeDeleted = 'employee_deleted';
  static const employeeDeactivated = 'employee_deactivated';
  static const employeeActivated = 'employee_activated';
  static const failedLoadEmployees = 'failed_load_employees';
  static const failedSaveEmployee = 'failed_save_employee';
  static const failedDeleteEmployee = 'failed_delete_employee';
  static const failedUpdateEmployee = 'failed_update_employee';
  static const adminPermissionsMgmt = 'admin_permissions_mgmt';
  static const adminApprove = 'admin_approve';
  static const adminReject = 'admin_reject';
  static const adminRejected = 'admin_rejected';
  static const adminReports = 'admin_reports';
  static const adminLast7Days = 'admin_last_7_days';
  static const adminDeptRates = 'admin_dept_rates';
  static const adminSystemManager = 'admin_system_manager';
  static const adminLanguage = 'admin_language';
  static const adminNotifications = 'admin_notifications';
  static const noAdminNotifications = 'no_admin_notifications';
  static const markAllRead = 'mark_all_read';
  static const earlyLeaveDays = 'early_leave_days';
  static const adminAttendanceDetail = 'admin_attendance_detail';
  static const viewDailyMonthly = 'view_daily_monthly';
  static const dailyView = 'daily_view';
  static const monthlyView = 'monthly_view';
  static const lateTimes = 'late_times';
  static const permissionsDays = 'permissions_days';
  static const totalLateHours = 'total_late_hours';
  static const monthlyReportTitle = 'monthly_report_title';
  static const vacationLimitError = 'vacation_limit_error';

  static const forgotPassword = 'forgot_password';
  static const enterEmailForReset = 'enter_email_for_reset';
  static const passwordResetSent = 'password_reset_sent';
  static const logoutConfirmTitle = 'logout_confirm_title';
  static const logoutConfirmMsg = 'logout_confirm_msg';
  static const confirm = 'confirm';
  static const cancel = 'cancel';
  static const scanQr = 'scan_qr';
  static const earlyLeaveThresholdMsg = 'early_leave_threshold_msg';

  // ---------------------------------------------------------- local storage
  static const errorDatabase = 'error_database';
  static const errorResetUnavailableOffline = 'error_reset_unavailable_offline';

  // ------------------------------------------------------- ZKTeco terminal
  static const errorDeviceNotConfigured = 'error_device_not_configured';
  static const errorDeviceUnreachable = 'error_device_unreachable';
  static const errorDeviceRead = 'error_device_read';
  static const errorDuplicateDeviceUser = 'error_duplicate_device_user';

  static const deviceTitle = 'device_title';
  static const deviceSubtitle = 'device_subtitle';
  static const deviceConnection = 'device_connection';
  static const deviceIp = 'device_ip';
  static const deviceIpHint = 'device_ip_hint';
  static const devicePort = 'device_port';
  static const deviceCommKey = 'device_comm_key';
  static const deviceCommKeyHint = 'device_comm_key_hint';
  static const deviceUseTcp = 'device_use_tcp';
  static const deviceUseTcpHint = 'device_use_tcp_hint';
  static const deviceSkipPing = 'device_skip_ping';
  static const deviceSkipPingHint = 'device_skip_ping_hint';
  static const deviceAutoSync = 'device_auto_sync';
  static const deviceAutoSyncOff = 'device_auto_sync_off';
  static const deviceEveryMinutes = 'device_every_minutes';
  static const deviceSaveSettings = 'device_save_settings';
  static const deviceSettingsSaved = 'device_settings_saved';

  static const deviceTestConnection = 'device_test_connection';
  static const deviceConnected = 'device_connected';
  static const deviceNotConfiguredHint = 'device_not_configured_hint';
  static const deviceName = 'device_name';
  static const deviceSerial = 'device_serial';
  static const deviceFirmware = 'device_firmware';
  static const deviceClock = 'device_clock';
  static const deviceClockDrift = 'device_clock_drift';
  static const deviceSyncClock = 'device_sync_clock';
  static const deviceClockSynced = 'device_clock_synced';

  static const deviceSyncNow = 'device_sync_now';
  static const deviceSyncing = 'device_syncing';
  static const deviceLastSync = 'device_last_sync';
  static const deviceNeverSynced = 'device_never_synced';
  static const deviceSyncDone = 'device_sync_done';
  static const devicePunchesRead = 'device_punches_read';
  static const devicePunchesNew = 'device_punches_new';
  static const deviceRecordsWritten = 'device_records_written';

  static const deviceMapping = 'device_mapping';
  static const deviceMappingHint = 'device_mapping_hint';
  static const deviceUserId = 'device_user_id';
  static const deviceUnmapped = 'device_unmapped';
  static const deviceUnmappedCount = 'device_unmapped_count';
  static const deviceNoUnmapped = 'device_no_unmapped';
  static const deviceMapToEmployee = 'device_map_to_employee';
  static const deviceMapped = 'device_mapped';
  static const devicePunchCount = 'device_punch_count';
  static const deviceLastSeen = 'device_last_seen';
  static const deviceLoadUsers = 'device_load_users';
  static const deviceEnrolledUsers = 'device_enrolled_users';

  // ------------------------------------------------------- punch report
  static const reportPunchTitle = 'report_punch_title';
  static const reportCheckIn = 'report_check_in';
  static const reportCheckOut = 'report_check_out';
  static const reportBreakOut = 'report_break_out';
  static const reportBreakIn = 'report_break_in';
  static const reportBreaks = 'report_breaks';
  static const reportBreakTime = 'report_break_time';
  static const reportOvertimeIn = 'report_overtime_in';
  static const reportOvertimeOut = 'report_overtime_out';
  static const reportWorked = 'report_worked';
  static const reportOvertime = 'report_overtime';
  static const reportRows = 'report_rows';
  static const reportNoRows = 'report_no_rows';
  static const reportAllEmployees = 'report_all_employees';
  static const reportThisMonth = 'report_this_month';
  static const reportLastMonth = 'report_last_month';
  static const reportToday = 'report_today';
  static const reportPickDay = 'report_pick_day';
  static const reportRange = 'report_range';
  static const reportDay = 'report_day';
  static const reportPdf = 'report_pdf';
  static const reportPdfBuilding = 'report_pdf_building';
  static const reportPdfSaved = 'report_pdf_saved';
  static const reportPdfFailed = 'report_pdf_failed';
  static const reportGeneratedAt = 'report_generated_at';
  static const reportTotals = 'report_totals';
  static const reportRefresh = 'report_refresh';
  static const reportRefreshing = 'report_refreshing';
  static const reportRefreshed = 'report_refreshed';
  static const reportTab = 'report_tab';
  static const reportCopyCsv = 'report_copy_csv';
  static const reportCsvCopied = 'report_csv_copied';

  // ------------------------------------------ the monthly punches workbook
  static const reportMonthly = 'report_monthly';
  static const reportMonthlyBuilding = 'report_monthly_building';
  static const reportMonthlySaved = 'report_monthly_saved';
  static const reportMonthlyFailed = 'report_monthly_failed';
  static const reportMonthlyTitle = 'report_monthly_title';
  static const reportAllSheet = 'report_all_sheet';
  static const reportStaffNumber = 'report_staff_number';
  static const reportCorrectedBy = 'report_corrected_by';

  // ----------------------------------------- the admin's one daily correction
  static const reportCorrect = 'report_correct';
  static const reportCorrectTitle = 'report_correct_title';
  static const reportCorrectWarning = 'report_correct_warning';
  static const reportCorrectSave = 'report_correct_save';
  static const reportCorrectUsed = 'report_correct_used';
  static const reportCorrectClosed = 'report_correct_closed';
  static const reportCorrectionSaved = 'report_correction_saved';
  static const errorRecordNotFound = 'error_record_not_found';
  static const errorCorrectionUsed = 'error_correction_used';
  static const errorCorrectionNotToday = 'error_correction_not_today';
  static const errorCorrectionEmpty = 'error_correction_empty';
  static const errorCorrectionOrder = 'error_correction_order';
  static const errorCorrectionTime = 'error_correction_time';
  // `date` is already declared above and reused here.
  static const status = 'status';

  static const deviceLiveSync = 'device_live_sync';
  static const deviceLiveSyncHint = 'device_live_sync_hint';
  static const deviceLiveActive = 'device_live_active';
  static const deviceLivePunch = 'device_live_punch';
  static const deviceImportEmployees = 'device_import_employees';
  static const deviceImportEmployeesHint = 'device_import_employees_hint';
  static const deviceEmployeesImported = 'device_employees_imported';
  static const deviceEmployeesPending = 'device_employees_pending';

  static const deviceMatchReview = 'device_match_review';
  static const deviceMatchReviewHint = 'device_match_review_hint';
  static const deviceMatchOnDevice = 'device_match_on_device';
  static const deviceMatchNoName = 'device_match_no_name';
  static const deviceMatchSamePersonQuestion =
      'device_match_same_person_question';
  static const deviceMatchWhichPerson = 'device_match_which_person';
  static const deviceMatchExact = 'device_match_exact';
  static const deviceMatchPartial = 'device_match_partial';
  static const deviceMatchLink = 'device_match_link';
  static const deviceMatchNotTheSame = 'device_match_not_the_same';
  static const deviceMatchLinked = 'device_match_linked';
  static const deviceMatchCreated = 'device_match_created';

  static const employeeMatchBannerTitle = 'employee_match_banner_title';
  static const employeeMatchBannerHint = 'employee_match_banner_hint';
  static const employeeMatchBannerAction = 'employee_match_banner_action';

  static const deviceFetch = 'device_fetch';
  static const deviceFetching = 'device_fetching';
  static const deviceFetchHint = 'device_fetch_hint';
  static const deviceFetchDone = 'device_fetch_done';
  static const deviceFetchCreated = 'device_fetch_created';
  static const deviceFetchHeld = 'device_fetch_held';
  static const deviceFetchRead = 'device_fetch_read';
  static const deviceFetchDeleted = 'device_fetch_deleted';

  static const restoreTitle = 'restore_title';
  static const restoreHint = 'restore_hint';
  static const restoreAction = 'restore_action';

  static const clashTitle = 'clash_title';
  static const clashHint = 'clash_hint';
  static const clashSharedBy = 'clash_shared_by';
  static const clashCertainlyDistinct = 'clash_certainly_distinct';
  static const clashMayBeSame = 'clash_may_be_same';
  static const clashEnrolledAs = 'clash_enrolled_as';
  static const clashNotEnrolled = 'clash_not_enrolled';
  static const clashRename = 'clash_rename';
  static const clashAllResolved = 'clash_all_resolved';
  static const clashReview = 'clash_review';
  static const clashBanner = 'clash_banner';

  static const employeeNumberGenerated = 'employee_number_generated';

  static const save = 'save';

  // ------------------------------------------------- fingerprint enrolment
  static const errorEnrollNeedsName = 'error_enroll_needs_name';
  static const errorEnrollStartFailed = 'error_enroll_start_failed';
  static const errorEnrollNoTemplate = 'error_enroll_no_template';
  static const errorDeviceWriteFailed = 'error_device_write_failed';
  static const errorDeviceDeleteFailed = 'error_device_delete_failed';
  static const deleteAlsoRemovesFingerprint = 'delete_also_removes_fingerprint';
  static const deleteDeviceUnreachable = 'delete_device_unreachable';

  static const enrollTitle = 'enroll_title';
  static const enrollNone = 'enroll_none';
  static const enrollAdd = 'enroll_add';
  static const enrollPreparing = 'enroll_preparing';
  static const enrollPlaceFinger = 'enroll_place_finger';
  static const enrollPlaceFingerHint = 'enroll_place_finger_hint';
  static const enrollDone = 'enroll_done';
  static const enrollVerifying = 'enroll_verifying';
  static const enrollEnrolled = 'enroll_enrolled';
  static const enrollRedo = 'enroll_redo';
  static const enrollCancel = 'enroll_cancel';
  static const enrollDeviceId = 'enroll_device_id';

  // ---------------------------------------------------------- working hours
  static const scheduleTitle = 'schedule_title';
  static const scheduleHint = 'schedule_hint';
  static const scheduleWorkStart = 'schedule_work_start';
  static const scheduleWorkEnd = 'schedule_work_end';
  static const scheduleOvertimeStart = 'schedule_overtime_start';
  static const scheduleOvertimeEnd = 'schedule_overtime_end';
  static const scheduleWorkHint = 'schedule_work_hint';
  static const scheduleOvertimeHint = 'schedule_overtime_hint';
  static const scheduleSaved = 'schedule_saved';
  static const scheduleInvalid = 'schedule_invalid';
  static const scheduleRefreshHint = 'schedule_refresh_hint';

  // ------------------------------------------------------- excel employee import
  static const yes = 'yes';
  static const no = 'no';
  static const close = 'close';

  static const importExcel = 'import_excel';
  static const importEmployees = 'import_employees';
  static const importColumnsHint = 'import_columns_hint';
  static const importTemplate = 'import_template';
  static const importTemplateHint = 'import_template_hint';
  static const importFileType = 'import_file_type';
  static const importing = 'importing';
  static const importDone = 'import_done';
  static const importFailed = 'import_failed';
  static const importNoRows = 'import_no_rows';
  static const importNoNameColumn = 'import_no_name_column';
  static const importUnreadableFile = 'import_unreadable_file';
  static const importUnsupportedFile = 'import_unsupported_file';
  static const importTemplateSaved = 'import_template_saved';
  static const importTemplateFailed = 'import_template_failed';
  static const importResultTitle = 'import_result_title';
  static const importResultAdded = 'import_result_added';
  static const importResultSkipped = 'import_result_skipped';
  static const importSkippedRow = 'import_skipped_row';
  static const importRowNoName = 'import_row_no_name';
  static const importRowDuplicateName = 'import_row_duplicate_name';
  static const importRowRepeatedInFile = 'import_row_repeated_in_file';
  static const importRowFailed = 'import_row_failed';
  static const importSampleName = 'import_sample_name';
  static const importSampleDepartment = 'import_sample_department';
  static const importSamplePosition = 'import_sample_position';

  // ------------------------------------------------------------- departments
  static const departmentsTitle = 'departments_title';
  static const departmentsHint = 'departments_hint';
  static const departmentAdd = 'department_add';
  static const departmentRename = 'department_rename';
  static const departmentName = 'department_name';
  static const departmentNone = 'department_none';
  static const departmentChoose = 'department_choose';
  static const departmentInUse = 'department_in_use';
  static const departmentUnlisted = 'department_unlisted';
  static const departmentsEmpty = 'departments_empty';
  static const departmentsEmptyHint = 'departments_empty_hint';
  static const departmentAdded = 'department_added';
  static const departmentRenamed = 'department_renamed';
  static const departmentDeleted = 'department_deleted';
  static const departmentDeleteTitle = 'department_delete_title';
  static const departmentDeleteMsg = 'department_delete_msg';
  static const departmentDeleteMoves = 'department_delete_moves';
  static const errorDepartmentExists = 'error_department_exists';
  static const errorDepartmentNameRequired = 'error_department_name_required';

  // ------------------------------------------------------------------ shifts
  static const shiftsTitle = 'shifts_title';
  static const shiftsHint = 'shifts_hint';
  static const shiftAdd = 'shift_add';
  static const shiftEdit = 'shift_edit';
  static const shiftName = 'shift_name';
  static const shiftNameHint = 'shift_name_hint';
  static const shiftStartWork = 'shift_start_work';
  static const shiftEndWork = 'shift_end_work';
  static const shiftLateGrace = 'shift_late_grace';
  static const shiftEarlyOutGrace = 'shift_early_out_grace';
  static const shiftGraceHint = 'shift_grace_hint';
  static const shiftMinutes = 'shift_minutes';
  static const shiftOvertimeDerived = 'shift_overtime_derived';
  static const shiftDefault = 'shift_default';
  static const shiftDefaultHint = 'shift_default_hint';
  static const shiftChoose = 'shift_choose';
  static const shiftInUse = 'shift_in_use';
  static const shiftsEmpty = 'shifts_empty';
  static const shiftsEmptyHint = 'shifts_empty_hint';
  static const shiftAdded = 'shift_added';
  static const shiftUpdated = 'shift_updated';
  static const shiftDeleted = 'shift_deleted';
  static const shiftDeleteTitle = 'shift_delete_title';
  static const shiftDeleteMsg = 'shift_delete_msg';
  static const shiftDeleteMoves = 'shift_delete_moves';
  static const shiftOnTimeUntil = 'shift_on_time_until';
  static const shiftLeaveFrom = 'shift_leave_from';
  static const errorShiftExists = 'error_shift_exists';
  static const errorShiftNameRequired = 'error_shift_name_required';
  static const errorShiftInvalidHours = 'error_shift_invalid_hours';
  static const errorShiftRequired = 'error_shift_required';

  // -------------------------------------------------- confirming an identity
  static const confirmIdentityTitle = 'confirm_identity_title';
  static const confirmIdentityPassword = 'confirm_identity_password';
  static const confirmIdentityConfirm = 'confirm_identity_confirm';
  static const confirmIdentityCorrection = 'confirm_identity_correction';

  // ------------------------------------------- what was unusual about a day
  static const flagMissingCheckout = 'flag_missing_checkout';
  static const flagOpenBreak = 'flag_open_break';
  static const flagCorrected = 'flag_corrected';

  // ------------------------------------------------- the working-day calendar
  static const restDaysTitle = 'rest_days_title';
  static const restDaysHint = 'rest_days_hint';
  static const restDaysNone = 'rest_days_none';
  static const holidaysTitle = 'holidays_title';
  static const holidaysHint = 'holidays_hint';
  static const holidayAdd = 'holiday_add';
  static const holidayEdit = 'holiday_edit';
  static const holidayName = 'holiday_name';
  static const holidayNameHint = 'holiday_name_hint';
  static const holidayStart = 'holiday_start';
  static const holidayEnd = 'holiday_end';
  static const holidayPaid = 'holiday_paid';
  static const holidayDays = 'holiday_days';
  static const holidaysEmpty = 'holidays_empty';
  static const holidaysEmptyHint = 'holidays_empty_hint';
  static const holidaysTotal = 'holidays_total';
  static const holidayAdded = 'holiday_added';
  static const holidayUpdated = 'holiday_updated';
  static const holidayDeleted = 'holiday_deleted';
  static const holidayDeleteTitle = 'holiday_delete_title';
  static const holidayDeleteMsg = 'holiday_delete_msg';
  static const errorHolidayNameRequired = 'error_holiday_name_required';
  static const errorHolidayInvalidRange = 'error_holiday_invalid_range';
  static const flagRestDay = 'flag_rest_day';
  static const flagHoliday = 'flag_holiday';

  // ------------------------------------------- reading one person's pattern
  static const reportPatterns = 'report_patterns';
  static const reportIssuesOnly = 'report_issues_only';
  static const reportNoIssues = 'report_no_issues';
  static const reportIssueDays = 'report_issue_days';
  static const reportLateTotal = 'report_late_total';
  static const reportEarlyOutTotal = 'report_early_out_total';

  static const backupTitle = 'backup_title';
  static const backupHint = 'backup_hint';
  static const backupNow = 'backup_now';
  static const backupDone = 'backup_done';
  static const backupFailed = 'backup_failed';
}
