class Utils {
  static bool requiresLocationData(String message) {
    // Remove punctuation from the message and convert to lowercase
    final normalizedMessage =
        message.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    // Check for keywords that imply location-based information is needed
    final keywords = ['location', 'weather', 'near me'];
    return keywords.any((keyword) => normalizedMessage.contains(keyword));
  }
}
