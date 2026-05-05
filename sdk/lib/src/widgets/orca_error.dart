import 'package:flutter/material.dart' show Icon, Icons;
import 'package:flutter/widgets.dart';
import '../client/orca_client.dart';

/// Builds a user-friendly error widget from an exception.
Widget buildOrcaError(Object error) {
  final String title;
  final String message;
  final IconData icon;

  if (error is OrcaClientException) {
    switch (error.statusCode) {
      case 401:
        title = 'Unauthorized';
        message = 'Invalid or missing API key. Please check your configuration.';
        icon = Icons.lock_outline;
      case 403:
        title = 'Forbidden';
        message = 'You do not have permission to access this resource.';
        icon = Icons.block;
      case 404:
        title = 'Not Found';
        message = 'The requested page could not be found.';
        icon = Icons.search_off;
      case 429:
        title = 'Too Many Requests';
        message = 'Please slow down and try again in a moment.';
        icon = Icons.speed;
      case >= 500:
        title = 'Server Error';
        message = 'Something went wrong on the server. Please try again later.';
        icon = Icons.cloud_off;
      default:
        title = 'Error';
        message = error.message;
        icon = Icons.error_outline;
    }
  } else if (error is FormatException) {
    title = 'Configuration Error';
    message = 'Invalid value in configuration. Please check your setup.';
    icon = Icons.settings;
  } else {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      title = 'Connection Failed';
      message = 'Unable to reach the server. Please check your network and server status.';
      icon = Icons.wifi_off;
    } else {
      title = 'Something Went Wrong';
      message = 'An unexpected error occurred. Please try again.';
      icon = Icons.error_outline;
    }
  }

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0x99000000)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xDD000000),
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0x99000000),
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
