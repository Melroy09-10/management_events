class Person {
  final String id;
  final String name;
  final String phone;

  const Person({required this.id, required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory Person.fromJson(String id, Map<String, dynamic> json) => Person(
        id: id,
        name: json['name'] as String,
        phone: json['phone'] as String,
      );
}
