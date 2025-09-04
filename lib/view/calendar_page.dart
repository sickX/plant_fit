import 'package:flutter/material.dart';
import 'package:plant_fit/main.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  final List<WaterHistory> waterHistory;

  CalendarPage({required this.waterHistory});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<WaterHistory>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _groupEventsByDate();
  }

  void _groupEventsByDate() {
    _events = {};
    for (var history in widget.waterHistory) {
      final day = _formatDateToDay(history.waterDate);
      if (_events[day] == null) {
        _events[day] = [];
      }
      _events[day]!.add(history);
    }
  }

  List<WaterHistory> _getEventsForDay(DateTime? date) {
    String day = _formatDateToDay(date);
    return _events[day] ?? [];
  }

  String _formatDateToDay(DateTime? date) {
    return '${date?.year}-${date?.month.toString().padLeft(2, '0')}-${date?.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('浇水日历'),
      ),
      body: Column(
        children: [
          TableCalendar<WaterHistory>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        events.length.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay);
    
    if (events.isEmpty) {
      return Center(
        child: Text('没有浇水记录'),
      );
    }
    
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          leading: Icon(Icons.water_drop, color: Colors.blue),
          title: Text(DateFormat('HH:mm').format(event.waterDate)),
          subtitle: event.notes.isNotEmpty ? Text(event.notes) : null,
        );
      },
    );
  }
}