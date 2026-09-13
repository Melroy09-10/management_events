/// An event type (e.g. "Wedding") together with the event names that can be
/// picked once that type is selected (e.g. "Wedding Reception"). Stored so
/// new types/names can be added from the Add Event form without a code change.
class EventType {
  final String id;
  final String name;
  final List<String> eventNames;

  const EventType({required this.id, required this.name, required this.eventNames});

  factory EventType.fromJson(String id, Map<String, dynamic> json) => EventType(
        id: id,
        name: json['name'] as String,
        eventNames: List<String>.from(json['eventNames'] as List? ?? const []),
      );
}
