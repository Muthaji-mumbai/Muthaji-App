  // To parse this JSON data, do
  //
  //     final category = categoryFromJson(jsonString);

  import 'dart:convert';

  Category categoryFromJson(String str) => Category.fromJson(json.decode(str));

  String categoryToJson(Category data) => json.encode(data.toJson());

  class Category {
      bool success;
      List<Datum> data;
      String message;

      Category({
          required this.success,
          required this.data,
          required this.message,
      });

      factory Category.fromJson(Map<String, dynamic> json) => Category(
          success: json["success"],
          data: List<Datum>.from(json["data"].map((x) => Datum.fromJson(x))),
          message: json["message"],
      );

      Map<String, dynamic> toJson() => {
          "success": success,
          "data": List<dynamic>.from(data.map((x) => x.toJson())),
          "message": message,
      };
  }

  class Datum {
      String id;
      String categoryname;
      int v;

      Datum({
          required this.id,
          required this.categoryname,
          required this.v,
      });

      factory Datum.fromJson(Map<String, dynamic> json) => Datum(
          id: json["_id"],
          categoryname: json["categoryname"],
          v: json["__v"],
      );

      Map<String, dynamic> toJson() => {
          "_id": id,
          "categoryname": categoryname,
          "__v": v,
      };
  }
