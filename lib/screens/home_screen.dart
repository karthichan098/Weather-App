import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weatherv2/services/weather_services.dart';
import 'package:weatherv2/screens/forecast_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; // Added for date formatting
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  String _city = "Pondicherry";
  Map<String, dynamic>? _currentWeather;
  List<dynamic>? _hour;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();



  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _getCurrentLocation();
    _initializeNotifications();

  }

  Future<void> _fetchWeather() async {
    try {
      final weatherData = await _weatherService.fetchCurrentWeather(_city);
      setState(() {
        _currentWeather = weatherData;
        _hour = weatherData['forecast']['forecastday'][0]['hour'];
      });
      _showWeatherNotification(weatherData); // Show notification
    } catch (e) {
      print(e);
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _fetchWeatherForLocation(position.latitude, position.longitude);
  }

  Future<void> _fetchWeatherForLocation(
      double latitude, double longitude) async {
    try {
      final weatherData =
      await _weatherService.fetchWeatherByLocation(latitude, longitude);
      setState(() {
        _currentWeather = weatherData;
        _hour = weatherData['forecast']['forecastday'][0]['hour'];
        _city = weatherData['location']['name']; // Update city name
      });
    } catch (e) {
      print(e);
    }
  }

  void _initializeNotifications() {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create a notification channel for Android 8.0+
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        'weather_channel_id',
        'Weather Updates',
        description: 'This channel is used for weather updates',
        importance: Importance.max,
      ),
    );
  }


  void _showWeatherNotification(Map<String, dynamic> weatherData) async {
    final String condition = weatherData['current']['condition']['text'];
    final double temperature = weatherData['current']['temp_c'];
    final String location = weatherData['location']['name'];

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'weather_channel_id', // Unique ID for this channel
      'Weather Updates', // Channel name
      channelDescription: 'Daily weather updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Weather in $location',
      'Current condition: $condition, Temperature: ${temperature.round()}°C',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }


  void _showCitySelectionDialog(){
    showDialog(
        context: context,
        builder: (BuildContext context){
          return AlertDialog(
            title: Text('Enter City Name'),
            content: TypeAheadField(
              suggestionsCallback: (patttern) async{
                return await _weatherService.fetchCitySuggestions(patttern);
              },
              builder: (context, controller, focusMode){
                return TextField(
                  controller: controller,
                  focusNode: focusMode,
                  autofocus: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(

                    ),
                    label: Text("city")
                  ),
                );
              },
              itemBuilder: (context, suggestion){
                return ListTile(title: Text(suggestion['name']),);
              },
              onSelected: (city){
                _city = city['name'];
              },
            ),
            actions: [
              TextButton(onPressed: () {
                Navigator.pop(context);

              }, child: Text('Cancel')),
              TextButton(onPressed: () {
                Navigator.pop(context);
                _fetchWeather();
              }, child: Text('Submit')),

            ],
          );
        },
    );
  }
  IconData _getWeatherIcon(String condition) {
    if (condition.toLowerCase().contains('rain')) {
      return Icons.beach_access; // Example: rain icon
    } else if (condition.toLowerCase().contains('cloud')) {
      return Icons.cloud; // Cloud icon for cloudy weather
    } else if (condition.toLowerCase().contains('clear') || condition.toLowerCase().contains('sunny')) {
      return Icons.wb_sunny; // Sun icon for clear weather
    } else if (condition.toLowerCase().contains('snow')) {
      return Icons.ac_unit; // Snowflake icon for snowy weather
    } else {
      return Icons.cloud; // Default to cloud icon
    }
  }
  Widget _buildHourlyCloudReport() {
    if (_hour == null || _hour!.isEmpty) {
      return Center(
        child: Text(
          'No hourly data available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    int currentHour = DateTime.now().hour;

    // Create a ScrollController to control the scrolling behavior
    ScrollController scrollController = ScrollController(
      initialScrollOffset: currentHour * 80, // Adjust the scroll offset based on the current hour
    );

    return Container(
      height: 150,
      child: Center(
        child: ListView.builder(
          controller: scrollController, // Assign the controller to the ListView
          scrollDirection: Axis.horizontal,
          itemCount: _hour!.length, // Show all hourly weather reports
          itemBuilder: (context, index) {
            var hourData = _hour![index];
            int hour = DateTime.parse(hourData['time']).hour;

            // Adjust index to wrap around to current hour
            int displayHour = (currentHour + index) % 24;

            // Get the formatted hour label
            String hourLabel = displayHour == 0
                ? '12 AM'
                : displayHour > 12
                ? '${displayHour - 12} PM'
                : '$displayHour AM';

            // Determine the icon based on weather condition
            IconData weatherIcon = _getWeatherIcon(hourData['condition']['text']);

            return _buildHourDetails(
              hourLabel,
              weatherIcon, // Use the determined weather icon
              hourData['condition']['text'],
            );
          },
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {


    return Scaffold(
     body: _currentWeather == null ? Container(
       decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topCenter,
             end: Alignment.bottomCenter,
             colors: [
               Color(0xFF87CEEB), // Sky Blue
               Color(0xFF00BFFF), // Deep Sky Blue
               Color(0xFF1E90FF), // Dodger Blue
               Color(0xFF007FFF), // Azure

             ],
         )
       ),
       child: Center(
         child: CircularProgressIndicator(
           color: Colors.white,
         ),
       ),
     ) : Container(
       padding: EdgeInsets.all(20),
       decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topCenter,
             end: Alignment.bottomCenter,
               colors: [

                 Color(0xFF87CEEB), // Sky Blue
                 Color(0xFF00BFFF), // Deep Sky Blue
                 Color(0xFF1E90FF), // Dodger Blue
                 Color(0xFF007FFF), // Azure


               ],

           )
       ),
       child: ListView(
         children: [
           SizedBox(height: 10),
           InkWell(
             onTap: _showCitySelectionDialog,
             child: Row(
               children: [
                 Text(
                   _city,
                   style: GoogleFonts.lato(
                     fontSize: 36,
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 SizedBox(width: 10), // Add some spacing between text and icon
                 Icon(Icons.location_on, color: Colors.red, size: 30),
               ],
             ),
           ),

           SizedBox(height: 30,),
           Center(
             child: Column(
               children: [
                 Image.network('http:${_currentWeather!['current']['condition']['icon']}',
                   height: 100,
                   width: 100,
                   fit: BoxFit.cover,
                 ),
                 Text('${_currentWeather!['current']['temp_c'].round()}°C',
                 style: GoogleFonts.lato(
                   fontSize: 36,
                   color: Colors.white,
                   fontWeight: FontWeight.bold,
                 ),
                 ),
                 Text('${_currentWeather!['current']['condition']['text']}°C',
                   style: GoogleFonts.lato(
                     fontSize: 36,
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 SizedBox(height: 10,),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                     Text( 'Max:${_currentWeather!['forecast']['forecastday'][0]['day']['maxtemp_c'].round()}°C',
                       style: GoogleFonts.lato(
                         fontSize: 22,
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     Text( 'Min:${_currentWeather!['forecast']['forecastday'][0]['day']['mintemp_c'].round()}°C',
                       style: GoogleFonts.lato(
                         fontSize: 22,
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                       ),
                     ),

                   ],
                 )
               ],
             ),
           ),
           SizedBox(height: 30),

           // Hourly Cloud Report Section
           Text(
             'Hourly Cloud Report',
             style: GoogleFonts.lato(
               fontSize: 22,
               color: Colors.white,
               fontWeight: FontWeight.bold,
             ),
           ),
           SizedBox(height: 10),
           _buildHourlyCloudReport(),

           SizedBox(height: 45),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children:[
               _buildWeatherDetails('sunrise',
                   Icons.wb_sunny,
                   _currentWeather!['forecast']['forecastday'][0]
                   ['astro']['sunrise']
               ),
               _buildWeatherDetails('sunset',
                   Icons.brightness_3,
                   _currentWeather!['forecast']['forecastday'][0]
                   ['astro']['sunset']
               ),

             ]
           ),
           SizedBox(height: 20),
           Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children:[
                 _buildWeatherDetails('humidity',
                     Icons.opacity,
                     _currentWeather!['current']['humidity']
                 ),
                 _buildWeatherDetails('Wind(KPM)',
                     Icons.wind_power,
                     _currentWeather!['current']['wind_kph']
                 ),

               ]
           ),
           SizedBox(height: 20),
           Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children:[
                 _buildWeatherDetails('Feelslike',
                     Icons.thermostat,
                     _currentWeather!['current']['feelslike_c']
                 ),
                 _buildWeatherDetails('UV',
                     Icons.sunny,
                     _currentWeather!['current']['uv']
                 ),

               ]
           ),
           SizedBox(height: 20),
           Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children:[
                 _buildWeatherDetails('Preasure',
                     Icons.speed,
                     _currentWeather!['current']['pressure_in']
                 ),
                 _buildWeatherDetails('Visibility',
                     Icons.remove_red_eye,
                     _currentWeather!['current']['vis_km']
                 ),

               ]
           ),

           SizedBox(height: 40),
           Center(
             child: ElevatedButton(onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (context)=> ForecastScreen(city: _city, ),));
             },
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.transparent
               ),
               child: Text('Next 3 days forecast',
                 style: GoogleFonts.lato(
                   fontSize: 18,
                   color: Colors.white,

                 ),),
           )
     )],
       ),
     ),
    );
  }
}
Widget _buildWeatherDetails(String Label, IconData icon, dynamic value){
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: ClipRect(
        child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
    child: Container(
      padding: EdgeInsets.all(5),
      height: 130,
      width: 110,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
    gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A2344).withOpacity(0.5),
      Color(0xFF1A2344).withOpacity(0.2),
    ],
    )
    ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white,),
          SizedBox(height: 10,),
          Text( Label, style: GoogleFonts.lato(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),),
          SizedBox(height: 10,),
          Text( value is String ? value : value.toString(),
            style: GoogleFonts.lato(
            fontSize: 18,
            color: Colors.white,
          ),),

        ],
      ),

    ),
    )
    ),
  );
}
Widget _buildHourDetails(String label, IconData icon, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          padding: EdgeInsets.all(5),
          height: 80,
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A2344).withOpacity(0.5),
                Color(0xFF1A2344).withOpacity(0.2),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Add this to center text horizontally
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center, // Ensure text is centered horizontally
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                value,
                textAlign: TextAlign.center, // Ensure text is centered horizontally
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
