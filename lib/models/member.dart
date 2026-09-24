/// A Member in the currently signed-in Admin's own roster — just a name and
/// phone number, with no Firebase Auth login of its own. Distinct from
/// [Person] (the "Person Who Called" directory) and from [AppUser] (a real
/// login account with role Member/Admin/Super Admin).
class Member {
  final String id;
  final String name;
  final String phone;

  const Member({required this.id, required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory Member.fromJson(String id, Map<String, dynamic> json) => Member(
    id: id,
    name: json['name'] as String,
    phone: json['phone'] as String,
  );
}
