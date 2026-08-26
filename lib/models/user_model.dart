class UserModel {

  final int id;

  final String name;

  final String phone;

  final String email;

  final String photo;

  UserModel({

    required this.id,

    required this.name,

    required this.phone,

    required this.email,

    required this.photo,

  });

  factory UserModel.fromJson(
      Map<String,dynamic> json){

    return UserModel(

      id: int.parse(json["id"].toString()),

      name: json["name"],

      phone: json["phone"],

      email: json["email"],

      photo: json["photo"] ?? "",

    );

  }

}