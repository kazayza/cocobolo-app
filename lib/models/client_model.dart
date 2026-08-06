class ClientModel {
  final int partyId;
  final String partyName;
  final String? phone;
  final String? phone2;
  final String? address;
  final String? email;

  ClientModel({
    required this.partyId,
    required this.partyName,
    this.phone,
    this.phone2,
    this.address,
    this.email,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      partyId: json['PartyID'] ?? 0,
      partyName: json['PartyName'] ?? '',
      phone: json['Phone'],
      phone2: json['Phone2'],
      address: json['Address'],
      email: json['Email'],
    );
  }
}