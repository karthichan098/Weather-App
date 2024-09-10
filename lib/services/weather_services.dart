import 'package:http/http.dart' as http;
import 'dart:convert';

class WeatherService {
  final String apiKey = '98257dd0209c4c339c044905240506';
  final String forecastBaseUrl = "http://api.weatherapi.com/v1/forecast.json";
  final String searchBaseUrl = "http://api.weatherapi.com/v1/search.json";



  Future<Map<String, dynamic>> fetchCurrentWeather(String city) async {
    final url = '$forecastBaseUrl?key=$apiKey&q=$city&days=1&aqi=no&alerts=no';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load weather data');
    }
  }

  // Fetch weather by location (latitude and longitude)
  Future<Map<String, dynamic>> fetchWeatherByLocation(double latitude, double longitude) async {
    final response = await http.get(Uri.parse('$forecastBaseUrl/current.json?key=$apiKey&q=$latitude,$longitude'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load weather data for location');
    }
  }

  Future<Map<String, dynamic>> fetch7dayforecast(String city) async {
    // Corrected URL to fetch a 7-day forecast
    final url = '$forecastBaseUrl?key=$apiKey&q=$city&days=7&aqi=no&alerts=no';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load forecast data');
    }
  }

  Future<List<dynamic>?> fetchCitySuggestions(String query) async {
    final url = '$searchBaseUrl?key=$apiKey&q=$query';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return null;
    }
  }
}
