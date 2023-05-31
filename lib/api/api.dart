import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:tfg/api/credentials.dart';
import 'package:tfg/api/http.dart';
import 'package:http/http.dart' as http;

class Api {
  late HTTP _httpr;
  late String _base64_auth;

  Api() {
    _httpr = HTTP();
    _base64_auth = base64.encode(utf8.encode("$clientID:$clientSecret"));
  }

  // Peticion de tipo POST para recibir el access-token y refresh-token
  Future<Map<String, dynamic>> postToken({int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    final String url = postTokenUrl;

    Map<String, String> _authenticationHeader = {
      "Authorization": "Basic $_base64_auth",
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept": "application/json"
    };

    final _loginBody = {
      "client_id": "$clientID",
      "client_secret": "$clientSecret",
      "grant_type": "password",
      "scope": "read",
      "username": "$username",
      "password": "$password"
    };

    final http.Response response = await _httpr.post(
      Uri.encodeFull(url),
      headers: _authenticationHeader,
      body: _loginBody,
      numAttemps: numAttemps,
      timeoutDuration: timeoutDuration,
    );

    Map<String, dynamic> responseJson = json.decode(response.body);

    return responseJson;
  }

  // Peticion de tipo GET para enviar el token de acceso
  Future<Map<String, dynamic>> getToken(String token, {int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    final String url = getTokenUrl;

    Map<String, String> _authenticationHeader = {
      "Authorization": "bearer $token",
      "cache-control": "no-cache"
    };

    final http.Response response = await _httpr.get(
        Uri.encodeFull(url),
        headers: _authenticationHeader,
        numAttemps: numAttemps,
      timeoutDuration: timeoutDuration,
    );

    Map<String, dynamic> responseJson = json.decode(response.body);

    return responseJson;
  }

  // Peticion de tipo POST para introducir un datapoint en la base de datos
  Future<Map<String, dynamic>> postDataPoint(String token, String dataPoint, {int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    final String url = postDataPointUrl;

    Map<String, String> _authenticationHeader = {
      "Content-Type": "application/json",
      "Authorization": "bearer $token",
      "cache-control": "no-cache"
    };

    final http.Response response = await _httpr.post(
      Uri.encodeFull(url),
      headers: _authenticationHeader,
      body: dataPoint,
      numAttemps: numAttemps,
      timeoutDuration: timeoutDuration,
    );

    Map<String, dynamic> responseJson = json.decode(response.body);

    return responseJson;
  }

  Future sendBatchDataPoint(String token, String datapoints, {int numAttemps = 1, Duration timeoutDuration = const Duration(seconds: 10)}) async {
    final String url = batchPostDataPointUrl;

    var request = http.MultipartRequest("POST", Uri.parse(url));
    request.headers['Authorization'] = "bearer $token";
    request.headers['Content-Type'] = 'multipart/form-data';
    request.headers['cache-control'] = 'no-cache';

    request.files.add(http.MultipartFile.fromString(
      'file',
      datapoints,
      filename: 'datapoints.json',
      contentType: MediaType('application', 'json'),
    ));

    // sending the request using the retry approach
    _httpr.send(request, numAttemps: numAttemps, timeoutDuration: timeoutDuration).then((response) async {
      final int httpStatusCode = response.statusCode;

      // CARP web service returns 200 or 201 when a file is uploaded to the server
      if ((httpStatusCode == HttpStatus.ok) ||
          (httpStatusCode == HttpStatus.created)) return;

      // everything else is an exception
      response.stream.toStringStream().first.then((body) {
        final Map<String, dynamic> responseJson = json.decode(body);
      });
    });
  }
}