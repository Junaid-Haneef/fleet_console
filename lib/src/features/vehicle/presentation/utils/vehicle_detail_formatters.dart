String formatVehicleUtcTimestamp(DateTime value) {
  final utc = value.toUtc();
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  final hh = utc.hour.toString().padLeft(2, '0');
  final mm = utc.minute.toString().padLeft(2, '0');
  final ss = utc.second.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm:$ss UTC';
}

String formatVehicleReadingAge(int ageSeconds) {
  if (ageSeconds < 60) {
    return '${ageSeconds}s';
  }

  final minutes = ageSeconds ~/ 60;
  if (minutes < 60) {
    return '${minutes}m';
  }

  final hours = minutes ~/ 60;
  final remMinutes = minutes % 60;
  return '${hours}h ${remMinutes}m';
}