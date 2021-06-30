import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_calendar/device_calendar.dart';

double airTemp = 0, airHum = 0, soil1 = 0, soil2 = 0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final DeviceCalendarPlugin plugin = DeviceCalendarPlugin();

List<Event> events;

Socket socket;

Future<void> showNotification(
    String title, String body, String payload, bool isImportant) async {
  Importance importance;
  Priority priority;
  if (isImportant) {
    importance = Importance.max;
    priority = Priority.high;
  } else {
    importance = Importance.min;
    priority = Priority.low;
  }
  final AndroidNotificationDetails androidPlatformCha =
      AndroidNotificationDetails('id', 'name', 'description',
          importance: importance, priority: priority, showWhen: false);
  final NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformCha);
  await flutterLocalNotificationsPlugin
      .show(0, title, body, platformChannelSpecifics, payload: payload);
}

Map<DateTime, dynamic> decodeMap(Map<String, dynamic> map) {
  final Map<DateTime, dynamic> newMap = <DateTime, dynamic>{};
  // ignore: always_specify_types
  map.forEach((String key, value) {
    newMap[DateTime.parse(key)] = map[key];
  });
  return newMap;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
    if (payload != null) {
      if (payload == 'cancelIrrigation') {
        socket.writeln('cancelIrrigation');
        await showNotification('Done!', 'Irrigation was Canceled', null, true);
      }
    }
  });
  await plugin.requestPermissions();
  final Result<UnmodifiableListView<Calendar>> calendars =
      await plugin.retrieveCalendars();
  final RetrieveEventsParams params = RetrieveEventsParams(
      startDate: DateTime(2021, 6, 4), endDate: DateTime(2021, 10, 4));
  final Result<UnmodifiableListView<Event>> eventsInst =
      await plugin.retrieveEvents(calendars.data.elementAt(0).id, params);
  events = <Event>[];
  for (int i = 0; i < eventsInst.data.length; ++i) {
    events.add(eventsInst.data[i]);
  }
  try {
    socket = await Socket.connect('192.168.1.4', 80);
  } on Exception catch (_) {}
  runApp(const App());
}

