const _months = [
  'Jan','Feb','Mar','Apr','May','Jun',
  'Jul','Aug','Sep','Oct','Nov','Dec',
];

/// Returns compact time like Twitter: "now", "5m", "7h", "3d", "Jun 19"
String compactTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)  return 'now';
  if (diff.inMinutes < 60)  return '${diff.inMinutes}m';
  if (diff.inHours < 24)    return '${diff.inHours}h';
  if (diff.inDays < 7)      return '${diff.inDays}d';
  if (diff.inDays < 365)    return '${_months[dt.month - 1]} ${dt.day}';
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
