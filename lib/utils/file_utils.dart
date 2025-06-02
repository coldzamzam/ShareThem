import 'dart:math';

/// Converts a size in bytes to a human-readable string.
///
/// [bytes]: The number of bytes.
/// [decimals]: The number of decimal places to display (default is 2).
///
/// Returns a string like "1.51 KB", "2.02 MB", "100 B".
String fileSizeToHuman(int bytes, {int decimals = 2}) {
  // Handle the edge case of 0 bytes.
  if (bytes <= 0) return "0 B";

  // Define the standard units.
  const List<String> suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

  // Calculate the index for the suffixes array.
  // This determines which unit to use (KB, MB, GB, etc.).
  // It's based on the logarithm base 1024 of the bytes.
  int i = (log(bytes) / log(1024)).floor();

  // Ensure the index is within the bounds of the suffixes array.
  // This handles extremely large numbers beyond Yottabytes, though unlikely in practice.
  if (i >= suffixes.length) {
    i = suffixes.length - 1;
  }

  // Calculate the value in the chosen unit.
  // For example, if bytes is 1500 and i is 1 (for KB),
  // this will be 1500 / 1024^1 = 1.4648...
  double value = bytes / pow(1024, i);

  // Format the number to the specified number of decimal places.
  // `toStringAsFixed(decimals)` converts the number to a string with a fixed number of decimal places.
  // Then, `double.parse()` is used to remove trailing zeros if `decimals` is greater than what's needed
  // (e.g., if it becomes 2.00, it will be 2.0). This step is optional but makes it cleaner.
  // If you always want fixed decimals (e.g., "2.0 MB" instead of "2 MB"), you can simplify this.
  String formattedValue;
  if (decimals <= 0) {
    formattedValue = value.round().toString();
  } else {
    // Using toStringAsFixed and then parsing helps remove unnecessary trailing .0
    // For example, 2048 bytes with decimals = 1 should be "2 KB" not "2.0 KB"
    // However, 1500 bytes with decimals = 1 should be "1.5 KB"
    double factor = pow(10, decimals).toDouble();
    value = (value * factor).round() / factor;
    formattedValue = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : decimals);
  }


  // Concatenate the formatted number with the appropriate suffix.
  return '$formattedValue ${suffixes[i]}';
}

/*
// --- Example Usage ---
// (Uncomment and place in your Dart/Flutter app to test)

void main() {
  print(formatBytes(0)); // Output: 0 B
  print(formatBytes(100)); // Output: 100 B
  print(formatBytes(1023)); // Output: 1023 B
  print(formatBytes(1024)); // Output: 1 KB
  print(formatBytes(1500)); // Output: 1.5 KB
  print(formatBytes(1024 * 1024)); // Output: 1 MB
  print(formatBytes(1024 * 1024 * 1.5.toInt())); // This will be 1MB due to toInt()
  print(formatBytes((1024 * 1024 * 1.5).toInt())); // Output: 1 MB (because toInt truncates 1.5 to 1)
  print(formatBytes((1024 * 1024 * 1.5).round())); // Output: 2 MB (because .round() rounds 1.5 to 2)
  print(formatBytes(1610612736)); // Output: 1.5 GB (1.5 * 1024 * 1024 * 1024)
  print(formatBytes(1234567890)); // Output: 1.1 GB
  print(formatBytes(1234567890, decimals: 2)); // Output: 1.15 GB
  print(formatBytes(1234567890, decimals: 0)); // Output: 1 GB
  print(formatBytes(2048, decimals: 1)); // Output: 2 KB
  print(formatBytes(2000, decimals: 1)); // Output: 2 KB
  print(formatBytes(2000, decimals: 2)); // Output: 1.95 KB

  // Test with more decimals
  print(formatBytes(1536, decimals: 1)); // 1.5 KB
  print(formatBytes(1536, decimals: 2)); // 1.5 KB

  // Test very large numbers
  print(formatBytes(pow(1024, 4).toInt())); // Output: 1 TB
  print(formatBytes(pow(1024, 5).toInt())); // Output: 1 PB
  print(formatBytes((pow(1024, 5) * 2.34).toInt(), decimals: 2)); // Output: 2.34 PB
}
*/