class App extends StatelessWidget {
  const App({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays(
        <SystemUiOverlay>[SystemUiOverlay.bottom]);
    SystemChrome.setPreferredOrientations(
        <DeviceOrientation>[DeviceOrientation.portraitUp]);
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    socket.listen((Uint8List inStream) async {
      final String dataStr =
          utf8.decode(inStream).replaceAll('\n', '').replaceAll('\r', '');
      final List<String> data = dataStr.split(',');
      if (dataStr == 'Irrigation Time') {
        final DateTime now = DateTime.now();
        final List<Event> fma = <Event>[];
        for (int i = 0; i < events.length; ++i) {
          if (events[i].start.isAfter(now) && events[i].end.isAfter(now)) {
            if (events[i].start.difference(now).inMinutes <= 5) {
              fma.add(events[i]);
            }
          }
        }
        if (fma.isNotEmpty) {
          final StringBuffer eventsName = StringBuffer();
          for (final Event event in fma) {
            eventsName.write('$event.title\n');
          }
          await showNotification(
              'Hi Boss!',
              'Now is time to irrigation '
                  'and you have this events : \n$eventsName '
                  'if you want to cancel it click here.',
              'cancelIrrigation',
              true);
        } else {
          await showNotification(
              'Hi Boss!',
              'Time to irrigation for cancel it click on this notification.',
              'cancelIrrigation',
              false);
        }
      } else {
        setState(() {
          if (data != null) {
            airTemp = double.tryParse(data[0]);
            try {
              if (airTemp > 50) {
                airTemp = 50;
              } else if (airTemp < 0) {
                airTemp = 0;
              }
              // ignore: avoid_catches_without_on_clauses
            } catch (_) {
              airTemp = 0;
            }

            airHum = double.tryParse(data[1]);
            try {
              if (airHum > 100) {
                airHum = 100;
              } else if (airHum < 0) {
                airHum = 0;
              }
              // ignore: avoid_catches_without_on_clauses
            } catch (_) {
              airHum = 0;
            }

            soil1 = double.tryParse(data[2]);
            try {
              if (soil1 > 4096) {
                soil1 = 4096;
              } else if (soil1 < 0) {
                soil1 = 0;
              }
              // ignore: avoid_catches_without_on_clauses
            } catch (_) {
              soil1 = 0;
            }

            soil2 = double.tryParse(data[3]);
            try {
              if (soil2 > 4096) {
                soil2 = 4096;
              } else if (soil2 < 0) {
                soil2 = 0;
              }
              // ignore: avoid_catches_without_on_clauses
            } catch (_) {
              soil2 = 0;
            }
          }
        });
      }
    });
    try {
      Timer.periodic(const Duration(seconds: 2), (Timer timer) async {
        socket.writeln('getData');
      });
    } on Exception catch (_) {}
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Card(
                      margin: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      color: Colors.redAccent,
                      child: Column(
                        // ignore: prefer_const_literals_to_create_immutables
                        children: <Widget>[
                          const Spacer(),
                          Expanded(
                            child: Row(
                              // ignore: prefer_const_literals_to_create_immutables
                              children: <Widget>[
                                const Icon(Icons.thermostat,
                                    color: Colors.white, size: 100),
                                const Spacer(),
                              ],
                            ),
                          ),
                          const Spacer(flex: 3),
                          Expanded(
                            child: Row(
                              // ignore: prefer_const_literals_to_create_immutables
                              children: <Widget>[
                                const Spacer(flex: 2),
                                Text(
                                  '$airTemp °C',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 35,
                                      fontWeight: FontWeight.w900),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Card(
                      margin: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      color: Colors.blueAccent,
                      child: Column(
                        // ignore: prefer_const_literals_to_create_immutables
                        children: <Widget>[
                          const Spacer(),
                          Expanded(
                            child: Row(
                              // ignore: prefer_const_literals_to_create_immutables
                              children: <Widget>[
                                const Icon(Icons.opacity,
                                    color: Colors.white, size: 100),
                                const Spacer(),
                              ],
                            ),
                          ),
                          const Spacer(flex: 3),
                          Expanded(
                            child: Row(
                              // ignore: prefer_const_literals_to_create_immutables
                              children: <Widget>[
                                const Spacer(flex: 2),
                                Text(
                                  '$airHum %',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 35,
                                      fontWeight: FontWeight.w900),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 50, horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      color: Colors.orangeAccent,
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: const <Widget>[
                                Spacer(),
                                Text(
                                  'Soil Humidity <First Plant>',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900),
                                ),
                                Spacer(),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(children: <Widget>[
                              const Spacer(),
                              const Icon(Icons.water,
                                  color: Colors.white, size: 100),
                              const Spacer(flex: 8),
                              Text(
                                '$soil1',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 35,
                                    fontWeight: FontWeight.w900),
                              ),
                              const Spacer(flex: 2)
                            ]),
                          ),
                          Expanded(
                            child: Row(children: <Widget>[
                              const Spacer(flex: 8),
                              Text(
                                '${((4096 - soil1) / 40.96).round()} %',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900),
                              ),
                              const Spacer(flex: 2)
                            ]),
                          ),
                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Card(
                      margin: const EdgeInsets.only(
                          left: 20, right: 20, bottom: 100),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      color: Colors.amber,
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: const <Widget>[
                                Spacer(),
                                Text(
                                  'Soil Humidity <Second Plant>',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900),
                                ),
                                Spacer(),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(children: <Widget>[
                              const Spacer(),
                              const Icon(Icons.water,
                                  color: Colors.white, size: 100),
                              const Spacer(flex: 8),
                              Text(
                                '$soil2',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 35,
                                    fontWeight: FontWeight.w900),
                              ),
                              const Spacer(flex: 2)
                            ]),
                          ),
                          Expanded(
                            child: Row(children: <Widget>[
                              const Spacer(flex: 8),
                              Text(
                                '${((4096 - soil2) / 40.96).round()} %',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900),
                              ),
                              const Spacer(flex: 2)
                            ]),
                          ),
                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ));
}
