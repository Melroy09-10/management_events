class EventRecord {
  final String id;
  final String eventTypeId;
  final String eventType;
  final String eventName;
  final String location;
  final double dayAmount;
  final double nightAmount;

  const EventRecord({
    required this.id,
    required this.eventTypeId,
    required this.eventType,
    required this.eventName,
    required this.location,
    required this.dayAmount,
    required this.nightAmount,
  });

  Map<String, dynamic> toJson() => {
        'eventTypeId': eventTypeId,
        'eventType': eventType,
        'eventName': eventName,
        'location': location,
        'dayAmount': dayAmount,
        'nightAmount': nightAmount,
      };

  factory EventRecord.fromJson(String id, Map<String, dynamic> json) => EventRecord(
        id: id,
        eventTypeId: json['eventTypeId'] as String,
        eventType: json['eventType'] as String,
        eventName: json['eventName'] as String,
        location: json['location'] as String,
        dayAmount: (json['dayAmount'] as num).toDouble(),
        nightAmount: (json['nightAmount'] as num).toDouble(),
      );
}
