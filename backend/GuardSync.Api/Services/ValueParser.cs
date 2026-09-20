using System.Globalization;

namespace GuardSync.Api.Services;

/// <summary>
/// The app speaks dates as "yyyy-MM-dd", times as "HH:mm" and ids as GUID strings.
/// Parsing lives here so no controller has to repeat the format handling.
/// </summary>
public static class ValueParser
{
    private static readonly string[] TimeFormats = ["HH\\:mm", "HH\\:mm\\:ss", "H\\:mm"];

    public static bool TryDate(string? value, out DateOnly date) =>
        DateOnly.TryParseExact(value ?? string.Empty, "yyyy-MM-dd",
            CultureInfo.InvariantCulture, DateTimeStyles.None, out date);

    public static DateOnly? DateOrNull(string? value) =>
        TryDate(value, out var d) ? d : null;

    public static bool TryTime(string? value, out TimeOnly time)
    {
        time = default;
        if (string.IsNullOrWhiteSpace(value)) return false;
        return TimeOnly.TryParseExact(value, TimeFormats,
            CultureInfo.InvariantCulture, DateTimeStyles.None, out time);
    }

    public static TimeOnly? TimeOrNull(string? value) =>
        TryTime(value, out var t) ? t : null;

    public static bool TryId(string? value, out Guid id) =>
        Guid.TryParse(value, out id);

    /// <summary>
    /// Expands "yyyy-MM" into the real first and last day of that month.
    /// The Firestore version approximated the end as "-31", which silently
    /// over-counted for shorter months.
    /// </summary>
    public static bool TryMonthRange(string? yearMonth, out DateOnly start, out DateOnly end)
    {
        start = default;
        end = default;
        if (!DateTime.TryParseExact(yearMonth ?? string.Empty, "yyyy-MM",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
        {
            return false;
        }

        start = new DateOnly(parsed.Year, parsed.Month, 1);
        end = start.AddMonths(1).AddDays(-1);
        return true;
    }
}
