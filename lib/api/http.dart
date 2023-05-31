import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class HTTP {
  var client = http.Client();

  /// Sends an generic HTTP [MultipartRequest].
  Future<http.StreamedResponse> send(http.MultipartRequest request, {int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    http.MultipartRequest sending = request;
    http.StreamedResponse? response;

    for (int i = 0; i < numAttemps; i++) {
      try {
        response = await client.send(sending).timeout(timeoutDuration);

        if (response.statusCode == HttpStatus.ok)
          break;

      } on TimeoutException {
        print("SEND REQUEST - TIMEOUT IN ATTEMP ${i+1}");
      }
    }

    return response!;
  }

  /// Sends an HTTP GET request with the given [headers] to the given [url].
  Future<http.Response> get(String url, {Map<String, String>? headers, int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    http.Response? response;

    for (int i = 0; i < numAttemps; i++) {
      try {
        response = await client.get(
          Uri.parse(Uri.encodeFull(url)),
          headers: headers,
        ).timeout(timeoutDuration);

        if (response.statusCode == HttpStatus.ok)
          break;
      } on TimeoutException {
        print("GET REQUEST - TIMEOUT IN ATTEMP ${i+1}");
      }
    }

    return response!;
  }

  /// Sends an HTTP POST request with the given [headers] and [body] to the given [url].
  Future<http.Response> post(String url, {Map<String, String>? headers, body, encoding, int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    http.Response? response;

    for (int i = 0; i < numAttemps; i++) {
      try {
        response = await client.post(
          Uri.parse(Uri.encodeFull(url)),
          headers: headers,
          body: body,
          encoding: encoding,
        ).timeout(timeoutDuration);

        if (response.statusCode == HttpStatus.created)
          break;

      } on TimeoutException {
        print("POST REQUEST - TIMEOUT IN ATTEMP ${i+1}");
      }
    }

    return response!;
  }

  /// Sends an HTTP PUT request with the given [headers] and [body] to the given [url].
  Future<http.Response> put(String url, {Map<String, String>? headers, body, encoding, int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    http.Response? response;

    for (int i = 0; i < numAttemps; i++) {
      try {
        response = await client.put(
          Uri.parse(Uri.encodeFull(url)),
          headers: headers,
          body: body,
          encoding: encoding,
        ).timeout(timeoutDuration);

        if (response.statusCode == HttpStatus.ok)
          break;
      } on TimeoutException {
        print("PUT REQUEST - TIMEOUT IN ATTEMP ${i + 1}");
      }
    }

    return response!;
  }

  /// Sends an HTTP DELETE request with the given [headers] to the given [url].
  Future<http.Response> delete(String url, {Map<String, String>? headers, int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    http.Response? response;
    
    for (int i = 0; i < numAttemps; i++) {
      try {
        response = await client.delete(
          Uri.parse(Uri.encodeFull(url)),
          headers: headers,
        ).timeout(timeoutDuration);

        if (response.statusCode == HttpStatus.ok)
          break;
      } on TimeoutException {
        print("DELETE REQUEST - TIMEOUT IN ATTEMP ${i+1}");
      }
    }

    return response!;
  }
}