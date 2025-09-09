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
      List<String> size;
      String unit;
      int v;

      Datum({
          required this.id,
          required this.categoryname,
          required this.size,
          required this.unit,
          required this.v,
      });

      factory Datum.fromJson(Map<String, dynamic> json) => Datum(
          id: json["_id"],
          categoryname: json["categoryname"],
          size: json["size"] == null
              ? <String>[]
              : List<String>.from((json["size"] as List).map((x) => x.toString())),
          unit: (json["unit"] ?? '').toString(),
          v: json["__v"] ?? 0,
      );

      Map<String, dynamic> toJson() => {
          "_id": id,
          "categoryname": categoryname,
          "size": List<dynamic>.from(size.map((x) => x)),
          "unit": unit,
          "__v": v,
      };
  }
