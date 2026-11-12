const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Format tanggal singkat Indonesia, mis. `9 Nov 2026`.
String formatShortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
