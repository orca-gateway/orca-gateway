/// Wraps [content] with XML comment markers for the given [pluginName].
///
/// Result format:
/// ```xml
/// <!-- ORCA:plugin_name -->
/// ...content...
/// <!-- /ORCA:plugin_name -->
/// ```
String wrapWithXmlMarker(String pluginName, String content) {
  return '<!-- ORCA:$pluginName -->\n$content\n<!-- /ORCA:$pluginName -->';
}

/// Wraps [content] with line comment markers for the given [pluginName].
///
/// [prefix] defaults to `//` for Groovy/Kotlin files. Use `#` for Ruby files.
///
/// Result format:
/// ```
/// // ORCA:plugin_name
/// ...content...
/// // /ORCA:plugin_name
/// ```
String wrapWithLineMarker(
  String pluginName,
  String content, {
  String prefix = '//',
}) {
  return '$prefix ORCA:$pluginName\n$content\n$prefix /ORCA:$pluginName';
}

/// Returns `true` if [fileContent] contains markers for [pluginName].
///
/// Detects both XML comment markers (`<!-- ORCA:... -->`) and line comment
/// markers (`// ORCA:...` or `# ORCA:...`).
bool hasMarker(String fileContent, String pluginName) {
  // XML style
  if (fileContent.contains('<!-- ORCA:$pluginName -->')) return true;
  // Line comment style (// or #)
  final linePattern = RegExp(r'(//|#) ORCA:' + RegExp.escape(pluginName));
  return linePattern.hasMatch(fileContent);
}

/// Removes the marker block for [pluginName] and all content between the
/// opening and closing markers.
///
/// Handles both XML comment style and line comment style markers.
String removeMarker(String fileContent, String pluginName) {
  final escaped = RegExp.escape(pluginName);

  // XML style: <!-- ORCA:name --> ... <!-- /ORCA:name -->
  final xmlPattern = RegExp(
    r'[ \t]*<!-- ORCA:' + escaped + r' -->.*?<!-- /ORCA:' + escaped + r' -->\n?',
    dotAll: true,
  );
  var result = fileContent.replaceAll(xmlPattern, '');

  // Line comment style with // prefix
  final slashPattern = RegExp(
    r'[ \t]*// ORCA:' + escaped + r'\n.*?// /ORCA:' + escaped + r'\n?',
    dotAll: true,
  );
  result = result.replaceAll(slashPattern, '');

  // Line comment style with # prefix
  final hashPattern = RegExp(
    r'[ \t]*# ORCA:' + escaped + r'\n.*?# /ORCA:' + escaped + r'\n?',
    dotAll: true,
  );
  result = result.replaceAll(hashPattern, '');

  return result;
}
